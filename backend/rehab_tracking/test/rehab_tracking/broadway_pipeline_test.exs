defmodule RehabTracking.BroadwayPipelineTest do
  use ExUnit.Case
  
  alias RehabTracking.BroadwayPipeline
  
  describe "Broadway Pipeline" do
    test "pipeline configuration is correct" do
      config = BroadwayPipeline.metrics()
      
      assert config.config.producers == 2
      assert config.config.processors == 10  
      assert config.config.batchers == 2
      assert config.config.batch_size == 100
      assert config.config.batch_timeout == 1000
      assert config.target_throughput == "1000 events/sec"
    end
    
    test "health check returns status" do
      # Note: In test env, Broadway may not be started
      # So we just test the structure
      case BroadwayPipeline.health_check() do
        {:ok, status} ->
          assert Map.has_key?(status, :status)
          assert Map.has_key?(status, :producers)
          
        {:error, :no_producers} ->
          # Expected in test environment
          assert true
          
        {:error, status} ->
          assert Map.has_key?(status, :status)
          assert Map.has_key?(status, :producers)
      end
    end
  end
  
  describe "Event Processing" do
    test "handle_message processes exercise session events" do
      event_data = %{
        "kind" => "exercise_session",
        "subject_id" => "test_patient_123",
        "body" => %{
          "duration_minutes" => 20,
          "quality_score" => 0.8,
          "exercise_type" => "squats"
        },
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      message = %Broadway.Message{
        data: Jason.encode!(event_data),
        acknowledger: Broadway.NoopAcknowledger.init()
      }
      
      # This should not crash
      result = BroadwayPipeline.handle_message(:default, message, %{})
      assert %Broadway.Message{} = result
    end
    
    test "handle_message processes rep observation events" do
      event_data = %{
        "kind" => "rep_observation",
        "subject_id" => "test_patient_123",
        "body" => %{
          "rep_number" => 5,
          "rep_quality" => 0.7,
          "form_errors" => ["knee_alignment"]
        },
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      message = %Broadway.Message{
        data: Jason.encode!(event_data),
        acknowledger: Broadway.NoopAcknowledger.init()
      }
      
      result = BroadwayPipeline.handle_message(:default, message, %{})
      assert %Broadway.Message{} = result
    end
    
    test "handle_batch processes multiple events" do
      events = [
        %{
          "kind" => "exercise_session",
          "subject_id" => "test_patient_123",
          "body" => %{"duration_minutes" => 15}
        },
        %{
          "kind" => "rep_observation", 
          "subject_id" => "test_patient_123",
          "body" => %{"rep_quality" => 0.6}
        }
      ]
      
      messages = Enum.map(events, fn event ->
        %Broadway.Message{
          data: Jason.encode!(event),
          acknowledger: Broadway.NoopAcknowledger.init()
        }
      end)
      
      batch_info = %{batch_key: :default}
      
      result = BroadwayPipeline.handle_batch(:default, messages, batch_info, %{})
      assert is_list(result)
      assert length(result) == length(messages)
    end
  end
end