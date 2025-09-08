defmodule RehabTracking.Repo.Migrations.CreateUserAuthentication do
  @moduledoc """
  Creates user authentication and authorization tables.
  
  Supports therapists, patients, and admin users with role-based access control.
  Includes PHI consent tracking and break-glass emergency access.
  """
  use Ecto.Migration

  def up do
    # Core users table
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :string, size: 255, null: false
      add :password_hash, :string, size: 128, null: false
      add :role, :string, size: 20, null: false  # patient, therapist, admin, emergency
      add :status, :string, size: 20, null: false, default: "active"
      
      # Profile information
      add :first_name, :string, size: 100, null: false
      add :last_name, :string, size: 100, null: false
      add :phone, :string, size: 20
      add :timezone, :string, size: 50, default: "UTC"
      
      # Security tracking
      add :last_login_at, :utc_datetime_usec
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime_usec
      add :password_changed_at, :utc_datetime_usec
      add :email_confirmed_at, :utc_datetime_usec
      
      # PHI access permissions
      add :phi_access_granted, :boolean, default: false
      add :phi_training_completed_at, :utc_datetime_usec
      add :hipaa_acknowledgment_at, :utc_datetime_usec
      
      timestamps(type: :utc_datetime_usec)
    end

    # Therapist-specific profile information
    create table(:therapist_profiles, primary_key: false) do
      add :user_id, :uuid, primary_key: true
      add :license_number, :string, size: 50
      add :license_type, :string, size: 50  # PT, OT, etc.
      add :license_state, :string, size: 10
      add :license_expires_at, :date
      
      # Professional information
      add :clinic_name, :string, size: 200
      add :npi_number, :string, size: 20
      add :specializations, {:array, :string}, default: []
      
      # System preferences
      add :default_alert_preferences, :jsonb, default: fragment("'{}'::jsonb")
      add :workload_capacity_minutes, :integer, default: 480
      add :patient_load_limit, :integer, default: 50
      
      timestamps(type: :utc_datetime_usec)
    end

    # Patient-specific profile information
    create table(:patient_profiles, primary_key: false) do
      add :user_id, :uuid, primary_key: true
      add :patient_id, :string, size: 50  # External patient ID from EMR
      add :date_of_birth, :date
      add :gender, :string, size: 20
      
      # Medical information (encrypted PHI)
      add :primary_diagnosis, :text  # encrypted
      add :secondary_conditions, {:array, :string}, default: []
      add :medications, {:array, :string}, default: []
      add :allergies, {:array, :string}, default: []
      
      # Program assignment
      add :assigned_therapist_id, :uuid
      add :program_start_date, :date
      add :program_end_date, :date
      add :program_type, :string, size: 50
      
      # Emergency contacts (encrypted PHI)
      add :emergency_contact_name, :text  # encrypted
      add :emergency_contact_phone, :text  # encrypted
      add :emergency_contact_relation, :text  # encrypted
      
      timestamps(type: :utc_datetime_usec)
    end

    # PHI consent tracking
    create table(:phi_consents) do
      add :id, :uuid, primary_key: true
      add :patient_user_id, :uuid, null: false
      add :consenting_user_id, :uuid, null: false  # Could be patient or guardian
      add :consent_type, :string, size: 50, null: false  # data_collection, sharing, research
      add :consent_status, :string, size: 20, null: false  # granted, revoked, expired
      
      # Consent details
      add :consent_text, :text, null: false
      add :consent_version, :string, size: 20, null: false
      add :granted_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      add :revocation_reason, :string, size: 200
      
      # Scope of consent
      add :data_types_consented, {:array, :string}, default: []
      add :sharing_permissions, :jsonb, default: fragment("'{}'::jsonb")
      add :third_party_sharing, :boolean, default: false
      
      # Legal compliance
      add :witness_name, :string, size: 100
      add :witness_signature_hash, :string, size: 128
      add :digital_signature_hash, :string, size: 128
      add :ip_address, :string, size: 45
      add :user_agent, :text
      
      timestamps(type: :utc_datetime_usec)
    end

    # Authentication sessions and tokens
    create table(:user_sessions) do
      add :id, :uuid, primary_key: true
      add :user_id, :uuid, null: false
      add :token_hash, :string, size: 128, null: false
      add :device_fingerprint, :string, size: 128
      add :ip_address, :string, size: 45
      add :user_agent, :text
      
      # Session management
      add :created_at, :utc_datetime_usec, null: false
      add :last_accessed_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :invalidated_at, :utc_datetime_usec
      add :invalidation_reason, :string, size: 100
      
      # Security context
      add :phi_access_session, :boolean, default: false
      add :break_glass_access, :boolean, default: false
      add :session_type, :string, size: 20, default: "standard"  # standard, emergency, api
      
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Break-glass emergency access logging
    create table(:emergency_access_logs) do
      add :id, :uuid, primary_key: true
      add :accessing_user_id, :uuid, null: false
      add :patient_user_id, :uuid, null: false
      add :reason, :string, size: 500, null: false
      add :justification, :text, null: false
      
      # Access details
      add :access_granted_at, :utc_datetime_usec, null: false
      add :access_duration_minutes, :integer, null: false
      add :data_accessed, {:array, :string}, default: []
      add :actions_taken, {:array, :string}, default: []
      
      # Approval and oversight
      add :supervisor_approval, :boolean, default: false
      add :supervisor_user_id, :uuid
      add :approved_at, :utc_datetime_usec
      add :audit_reviewed, :boolean, default: false
      add :audit_reviewed_at, :utc_datetime_usec
      
      # Risk and compliance
      add :risk_level, :string, size: 20, null: false  # low, medium, high, critical
      add :compliance_flags, {:array, :string}, default: []
      
      timestamps(type: :utc_datetime_usec)
    end

    # Create indexes for performance
    create unique_index(:users, [:email])
    create index(:users, [:role, :status])
    create index(:users, [:last_login_at])
    create index(:users, [:locked_until])
    
    create index(:therapist_profiles, [:license_number])
    create index(:therapist_profiles, [:license_expires_at])
    
    create index(:patient_profiles, [:patient_id])
    create index(:patient_profiles, [:assigned_therapist_id])
    create index(:patient_profiles, [:program_start_date, :program_end_date])
    
    create index(:phi_consents, [:patient_user_id, :consent_type])
    create index(:phi_consents, [:consent_status])
    create index(:phi_consents, [:expires_at])
    create index(:phi_consents, [:granted_at])
    
    create unique_index(:user_sessions, [:token_hash])
    create index(:user_sessions, [:user_id, :expires_at])
    create index(:user_sessions, [:phi_access_session])
    create index(:user_sessions, [:break_glass_access])
    
    create index(:emergency_access_logs, [:accessing_user_id, :access_granted_at])
    create index(:emergency_access_logs, [:patient_user_id])
    create index(:emergency_access_logs, [:risk_level])
    create index(:emergency_access_logs, [:audit_reviewed])

    # Foreign key constraints
    alter table(:therapist_profiles) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all)
    end
    
    alter table(:patient_profiles) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      modify :assigned_therapist_id, references(:users, type: :uuid, on_delete: :nilify_all)
    end
    
    alter table(:phi_consents) do
      modify :patient_user_id, references(:users, type: :uuid, on_delete: :delete_all)
      modify :consenting_user_id, references(:users, type: :uuid, on_delete: :delete_all)
    end
    
    alter table(:user_sessions) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all)
    end
    
    alter table(:emergency_access_logs) do
      modify :accessing_user_id, references(:users, type: :uuid, on_delete: :restrict)
      modify :patient_user_id, references(:users, type: :uuid, on_delete: :restrict)
      modify :supervisor_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
    end

    # Data validation constraints
    create constraint(:users, :valid_role,
           check: "role IN ('patient', 'therapist', 'admin', 'emergency')")
    create constraint(:users, :valid_status,
           check: "status IN ('active', 'inactive', 'suspended', 'locked')")
    create constraint(:users, :valid_email_format,
           check: "email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'")
    
    create constraint(:phi_consents, :valid_consent_type,
           check: "consent_type IN ('data_collection', 'data_sharing', 'research_participation', 'emergency_access')")
    create constraint(:phi_consents, :valid_consent_status,
           check: "consent_status IN ('granted', 'revoked', 'expired')")
    
    create constraint(:user_sessions, :valid_session_type,
           check: "session_type IN ('standard', 'emergency', 'api', 'mobile')")
    
    create constraint(:emergency_access_logs, :valid_risk_level,
           check: "risk_level IN ('low', 'medium', 'high', 'critical')")
    create constraint(:emergency_access_logs, :positive_duration,
           check: "access_duration_minutes > 0")
  end

  def down do
    drop table(:emergency_access_logs)
    drop table(:user_sessions)
    drop table(:phi_consents)
    drop table(:patient_profiles)
    drop table(:therapist_profiles)
    drop table(:users)
  end
end