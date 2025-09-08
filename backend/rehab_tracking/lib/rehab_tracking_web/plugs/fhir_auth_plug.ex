defmodule RehabTrackingWeb.Plugs.FHIRAuthPlug do
  @moduledoc """
  FHIR-specific authentication plug for EMR system integration.
  Supports OAuth 2.0 client credentials flow and SMART on FHIR.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        validate_fhir_token(conn, token)
        
      [] ->
        # Check for client credentials in basic auth
        case get_req_header(conn, "authorization") do
          ["Basic " <> encoded] ->
            validate_client_credentials(conn, encoded)
            
          _ ->
            conn
            |> put_status(:unauthorized)
            |> json(%{
              error: "Authentication required",
              message: "FHIR endpoints require OAuth 2.0 Bearer token or client credentials"
            })
            |> halt()
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid authorization header"})
        |> halt()
    end
  end

  defp validate_fhir_token(conn, token) do
    case RehabTracking.Auth.FHIRTokenService.verify_token(token) do
      {:ok, claims} ->
        conn
        |> assign(:fhir_client_id, claims["client_id"])
        |> assign(:fhir_scope, claims["scope"])
        |> assign(:fhir_authenticated, true)
        
      {:error, reason} ->
        Logger.warning("FHIR token validation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid FHIR access token"})
        |> halt()
    end
  end

  defp validate_client_credentials(conn, encoded) do
    with {:ok, decoded} <- Base.decode64(encoded),
         [client_id, client_secret] <- String.split(decoded, ":", parts: 2),
         {:ok, client} <- RehabTracking.Auth.FHIRClientService.validate_credentials(client_id, client_secret) do
      
      conn
      |> assign(:fhir_client_id, client.id)
      |> assign(:fhir_scope, client.scope)
      |> assign(:fhir_authenticated, true)
      
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid client credentials"})
        |> halt()
    end
  end
end