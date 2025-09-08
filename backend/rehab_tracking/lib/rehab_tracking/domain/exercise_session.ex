defmodule RehabTracking.Domain.ExerciseSession do
  @moduledoc """
  ExerciseSession aggregate responsible for managing exercise session lifecycle.
  Handles commands for starting sessions, recording sets, and ending sessions.
  """

  defstruct [
    :session_id,
    :patient_id,
    :exercise_id,
    :status,
    :started_at,
    :ended_at,
    :sets,
    :total_reps
  ]

  alias __MODULE__
  alias RehabTracking.Domain.Commands.{StartSession, RecordSet, EndSession}
  alias RehabTracking.Domain.Events.{SessionStarted, SetRecorded, SessionEnded}

  # Command handlers

  def execute(%ExerciseSession{session_id: nil}, %StartSession{} = command) do
    %SessionStarted{
      session_id: command.session_id,
      patient_id: command.patient_id,
      exercise_id: command.exercise_id,
      started_at: command.started_at || DateTime.utc_now(),
      target_sets: command.target_sets,
      target_reps_per_set: command.target_reps_per_set
    }
  end

  def execute(%ExerciseSession{status: :active}, %RecordSet{} = command) do
    %SetRecorded{
      session_id: command.session_id,
      set_number: command.set_number,
      reps_completed: command.reps_completed,
      quality_score: command.quality_score,
      recorded_at: command.recorded_at || DateTime.utc_now()
    }
  end

  def execute(%ExerciseSession{status: :active}, %EndSession{} = command) do
    %SessionEnded{
      session_id: command.session_id,
      ended_at: command.ended_at || DateTime.utc_now(),
      completion_status: command.completion_status,
      total_sets: command.total_sets,
      total_reps: command.total_reps,
      average_quality: command.average_quality
    }
  end

  def execute(%ExerciseSession{session_id: nil}, _command) do
    {:error, :session_not_started}
  end

  def execute(%ExerciseSession{status: :ended}, _command) do
    {:error, :session_already_ended}
  end

  def execute(%ExerciseSession{status: :cancelled}, _command) do
    {:error, :session_cancelled}
  end

  # Event handlers (state changes)

  def apply(%ExerciseSession{} = session, %SessionStarted{} = event) do
    %ExerciseSession{
      session
      | session_id: event.session_id,
        patient_id: event.patient_id,
        exercise_id: event.exercise_id,
        status: :active,
        started_at: event.started_at,
        sets: [],
        total_reps: 0
    }
  end

  def apply(%ExerciseSession{} = session, %SetRecorded{} = event) do
    new_set = %{
      set_number: event.set_number,
      reps_completed: event.reps_completed,
      quality_score: event.quality_score,
      recorded_at: event.recorded_at
    }

    %ExerciseSession{
      session
      | sets: [new_set | session.sets],
        total_reps: session.total_reps + event.reps_completed
    }
  end

  def apply(%ExerciseSession{} = session, %SessionEnded{} = event) do
    %ExerciseSession{
      session
      | status: :ended,
        ended_at: event.ended_at
    }
  end

  # Helper functions

  def current_set_number(%ExerciseSession{sets: sets}) do
    length(sets) + 1
  end

  def session_duration(%ExerciseSession{started_at: started_at, ended_at: ended_at}) 
      when not is_nil(ended_at) do
    DateTime.diff(ended_at, started_at, :second)
  end

  def session_duration(%ExerciseSession{started_at: started_at}) do
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end

  def average_quality_score(%ExerciseSession{sets: []}), do: 0

  def average_quality_score(%ExerciseSession{sets: sets}) do
    quality_scores = Enum.map(sets, & &1.quality_score)
    Enum.sum(quality_scores) / length(quality_scores)
  end
end