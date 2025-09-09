defmodule RehabTracking.Schemas.Auth do
  @moduledoc """
  Ecto schemas for user authentication and authorization.
  
  These schemas handle user management, PHI consent tracking,
  and security logging for HIPAA compliance.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defmodule User do
    @moduledoc "Core user schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    # @derive {Phoenix.Param, key: :id}  # Commented out - Phoenix not loaded yet
    schema "users" do
      field :email, :string
      field :password_hash, :string
      field :role, :string
      field :status, :string, default: "active"
      
      field :first_name, :string
      field :last_name, :string
      field :phone, :string
      field :timezone, :string, default: "UTC"
      
      field :last_login_at, :utc_datetime_usec
      field :failed_login_attempts, :integer, default: 0
      field :locked_until, :utc_datetime_usec
      field :password_changed_at, :utc_datetime_usec
      field :email_confirmed_at, :utc_datetime_usec
      
      field :phi_access_granted, :boolean, default: false
      field :phi_training_completed_at, :utc_datetime_usec
      field :hipaa_acknowledgment_at, :utc_datetime_usec
      
      # Virtual fields
      field :password, :string, virtual: true
      field :password_confirmation, :string, virtual: true
      
      # Associations
      has_one :therapist_profile, RehabTracking.Schemas.Auth.TherapistProfile
      has_one :patient_profile, RehabTracking.Schemas.Auth.PatientProfile
      has_many :sessions, RehabTracking.Schemas.Auth.UserSession
      has_many :phi_consents, RehabTracking.Schemas.Auth.PHIConsent, foreign_key: :patient_user_id
      
      timestamps(type: :utc_datetime_usec)
    end

    @roles ~w(patient therapist admin emergency)
    @statuses ~w(active inactive suspended locked)
    
    @required_fields [:email, :first_name, :last_name, :role]
    @optional_fields [:phone, :timezone, :status, :last_login_at, :failed_login_attempts,
                     :locked_until, :password_changed_at, :email_confirmed_at, :phi_access_granted,
                     :phi_training_completed_at, :hipaa_acknowledgment_at]

    def changeset(user, attrs \\ %{}) do
      user
      |> cast(attrs, @required_fields ++ @optional_fields ++ [:password, :password_confirmation])
      |> validate_required(@required_fields)
      |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/)
      |> validate_length(:first_name, min: 1, max: 100)
      |> validate_length(:last_name, min: 1, max: 100)
      |> validate_inclusion(:role, @roles)
      |> validate_inclusion(:status, @statuses)
      |> unique_constraint(:email)
      |> validate_password()
    end

    def registration_changeset(user, attrs \\ %{}) do
      user
      |> changeset(attrs)
      |> validate_required([:password])
      |> validate_confirmation(:password, message: "does not match password")
      |> hash_password()
      |> put_password_changed_at()
    end

    def password_changeset(user, attrs \\ %{}) do
      user
      |> cast(attrs, [:password, :password_confirmation])
      |> validate_required([:password])
      |> validate_confirmation(:password, message: "does not match password")
      |> validate_password()
      |> hash_password()
      |> put_password_changed_at()
    end

    defp validate_password(changeset) do
      changeset
      |> validate_length(:password, min: 8, max: 128)
      |> validate_format(:password, ~r/[A-Z]/, message: "must contain at least one uppercase letter")
      |> validate_format(:password, ~r/[a-z]/, message: "must contain at least one lowercase letter")
      |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one number")
      |> validate_format(:password, ~r/[^A-Za-z0-9]/, message: "must contain at least one special character")
    end

    defp hash_password(changeset) do
      case get_change(changeset, :password) do
        nil -> changeset
        password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      end
    end

    defp put_password_changed_at(changeset) do
      put_change(changeset, :password_changed_at, DateTime.utc_now())
    end

    @doc "Verify password against hash"
    def valid_password?(%{password_hash: hash}, password) when is_binary(hash) and is_binary(password) do
      Bcrypt.verify_pass(password, hash)
    end
    def valid_password?(_, _), do: false

    @doc "Check if user account is locked"
    def locked?(%{locked_until: locked_until}) when is_struct(locked_until) do
      DateTime.compare(DateTime.utc_now(), locked_until) == :lt
    end
    def locked?(_), do: false

    @doc "Get active users by role"
    def active_users_query(role) do
      from u in __MODULE__,
        where: u.role == ^role and u.status == "active",
        order_by: [asc: u.last_name, asc: u.first_name]
    end

    @doc "Get users requiring PHI training"
    def phi_training_required_query do
      from u in __MODULE__,
        where: u.role in ^["therapist", "admin"] and is_nil(u.phi_training_completed_at),
        where: u.status == "active",
        order_by: [asc: u.inserted_at]
    end

    def full_name(%{first_name: first, last_name: last}), do: "#{first} #{last}"
  end

  defmodule TherapistProfile do
    @moduledoc "Therapist-specific profile information"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:user_id, :binary_id, autogenerate: false}
    schema "therapist_profiles" do
      belongs_to :user, RehabTracking.Schemas.Auth.User,
        define_field: false, type: :binary_id
      
      field :license_number, :string
      field :license_type, :string
      field :license_state, :string
      field :license_expires_at, :date
      
      field :clinic_name, :string
      field :npi_number, :string
      field :specializations, {:array, :string}, default: []
      
      field :default_alert_preferences, :map, default: %{}
      field :workload_capacity_minutes, :integer, default: 480
      field :patient_load_limit, :integer, default: 50
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:user_id]
    @optional_fields [:license_number, :license_type, :license_state, :license_expires_at,
                     :clinic_name, :npi_number, :specializations, :default_alert_preferences,
                     :workload_capacity_minutes, :patient_load_limit]

    def changeset(profile, attrs \\ %{}) do
      profile
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_length(:license_number, max: 50)
      |> validate_length(:clinic_name, max: 200)
      |> validate_length(:npi_number, is: 10)
      |> validate_number(:workload_capacity_minutes, greater_than: 0)
      |> validate_number(:patient_load_limit, greater_than: 0)
      |> foreign_key_constraint(:user_id)
    end

    @doc "Get therapists with expiring licenses"
    def expiring_licenses_query(days_ahead \\ 30) do
      cutoff_date = Date.add(Date.utc_today(), days_ahead)
      
      from p in __MODULE__,
        join: u in RehabTracking.Schemas.Auth.User, on: p.user_id == u.id,
        where: not is_nil(p.license_expires_at) and p.license_expires_at <= ^cutoff_date,
        where: u.status == "active",
        order_by: [asc: p.license_expires_at],
        preload: [:user]
    end
  end

  defmodule PatientProfile do
    @moduledoc "Patient-specific profile information"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:user_id, :binary_id, autogenerate: false}
    schema "patient_profiles" do
      belongs_to :user, RehabTracking.Schemas.Auth.User,
        define_field: false, type: :binary_id
      belongs_to :assigned_therapist, RehabTracking.Schemas.Auth.User,
        type: :binary_id, foreign_key: :assigned_therapist_id
      
      field :patient_id, :string  # External EMR patient ID
      field :date_of_birth, :date
      field :gender, :string
      
      # Encrypted PHI fields
      field :primary_diagnosis, :string
      field :secondary_conditions, {:array, :string}, default: []
      field :medications, {:array, :string}, default: []
      field :allergies, {:array, :string}, default: []
      
      field :program_start_date, :date
      field :program_end_date, :date
      field :program_type, :string
      
      # Emergency contacts (encrypted)
      field :emergency_contact_name, :string
      field :emergency_contact_phone, :string
      field :emergency_contact_relation, :string
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:user_id]
    @optional_fields [:patient_id, :date_of_birth, :gender, :primary_diagnosis, :secondary_conditions,
                     :medications, :allergies, :assigned_therapist_id, :program_start_date,
                     :program_end_date, :program_type, :emergency_contact_name, :emergency_contact_phone,
                     :emergency_contact_relation]

    def changeset(profile, attrs \\ %{}) do
      profile
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_length(:patient_id, max: 50)
      |> validate_inclusion(:gender, ["male", "female", "non-binary", "other", "prefer_not_to_say"])
      |> validate_length(:program_type, max: 50)
      |> foreign_key_constraint(:user_id)
      |> foreign_key_constraint(:assigned_therapist_id)
    end

    @doc "Get patients assigned to therapist"
    def therapist_patients_query(therapist_id) do
      from p in __MODULE__,
        join: u in RehabTracking.Schemas.Auth.User, on: p.user_id == u.id,
        where: p.assigned_therapist_id == ^therapist_id,
        where: u.status == "active",
        order_by: [asc: u.last_name, asc: u.first_name],
        preload: [:user]
    end

    @doc "Get active program patients"
    def active_program_query do
      today = Date.utc_today()
      
      from p in __MODULE__,
        join: u in RehabTracking.Schemas.Auth.User, on: p.user_id == u.id,
        where: p.program_start_date <= ^today,
        where: is_nil(p.program_end_date) or p.program_end_date >= ^today,
        where: u.status == "active",
        preload: [:user, :assigned_therapist]
    end
  end

  defmodule PHIConsent do
    @moduledoc "PHI consent tracking schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "phi_consents" do
      belongs_to :patient_user, RehabTracking.Schemas.Auth.User, type: :binary_id
      belongs_to :consenting_user, RehabTracking.Schemas.Auth.User, type: :binary_id
      
      field :consent_type, :string
      field :consent_status, :string
      
      field :consent_text, :string
      field :consent_version, :string
      field :granted_at, :utc_datetime_usec
      field :expires_at, :utc_datetime_usec
      field :revoked_at, :utc_datetime_usec
      field :revocation_reason, :string
      
      field :data_types_consented, {:array, :string}, default: []
      field :sharing_permissions, :map, default: %{}
      field :third_party_sharing, :boolean, default: false
      
      field :witness_name, :string
      field :witness_signature_hash, :string
      field :digital_signature_hash, :string
      field :ip_address, :string
      field :user_agent, :string
      
      timestamps(type: :utc_datetime_usec)
    end

    @consent_types ~w(data_collection data_sharing research_participation emergency_access)
    @consent_statuses ~w(granted revoked expired)
    
    @required_fields [:patient_user_id, :consenting_user_id, :consent_type, :consent_status,
                     :consent_text, :consent_version, :granted_at]
    @optional_fields [:expires_at, :revoked_at, :revocation_reason, :data_types_consented,
                     :sharing_permissions, :third_party_sharing, :witness_name, :witness_signature_hash,
                     :digital_signature_hash, :ip_address, :user_agent]

    def changeset(consent, attrs \\ %{}) do
      consent
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:consent_type, @consent_types)
      |> validate_inclusion(:consent_status, @consent_statuses)
      |> validate_length(:revocation_reason, max: 200)
      |> foreign_key_constraint(:patient_user_id)
      |> foreign_key_constraint(:consenting_user_id)
    end

    @doc "Get active consents for patient"
    def active_consents_query(patient_user_id) do
      now = DateTime.utc_now()
      
      from c in __MODULE__,
        where: c.patient_user_id == ^patient_user_id,
        where: c.consent_status == "granted",
        where: is_nil(c.expires_at) or c.expires_at > ^now,
        order_by: [desc: c.granted_at]
    end

    @doc "Check if specific consent is active"
    def has_active_consent?(repo, patient_user_id, consent_type) do
      query = from c in active_consents_query(patient_user_id),
        where: c.consent_type == ^consent_type,
        limit: 1
      
      repo.exists?(query)
    end

    @doc "Revoke consent"
    def revoke_consent(consent, reason) do
      consent
      |> changeset(%{
        consent_status: "revoked",
        revoked_at: DateTime.utc_now(),
        revocation_reason: reason
      })
    end
  end

  defmodule UserSession do
    @moduledoc "User session tracking schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "user_sessions" do
      belongs_to :user, RehabTracking.Schemas.Auth.User, type: :binary_id
      
      field :token_hash, :string
      field :device_fingerprint, :string
      field :ip_address, :string
      field :user_agent, :string
      
      field :created_at, :utc_datetime_usec
      field :last_accessed_at, :utc_datetime_usec
      field :expires_at, :utc_datetime_usec
      field :invalidated_at, :utc_datetime_usec
      field :invalidation_reason, :string
      
      field :phi_access_session, :boolean, default: false
      field :break_glass_access, :boolean, default: false
      field :session_type, :string, default: "standard"
      
      # Virtual field for token
      field :token, :string, virtual: true
      
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    @session_types ~w(standard emergency api mobile)
    
    @required_fields [:user_id, :token_hash, :created_at, :last_accessed_at, :expires_at]
    @optional_fields [:device_fingerprint, :ip_address, :user_agent, :invalidated_at,
                     :invalidation_reason, :phi_access_session, :break_glass_access, :session_type]

    def changeset(session, attrs \\ %{}) do
      session
      |> cast(attrs, @required_fields ++ @optional_fields ++ [:token])
      |> validate_required(@required_fields)
      |> validate_inclusion(:session_type, @session_types)
      |> unique_constraint(:token_hash)
      |> hash_token()
    end

    defp hash_token(changeset) do
      case get_change(changeset, :token) do
        nil -> changeset
        token -> put_change(changeset, :token_hash, :crypto.hash(:sha256, token) |> Base.encode64())
      end
    end

    @doc "Create new session"
    def create_session(user_id, session_attrs \\ %{}) do
      token = generate_token()
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, 8 * 60 * 60, :second)  # 8 hours
      
      %__MODULE__{}
      |> changeset(Map.merge(session_attrs, %{
        user_id: user_id,
        token: token,
        created_at: now,
        last_accessed_at: now,
        expires_at: expires_at
      }))
    end

    @doc "Get active sessions for user"
    def active_sessions_query(user_id) do
      now = DateTime.utc_now()
      
      from s in __MODULE__,
        where: s.user_id == ^user_id,
        where: is_nil(s.invalidated_at) and s.expires_at > ^now,
        order_by: [desc: s.last_accessed_at]
    end

    @doc "Invalidate session"
    def invalidate_session(session, reason \\ "logout") do
      session
      |> changeset(%{
        invalidated_at: DateTime.utc_now(),
        invalidation_reason: reason
      })
    end

    defp generate_token do
      32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    end
  end

  defmodule EmergencyAccessLog do
    @moduledoc "Emergency break-glass access logging schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "emergency_access_logs" do
      belongs_to :accessing_user, RehabTracking.Schemas.Auth.User, type: :binary_id
      belongs_to :patient_user, RehabTracking.Schemas.Auth.User, type: :binary_id
      belongs_to :supervisor_user, RehabTracking.Schemas.Auth.User, type: :binary_id
      
      field :reason, :string
      field :justification, :string
      
      field :access_granted_at, :utc_datetime_usec
      field :access_duration_minutes, :integer
      field :data_accessed, {:array, :string}, default: []
      field :actions_taken, {:array, :string}, default: []
      
      field :supervisor_approval, :boolean, default: false
      field :approved_at, :utc_datetime_usec
      field :audit_reviewed, :boolean, default: false
      field :audit_reviewed_at, :utc_datetime_usec
      
      field :risk_level, :string
      field :compliance_flags, {:array, :string}, default: []
      
      timestamps(type: :utc_datetime_usec)
    end

    @risk_levels ~w(low medium high critical)
    
    @required_fields [:accessing_user_id, :patient_user_id, :reason, :justification,
                     :access_granted_at, :access_duration_minutes, :risk_level]
    @optional_fields [:data_accessed, :actions_taken, :supervisor_approval, :supervisor_user_id,
                     :approved_at, :audit_reviewed, :audit_reviewed_at, :compliance_flags]

    def changeset(log, attrs \\ %{}) do
      log
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:risk_level, @risk_levels)
      |> validate_length(:reason, max: 500)
      |> validate_number(:access_duration_minutes, greater_than: 0)
      |> foreign_key_constraint(:accessing_user_id)
      |> foreign_key_constraint(:patient_user_id)
      |> foreign_key_constraint(:supervisor_user_id)
    end

    @doc "Get emergency access logs requiring review"
    def pending_review_query do
      from l in __MODULE__,
        where: l.audit_reviewed == false,
        order_by: [desc: l.access_granted_at],
        preload: [:accessing_user, :patient_user, :supervisor_user]
    end

    @doc "Get high-risk emergency accesses"
    def high_risk_query(days_back \\ 30) do
      cutoff = DateTime.add(DateTime.utc_now(), -days_back * 24 * 60 * 60, :second)
      
      from l in __MODULE__,
        where: l.risk_level in ^["high", "critical"],
        where: l.access_granted_at >= ^cutoff,
        order_by: [desc: l.access_granted_at],
        preload: [:accessing_user, :patient_user]
    end
  end

  # Helper functions for authentication operations
  @doc "Authenticate user with email and password"
  def authenticate_user(repo, email, password) do
    case repo.get_by(User, email: String.downcase(email)) do
      nil ->
        {:error, :invalid_credentials}
      
      user ->
        if User.locked?(user) do
          {:error, :account_locked}
        else
          verify_password(repo, user, password)
        end
    end
  end

  defp verify_password(repo, user, password) do
    if User.valid_password?(user, password) do
      # Reset failed attempts on successful login
      user
      |> User.changeset(%{
        failed_login_attempts: 0,
        last_login_at: DateTime.utc_now()
      })
      |> repo.update()
      
      {:ok, user}
    else
      # Increment failed attempts
      attempts = (user.failed_login_attempts || 0) + 1
      lock_until = if attempts >= 5, do: DateTime.add(DateTime.utc_now(), 30 * 60, :second), else: nil
      
      user
      |> User.changeset(%{
        failed_login_attempts: attempts,
        locked_until: lock_until
      })
      |> repo.update()
      
      {:error, :invalid_credentials}
    end
  end

  @doc "Create user session with token"
  def create_user_session(repo, user, session_attrs \\ %{}) do
    with {:ok, session} <- UserSession.create_session(user.id, session_attrs) |> repo.insert() do
      {:ok, session.token, session}
    end
  end

  @doc "Get user from session token"
  def get_user_by_session_token(repo, token) do
    token_hash = :crypto.hash(:sha256, token) |> Base.encode64()
    now = DateTime.utc_now()
    
    query = from s in UserSession,
      join: u in User, on: s.user_id == u.id,
      where: s.token_hash == ^token_hash,
      where: is_nil(s.invalidated_at) and s.expires_at > ^now,
      select: {u, s}
    
    case repo.one(query) do
      {user, session} ->
        # Update last accessed time
        session
        |> UserSession.changeset(%{last_accessed_at: now})
        |> repo.update()
        
        {:ok, user}
      
      nil ->
        {:error, :invalid_session}
    end
  end

  @doc "Log emergency break-glass access"
  def log_emergency_access(repo, attrs) do
    %EmergencyAccessLog{}
    |> EmergencyAccessLog.changeset(attrs)
    |> repo.insert()
  end
end