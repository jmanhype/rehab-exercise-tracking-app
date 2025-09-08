defmodule RehabTrackingWeb.Plugs.RequireAuthPlug do
  @moduledoc """
  Plug that ensures the request has valid authentication.
  Should be used in pipelines that require authentication.
  """
  
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:authenticated] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{
        error: "Authentication required",
        message: "This endpoint requires valid authentication"
      })
      |> halt()
    end
  end
end