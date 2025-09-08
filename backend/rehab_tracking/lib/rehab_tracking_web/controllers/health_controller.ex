defmodule RehabTrackingWeb.HealthController do
  use RehabTrackingWeb, :controller

  @moduledoc """
  Health check endpoints for monitoring system status.
  """

  def check(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end

  def ready(conn, _params) do
    case RehabTracking.EventStore.ping() do
      :pong ->
        json(conn, %{status: "ready", services: %{event_store: "connected"}})
      _ ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "not_ready", services: %{event_store: "disconnected"}})
    end
  end

  def live(conn, _params) do
    json(conn, %{status: "alive", uptime: :erlang.system_info(:uptime)})
  end
end