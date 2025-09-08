defmodule RehabTracking.Core.Events do
  @moduledoc """
  Public interface module for all core domain events.
  Provides convenient access to all event types.
  """

  alias RehabTracking.Core.Events.{
    ExerciseSession,
    RepObservation,
    Feedback,
    Alert,
    Consent
  }

  # Re-export event modules for easy access
  defdelegate exercise_session_new(attrs), to: ExerciseSession, as: :new
  defdelegate rep_observation_new(attrs), to: RepObservation, as: :new
  defdelegate feedback_new(attrs), to: Feedback, as: :new
  defdelegate alert_new(attrs), to: Alert, as: :new
  defdelegate consent_new(attrs), to: Consent, as: :new

  # Convenience functions for common event creation patterns
  def coaching_feedback(attrs), do: Feedback.coaching_feedback(attrs)
  def patient_feedback(attrs), do: Feedback.patient_feedback(attrs)
  def therapist_feedback(attrs), do: Feedback.therapist_feedback(attrs)

  def missed_sessions_alert(patient_id, conditions), do: Alert.missed_sessions_alert(patient_id, conditions)
  def poor_form_alert(patient_id, exercise_id, conditions), do: Alert.poor_form_alert(patient_id, exercise_id, conditions)
  def pain_alert(patient_id, exercise_id, pain_level), do: Alert.pain_alert(patient_id, exercise_id, pain_level)

  def data_collection_consent(patient_id, attrs \\ %{}), do: Consent.data_collection_consent(patient_id, attrs)
  def sharing_consent(patient_id, therapist_ids, attrs \\ %{}), do: Consent.sharing_consent(patient_id, therapist_ids, attrs)
  def research_consent(patient_id, study_id, attrs \\ %{}), do: Consent.research_consent(patient_id, study_id, attrs)
end