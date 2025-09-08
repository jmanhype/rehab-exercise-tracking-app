defmodule RehabTracking.Adapters.Auth.JWTAdapter do
  @moduledoc """
  JWT-based authentication adapter with role-based access control.
  
  Supports roles: patient, therapist, admin, emergency as per requirements.
  Implements secure token generation, validation, and role management.
  """

  require Logger
  
  @type jwt_token :: String.t()
  @type user_role :: :patient | :therapist | :admin | :emergency
  @type jwt_claims :: %{
    sub: String.t(),         # Subject (user ID)
    iat: integer(),          # Issued at
    exp: integer(),          # Expires at
    role: user_role(),       # User role
    permissions: [String.t()], # Specific permissions
    session_id: String.t(),  # Session identifier
    device_info: map() | nil # Device information
  }
  @type auth_result :: %{
    user_id: String.t(),
    role: user_role(),
    permissions: [String.t()],
    session_id: String.t(),
    expires_at: DateTime.t()
  }
  @type login_credentials :: %{
    username: String.t(),
    password: String.t(),
    role: user_role() | nil,
    device_info: map() | nil
  }

  # JWT configuration
  @default_expiry_hours 24
  @emergency_expiry_hours 2
  @secret_key_base Application.compile_env(:rehab_tracking, :secret_key_base)
  
  # Role-based permissions
  @role_permissions %{
    patient: [
      "view_own_sessions",
      "create_own_sessions", 
      "view_own_progress",
      "update_own_profile"
    ],
    therapist: [
      "view_patient_sessions",
      "create_patient_sessions",
      "view_patient_progress",
      "update_care_plans",
      "send_notifications",
      "view_analytics"
    ],
    admin: [
      "view_all_data",
      "create_users",
      "update_users",
      "delete_users",
      "system_configuration",
      "audit_logs",
      "backup_restore"
    ],
    emergency: [
      "view_patient_sessions",
      "view_patient_progress",
      "emergency_access",
      "override_privacy"
    ]
  }

  @doc """
  Generates a JWT token for authenticated user.
  """
  def generate_token(user_id, role, opts \\ []) do
    Logger.debug("Generating JWT token for user #{user_id} with role #{role}")
    
    session_id = Keyword.get(opts, :session_id, UUID.uuid4())
    device_info = Keyword.get(opts, :device_info)
    custom_permissions = Keyword.get(opts, :permissions, [])
    
    # Calculate expiry based on role
    expiry_hours = case role do
      :emergency -> @emergency_expiry_hours
      _ -> Keyword.get(opts, :expiry_hours, @default_expiry_hours)
    end
    
    now = System.system_time(:second)
    exp = now + (expiry_hours * 3600)
    
    base_permissions = Map.get(@role_permissions, role, [])
    permissions = Enum.uniq(base_permissions ++ custom_permissions)
    
    claims = %{
      sub: user_id,
      iat: now,
      exp: exp,
      role: Atom.to_string(role),
      permissions: permissions,
      session_id: session_id,
      device_info: device_info
    }
    
    case sign_jwt(claims) do
      {:ok, token} ->
        Logger.info("JWT token generated for user #{user_id}, expires at #{DateTime.from_unix!(exp)}")
        {:ok, token, %{
          user_id: user_id,
          role: role,
          permissions: permissions,
          session_id: session_id,
          expires_at: DateTime.from_unix!(exp)
        }}
      {:error, reason} ->
        Logger.error("Failed to generate JWT token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validates and decodes a JWT token.
  """
  def validate_token(token) do
    Logger.debug("Validating JWT token")
    
    case verify_jwt(token) do
      {:ok, claims} ->
        case validate_claims(claims) do
          {:ok, auth_result} ->
            Logger.debug("JWT token validated for user #{auth_result.user_id}")
            {:ok, auth_result}
          {:error, reason} ->
            Logger.warning("JWT token validation failed: #{reason}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.warning("JWT token verification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Authenticates user credentials and returns JWT token.
  """
  def authenticate(credentials) do
    Logger.info("Authenticating user: #{credentials.username}")
    
    case verify_credentials(credentials) do
      {:ok, user_info} ->
        opts = [
          session_id: UUID.uuid4(),
          device_info: credentials.device_info
        ]
        
        case generate_token(user_info.user_id, user_info.role, opts) do
          {:ok, token, auth_result} ->
            # Log successful authentication
            log_auth_event("login_success", user_info.user_id, credentials.device_info)
            {:ok, token, auth_result}
          {:error, reason} ->
            log_auth_event("token_generation_failed", credentials.username, credentials.device_info)
            {:error, reason}
        end
      {:error, reason} ->
        log_auth_event("login_failed", credentials.username, credentials.device_info)
        {:error, reason}
    end
  end

  @doc """
  Refreshes an existing JWT token.
  """
  def refresh_token(token) do
    Logger.debug("Refreshing JWT token")
    
    case validate_token(token) do
      {:ok, auth_result} ->
        # Check if token is eligible for refresh (not expired more than 1 hour ago)
        case DateTime.compare(DateTime.utc_now(), 
                             DateTime.add(auth_result.expires_at, 3600, :second)) do
          :lt ->
            # Generate new token with same claims but extended expiry
            generate_token(auth_result.user_id, auth_result.role, [
              session_id: auth_result.session_id
            ])
          _ ->
            Logger.warning("Token too old for refresh: #{auth_result.user_id}")
            {:error, "Token expired beyond refresh window"}
        end
      {:error, reason} ->
        Logger.warning("Cannot refresh invalid token: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Revokes a JWT token by adding it to blacklist.
  """
  def revoke_token(token) do
    Logger.info("Revoking JWT token")
    
    case validate_token(token) do
      {:ok, auth_result} ->
        # Add token to blacklist (in production, use Redis or database)
        blacklist_token(token, auth_result.expires_at)
        log_auth_event("token_revoked", auth_result.user_id, nil)
        :ok
      {:error, reason} ->
        Logger.warning("Cannot revoke invalid token: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Checks if user has specific permission.
  """
  def has_permission?(auth_result, permission) do
    permission in auth_result.permissions
  end

  @doc """
  Checks if user has required role or higher.
  """
  def has_role?(auth_result, required_role) do
    user_role = auth_result.role
    
    case {user_role, required_role} do
      {role, role} -> true
      {:admin, _} -> true
      {:therapist, :patient} -> true
      {:emergency, :patient} -> true
      {:emergency, :therapist} -> true
      _ -> false
    end
  end

  @doc """
  Creates emergency access token with limited duration.
  """
  def create_emergency_token(requesting_user_id, target_patient_id, reason) do
    Logger.warning(
      "Emergency access requested by #{requesting_user_id} for patient #{target_patient_id}: #{reason}"
    )
    
    # Emergency tokens have special permissions and short expiry
    opts = [
      expiry_hours: @emergency_expiry_hours,
      permissions: ["emergency_access", "override_privacy"],
      session_id: "emergency_#{UUID.uuid4()}"
    ]
    
    case generate_token("emergency_#{requesting_user_id}", :emergency, opts) do
      {:ok, token, auth_result} ->
        # Log emergency access
        log_emergency_access(requesting_user_id, target_patient_id, reason)
        {:ok, token, auth_result}
      error ->
        error
    end
  end

  @doc """
  Validates session and checks if it's still active.
  """
  def validate_session(session_id) do
    # In production, check session store (Redis/ETS)
    case get_session_info(session_id) do
      {:ok, session_info} ->
        if session_info.active do
          {:ok, session_info}
        else
          {:error, "Session inactive"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets role-specific permissions.
  """
  def get_role_permissions(role) do
    Map.get(@role_permissions, role, [])
  end

  @doc """
  Lists all available permissions in the system.
  """
  def list_all_permissions do
    @role_permissions
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Private functions

  defp sign_jwt(claims) do
    try do
      signer = Joken.Signer.create("HS256", get_secret_key())
      token = Joken.generate_and_sign!(%{}, claims, signer)
      {:ok, token}
    rescue
      error ->
        {:error, "JWT signing failed: #{inspect(error)}"}
    end
  end

  defp verify_jwt(token) do
    try do
      signer = Joken.Signer.create("HS256", get_secret_key())
      
      case Joken.verify_and_validate(%{}, token, signer) do
        {:ok, claims} ->
          if token_blacklisted?(token) do
            {:error, "Token revoked"}
          else
            {:ok, claims}
          end
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, "JWT verification failed: #{inspect(error)}"}
    end
  end

  defp validate_claims(claims) do
    with {:ok, user_id} <- extract_subject(claims),
         {:ok, role} <- extract_role(claims),
         {:ok, permissions} <- extract_permissions(claims),
         {:ok, session_id} <- extract_session_id(claims),
         {:ok, expires_at} <- extract_expiry(claims) do
      
      auth_result = %{
        user_id: user_id,
        role: role,
        permissions: permissions,
        session_id: session_id,
        expires_at: expires_at
      }
      
      {:ok, auth_result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_subject(claims) do
    case Map.get(claims, "sub") do
      nil -> {:error, "Missing subject claim"}
      subject when is_binary(subject) -> {:ok, subject}
      _ -> {:error, "Invalid subject claim"}
    end
  end

  defp extract_role(claims) do
    case Map.get(claims, "role") do
      nil -> {:error, "Missing role claim"}
      role_string when is_binary(role_string) ->
        case String.to_existing_atom(role_string) do
          role when role in [:patient, :therapist, :admin, :emergency] ->
            {:ok, role}
          _ ->
            {:error, "Invalid role: #{role_string}"}
        end
      _ -> {:error, "Invalid role claim format"}
    end
  rescue
    ArgumentError -> {:error, "Unknown role"}
  end

  defp extract_permissions(claims) do
    case Map.get(claims, "permissions") do
      nil -> {:ok, []}
      permissions when is_list(permissions) -> {:ok, permissions}
      _ -> {:error, "Invalid permissions claim"}
    end
  end

  defp extract_session_id(claims) do
    case Map.get(claims, "session_id") do
      nil -> {:error, "Missing session_id claim"}
      session_id when is_binary(session_id) -> {:ok, session_id}
      _ -> {:error, "Invalid session_id claim"}
    end
  end

  defp extract_expiry(claims) do
    case Map.get(claims, "exp") do
      nil -> {:error, "Missing expiry claim"}
      exp when is_integer(exp) -> {:ok, DateTime.from_unix!(exp)}
      _ -> {:error, "Invalid expiry claim"}
    end
  end

  defp verify_credentials(credentials) do
    # In production, verify against user database
    case mock_user_lookup(credentials.username, credentials.password) do
      {:ok, user_info} ->
        # Check if specified role matches user's role
        if credentials.role == nil or credentials.role == user_info.role do
          {:ok, user_info}
        else
          {:error, "Role mismatch"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Mock user lookup - replace with actual user store in production
  defp mock_user_lookup(username, password) do
    # Simulate user database lookup
    users = %{
      "patient123" => %{user_id: "patient_123", role: :patient, password_hash: "hash123"},
      "therapist456" => %{user_id: "therapist_456", role: :therapist, password_hash: "hash456"},
      "admin789" => %{user_id: "admin_789", role: :admin, password_hash: "hash789"},
      "emergency911" => %{user_id: "emergency_911", role: :emergency, password_hash: "hash911"}
    }
    
    case Map.get(users, username) do
      nil ->
        # Simulate timing attack protection
        :timer.sleep(100)
        {:error, "Invalid credentials"}
      user_info ->
        if verify_password(password, user_info.password_hash) do
          {:ok, %{
            user_id: user_info.user_id,
            role: user_info.role
          }}
        else
          {:error, "Invalid credentials"}
        end
    end
  end

  defp verify_password(password, password_hash) do
    # Mock password verification - use proper password hashing in production
    expected_hash = "hash" <> String.slice(password, -3, 3)
    password_hash == expected_hash
  end

  defp blacklist_token(_token, expires_at) do
    # In production, store in Redis or database
    # For now, just log the blacklisting
    Logger.info("Token blacklisted until #{expires_at}")
  end

  defp token_blacklisted?(_token) do
    # In production, check blacklist store
    false
  end

  defp get_session_info(session_id) do
    # Mock session store - replace with Redis/ETS in production
    {:ok, %{
      session_id: session_id,
      active: true,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now()
    }}
  end

  defp log_auth_event(event_type, user_identifier, device_info) do
    Logger.info(
      "Auth event: #{event_type} for #{user_identifier}" <>
      case device_info do
        nil -> ""
        info -> " from #{info["device_type"] || "unknown"} device"
      end
    )
  end

  defp log_emergency_access(requesting_user_id, target_patient_id, reason) do
    # Emergency access should be audited
    Logger.warning(
      "EMERGENCY ACCESS: User #{requesting_user_id} accessing patient #{target_patient_id}. " <>
      "Reason: #{reason}"
    )
    
    # In production, store in audit log database
  end

  defp get_secret_key do
    case @secret_key_base do
      nil ->
        Logger.error("Secret key base not configured")
        raise "JWT secret key not configured"
      key when byte_size(key) < 32 ->
        Logger.error("Secret key base too short")
        raise "JWT secret key must be at least 32 bytes"
      key ->
        # Derive JWT signing key from secret key base
        :crypto.hash(:sha256, key <> "jwt_signing")
    end
  end
end