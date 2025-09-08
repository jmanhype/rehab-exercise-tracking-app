defmodule RehabTrackingWeb.HealthController do
  use RehabTrackingWeb, :controller

  @moduledoc """
  Health check endpoints for monitoring system status.
  """

  def index(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end

  def detailed(conn, _params) do
    services = %{
      postgres: check_postgres(),
      redis: check_redis(),
      rabbitmq: check_rabbitmq()
    }
    
    all_healthy = services |> Map.values() |> Enum.all?(&(&1 == "connected"))
    status = if all_healthy, do: "healthy", else: "degraded"
    
    json(conn, %{
      status: status,
      timestamp: DateTime.utc_now(),
      services: services,
      uptime: :erlang.system_info(:uptime)
    })
  end

  def ready(conn, _params) do
    # Check essential services for readiness
    postgres_status = check_postgres()
    
    case postgres_status do
      "connected" ->
        json(conn, %{status: "ready", services: %{postgres: "connected"}})
      _ ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "not_ready", services: %{postgres: "disconnected"}})
    end
  end

  def live(conn, _params) do
    json(conn, %{status: "alive", uptime: :erlang.system_info(:uptime)})
  end

  # Private helper functions for service checks
  defp check_postgres do
    try do
      case RehabTracking.Repo.query("SELECT 1") do
        {:ok, _} -> "connected"
        {:error, _} -> "disconnected"
      end
    rescue
      _ -> "disconnected"
    end
  end

  defp check_redis do
    # Redis check would go here when configured
    "not_configured"
  end

  defp check_rabbitmq do
    # RabbitMQ check would go here when configured
    "not_configured"
  end
end