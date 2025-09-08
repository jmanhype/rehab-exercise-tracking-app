defmodule RehabTracking.Core.Router do
  @moduledoc """
  Commanded router for routing commands to their appropriate aggregates.
  This is the central nervous system that determines which aggregate handles which command.
  """

  use Commanded.Commands.Router

  alias RehabTracking.Domain.ExerciseSession
  alias RehabTracking.Domain.Commands.{StartSession, RecordSet, EndSession}

  identify(ExerciseSession, by: :session_id, prefix: "session-")

  dispatch([StartSession, RecordSet, EndSession],
    to: ExerciseSession,
    identity: :session_id
  )
end