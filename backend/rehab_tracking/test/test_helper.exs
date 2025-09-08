# Configure ExUnit for TDD test suites
ExUnit.configure([
  colors: [enabled: true],
  formatters: [ExUnit.CLIFormatter],
  exclude: [],
  seed: 0,
  timeout: 60_000,
  capture_log: true
])

# Start ExUnit
ExUnit.start()

# Configure test database and mocks
# Note: These will need actual implementation after TDD red phase
# Mix.Task.run("ecto.drop", ["--quiet"])
# Mix.Task.run("ecto.create", ["--quiet"])
# Mix.Task.run("ecto.migrate", ["--quiet"])

# Test data factories for consistent test data
defmodule RehabTracking.TestFactory do
  @doc "Generate consistent patient IDs for tests"
  def patient_id(suffix \\ nil) do
    base = "patient_test_#{:rand.uniform(10_000)}"
    if suffix, do: "#{base}_#{suffix}", else: base
  end
  
  @doc "Generate consistent therapist IDs for tests"
  def therapist_id(suffix \\ nil) do
    base = "therapist_test_#{:rand.uniform(1_000)}"
    if suffix, do: "#{base}_#{suffix}", else: base
  end
  
  @doc "Generate valid consent ID"
  def consent_id(patient_id) do
    "consent_active_#{patient_id}"
  end
  
  @doc "Generate exercise session event template"
  def exercise_session_event(patient_id, session_id, overrides \\ %{}) do
    base = %{
      kind: "exercise_session",
      subject_id: patient_id,
      body: %{
        session_id: session_id,
        exercise_id: "squat_basic",
        target_reps: 15,
        started_at: DateTime.utc_now()
      },
      meta: %{
        phi: true,
        consent_id: consent_id(patient_id),
        device: "test_device",
        app_version: "test"
      }
    }
    
    deep_merge(base, overrides)
  end
  
  @doc "Generate rep observation event template"
  def rep_observation_event(patient_id, session_id, rep_number, overrides \\ %{}) do
    base = %{
      kind: "rep_observation",
      subject_id: patient_id,
      body: %{
        session_id: session_id,
        exercise_id: "squat_basic",
        rep_number: rep_number,
        form_score: 0.75 + (:rand.uniform(50) - 25) / 100,  # 0.5-1.0
        joint_angles: %{
          knee: 85 + :rand.uniform(30),
          hip: 80 + :rand.uniform(25),
          ankle: 15 + :rand.uniform(20)
        }
      },
      meta: %{
        phi: true,
        consent_id: consent_id(patient_id),
        ml_confidence: 0.85 + :rand.uniform(15) / 100
      }
    }
    
    deep_merge(base, overrides)
  end
  
  # Deep merge helper for nested maps
  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _k, %{} = v1, %{} = v2 -> deep_merge(v1, v2)
      _k, _v1, v2 -> v2
    end)
  end
end

# Configure test database sandbox
# Note: Uncomment when Ecto repo is implemented
# Ecto.Adapters.SQL.Sandbox.mode(RehabTracking.Repo, :manual)
