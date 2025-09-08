defmodule RehabTrackingWeb.AuthController do
  @moduledoc """
  Authentication controller for login, token refresh, and logout.
  """
  
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Authenticate user and return JWT tokens.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case RehabTracking.Auth.UserService.authenticate(email, password) do
      {:ok, user} ->
        {:ok, access_token} = RehabTracking.Auth.TokenService.generate_access_token(user)
        {:ok, refresh_token} = RehabTracking.Auth.TokenService.generate_refresh_token(user)
        
        conn
        |> put_status(:ok)
        |> json(%{
          access_token: access_token,
          refresh_token: refresh_token,
          token_type: "Bearer",
          expires_in: 3600,
          user: %{
            id: user.id,
            email: user.email,
            role: user.role,
            permissions: user.permissions
          }
        })
        
      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
        
      {:error, :user_disabled} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Account is disabled"})
    end
  end

  def login(conn, _invalid_params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Email and password are required"})
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case RehabTracking.Auth.TokenService.verify_refresh_token(refresh_token) do
      {:ok, user} ->
        {:ok, access_token} = RehabTracking.Auth.TokenService.generate_access_token(user)
        
        conn
        |> put_status(:ok)
        |> json(%{
          access_token: access_token,
          token_type: "Bearer",
          expires_in: 3600
        })
        
      {:error, :invalid_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid refresh token"})
        
      {:error, :expired_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Refresh token has expired"})
    end
  end

  def refresh(conn, _invalid_params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Refresh token is required"})
  end
end