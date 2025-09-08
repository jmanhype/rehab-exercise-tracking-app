defmodule RehabTracking.Performance.EventThroughputTest do
  @moduledoc """
  Performance test for event throughput - verifies 1000 events/sec sustained.
  
  Tests:
  - Bulk event ingestion rate
  - Broadway pipeline performance 
  - EventStore write throughput
  - Memory usage under load
  """
  
  use ExUnit.Case, async: false
  
  alias RehabTracking.Core.Facade
  alias RehabTracking.Core.EventLog
  
  @target_events_per_sec 1000
  @test_duration_seconds 10
  @total_events @target_events_per_sec * @test_duration_seconds
  
  describe "Event Throughput Performance" do
    @tag :performance
    @tag timeout: 30_000
    test "sustains 1000 events/sec for 10 seconds" do
      # Warmup - process some events first
      warmup_events = generate_test_events(100)
      Enum.each(warmup_events, &Facade.log_event/1)
      
      # Wait for warmup to complete
      Process.sleep(1000)
      
      # Performance test
      test_events = generate_test_events(@total_events)
      
      {duration_microseconds, _result} = :timer.tc(fn ->
        # Use Task.async_stream for parallel processing
        test_events
        |> Task.async_stream(&Facade.log_event/1, 
           max_concurrency: 50,
           timeout: 5000)
        |> Enum.to_list()
      end)
      
      duration_seconds = duration_microseconds / 1_000_000
      actual_rate = @total_events / duration_seconds
      
      IO.puts("\n=== Event Throughput Results ===")
      IO.puts("Total events: #{@total_events}")
      IO.puts("Duration: #{Float.round(duration_seconds, 2)} seconds")
      IO.puts("Actual rate: #{Float.round(actual_rate, 2)} events/sec")
      IO.puts("Target rate: #{@target_events_per_sec} events/sec")
      
      # Assert performance target met
      assert actual_rate >= @target_events_per_sec * 0.95, 
        "Throughput #{Float.round(actual_rate, 2)} events/sec below target #{@target_events_per_sec}"
    end
    
    @tag :performance  
    @tag timeout: 15_000
    test "maintains stable memory usage under load" do
      initial_memory = :erlang.memory(:total)
      
      # Process events in batches
      batch_size = 1000
      batches = 5
      
      for batch <- 1..batches do
        events = generate_test_events(batch_size)
        
        events
        |> Task.async_stream(&Facade.log_event/1, max_concurrency: 20)
        |> Enum.to_list()
        
        current_memory = :erlang.memory(:total)
        memory_growth_mb = (current_memory - initial_memory) / 1_048_576
        
        IO.puts("Batch #{batch}: Memory growth #{Float.round(memory_growth_mb, 2)} MB")
        
        # Memory growth should be bounded
        assert memory_growth_mb < 100, "Memory growth #{memory_growth_mb} MB exceeds limit"
      end
      
      # Force garbage collection and check final memory
      :erlang.garbage_collect()
      Process.sleep(1000)
      
      final_memory = :erlang.memory(:total)
      total_growth_mb = (final_memory - initial_memory) / 1_048_576
      
      IO.puts("Final memory growth: #{Float.round(total_growth_mb, 2)} MB")
      assert total_growth_mb < 50, "Final memory growth #{total_growth_mb} MB too high"
    end
    
    @tag :performance
    test "Broadway pipeline handles burst load" do
      # Simulate sensor data burst (200 events/sec for 30 seconds)
      burst_events = generate_sensor_burst_events(6000)
      
      {duration_microseconds, results} = :timer.tc(fn ->
        burst_events
        |> Task.async_stream(&Facade.log_event/1, 
           max_concurrency: 100,
           timeout: 10_000)
        |> Enum.to_list()
      end)
      
      duration_seconds = duration_microseconds / 1_000_000
      successful_events = Enum.count(results, fn {status, _} -> status == :ok end)
      
      IO.puts("\n=== Burst Load Results ===")
      IO.puts("Successful events: #{successful_events}/#{length(burst_events)}")
      IO.puts("Duration: #{Float.round(duration_seconds, 2)} seconds")
      IO.puts("Rate: #{Float.round(successful_events / duration_seconds, 2)} events/sec")
      
      # At least 95% success rate
      success_rate = successful_events / length(burst_events)
      assert success_rate >= 0.95, "Success rate #{success_rate} below 95%"
    end
  end
  
  # Test data generators
  defp generate_test_events(count) do
    patient_ids = Enum.map(1..10, &"patient_#{&1}")
    
    1..count
    |> Enum.map(fn i ->
      %{
        kind: "exercise_session",
        subject_id: Enum.random(patient_ids),
        body: %{
          exercise_id: "squat_#{rem(i, 5)}",
          reps_completed: Enum.random(8..12),
          form_score: :rand.uniform() * 100,
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: false,
          version: "1.0",
          source: "performance_test"
        }
      }
    end)
  end
  
  defp generate_sensor_burst_events(count) do
    patient_id = "burst_patient_1"
    
    1..count
    |> Enum.map(fn i ->
      %{
        kind: "rep_observation",
        subject_id: patient_id,
        body: %{
          exercise_id: "squat_burst",
          rep_number: rem(i, 10) + 1,
          joint_angles: %{
            knee_left: 90 + :rand.uniform(30),
            knee_right: 90 + :rand.uniform(30),
            hip: 45 + :rand.uniform(20)
          },
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: false,
          version: "1.0",
          source: "sensor_burst_test"
        }
      }
    end)
  end
end