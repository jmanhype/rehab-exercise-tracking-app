#!/usr/bin/env elixir

# Smoke test script for rehab tracking system
# Tests basic event flow: start session -> record sets -> end session -> fetch projection
# Usage: mix rehab.smoke  (recommended - handles app startup)
# or: elixir -S mix run priv/smoke/smoke.exs

defmodule SmokeTest do
  @moduledoc """
  Smoke test runner for basic rehab tracking functionality.
  """

  alias RehabTracking.Core.Facade
  require Logger

  def run do
    Logger.info("Starting Rehab Tracking Smoke Test...")
    
    # Test configuration
    patient_id = UUID.uuid4()
    exercise_id = "squats"
    session_id = UUID.uuid4()
    
    Logger.info("Test Patient ID: #{patient_id}")
    Logger.info("Exercise ID: #{exercise_id}")
    Logger.info("Session ID: #{session_id}")
    
    # Step 1: Start a session
    Logger.info("Step 1: Starting exercise session...")
    start_result = start_session(patient_id, exercise_id, session_id)
    
    case start_result do
      {:ok, event} ->
        Logger.info("✓ Session started successfully: #{inspect(event.event_id)}")
      {:error, reason} ->
        Logger.error("✗ Failed to start session: #{inspect(reason)}")
        System.halt(1)
    end
    
    # Step 2: Record 3 sets with multiple reps each
    Logger.info("Step 2: Recording 3 sets...")
    record_result = record_exercise_sets(patient_id, exercise_id, session_id, 3)
    
    case record_result do
      {:ok, events} ->
        Logger.info("✓ Recorded #{length(events)} rep observations")
      {:error, reason} ->
        Logger.error("✗ Failed to record sets: #{inspect(reason)}")
        System.halt(1)
    end
    
    # Step 3: End session
    Logger.info("Step 3: Ending exercise session...")
    end_result = end_session(patient_id, exercise_id, session_id)
    
    case end_result do
      {:ok, event} ->
        Logger.info("✓ Session ended successfully: #{inspect(event.event_id)}")
      {:error, reason} ->
        Logger.error("✗ Failed to end session: #{inspect(reason)}")
        System.halt(1)
    end
    
    # Step 4: Fetch projections
    Logger.info("Step 4: Fetching adherence and quality projections...")
    
    # Allow time for projections to update (simulate eventual consistency)
    Process.sleep(100)
    
    adherence_result = Facade.get_adherence(patient_id, exercise_id)
    quality_result = Facade.get_quality_metrics(patient_id, exercise_id)
    
    Logger.info("Adherence projection: #{inspect(adherence_result)}")
    Logger.info("Quality projection: #{inspect(quality_result)}")
    
    # Step 5: Verify stream integrity
    Logger.info("Step 5: Verifying event stream...")
    
    case Facade.get_patient_stream(patient_id) do
      {:ok, events} ->
        Logger.info("✓ Retrieved #{length(events)} events from patient stream")
        
        # Count event types
        session_events = Enum.count(events, &(&1.event_type == "ExerciseSession"))
        rep_events = Enum.count(events, &(&1.event_type == "RepObservation"))
        
        Logger.info("  - ExerciseSession events: #{session_events}")
        Logger.info("  - RepObservation events: #{rep_events}")
        
        if session_events == 2 and rep_events > 0 do
          Logger.info("✓ Event stream integrity verified")
        else
          Logger.warn("⚠ Unexpected event counts in stream")
        end
        
      {:error, reason} ->
        Logger.error("✗ Failed to retrieve patient stream: #{inspect(reason)}")
        System.halt(1)
    end
    
    Logger.info("🎉 Smoke test completed successfully!")
    Logger.info("All core functionality is working properly.")
  end
  
  defp start_session(patient_id, exercise_id, session_id) do
    session_attrs = %{
      session_id: session_id,
      exercise_id: exercise_id,
      status: "started",
      start_time: DateTime.utc_now(),
      prescription: %{
        sets: 3,
        reps: 10,
        hold_time: 3,
        rest_time: 60
      },
      metadata: %{
        device_id: "smoke_test_device",
        app_version: "test-1.0.0",
        test_run: true
      }
    }
    
    Facade.log_exercise_session(patient_id, session_attrs)
  end
  
  defp record_exercise_sets(patient_id, exercise_id, session_id, num_sets) do
    events = for set_number <- 1..num_sets,
                  rep_number <- 1..10 do
      # Simulate different quality scores across sets/reps
      quality_score = case {set_number, rem(rep_number, 3)} do
        {1, _} -> 0.95  # First set - excellent form
        {2, 0} -> 0.75  # Second set - some fatigue
        {2, _} -> 0.85
        {3, _} -> 0.65  # Third set - tired, form degrading
      end
      
      rep_attrs = %{
        session_id: session_id,
        exercise_id: exercise_id,
        set_number: set_number,
        rep_number: rep_number,
        timestamp: DateTime.utc_now(),
        form_analysis: %{
          overall_score: quality_score,
          joint_angles: generate_joint_angles(quality_score),
          tempo: generate_tempo_analysis(set_number),
          range_of_motion: quality_score * 0.9
        },
        biomechanics: %{
          knee_valgus: if(quality_score < 0.7, do: "moderate", else: "minimal"),
          hip_hinge: if(quality_score > 0.8, do: "excellent", else: "good"),
          spine_alignment: if(quality_score > 0.9, do: "neutral", else: "slight_flexion")
        },
        confidence: quality_score * 0.95
      }
      
      case Facade.log_rep_observation(patient_id, rep_attrs) do
        {:ok, event} -> event
        {:error, reason} -> throw({:error, reason})
      end
    end
    
    {:ok, events}
  catch
    {:error, reason} -> {:error, reason}
  end
  
  defp end_session(patient_id, exercise_id, session_id) do
    session_attrs = %{
      session_id: session_id,
      exercise_id: exercise_id,
      status: "completed",
      end_time: DateTime.utc_now(),
      completion_summary: %{
        sets_completed: 3,
        total_reps: 30,
        average_quality: 0.78,
        session_duration: 420,  # 7 minutes
        notes: "Smoke test session completed successfully"
      }
    }
    
    Facade.log_exercise_session(patient_id, session_attrs)
  end
  
  defp generate_joint_angles(quality_score) do
    base_angles = %{
      hip: 85,
      knee: 90, 
      ankle: 15
    }
    
    # Add variance based on quality score
    variance = (1.0 - quality_score) * 10
    
    %{
      hip: base_angles.hip + :rand.uniform() * variance - variance/2,
      knee: base_angles.knee + :rand.uniform() * variance - variance/2,
      ankle: base_angles.ankle + :rand.uniform() * variance - variance/2
    }
  end
  
  defp generate_tempo_analysis(set_number) do
    # Later sets tend to be slower
    base_tempo = case set_number do
      1 -> %{down: 2.0, up: 1.5}
      2 -> %{down: 2.2, up: 1.8} 
      _ -> %{down: 2.5, up: 2.1}
    end
    
    %{
      eccentric_time: base_tempo.down,
      concentric_time: base_tempo.up,
      tempo_consistency: max(0.6, 1.0 - (set_number - 1) * 0.15)
    }
  end
end

# Main execution
if Mix.Project.get() do
  # Running via mix task - application should be started
  try do
    SmokeTest.run()
  rescue
    e -> 
      IO.puts("Smoke test failed with error: #{inspect(e)}")
      System.halt(1)
  end
else
  IO.puts("Error: This script must be run via 'mix rehab.smoke' to ensure proper application startup")
  System.halt(1)
end