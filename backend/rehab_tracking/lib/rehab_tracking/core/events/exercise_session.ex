defmodule RehabTracking.Core.Events.ExerciseSession do
  @moduledoc """
  Event representing an exercise session performed by a patient.
  Records the start/end of an exercise session with contextual metadata.
  """

  @derive Jason.Encoder
  defstruct [
    :session_id,
    :patient_id,
    :exercise_id,
    :exercise_name,
    :started_at,
    :ended_at,
    :duration_seconds,
    :total_reps_planned,
    :total_reps_completed,
    :session_status,  # :started, :completed, :abandoned
    :device_info,
    :app_version,
    :metadata
  ]

  @type t :: %__MODULE__{
    session_id: String.t(),
    patient_id: String.t(),
    exercise_id: String.t(),
    exercise_name: String.t(),
    started_at: DateTime.t(),
    ended_at: DateTime.t() | nil,
    duration_seconds: non_neg_integer() | nil,
    total_reps_planned: non_neg_integer(),
    total_reps_completed: non_neg_integer(),
    session_status: :started | :completed | :abandoned,
    device_info: map() | nil,
    app_version: String.t() | nil,
    metadata: map() | nil
  }

  @doc """
  Creates a new exercise session event.
  """
  def new(attrs) do
    %__MODULE__{
      session_id: attrs.session_id,
      patient_id: attrs.patient_id,
      exercise_id: attrs.exercise_id,
      exercise_name: attrs.exercise_name,
      started_at: attrs.started_at || DateTime.utc_now(),
      ended_at: attrs[:ended_at],
      duration_seconds: attrs[:duration_seconds],
      total_reps_planned: attrs.total_reps_planned || 0,
      total_reps_completed: attrs.total_reps_completed || 0,
      session_status: attrs.session_status || :started,
      device_info: attrs[:device_info],
      app_version: attrs[:app_version],
      metadata: attrs[:metadata] || %{}
    }
  end

  @doc """
  Validates the exercise session event structure.
  """
  def valid?(%__MODULE__{} = event) do
    not is_nil(event.session_id) and
    not is_nil(event.patient_id) and
    not is_nil(event.exercise_id) and
    not is_nil(event.started_at) and
    event.session_status in [:started, :completed, :abandoned]
  end

  def valid?(_), do: false
end