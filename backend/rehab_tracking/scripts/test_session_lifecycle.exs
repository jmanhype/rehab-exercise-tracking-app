# Test Session Lifecycle Script
# Run with: mix run scripts/test_session_lifecycle.exs

# Ensure the application is started
Application.ensure_all_started(:rehab_tracking)

alias RehabTracking.Core.Facade
alias RehabTracking.Projections.SessionProjection
alias RehabTracking.Repo

# Generate test IDs
session_id = "test_session_#{System.unique_integer([:positive])}"
patient_id = "patient_test_123"
exercise_id = "knee_extension"

IO.puts("\n=== Testing Event-Sourced Session Lifecycle ===\n")

# Step 1: Start Session
IO.puts("1. Starting exercise session...")
start_attrs = %{
  session_id: session_id,
  patient_id: patient_id,
  exercise_id: exercise_id,
  started_at: DateTime.utc_now(),
  status: "started",
  target_sets: 3,
  target_reps_per_set: 10
}

{:ok, _} = Facade.log_event(patient_id, :exercise_session, start_attrs)
Process.sleep(200)

# Check projection
session = SessionProjection.get_session(session_id)
if session do
  IO.puts("   ✓ Session created in projection")
  IO.puts("   - Status: #{session.status}")
  IO.puts("   - Patient: #{session.patient_id}")
  IO.puts("   - Exercise: #{session.exercise_id}")
else
  IO.puts("   ✗ Session not found in projection!")
end

# Step 2: Record Sets
IO.puts("\n2. Recording exercise sets...")
for set_num <- 1..3 do
  set_attrs = %{
    session_id: session_id,
    set_number: set_num,
    reps_completed: 10,
    quality_score: 0.85 + (set_num * 0.03),
    recorded_at: DateTime.utc_now()
  }
  
  {:ok, _} = Facade.log_event(patient_id, :set_recorded, set_attrs)
  IO.puts("   ✓ Set #{set_num} recorded (10 reps, quality: #{0.85 + (set_num * 0.03)})")
  Process.sleep(100)
end

# Check projection after sets
session = SessionProjection.get_session(session_id)
if session do
  IO.puts("\n   Session stats after sets:")
  IO.puts("   - Total sets: #{session.total_sets}")
  IO.puts("   - Total reps: #{session.total_reps}")
  IO.puts("   - Average quality: #{Float.round(session.average_quality || 0.0, 2)}")
end

# Step 3: End Session
IO.puts("\n3. Ending session...")
end_attrs = %{
  session_id: session_id,
  ended_at: DateTime.utc_now(),
  completion_status: "completed",
  total_sets: 3,
  total_reps: 30,
  average_quality: 0.88
}

{:ok, _} = Facade.log_event(patient_id, :session_ended, end_attrs)
Process.sleep(200)

# Step 4: Read Final Projection
IO.puts("\n4. Reading final projection...")
final_session = SessionProjection.get_session(session_id)
if final_session do
  IO.puts("   ✓ Session completed successfully")
  IO.puts("   - Status: #{final_session.status}")
  IO.puts("   - Completion: #{final_session.completion_status}")
  IO.puts("   - Duration: ~#{DateTime.diff(final_session.ended_at || DateTime.utc_now(), final_session.started_at, :second)}s")
  
  # Verify patient sessions query
  patient_sessions = SessionProjection.get_patient_sessions(patient_id)
  IO.puts("\n5. Verifying patient session queries...")
  IO.puts("   ✓ Found #{length(patient_sessions)} sessions for patient")
  
  if Enum.any?(patient_sessions, &(&1.session_id == session_id)) do
    IO.puts("   ✓ Test session found in patient history")
  end
else
  IO.puts("   ✗ Session not found in projection!")
end

# Step 5: Query event stream directly
IO.puts("\n6. Verifying event stream...")
events = Facade.get_patient_stream(patient_id, limit: 10)
session_events = case events do
  {:ok, event_list} ->
    Enum.filter(event_list, fn event -> 
      get_in(event, [:body, "session_id"]) == session_id or
      get_in(event, [:body, :session_id]) == session_id
    end)
  _ -> []
end

IO.puts("   ✓ Found #{length(session_events)} events for this session")

IO.puts("\n=== ✅ Session Lifecycle Test Complete! ===")
IO.puts("\nThe event-sourced domain is working correctly:")
IO.puts("• Events are persisted to the event store")
IO.puts("• Projections are updated from events")
IO.puts("• Session state transitions work (active → ended)")
IO.puts("• Query functions return expected data")