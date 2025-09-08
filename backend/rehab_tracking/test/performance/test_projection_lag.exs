defmodule RehabTracking.Performance.ProjectionLagTest do
  @moduledoc """
  Performance test for projection lag - verifies <100ms eventual consistency.
  
  Tests:
  - Event to projection propagation time
  - Projection rebuild performance
  - Query response times under load
  - Concurrent read/write performance
  """
  
  use ExUnit.Case, async: false
  
  alias RehabTracking.Core.Facade
  alias RehabTracking.Core.Projectors.{Adherence, Quality, WorkQueue}
  
  @max_projection_lag_ms 100
  @projection_timeout 5000
  
  describe "Projection Lag Performance" do
    @tag :performance
    @tag timeout: 10_000
    test "adherence projection updates within 100ms" do
      patient_id = "lag_test_patient_#{:rand.uniform(10000)}"
      
      # Log exercise session event
      event = %{
        kind: "exercise_session",
        subject_id: patient_id,
        body: %{
          exercise_id: "squat_adherence",
          reps_completed: 10,
          form_score: 85.5,
          timestamp: DateTime.utc_now(),
          session_duration: 300
        },
        meta: %{
          phi: false,
          version: "1.0",
          test_marker: "lag_test_#{System.system_time(:millisecond)}"
        }
      }
      
      # Record timestamp before event
      event_time = System.monotonic_time(:millisecond)
      
      {:ok, _} = Facade.log_event(event)
      
      # Poll for projection update
      projection_time = poll_for_projection_update(
        patient_id,
        event.meta.test_marker,
        event_time
      )
      
      lag_ms = projection_time - event_time
      
      IO.puts("\n=== Adherence Projection Lag ===")
      IO.puts("Event logged at: #{event_time}")
      IO.puts("Projection updated at: #{projection_time}")
      IO.puts("Lag: #{lag_ms} ms")
      
      assert lag_ms <= @max_projection_lag_ms, 
        "Projection lag #{lag_ms}ms exceeds limit #{@max_projection_lag_ms}ms"
    end
    
    @tag :performance
    @tag timeout: 15_000
    test "quality projection handles concurrent updates" do
      patient_id = "concurrent_test_patient"
      concurrent_events = 50
      
      # Create concurrent events
      events = Enum.map(1..concurrent_events, fn i ->
        %{
          kind: "rep_observation",
          subject_id: patient_id,
          body: %{
            exercise_id: "concurrent_squat",
            rep_number: i,
            form_score: 70 + :rand.uniform(30),
            timestamp: DateTime.utc_now()
          },
          meta: %{
            phi: false,
            version: "1.0",
            concurrent_batch: "batch_#{System.system_time(:millisecond)}"
          }
        }
      end)
      
      # Log all events concurrently
      start_time = System.monotonic_time(:millisecond)
      
      results = events
      |> Task.async_stream(&Facade.log_event/1, max_concurrency: 20)
      |> Enum.to_list()
      
      # Wait for all projections to update
      Process.sleep(200)
      
      # Check quality projection consistency
      {:ok, quality_data} = Facade.project(:quality, 
        patient_id: patient_id,
        exercise_id: "concurrent_squat"
      )
      
      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time
      
      IO.puts("\n=== Concurrent Quality Updates ===")
      IO.puts("Events processed: #{length(results)}")
      IO.puts("Total time: #{total_time} ms")
      IO.puts("Quality entries: #{length(quality_data.form_scores || [])}")
      
      # Verify all events processed
      success_count = Enum.count(results, fn {status, _} -> status == :ok end)
      assert success_count == concurrent_events, 
        "Only #{success_count}/#{concurrent_events} events processed"
      
      # Verify projection consistency
      assert length(quality_data.form_scores || []) >= concurrent_events * 0.95,
        "Projection missing events: got #{length(quality_data.form_scores || [])}, expected ~#{concurrent_events}"
    end
    
    @tag :performance
    test "work queue projection maintains priority ordering under load" do
      therapist_id = "load_test_therapist"
      
      # Create alerts with different priorities
      high_priority_events = create_priority_events(therapist_id, "high", 10)
      medium_priority_events = create_priority_events(therapist_id, "medium", 20)
      low_priority_events = create_priority_events(therapist_id, "low", 30)
      
      all_events = Enum.shuffle(high_priority_events ++ medium_priority_events ++ low_priority_events)
      
      # Log events concurrently
      start_time = System.monotonic_time(:millisecond)
      
      all_events
      |> Task.async_stream(&Facade.log_event/1, max_concurrency: 15)
      |> Enum.to_list()
      
      # Wait for work queue projection
      Process.sleep(300)
      
      # Verify work queue ordering
      {:ok, work_queue} = Facade.project(:work_queue, therapist_id: therapist_id)
      
      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time
      
      IO.puts("\n=== Work Queue Priority Test ===")
      IO.puts("Total events: #{length(all_events)}")
      IO.puts("Processing time: #{processing_time} ms")
      IO.puts("Queue items: #{length(work_queue.items || [])}")
      
      # Verify priority ordering (high priority items should come first)
      queue_items = work_queue.items || []
      high_items = Enum.filter(queue_items, fn item -> item.priority == "high" end)
      
      # First 10 items should be high priority (allowing for some eventual consistency)
      top_items = Enum.take(queue_items, 10)
      high_in_top = Enum.count(top_items, fn item -> item.priority == "high" end)
      
      assert high_in_top >= 8, 
        "Only #{high_in_top}/10 high priority items in top positions"
      
      assert processing_time <= 500, 
        "Work queue processing took #{processing_time}ms, expected <500ms"
    end
    
    @tag :performance
    test "projection rebuild performance from event stream" do
      patient_id = "rebuild_test_patient"
      
      # Create historical events (simulating existing data)
      historical_events = create_historical_events(patient_id, 1000)
      
      # Log historical events
      historical_events
      |> Task.async_stream(&Facade.log_event/1, max_concurrency: 50)
      |> Enum.to_list()
      
      # Wait for initial projections
      Process.sleep(2000)
      
      # Measure projection rebuild time
      rebuild_start = System.monotonic_time(:millisecond)
      
      # Simulate projection rebuild (this would normally be done by projection restart)
      {:ok, _} = Facade.project(:adherence, 
        patient_id: patient_id, 
        rebuild: true,
        window: :all_time
      )
      
      rebuild_end = System.monotonic_time(:millisecond)
      rebuild_time = rebuild_end - rebuild_start
      
      IO.puts("\n=== Projection Rebuild Performance ===")
      IO.puts("Historical events: #{length(historical_events)}")
      IO.puts("Rebuild time: #{rebuild_time} ms")
      IO.puts("Events/sec: #{Float.round(length(historical_events) / (rebuild_time / 1000), 2)}")
      
      # Rebuild should complete within reasonable time
      assert rebuild_time <= 5000, 
        "Projection rebuild took #{rebuild_time}ms for #{length(historical_events)} events"
      
      # Verify rebuild rate (should process at least 500 events/sec)
      events_per_sec = length(historical_events) / (rebuild_time / 1000)
      assert events_per_sec >= 500, 
        "Rebuild rate #{Float.round(events_per_sec, 2)} events/sec below 500"
    end
  end
  
  # Helper functions
  defp poll_for_projection_update(patient_id, test_marker, start_time, attempts \\ 0) do
    if attempts >= 50 do
      raise "Projection update timeout after #{attempts} attempts"
    end
    
    case Facade.project(:adherence, patient_id: patient_id) do
      {:ok, data} ->
        # Check if our test event is reflected in the projection
        if projection_contains_marker?(data, test_marker) do
          System.monotonic_time(:millisecond)
        else
          Process.sleep(2)
          poll_for_projection_update(patient_id, test_marker, start_time, attempts + 1)
        end
      
      {:error, _} ->
        Process.sleep(2)
        poll_for_projection_update(patient_id, test_marker, start_time, attempts + 1)
    end
  end
  
  defp projection_contains_marker?(%{sessions: sessions}, test_marker) when is_list(sessions) do
    Enum.any?(sessions, fn session ->
      session.meta && String.contains?(session.meta["test_marker"] || "", test_marker)
    end)
  end
  defp projection_contains_marker?(_, _), do: false
  
  defp create_priority_events(therapist_id, priority, count) do
    Enum.map(1..count, fn i ->
      %{
        kind: "alert",
        subject_id: "patient_#{priority}_#{i}",
        body: %{
          alert_type: "form_degradation",
          severity: priority,
          message: "Form quality below threshold",
          therapist_id: therapist_id,
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: false,
          version: "1.0",
          priority: priority
        }
      }
    end)
  end
  
  defp create_historical_events(patient_id, count) do
    base_time = DateTime.add(DateTime.utc_now(), -86400 * 30, :second) # 30 days ago
    
    Enum.map(1..count, fn i ->
      timestamp = DateTime.add(base_time, i * 60, :second) # One per minute
      
      %{
        kind: Enum.random(["exercise_session", "rep_observation", "feedback"]),
        subject_id: patient_id,
        body: %{
          exercise_id: "historical_#{rem(i, 5)}",
          data: %{value: i},
          timestamp: timestamp
        },
        meta: %{
          phi: false,
          version: "1.0",
          historical: true
        }
      }
    end)
  end
end