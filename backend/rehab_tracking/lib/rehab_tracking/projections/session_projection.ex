defmodule RehabTracking.Projections.SessionProjection do
  @moduledoc """
  Read model projection for exercise sessions.
  Maintains current state of all sessions for efficient querying.
  """

  use Commanded.Projections.Ecto,
    application: RehabTracking.Core.CommandedApp,
    repo: RehabTracking.Repo,
    name: "session_projection"

  import Ecto.Query
  alias RehabTracking.Domain.Events.{SessionStarted, SetRecorded, SessionEnded}
  alias RehabTracking.Projections.Schemas.Session

  project(%SessionStarted{} = event, _metadata, fn multi ->
    session = %{
      session_id: event.session_id,
      patient_id: event.patient_id,
      exercise_id: event.exercise_id,
      status: "active",
      started_at: event.started_at,
      target_sets: event.target_sets,
      target_reps_per_set: event.target_reps_per_set,
      total_sets: 0,
      total_reps: 0,
      average_quality: 0.0,
      sets: [],
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    Ecto.Multi.insert(multi, :session, Session.changeset(%Session{}, session))
  end)

  project(%SetRecorded{} = event, _metadata, fn multi ->
    set_data = %{
      set_number: event.set_number,
      reps_completed: event.reps_completed,
      quality_score: event.quality_score,
      recorded_at: event.recorded_at
    }

    Ecto.Multi.run(multi, :update_session, fn _repo, _changes ->
      case RehabTracking.Repo.get_by(Session, session_id: event.session_id) do
        nil ->
          {:error, :session_not_found}

        session ->
          new_sets = [set_data | session.sets]
          new_total_reps = session.total_reps + event.reps_completed
          new_total_sets = length(new_sets)
          
          # Calculate average quality
          quality_scores = Enum.map(new_sets, & &1.quality_score)
          new_average_quality = Enum.sum(quality_scores) / length(quality_scores)

          updates = %{
            sets: new_sets,
            total_sets: new_total_sets,
            total_reps: new_total_reps,
            average_quality: new_average_quality,
            updated_at: DateTime.utc_now()
          }

          session
          |> Session.changeset(updates)
          |> RehabTracking.Repo.update()
      end
    end)
  end)

  project(%SessionEnded{} = event, _metadata, fn multi ->
    updates = %{
      status: "ended",
      ended_at: event.ended_at,
      completion_status: event.completion_status,
      updated_at: DateTime.utc_now()
    }

    Ecto.Multi.run(multi, :end_session, fn _repo, _changes ->
      case RehabTracking.Repo.get_by(Session, session_id: event.session_id) do
        nil ->
          {:error, :session_not_found}

        session ->
          session
          |> Session.changeset(updates)
          |> RehabTracking.Repo.update()
      end
    end)
  end)

  # Helper functions for querying

  def get_session(session_id) do
    RehabTracking.Repo.get_by(Session, session_id: session_id)
  end

  def get_patient_sessions(patient_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    query = from s in Session,
      where: s.patient_id == ^patient_id,
      order_by: [desc: s.started_at],
      limit: ^limit

    query = if status do
      from s in query, where: s.status == ^status
    else
      query
    end

    RehabTracking.Repo.all(query)
  end

  def get_active_sessions(patient_id) do
    get_patient_sessions(patient_id, status: "active")
  end

  def get_exercise_sessions(patient_id, exercise_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(s in Session,
      where: s.patient_id == ^patient_id and s.exercise_id == ^exercise_id,
      order_by: [desc: s.started_at],
      limit: ^limit
    )
    |> RehabTracking.Repo.all()
  end
end