defmodule RehabTrackingWeb.ProjectionController do
  @moduledoc """
  API controller for querying projection read models.
  Handles GET requests for adherence, quality, and summary projections.
  """

  use RehabTrackingWeb, :controller
  
  alias RehabTracking.Core.Facade
  alias RehabTrackingWeb.ProjectionView

  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Gets adherence metrics for a patient.
  GET /api/v1/projections/adherence/:patient_id
  GET /api/v1/projections/adherence/:patient_id/:exercise_id
  """
  def adherence(conn, %{"patient_id" => patient_id, "exercise_id" => exercise_id}) do
    case Facade.get_adherence(patient_id, exercise_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Adherence data not found"})

      adherence_data ->
        conn
        |> render("adherence.json", %{adherence: adherence_data})
    end
  end

  def adherence(conn, %{"patient_id" => patient_id}) do
    case Facade.get_adherence(patient_id) do
      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No adherence data found for patient"})

      adherence_list ->
        conn
        |> render("adherence_list.json", %{adherence_list: adherence_list})
    end
  end

  @doc """
  Gets quality metrics for a patient.
  GET /api/v1/projections/quality/:patient_id
  GET /api/v1/projections/quality/:patient_id/:exercise_id
  """
  def quality(conn, %{"patient_id" => patient_id, "exercise_id" => exercise_id}) do
    case Facade.get_quality_metrics(patient_id, exercise_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Quality data not found"})

      quality_data ->
        conn
        |> render("quality.json", %{quality: quality_data})
    end
  end

  def quality(conn, %{"patient_id" => patient_id}) do
    case Facade.get_quality_metrics(patient_id) do
      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No quality data found for patient"})

      quality_list ->
        conn
        |> render("quality_list.json", %{quality_list: quality_list})
    end
  end

  @doc """
  Gets patient clinical summary.
  GET /api/v1/projections/summary/:patient_id
  """
  def summary(conn, %{"patient_id" => patient_id}) do
    case Facade.get_patient_summary(patient_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Patient summary not found"})

      summary_data ->
        conn
        |> render("patient_summary.json", %{summary: summary_data})
    end
  end

  @doc """
  Gets FHIR-compatible clinical summary.
  GET /api/v1/projections/summary/:patient_id/fhir
  """
  def fhir_summary(conn, %{"patient_id" => patient_id}) do
    case Facade.get_clinical_summary(patient_id) do
      {:ok, clinical_summary} ->
        conn
        |> render("fhir_summary.json", %{clinical_summary: clinical_summary})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Clinical summary not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to generate clinical summary", reason: reason})
    end
  end

  @doc """
  Gets work queue items for a therapist.
  GET /api/v1/projections/work_queue/:therapist_id
  """
  def work_queue(conn, %{"therapist_id" => therapist_id} = params) do
    opts = build_work_queue_options(params)
    
    case Facade.get_work_queue(therapist_id, opts) do
      [] ->
        conn
        |> json(%{
          therapist_id: therapist_id,
          work_items: [],
          total_items: 0,
          message: "No pending work items"
        })

      work_items ->
        conn
        |> render("work_queue.json", %{
          therapist_id: therapist_id,
          work_items: work_items
        })
    end
  end

  @doc """
  Gets aggregated dashboard data for a therapist.
  GET /api/v1/projections/dashboard/:therapist_id
  """
  def dashboard(conn, %{"therapist_id" => therapist_id}) do
    case Facade.get_therapist_dashboard(therapist_id) do
      {:ok, dashboard_data} ->
        conn
        |> render("therapist_dashboard.json", %{
          therapist_id: therapist_id,
          dashboard: dashboard_data
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to load dashboard", reason: reason})
    end
  end

  @doc """
  Gets patient progress report.
  GET /api/v1/projections/progress/:patient_id
  """
  def progress_report(conn, %{"patient_id" => patient_id} = params) do
    date_range = parse_date_range(params)
    
    case Facade.get_patient_progress_report(patient_id, date_range) do
      {:ok, progress_report} ->
        conn
        |> render("progress_report.json", %{
          patient_id: patient_id,
          report: progress_report
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to generate progress report", reason: reason})
    end
  end

  @doc """
  Generic projection query endpoint.
  GET /api/v1/projections/:projection_name
  """
  def query(conn, %{"projection_name" => projection_name} = params) do
    projection_atom = String.to_atom(projection_name)
    filters = build_projection_filters(params)

    case Facade.project(projection_atom, filters) do
      {:error, :unknown_projection} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Unknown projection type", available: ["adherence", "quality", "work_queue", "patient_summary"]})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid query parameters", reason: reason})

      result ->
        conn
        |> render("generic_projection.json", %{
          projection_name: projection_name,
          result: result
        })
    end
  end

  @doc """
  Gets projection health and statistics.
  GET /api/v1/projections/health
  """
  def health(conn, _params) do
    case Facade.get_system_health() do
      {:ok, health_data} ->
        projection_health = health_data[:projections] || %{}
        
        conn
        |> json(%{
          status: "healthy",
          projections: projection_health,
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          reason: reason,
          timestamp: DateTime.utc_now()
        })
    end
  end

  # Helper functions
  defp build_work_queue_options(params) do
    []
    |> add_option_if_present(:limit, params["limit"], &parse_integer/1)
    |> add_option_if_present(:priority, params["priority"])
    |> add_option_if_present(:status, params["status"])
    |> add_option_if_present(:category, params["category"])
  end

  defp add_option_if_present(opts, _key, nil, _parser), do: opts
  defp add_option_if_present(opts, _key, nil), do: opts
  defp add_option_if_present(opts, key, value, parser) when is_function(parser) do
    case parser.(value) do
      nil -> opts
      parsed_value -> [{key, parsed_value} | opts]
    end
  end
  defp add_option_if_present(opts, key, value) do
    [{key, value} | opts]
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> nil
    end
  end

  defp parse_date_range(params) do
    case {params["start_date"], params["end_date"]} do
      {nil, nil} -> nil
      {start_date, end_date} ->
        %{
          start_date: start_date,
          end_date: end_date
        }
    end
  end

  defp build_projection_filters(params) do
    Map.drop(params, ["projection_name"])
    |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)
  end
end