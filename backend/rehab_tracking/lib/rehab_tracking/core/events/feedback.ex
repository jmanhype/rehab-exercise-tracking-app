defmodule RehabTracking.Core.Events.Feedback do
  @moduledoc """
  Event representing feedback provided to or from patients during exercise sessions.
  Supports both automated coaching feedback and patient self-reported feedback.
  """

  @derive Jason.Encoder
  defstruct [
    :feedback_id,
    :session_id,
    :patient_id,
    :exercise_id,
    :feedback_type,     # :coaching, :pain_scale, :difficulty, :motivation
    :feedback_source,   # :system, :patient, :therapist
    :content,
    :severity_level,    # :low, :medium, :high, :critical
    :triggered_by,      # Event ID that triggered this feedback
    :timestamp,
    :acknowledged_at,
    :response_data,     # Patient responses to feedback
    :metadata
  ]

  @type feedback_type :: :coaching | :pain_scale | :difficulty | :motivation | :completion
  @type feedback_source :: :system | :patient | :therapist
  @type severity_level :: :low | :medium | :high | :critical

  @type t :: %__MODULE__{
    feedback_id: String.t(),
    session_id: String.t(),
    patient_id: String.t(),
    exercise_id: String.t() | nil,
    feedback_type: feedback_type(),
    feedback_source: feedback_source(),
    content: String.t() | map(),
    severity_level: severity_level(),
    triggered_by: String.t() | nil,
    timestamp: DateTime.t(),
    acknowledged_at: DateTime.t() | nil,
    response_data: map() | nil,
    metadata: map() | nil
  }

  @doc """
  Creates coaching feedback based on form analysis.
  """
  def coaching_feedback(attrs) do
    new(Map.merge(attrs, %{
      feedback_type: :coaching,
      feedback_source: :system,
      severity_level: :medium
    }))
  end

  @doc """
  Creates patient self-reported feedback (pain, difficulty, etc).
  """
  def patient_feedback(attrs) do
    new(Map.merge(attrs, %{
      feedback_source: :patient,
      severity_level: attrs[:severity_level] || :low
    }))
  end

  @doc """
  Creates therapist feedback or intervention.
  """
  def therapist_feedback(attrs) do
    new(Map.merge(attrs, %{
      feedback_source: :therapist,
      severity_level: attrs[:severity_level] || :medium
    }))
  end

  @doc """
  Creates a new feedback event.
  """
  def new(attrs) do
    %__MODULE__{
      feedback_id: attrs[:feedback_id] || generate_id(),
      session_id: attrs.session_id,
      patient_id: attrs.patient_id,
      exercise_id: attrs[:exercise_id],
      feedback_type: attrs.feedback_type,
      feedback_source: attrs.feedback_source,
      content: attrs.content,
      severity_level: attrs.severity_level || :low,
      triggered_by: attrs[:triggered_by],
      timestamp: attrs[:timestamp] || DateTime.utc_now(),
      acknowledged_at: attrs[:acknowledged_at],
      response_data: attrs[:response_data],
      metadata: attrs[:metadata] || %{}
    }
  end

  @doc """
  Validates feedback event structure.
  """
  def valid?(%__MODULE__{} = event) do
    not is_nil(event.patient_id) and
    event.feedback_type in [:coaching, :pain_scale, :difficulty, :motivation, :completion] and
    event.feedback_source in [:system, :patient, :therapist] and
    event.severity_level in [:low, :medium, :high, :critical] and
    not is_nil(event.content)
  end

  def valid?(_), do: false

  defp generate_id, do: UUID.uuid4()
end