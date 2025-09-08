defmodule RehabTracking.Core.Facade do
  @moduledoc """
  Public API facade for the rehab tracking core domain.
  Provides a clean interface for logging events, reading streams, and querying projections.
  """

  alias RehabTracking.Core.{EventLog, Events}
  alias RehabTracking.Core.Projectors.{Adherence, Quality, WorkQueue, PatientSummary}
  
  # Event creation and logging
  @doc """
  Logs an exercise session event (started, completed, or abandoned).
  """
  def log_exercise_session(patient_id, session_attrs) do
    with event <- Events.ExerciseSession.new(session_attrs),
         true <- EventLog.validate_event(event),
         {:ok, _} <- EventLog.append_to_stream(patient_id, event) do
      {:ok, event}
    else
      false -> {:error, :invalid_event}
      error -> error
    end
  end

  @doc """
  Logs a repetition observation from edge ML analysis.
  """
  def log_rep_observation(patient_id, observation_attrs) do
    with event <- Events.RepObservation.new(observation_attrs),
         true <- EventLog.validate_event(event),
         {:ok, _} <- EventLog.append_to_stream(patient_id, event) do
      {:ok, event}
    else
      false -> {:error, :invalid_event}
      error -> error
    end
  end

  @doc """
  Logs patient or system feedback.
  """
  def log_feedback(patient_id, feedback_attrs) do
    event = case feedback_attrs.feedback_source do
      :patient -> Events.Feedback.patient_feedback(feedback_attrs)
      :system -> Events.Feedback.coaching_feedback(feedback_attrs)
      :therapist -> Events.Feedback.therapist_feedback(feedback_attrs)
      _ -> Events.Feedback.new(feedback_attrs)
    end

    with true <- EventLog.validate_event(event),
         {:ok, _} <- EventLog.append_to_stream(patient_id, event) do
      {:ok, event}
    else
      false -> {:error, :invalid_event}
      error -> error
    end
  end

  @doc """
  Logs a clinical alert requiring therapist attention.
  """
  def log_alert(patient_id, alert_attrs) do
    event = case alert_attrs.alert_type do
      :missed_sessions -> Events.Alert.missed_sessions_alert(patient_id, alert_attrs.trigger_conditions)
      :poor_form -> Events.Alert.poor_form_alert(patient_id, alert_attrs.exercise_id, alert_attrs.trigger_conditions)
      :pain_reported -> Events.Alert.pain_alert(patient_id, alert_attrs.exercise_id, alert_attrs.pain_level)
      _ -> Events.Alert.new(alert_attrs)
    end

    with true <- EventLog.validate_event(event),
         {:ok, _} <- EventLog.append_to_stream(patient_id, event) do
      {:ok, event}
    else
      false -> {:error, :invalid_event}
      error -> error
    end
  end

  @doc """
  Logs patient consent for data collection/sharing.
  """
  def log_consent(patient_id, consent_attrs) do
    event = case consent_attrs.consent_type do
      :data_collection -> Events.Consent.data_collection_consent(patient_id, consent_attrs)
      :sharing -> Events.Consent.sharing_consent(patient_id, consent_attrs.therapist_ids, consent_attrs)
      :research -> Events.Consent.research_consent(patient_id, consent_attrs.study_id, consent_attrs)
      _ -> Events.Consent.new(Map.put(consent_attrs, :patient_id, patient_id))
    end

    with true <- EventLog.validate_event(event),
         {:ok, _} <- EventLog.append_to_stream(patient_id, event) do
      {:ok, event}
    else
      false -> {:error, :invalid_event}
      error -> error
    end
  end

  @doc """
  Generic event logging with automatic validation and enrichment.
  """
  def log_event(patient_id, event_type, attrs) do
    case create_event(event_type, attrs) do
      {:ok, event} ->
        with true <- EventLog.validate_event(event),
             {:ok, _} <- EventLog.append_to_stream(patient_id, event) do
          {:ok, event}
        else
          false -> {:error, :invalid_event}
          error -> error
        end
      
      error -> error
    end
  end

  # Stream reading and querying
  @doc """
  Gets the complete event stream for a patient.
  """
  def get_patient_stream(patient_id, opts \\ []) do
    EventLog.read_stream(patient_id, opts)
  end

  @doc """
  Gets events of a specific type from a patient's stream.
  """
  def get_patient_events_by_type(patient_id, event_type, opts \\ []) do
    with {:ok, events} <- EventLog.read_stream(patient_id, opts) do
      filtered_events = Enum.filter(events, fn event ->
        event.event_type == event_type_string(event_type)
      end)
      {:ok, filtered_events}
    end
  end

  @doc """
  Gets the current version of a patient's event stream.
  """
  def get_stream_version(patient_id) do
    EventLog.stream_version(patient_id)
  end

  # Projection queries
  @doc """
  Gets adherence metrics for a patient.
  """
  def get_adherence(patient_id, exercise_id \\ nil) do
    case exercise_id do
      nil -> Adherence.get_patient_adherence(patient_id)
      exercise_id -> Adherence.get_exercise_adherence(patient_id, exercise_id)
    end
  end

  @doc """
  Gets quality metrics for a patient.
  """
  def get_quality_metrics(patient_id, exercise_id \\ nil) do
    case exercise_id do
      nil -> Quality.get_patient_quality(patient_id)
      exercise_id -> Quality.get_exercise_quality(patient_id, exercise_id)
    end
  end

  @doc """
  Gets work queue items for a therapist.
  """
  def get_work_queue(therapist_id, opts \\ []) do
    WorkQueue.get_therapist_queue(therapist_id, opts)
  end

  @doc """
  Gets patient summary for clinical review.
  """
  def get_patient_summary(patient_id) do
    PatientSummary.get_patient_summary(patient_id)
  end

  @doc """
  Gets clinical summary for FHIR integration.
  """
  def get_clinical_summary(patient_id) do
    PatientSummary.get_clinical_summary(patient_id)
  end

  # Projection management
  @doc """
  Generic projection query interface.
  """
  def project(projection_name, filters \\ %{}) do
    case projection_name do
      :adherence -> query_adherence_projection(filters)
      :quality -> query_quality_projection(filters)
      :work_queue -> query_work_queue_projection(filters)
      :patient_summary -> query_patient_summary_projection(filters)
      _ -> {:error, :unknown_projection}
    end
  end

  # Analytics and reporting
  @doc """
  Gets dashboard metrics for a therapist.
  """
  def get_therapist_dashboard(therapist_id) do
    with work_queue <- WorkQueue.get_therapist_queue(therapist_id, limit: 10),
         overdue_items <- WorkQueue.get_overdue_items(therapist_id),
         declining_patients <- Quality.get_declining_quality_patients() do
      
      {:ok, %{
        pending_tasks: length(work_queue),
        overdue_tasks: length(overdue_items),
        high_priority_alerts: count_high_priority(work_queue),
        patients_at_risk: length(declining_patients),
        work_queue: work_queue,
        recent_alerts: Enum.take(overdue_items, 5)
      }}
    end
  end

  @doc """
  Gets progress report for a patient.
  """
  def get_patient_progress_report(patient_id, date_range \\ nil) do
    with adherence <- get_adherence(patient_id),
         quality <- get_quality_metrics(patient_id),
         summary <- get_patient_summary(patient_id),
         {:ok, recent_events} <- get_recent_events(patient_id, 10) do
      
      {:ok, %{
        patient_id: patient_id,
        reporting_period: date_range || "all_time",
        adherence_metrics: adherence,
        quality_metrics: quality,
        clinical_summary: summary,
        recent_activity: recent_events,
        generated_at: DateTime.utc_now()
      }}
    end
  end

  # Health and monitoring
  @doc """
  Gets system health metrics.
  """
  def get_system_health do
    with {:ok, event_stats} <- EventLog.event_statistics() do
      {:ok, %{
        event_store: event_stats,
        projections: get_projection_health(),
        timestamp: DateTime.utc_now()
      }}
    end
  end

  # Helper functions
  defp create_event(:exercise_session, attrs), do: {:ok, Events.ExerciseSession.new(attrs)}
  defp create_event(:rep_observation, attrs), do: {:ok, Events.RepObservation.new(attrs)}
  defp create_event(:feedback, attrs), do: {:ok, Events.Feedback.new(attrs)}
  defp create_event(:alert, attrs), do: {:ok, Events.Alert.new(attrs)}
  defp create_event(:consent, attrs), do: {:ok, Events.Consent.new(attrs)}
  defp create_event(_, _), do: {:error, :unknown_event_type}

  defp event_type_string(:exercise_session), do: "ExerciseSession"
  defp event_type_string(:rep_observation), do: "RepObservation"
  defp event_type_string(:feedback), do: "Feedback"
  defp event_type_string(:alert), do: "Alert"
  defp event_type_string(:consent), do: "Consent"
  defp event_type_string(type) when is_binary(type), do: type

  defp query_adherence_projection(filters) do
    case {filters[:patient_id], filters[:exercise_id]} do
      {patient_id, nil} when not is_nil(patient_id) ->
        Adherence.get_patient_adherence(patient_id)
      {patient_id, exercise_id} when not is_nil(patient_id) and not is_nil(exercise_id) ->
        Adherence.get_exercise_adherence(patient_id, exercise_id)
      _ ->
        {:error, :invalid_filters}
    end
  end

  defp query_quality_projection(filters) do
    case {filters[:patient_id], filters[:exercise_id]} do
      {patient_id, nil} when not is_nil(patient_id) ->
        Quality.get_patient_quality(patient_id)
      {patient_id, exercise_id} when not is_nil(patient_id) and not is_nil(exercise_id) ->
        Quality.get_exercise_quality(patient_id, exercise_id)
      _ ->
        {:error, :invalid_filters}
    end
  end

  defp query_work_queue_projection(filters) do
    case filters[:therapist_id] do
      nil -> {:error, :therapist_id_required}
      therapist_id -> WorkQueue.get_therapist_queue(therapist_id, Map.to_list(filters))
    end
  end

  defp query_patient_summary_projection(filters) do
    case filters[:patient_id] do
      nil -> {:error, :patient_id_required}
      patient_id -> PatientSummary.get_patient_summary(patient_id)
    end
  end

  defp count_high_priority(work_items) do
    Enum.count(work_items, fn item -> item.priority in ["high", "urgent"] end)
  end

  defp get_recent_events(patient_id, limit) do
    EventLog.read_stream(patient_id, count: limit)
  end

  defp get_projection_health do
    # In a real implementation, this would check projection lag, errors, etc.
    %{
      adherence: "healthy",
      quality: "healthy", 
      work_queue: "healthy",
      patient_summary: "healthy"
    }
  end
end