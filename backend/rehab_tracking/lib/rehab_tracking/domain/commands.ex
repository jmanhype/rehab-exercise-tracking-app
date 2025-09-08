defmodule RehabTracking.Domain.Commands.StartSession do
  @moduledoc """
  Command to start a new exercise session.
  """
  
  @enforce_keys [:session_id, :patient_id, :exercise_id]
  defstruct [
    :session_id,
    :patient_id,
    :exercise_id,
    :started_at,
    :target_sets,
    :target_reps_per_set
  ]
end

defmodule RehabTracking.Domain.Commands.RecordSet do
  @moduledoc """
  Command to record a completed set within an exercise session.
  """
  
  @enforce_keys [:session_id, :set_number, :reps_completed]
  defstruct [
    :session_id,
    :set_number,
    :reps_completed,
    :quality_score,
    :recorded_at
  ]
end

defmodule RehabTracking.Domain.Commands.EndSession do
  @moduledoc """
  Command to end an active exercise session.
  """
  
  @enforce_keys [:session_id]
  defstruct [
    :session_id,
    :ended_at,
    :completion_status,
    :total_sets,
    :total_reps,
    :average_quality
  ]
end