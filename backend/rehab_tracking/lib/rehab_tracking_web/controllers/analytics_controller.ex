defmodule RehabTrackingWeb.AnalyticsController do
  @moduledoc """
  Analytics and reporting controller for adherence trends, quality metrics, and outcomes.
  """
  
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Get adherence trends analytics.
  """
  def adherence_trends(conn, params) do
    case RehabTracking.Analytics.AdherenceService.get_trends(params) do
      {:ok, trends} ->
        conn
        |> put_status(:ok)
        |> json(%{
          adherence_trends: trends,
          metadata: %{
            time_range: params["time_range"] || "30d",
            patient_id: params["patient_id"],
            generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get quality metrics analytics.
  """
  def quality_metrics(conn, params) do
    case RehabTracking.Analytics.QualityService.get_metrics(params) do
      {:ok, metrics} ->
        conn
        |> put_status(:ok)
        |> json(%{
          quality_metrics: metrics,
          metadata: %{
            time_range: params["time_range"] || "30d",
            patient_id: params["patient_id"],
            generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get outcomes analytics.
  """
  def outcomes(conn, params) do
    case RehabTracking.Analytics.OutcomesService.get_outcomes(params) do
      {:ok, outcomes} ->
        conn
        |> put_status(:ok)
        |> json(%{
          outcomes: outcomes,
          metadata: %{
            time_range: params["time_range"] || "30d",
            patient_id: params["patient_id"],
            generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end