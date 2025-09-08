defmodule RehabTrackingWeb.SessionController do
  @moduledoc """
  REST API controller for exercise session management.
  Provides endpoints for the minimal event-sourcing happy path.
  """

  use RehabTrackingWeb, :controller

  alias RehabTracking.Core.CommandedApp
  alias RehabTracking.Domain.Commands.{StartSession, RecordSet, EndSession}
  alias RehabTracking.Projections.SessionProjection

  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  POST /api/sessions
  Start a new exercise session
  """
  def create(conn, %{"session" => session_params}) do
    session_id = UUID.uuid4()
    
    command = %StartSession{
      session_id: session_id,
      patient_id: session_params["patient_id"],
      exercise_id: session_params["exercise_id"],
      started_at: DateTime.utc_now(),
      target_sets: session_params["target_sets"],
      target_reps_per_set: session_params["target_reps_per_set"]
    }

    case CommandedApp.dispatch(command) do
      :ok ->
        # Wait briefly for projection to catch up
        :timer.sleep(100)
        
        case SessionProjection.get_session(session_id) do
          nil ->
            conn
            |> put_status(:accepted)
            |> json(%{session_id: session_id, status: "started"})

          session ->
            conn
            |> put_status(:created)
            |> json(%{
              session_id: session.session_id,
              patient_id: session.patient_id,
              exercise_id: session.exercise_id,
              status: session.status,
              started_at: session.started_at,
              target_sets: session.target_sets,
              target_reps_per_set: session.target_reps_per_set
            })
        end

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to start session", reason: reason})
    end
  end

  @doc """
  POST /api/sessions/:id/sets
  Record a completed set in the session
  """
  def record_set(conn, %{"id" => session_id, "set" => set_params}) do
    command = %RecordSet{
      session_id: session_id,
      set_number: set_params["set_number"],
      reps_completed: set_params["reps_completed"],
      quality_score: set_params["quality_score"] || 0.0,
      recorded_at: DateTime.utc_now()
    }

    case CommandedApp.dispatch(command) do
      :ok ->
        # Wait briefly for projection to catch up
        :timer.sleep(100)
        
        case SessionProjection.get_session(session_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Session not found"})

          session ->
            conn
            |> put_status(:created)
            |> json(%{
              session_id: session.session_id,
              set_number: set_params["set_number"],
              total_sets: session.total_sets,
              total_reps: session.total_reps,
              average_quality: session.average_quality
            })
        end

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to record set", reason: reason})
    end
  end

  @doc """
  POST /api/sessions/:id/finish
  End an active exercise session
  """
  def finish(conn, %{"id" => session_id} = params) do
    # Get current session state to calculate totals
    case SessionProjection.get_session(session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})

      session ->
        command = %EndSession{
          session_id: session_id,
          ended_at: DateTime.utc_now(),
          completion_status: params["completion_status"] || "completed",
          total_sets: session.total_sets,
          total_reps: session.total_reps,
          average_quality: session.average_quality
        }

        case CommandedApp.dispatch(command) do
          :ok ->
            # Wait briefly for projection to catch up
            :timer.sleep(100)
            
            case SessionProjection.get_session(session_id) do
              nil ->
                conn
                |> put_status(:accepted)
                |> json(%{session_id: session_id, status: "ended"})

              updated_session ->
                duration_seconds = if updated_session.ended_at && updated_session.started_at do
                  DateTime.diff(updated_session.ended_at, updated_session.started_at)
                else
                  0
                end

                conn
                |> put_status(:ok)
                |> json(%{
                  session_id: updated_session.session_id,
                  status: updated_session.status,
                  started_at: updated_session.started_at,
                  ended_at: updated_session.ended_at,
                  total_sets: updated_session.total_sets,
                  total_reps: updated_session.total_reps,
                  average_quality: updated_session.average_quality,
                  completion_status: updated_session.completion_status,
                  duration_seconds: duration_seconds
                })
            end

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to end session", reason: reason})
        end
    end
  end

  @doc """
  GET /api/sessions/:id
  Show a specific exercise session
  """
  def show(conn, %{"id" => session_id}) do
    case SessionProjection.get_session(session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})

      session ->
        duration_seconds = if session.ended_at && session.started_at do
          DateTime.diff(session.ended_at, session.started_at)
        else
          0
        end

        conn
        |> put_status(:ok)
        |> json(%{
          session_id: session.session_id,
          patient_id: session.patient_id,
          exercise_id: session.exercise_id,
          status: session.status,
          started_at: session.started_at,
          ended_at: session.ended_at,
          target_sets: session.target_sets,
          target_reps_per_set: session.target_reps_per_set,
          total_sets: session.total_sets,
          total_reps: session.total_reps,
          average_quality: session.average_quality,
          completion_status: session.completion_status,
          duration_seconds: duration_seconds,
          sets: session.sets
        })
    end
  end

  @doc """
  GET /api/patients/:patient_id/sessions
  List sessions for a patient
  """
  def index(conn, %{"patient_id" => patient_id} = params) do
    opts = []
    opts = if params["limit"], do: Keyword.put(opts, :limit, String.to_integer(params["limit"])), else: opts
    opts = if params["status"], do: Keyword.put(opts, :status, params["status"]), else: opts

    sessions = SessionProjection.get_patient_sessions(patient_id, opts)
    
    formatted_sessions = Enum.map(sessions, fn session ->
      %{
        session_id: session.session_id,
        exercise_id: session.exercise_id,
        status: session.status,
        started_at: session.started_at,
        ended_at: session.ended_at,
        total_sets: session.total_sets,
        total_reps: session.total_reps,
        average_quality: session.average_quality,
        completion_status: session.completion_status
      }
    end)

    conn
    |> put_status(:ok)
    |> json(%{
      patient_id: patient_id,
      sessions: formatted_sessions,
      count: length(formatted_sessions)
    })
  end
end