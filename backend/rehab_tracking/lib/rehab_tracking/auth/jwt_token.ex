defmodule RehabTracking.Auth.JWTToken do
  @moduledoc """
  JWT token generation and validation using Joken.
  Provides secure token handling for authentication.
  """

  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud])
    |> add_claim("typ", fn -> "access" end, &(&1 == "access"))
  end

  @doc """
  Generates a JWT token for a user.
  """
  def generate_token(user_id, role, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600) # 1 hour default
    
    claims = %{
      "sub" => user_id,
      "role" => role,
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(expires_in, :second) |> DateTime.to_unix()
    }
    
    additional_claims = Keyword.get(opts, :claims, %{})
    claims = Map.merge(claims, additional_claims)
    
    case generate_and_sign(claims) do
      {:ok, token, _claims} -> {:ok, token}
      error -> error
    end
  end

  @doc """
  Verifies and decodes a JWT token.
  """
  def verify_token(token) do
    case verify_and_validate(token) do
      {:ok, claims} -> 
        {:ok, %{
          user_id: claims["sub"],
          role: claims["role"],
          expires_at: claims["exp"],
          issued_at: claims["iat"],
          claims: claims
        }}
      
      {:error, reason} -> 
        {:error, reason}
    end
  end

  @doc """
  Generates a refresh token with longer expiration.
  """
  def generate_refresh_token(user_id) do
    expires_in = 30 * 24 * 3600 # 30 days
    
    claims = %{
      "sub" => user_id,
      "typ" => "refresh",
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(expires_in, :second) |> DateTime.to_unix(),
      "jti" => UUID.uuid4() # Unique token ID for revocation
    }
    
    case Joken.generate_and_sign(claims, Joken.current_token_config()) do
      {:ok, token, _claims} -> {:ok, token}
      error -> error
    end
  end

  @doc """
  Revokes a token by adding it to a blacklist.
  """
  def revoke_token(jti) do
    # In production, store in Redis or database
    # For now, using ETS as a simple cache
    :ets.insert(:revoked_tokens, {jti, DateTime.utc_now()})
    :ok
  rescue
    ArgumentError ->
      # Table doesn't exist, create it
      :ets.new(:revoked_tokens, [:set, :public, :named_table])
      :ets.insert(:revoked_tokens, {jti, DateTime.utc_now()})
      :ok
  end

  @doc """
  Checks if a token has been revoked.
  """
  def token_revoked?(jti) do
    case :ets.lookup(:revoked_tokens, jti) do
      [{^jti, _timestamp}] -> true
      [] -> false
    end
  rescue
    ArgumentError -> false
  end
end