defmodule RehabTracking.Integration.SessionLifecycleTest do
  @moduledoc """
  Integration test for the complete session lifecycle:
  Start Session → Record Sets → End Session → Read Projection
  """
  
  use ExUnit.Case
  
  alias RehabTracking.Core.CommandedApp
  alias RehabTracking.Domain.Commands.{StartSession, RecordSet, EndSession}
  alias RehabTracking.Projections.SessionProjection
  alias RehabTracking.Repo
  
  setup do
    # Clean up any existing data
    Repo.delete_all(RehabTracking.Projections.Schemas.Session)
    
    # Generate test IDs
    session_id = "test_session_#{System.unique_integer([:positive])}"
    patient_id = "patient_123"
    exercise_id = "knee_extension"
    
    {:ok, session_id: session_id, patient_id: patient_id, exercise_id: exercise_id}
  end
  
  test "complete session lifecycle", %{session_id: session_id, patient_id: patient_id, exercise_id: exercise_id} do
    # Step 1: Start Session
    start_command = %StartSession{
      session_id: session_id,
      patient_id: patient_id,
      exercise_id: exercise_id,
      started_at: DateTime.utc_now(),
      target_sets: 3,
      target_reps_per_set: 10
    }
    
    {:ok, _} = CommandedApp.dispatch(start_command, consistency: :strong)
    
    # Wait for projection to update
    Process.sleep(100)
    
    # Verify session was created in projection
    session = SessionProjection.get_session(session_id)
    assert session != nil
    assert session.status == "active"
    assert session.patient_id == patient_id
    assert session.exercise_id == exercise_id
    assert session.target_sets == 3
    assert session.total_sets == 0
    
    # Step 2: Record Sets
    for set_num <- 1..3 do
      record_command = %RecordSet{
        session_id: session_id,
        set_number: set_num,
        reps_completed: 10,
        quality_score: 0.85 + (set_num * 0.03),
        recorded_at: DateTime.utc_now()
      }
      
      {:ok, _} = CommandedApp.dispatch(record_command, consistency: :strong)
      Process.sleep(50)
    end
    
    # Verify sets were recorded
    session = SessionProjection.get_session(session_id)
    assert session.total_sets == 3
    assert session.total_reps == 30
    assert length(session.sets) == 3
    assert session.average_quality > 0.85
    
    # Step 3: End Session
    end_command = %EndSession{
      session_id: session_id,
      ended_at: DateTime.utc_now(),
      completion_status: "completed",
      total_sets: 3,
      total_reps: 30,
      average_quality: 0.88
    }
    
    {:ok, _} = CommandedApp.dispatch(end_command, consistency: :strong)
    Process.sleep(100)
    
    # Step 4: Read Final Projection
    final_session = SessionProjection.get_session(session_id)
    assert final_session.status == "ended"
    assert final_session.completion_status == "completed"
    assert final_session.ended_at != nil
    
    # Verify patient sessions query works
    patient_sessions = SessionProjection.get_patient_sessions(patient_id)
    assert length(patient_sessions) > 0
    assert Enum.any?(patient_sessions, &(&1.session_id == session_id))
    
    IO.puts("\n✅ Session Lifecycle Test Passed!")
    IO.puts("   - Session started successfully")
    IO.puts("   - 3 sets recorded with quality scores")
    IO.puts("   - Session ended with completion status")
    IO.puts("   - Projection correctly reflects all changes")
  end
end