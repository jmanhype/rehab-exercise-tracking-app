defmodule RehabTracking.Services.PatientService do
  @moduledoc """
  Patient management service providing CQRS read operations.
  Wraps projections for controller consumption.
  """

  alias RehabTracking.Projections.{PatientSummary, SessionProjection}
  alias RehabTracking.Repo
  import Ecto.Query

  @doc """
  Lists all patients with basic information.
  """
  def list_patients(opts \\ []) do
    query = from p in PatientSummary,
      order_by: [desc: p.last_activity]

    query
    |> apply_filters(opts)
    |> Repo.all()
    |> Enum.map(&format_patient/1)
  end

  @doc """
  Gets a specific patient by ID.
  """
  def get_patient(patient_id) do
    case Repo.get(PatientSummary, patient_id) do
      nil -> {:error, :not_found}
      patient -> {:ok, format_patient(patient)}
    end
  end

  @doc """
  Gets patient's recent sessions.
  """
  def get_patient_sessions(patient_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    
    sessions = from s in SessionProjection,
      where: s.patient_id == ^patient_id,
      order_by: [desc: s.started_at],
      limit: ^limit
    
    sessions
    |> Repo.all()
    |> Enum.map(&format_session/1)
  end

  @doc """
  Calculates patient adherence metrics.
  """
  def get_adherence_metrics(patient_id, window \\ :week) do
    # Stub implementation - would aggregate from projections
    %{
      patient_id: patient_id,
      window: window,
      completion_rate: 0.85,
      sessions_completed: 12,
      sessions_scheduled: 14,
      current_streak: 3,
      longest_streak: 7,
      by_day: generate_adherence_by_day()
    }
  end

  @doc """
  Gets patient quality metrics.
  """
  def get_quality_metrics(patient_id) do
    # Stub implementation
    %{
      patient_id: patient_id,
      average_form_score: 0.82,
      rom_progress: %{
        improvement: 15,
        baseline: 75,
        current: 90
      },
      exercises: [
        %{
          name: "Knee Flexion",
          average_score: 0.85,
          trend: "improving"
        }
      ]
    }
  end

  @doc """
  Gets patient's current workout plan.
  """
  def get_workout_plan(patient_id) do
    # Stub implementation
    %{
      patient_id: patient_id,
      exercises: [
        %{
          id: "ex_001",
          name: "Knee Flexion",
          sets: 3,
          reps: 10,
          frequency: "daily"
        },
        %{
          id: "ex_002",
          name: "Quad Sets",
          sets: 3,
          reps: 15,
          frequency: "daily"
        }
      ],
      updated_at: DateTime.utc_now()
    }
  end

  # Private helpers

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:therapist_id, id}, q -> where(q, [p], p.therapist_id == ^id)
      {:status, status}, q -> where(q, [p], p.status == ^status)
      _, q -> q
    end)
  end

  defp format_patient(patient) do
    %{
      id: patient.patient_id,
      name: patient.name || "Unknown Patient",
      therapist_id: patient.therapist_id,
      status: patient.status || "active",
      last_activity: patient.last_activity,
      adherence_rate: patient.adherence_rate || 0.0,
      next_session: patient.next_session
    }
  end

  defp format_session(session) do
    %{
      id: session.session_id,
      patient_id: session.patient_id,
      exercise_id: session.exercise_id,
      started_at: session.started_at,
      completed_at: session.completed_at,
      duration_seconds: session.duration_seconds,
      total_reps: session.total_reps,
      form_score: session.form_score,
      sets: session.sets || []
    }
  end

  defp generate_adherence_by_day do
    # Generate mock data for past 7 days
    for i <- 6..0//-1 do
      date = Date.utc_today() |> Date.add(-i)
      %{
        date: Date.to_iso8601(date),
        completed: if(i in [0, 2], do: false, else: true)
      }
    end
  end
end