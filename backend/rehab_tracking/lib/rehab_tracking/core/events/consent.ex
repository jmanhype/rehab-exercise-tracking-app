defmodule RehabTracking.Core.Events.Consent do
  @moduledoc """
  Event representing patient consent for data collection, processing, and sharing.
  Critical for HIPAA compliance and PHI handling in healthcare contexts.
  """

  @derive Jason.Encoder
  defstruct [
    :consent_id,
    :patient_id,
    :consent_type,      # :data_collection, :sharing, :research, :marketing
    :consent_version,   # Version of consent form
    :granted_at,
    :expires_at,
    :revoked_at,
    :status,           # :granted, :revoked, :expired, :pending
    :granted_by,       # Patient identifier or guardian
    :witness_id,       # Healthcare provider witness
    :consent_details,   # Specific permissions granted
    :revocation_reason,
    :ip_address,       # For audit trail
    :user_agent,       # Device/browser info
    :digital_signature,
    :metadata
  ]

  @type consent_type :: :data_collection | :sharing | :research | :marketing | :video_recording
  @type status :: :granted | :revoked | :expired | :pending

  @type t :: %__MODULE__{
    consent_id: String.t(),
    patient_id: String.t(),
    consent_type: consent_type(),
    consent_version: String.t(),
    granted_at: DateTime.t() | nil,
    expires_at: DateTime.t() | nil,
    revoked_at: DateTime.t() | nil,
    status: status(),
    granted_by: String.t(),
    witness_id: String.t() | nil,
    consent_details: map(),
    revocation_reason: String.t() | nil,
    ip_address: String.t() | nil,
    user_agent: String.t() | nil,
    digital_signature: String.t() | nil,
    metadata: map() | nil
  }

  @doc """
  Creates a data collection consent (required for exercise tracking).
  """
  def data_collection_consent(patient_id, attrs \\ %{}) do
    new(Map.merge(attrs, %{
      patient_id: patient_id,
      consent_type: :data_collection,
      consent_details: %{
        exercise_data: true,
        video_analysis: Map.get(attrs, :video_analysis, false),
        biometric_data: Map.get(attrs, :biometric_data, false),
        device_sensors: true
      }
    }))
  end

  @doc """
  Creates a data sharing consent (for therapist access).
  """
  def sharing_consent(patient_id, therapist_ids, attrs \\ %{}) do
    new(Map.merge(attrs, %{
      patient_id: patient_id,
      consent_type: :sharing,
      consent_details: %{
        authorized_therapists: therapist_ids,
        share_progress_reports: true,
        share_adherence_data: true,
        share_form_analysis: Map.get(attrs, :share_form_analysis, true)
      }
    }))
  end

  @doc """
  Creates a research participation consent.
  """
  def research_consent(patient_id, study_id, attrs \\ %{}) do
    new(Map.merge(attrs, %{
      patient_id: patient_id,
      consent_type: :research,
      consent_details: %{
        study_id: study_id,
        anonymized_data: true,
        aggregate_analysis: true,
        publication_consent: Map.get(attrs, :publication_consent, false)
      }
    }))
  end

  @doc """
  Creates a new consent event.
  """
  def new(attrs) do
    %__MODULE__{
      consent_id: attrs[:consent_id] || generate_id(),
      patient_id: attrs.patient_id,
      consent_type: attrs.consent_type,
      consent_version: attrs[:consent_version] || "1.0",
      granted_at: if(attrs[:status] == :granted, do: DateTime.utc_now(), else: nil),
      expires_at: attrs[:expires_at] || default_expiry(),
      revoked_at: if(attrs[:status] == :revoked, do: DateTime.utc_now(), else: nil),
      status: attrs[:status] || :granted,
      granted_by: attrs.granted_by || attrs.patient_id,
      witness_id: attrs[:witness_id],
      consent_details: attrs[:consent_details] || %{},
      revocation_reason: attrs[:revocation_reason],
      ip_address: attrs[:ip_address],
      user_agent: attrs[:user_agent],
      digital_signature: attrs[:digital_signature],
      metadata: attrs[:metadata] || %{}
    }
  end

  @doc """
  Revokes an existing consent.
  """
  def revoke(%__MODULE__{} = consent, reason \\ nil) do
    %{consent |
      status: :revoked,
      revoked_at: DateTime.utc_now(),
      revocation_reason: reason
    }
  end

  @doc """
  Checks if consent is currently valid and active.
  """
  def active?(%__MODULE__{status: :granted, expires_at: expires_at}) do
    is_nil(expires_at) or DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end
  def active?(_), do: false

  @doc """
  Validates consent event structure.
  """
  def valid?(%__MODULE__{} = event) do
    not is_nil(event.patient_id) and
    event.consent_type in [:data_collection, :sharing, :research, :marketing, :video_recording] and
    event.status in [:granted, :revoked, :expired, :pending] and
    not is_nil(event.granted_by)
  end

  def valid?(_), do: false

  # Private helpers
  defp generate_id, do: UUID.uuid4()
  
  defp default_expiry do
    DateTime.utc_now() |> DateTime.add(365 * 24 * 60 * 60, :second) # 1 year
  end
end