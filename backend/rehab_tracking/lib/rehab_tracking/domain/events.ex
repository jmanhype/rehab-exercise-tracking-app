defmodule RehabTracking.Domain.Events.SessionStarted do
  @moduledoc """
  Event fired when a new exercise session is started.
  """
  
  @derive Jason.Encoder
  defstruct [
    :session_id,
    :patient_id,
    :exercise_id,
    :started_at,
    :target_sets,
    :target_reps_per_set
  ]
end

defmodule RehabTracking.Domain.Events.SetRecorded do
  @moduledoc """
  Event fired when a set is completed and recorded.
  """
  
  @derive Jason.Encoder
  defstruct [
    :session_id,
    :set_number,
    :reps_completed,
    :quality_score,
    :recorded_at
  ]
end

defmodule RehabTracking.Domain.Events.SessionEnded do
  @moduledoc """
  Event fired when an exercise session is completed or terminated.
  """
  
  @derive Jason.Encoder
  defstruct [
    :session_id,
    :ended_at,
    :completion_status,
    :total_sets,
    :total_reps,
    :average_quality
  ]
end