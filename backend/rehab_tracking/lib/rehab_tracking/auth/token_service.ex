defmodule RehabTracking.Auth.TokenService do
  @moduledoc """
  Service for generating and verifying JWT tokens
  """

  @access_token_ttl 3600  # 1 hour
  @refresh_token_ttl 86400 * 7  # 7 days

  def generate_access_token(user) do
    now = System.system_time(:second)
    claims = %{
      "sub" => to_string(user.id),
      "email" => user.email,
      "role" => user.role,
      "permissions" => user.permissions,
      "iat" => now,
      "exp" => now + @access_token_ttl,
      "type" => "access"
    }
    
    token = generate_jwt(claims)
    {:ok, token}
  end

  def generate_refresh_token(user) do
    now = System.system_time(:second)
    claims = %{
      "sub" => to_string(user.id),
      "email" => user.email,
      "iat" => now,
      "exp" => now + @refresh_token_ttl,
      "type" => "refresh"
    }
    
    token = generate_jwt(claims)
    {:ok, token}
  end

  def verify_access_token(token) do
    verify_jwt(token, "access")
  end

  def verify_refresh_token(token) do
    verify_jwt(token, "refresh")
  end

  defp generate_jwt(claims) do
    secret = get_secret()
    
    # Simple JWT implementation (in production, use Joken library)
    header = Base.url_encode64(Jason.encode!(%{"alg" => "HS256", "typ" => "JWT"}), padding: false)
    payload = Base.url_encode64(Jason.encode!(claims), padding: false)
    signature_input = "#{header}.#{payload}"
    signature = Base.url_encode64(:crypto.mac(:hmac, :sha256, secret, signature_input), padding: false)
    
    "#{header}.#{payload}.#{signature}"
  end

  defp verify_jwt(token, expected_type) do
    with [header, payload, signature] <- String.split(token, "."),
         {:ok, claims_json} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} <- Jason.decode(claims_json),
         true <- valid_signature?(token, signature),
         true <- valid_expiry?(claims),
         true <- claims["type"] == expected_type do
      
      # For refresh token, we need to get the full user
      if expected_type == "refresh" do
        RehabTracking.Auth.UserService.get_user(claims["sub"])
      else
        {:ok, claims}
      end
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp valid_signature?(token_without_sig, signature) do
    secret = get_secret()
    [header, payload | _] = String.split(token_without_sig, ".")
    signature_input = "#{header}.#{payload}"
    expected_signature = Base.url_encode64(:crypto.mac(:hmac, :sha256, secret, signature_input), padding: false)
    
    signature == expected_signature
  end

  defp valid_expiry?(claims) do
    now = System.system_time(:second)
    claims["exp"] > now
  end

  defp get_secret do
    System.get_env("JWT_SECRET") || "your-jwt-secret-key-at-least-32-characters-long"
  end
end