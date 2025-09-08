defmodule RehabTrackingWeb.AdminController do
  @moduledoc """
  System administration controller for system status, projections, and event store management.
  """
  
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Get system status and health metrics.
  """
  def system_status(conn, _params) do
    case RehabTracking.Admin.SystemService.get_system_status() do
      {:ok, status} ->
        conn
        |> put_status(:ok)
        |> json(%{
          system_status: status,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Rebuild all projections from event stream.
  """
  def rebuild_projections(conn, params) do
    projection_names = params["projections"] || ["adherence", "quality", "work_queue", "patient_summary"]
    
    case RehabTracking.Admin.ProjectionService.rebuild_projections(projection_names) do
      {:ok, rebuild_info} ->
        conn
        |> put_status(:accepted)
        |> json(%{
          message: "Projection rebuild started",
          projections: rebuild_info.projections,
          rebuild_id: rebuild_info.rebuild_id,
          estimated_completion: rebuild_info.estimated_completion
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get event store statistics.
  """
  def event_store_stats(conn, _params) do
    case RehabTracking.Admin.EventStoreService.get_statistics() do
      {:ok, stats} ->
        conn
        |> put_status(:ok)
        |> json(%{
          event_store_stats: stats,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end