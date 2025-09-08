defmodule RehabTracking.Adapters.Auth do
  @moduledoc """
  Authentication adapter that provides JWT token validation for the AuthPlug
  """

  alias RehabTracking.Auth.TokenService

  @doc """
  Validates a JWT token and returns the claims if valid
  """
  def validate_jwt_token(token) do
    TokenService.verify_access_token(token)
  end
end