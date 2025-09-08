defmodule RehabTrackingWeb.ProtocolController do
  @moduledoc """
  Exercise protocol management controller.
  """
  
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  List exercise protocols.
  """
  def index(conn, params) do
    case RehabTracking.Protocols.ProtocolService.list_protocols(params) do
      {:ok, protocols} ->
        conn
        |> put_status(:ok)
        |> json(%{protocols: protocols})
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get protocol details.
  """
  def show(conn, %{"id" => protocol_id}) do
    case RehabTracking.Protocols.ProtocolService.get_protocol(protocol_id) do
      {:ok, protocol} ->
        conn
        |> put_status(:ok)
        |> json(%{protocol: protocol})
        
      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Create new protocol.
  """
  def create(conn, %{"protocol" => protocol_params}) do
    case RehabTracking.Protocols.ProtocolService.create_protocol(protocol_params) do
      {:ok, protocol} ->
        conn
        |> put_status(:created)
        |> json(%{protocol: protocol})
        
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Update protocol.
  """
  def update(conn, %{"id" => protocol_id, "protocol" => protocol_params}) do
    case RehabTracking.Protocols.ProtocolService.update_protocol(protocol_id, protocol_params) do
      {:ok, protocol} ->
        conn
        |> put_status(:ok)
        |> json(%{protocol: protocol})
        
      {:error, changeset} ->
        {:error, changeset}
    end
  end
end