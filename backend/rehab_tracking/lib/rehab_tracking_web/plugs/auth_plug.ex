defmodule RehabTrackingWeb.Plugs.AuthPlug do
  @moduledoc """
  Main authentication plug for validating JWT tokens.
  Handles token extraction, validation, and setting current_user in conn.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  alias RehabTracking.Adapters.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip auth for certain paths
    case skip_auth?(conn.request_path) do
      true -> conn
      false -> authenticate_request(conn)
    end
  end

  defp skip_auth?(path) do
    path in ["/health", "/health/ready", "/health/live", "/api/v1/auth/login", "/api/v1/auth/refresh", "/api/v1/patients/register", "/login.html"]
  end

  defp authenticate_request(conn) do
    case extract_token(conn) do
      {:ok, token} -> validate_token(conn, token)
      {:error, :missing_token} -> handle_auth_error(conn, "Missing authorization token")
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp validate_token(conn, token) do
    case Auth.validate_jwt_token(token) do
      {:ok, claims} ->
        conn
        |> assign(:current_user, claims)
        |> assign(:authenticated, true)
      {:error, reason} ->
        handle_auth_error(conn, "Invalid token: #{reason}")
    end
  end

  defp handle_auth_error(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Authentication failed", message: message})
    |> halt()
  end
end