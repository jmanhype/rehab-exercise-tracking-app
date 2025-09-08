defmodule RehabTrackingWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use RehabTrackingWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: translate_errors(changeset)})
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Resource not found"})
  end

  # Handle unauthorized access
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized access"})
  end

  # Handle forbidden access
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Access forbidden"})
  end

  # Handle validation errors
  def call(conn, {:error, :validation_failed, errors}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Validation failed", details: errors})
  end

  # Handle rate limiting
  def call(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{error: "Rate limit exceeded"})
  end

  # Handle service unavailable
  def call(conn, {:error, :service_unavailable}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "Service temporarily unavailable"})
  end

  # Handle general server errors
  def call(conn, {:error, reason}) when is_binary(reason) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: reason})
  end

  # Catch-all for 404 on unmatched routes
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: "Endpoint not found",
      message: "The requested API endpoint does not exist",
      available_versions: ["v1"],
      documentation: "/api/docs"
    })
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting the following line:
    #
    #     Gettext.dgettext(RehabTrackingWeb.Gettext, "errors", msg, opts)
    #
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end