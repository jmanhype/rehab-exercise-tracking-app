defmodule RehabTracking.Core.Policy.Nudges do
  @moduledoc """
  Business rules for generating alerts and nudges based on patient events.
  
  Evaluates events to determine when clinical alerts should be created:
  - Missed sessions (adherence)
  - Poor form quality
  - High pain reports
  - No progress detection
  - Device connectivity issues
  """

  alias RehabTracking.Core.Events.{ExerciseSession, RepObservation, Feedback}
  
  require Logger

  @missed_sessions_threshold 3  # Days without exercise
  @poor_form_threshold 0.5      # Form score below this triggers alert
  @poor_form_session_count 3    # Number of consecutive poor form sessions
  @high_pain_threshold 6        # Pain level 6+ triggers alert
  @no_progress_days 14          # Days without quality improvement

  @doc """
  Evaluate an event to determine if any alerts should be generated.
  
  Returns:
  - {:create_alert, alert_data} - An alert should be created
  - :no_action - No alert needed
  - {:error, reason} - Error in evaluation
  """
  def evaluate_event(%{event_type: "exercise_session"} = event) do
    with {:ok, session} <- parse_exercise_session(event) do
      evaluate_session_patterns(session, event)
    end
  end

  def evaluate_event(%{event_type: "rep_observation"} = event) do
    with {:ok, observation} <- parse_rep_observation(event) do
      evaluate_form_quality(observation, event)
    end
  end

  def evaluate_event(%{event_type: "feedback"} = event) do
    with {:ok, feedback} <- parse_feedback(event) do
      evaluate_pain_feedback(feedback, event)
    end
  end

  def evaluate_event(_event), do: :no_action

  # Session pattern evaluation
  defp evaluate_session_patterns(session, event) do
    cond do
      session_indicates_missed_pattern?(session, event) ->
        create_missed_sessions_alert(event)
      
      session_indicates_device_issues?(session) ->
        create_device_alert(event)
      
      true ->
        :no_action
    end
  end

  # Form quality evaluation
  defp evaluate_form_quality(observation, event) do
    cond do
      observation.form_score < @poor_form_threshold and 
      observation.confidence > 0.8 ->
        evaluate_poor_form_pattern(event)
      
      observation.anomaly_detected ->
        create_form_anomaly_alert(event, observation)
      
      true ->
        :no_action
    end
  end

  # Pain feedback evaluation
  defp evaluate_pain_feedback(feedback, event) do
    cond do
      is_high_pain_report?(feedback) ->
        create_pain_alert(event, feedback)
      
      is_concerning_pain_pattern?(feedback, event) ->
        create_pain_pattern_alert(event, feedback)
      
      true ->
        :no_action
    end
  end

  # Alert creation functions
  defp create_missed_sessions_alert(event) do
    alert_data = %{
      event_type: "alert",
      patient_id: event.patient_id,
      alert_type: :missed_sessions,
      priority: :medium,
      title: "Missed Exercise Sessions",
      description: "Patient has missed #{@missed_sessions_threshold} or more consecutive exercise days",
      trigger_conditions: %{
        consecutive_days_missed: @missed_sessions_threshold,
        last_session_date: get_last_session_date(event.patient_id)
      },
      recommended_actions: [
        "Contact patient to assess barriers",
        "Review exercise prescription difficulty",
        "Consider motivational interventions"
      ],
      created_at: DateTime.utc_now()
    }
    
    {:create_alert, alert_data}
  end

  defp create_device_alert(event) do
    alert_data = %{
      event_type: "alert", 
      patient_id: event.patient_id,
      alert_type: :device_connectivity,
      priority: :low,
      title: "Device Connectivity Issues",
      description: "Multiple failed exercise attempts or incomplete sessions detected",
      trigger_conditions: %{
        failed_sessions: count_failed_sessions(event.patient_id),
        device_type: get_device_info(event)
      },
      recommended_actions: [
        "Check patient's device and app version",
        "Provide technical support guidance",
        "Consider alternative data collection methods"
      ],
      created_at: DateTime.utc_now()
    }
    
    {:create_alert, alert_data}
  end

  defp create_pain_alert(event, feedback) do
    pain_level = get_pain_level(feedback)
    
    alert_data = %{
      event_type: "alert",
      patient_id: event.patient_id,
      alert_type: :pain_reported,
      priority: determine_pain_priority(pain_level),
      title: "High Pain Level Reported",
      description: "Patient reported pain level #{pain_level}/10",
      trigger_conditions: %{
        pain_level: pain_level,
        exercise_id: feedback.exercise_id,
        pain_location: get_pain_location(feedback)
      },
      recommended_actions: [
        "Review exercise intensity and modifications",
        "Contact patient within 24 hours",
        "Consider pain management consultation",
        "Document pain assessment in clinical notes"
      ],
      created_at: DateTime.utc_now()
    }
    
    {:create_alert, alert_data}
  end

  defp evaluate_poor_form_pattern(event) do
    # Check if this is part of a pattern of poor form
    recent_form_scores = get_recent_form_scores(event.patient_id, event.exercise_id)
    
    if consecutive_poor_form?(recent_form_scores) do
      create_poor_form_alert(event, recent_form_scores)
    else
      :no_action
    end
  end

  defp create_poor_form_alert(event, form_scores) do
    avg_score = Enum.sum(form_scores) / length(form_scores)
    
    alert_data = %{
      event_type: "alert",
      patient_id: event.patient_id,
      alert_type: :poor_form,
      priority: :medium,
      title: "Declining Exercise Form Quality",
      description: "Form quality below threshold for #{length(form_scores)} consecutive sessions",
      trigger_conditions: %{
        exercise_id: event.exercise_id,
        sessions_count: length(form_scores),
        avg_form_score: Float.round(avg_score, 2),
        threshold: @poor_form_threshold
      },
      recommended_actions: [
        "Schedule form coaching session",
        "Review exercise technique video",
        "Consider exercise modification or regression",
        "Provide additional visual cues or feedback"
      ],
      created_at: DateTime.utc_now()
    }
    
    {:create_alert, alert_data}
  end

  defp create_form_anomaly_alert(event, observation) do
    alert_data = %{
      event_type: "alert",
      patient_id: event.patient_id,
      alert_type: :form_anomaly,
      priority: :high,
      title: "Exercise Form Anomaly Detected",
      description: "ML model detected unusual movement patterns",
      trigger_conditions: %{
        exercise_id: event.exercise_id,
        anomaly_type: observation.anomaly_type,
        confidence: observation.confidence,
        joint_angles: observation.joint_angles
      },
      recommended_actions: [
        "Review exercise video if available",
        "Assess for potential injury risk",
        "Contact patient for form assessment",
        "Consider immediate exercise modification"
      ],
      created_at: DateTime.utc_now()
    }
    
    {:create_alert, alert_data}
  end

  defp create_pain_pattern_alert(event, feedback) do
    alert_data = %{
      event_type: "alert",
      patient_id: event.patient_id,
      alert_type: :pain_pattern,
      priority: :medium,
      title: "Concerning Pain Pattern",
      description: "Pattern of increasing or persistent pain detected",
      trigger_conditions: %{
        pain_trend: get_pain_trend(event.patient_id),
        exercise_id: feedback.exercise_id,
        pattern_duration_days: get_pain_pattern_duration(event.patient_id)
      },
      recommended_actions: [
        "Comprehensive pain assessment",
        "Review exercise prescription",
        "Consider imaging or clinical evaluation",
        "Document pain progression patterns"
      ],
      created_at: DateTime.utc_now()
    }
    
    {:create_alert, alert_data}
  end

  # Helper functions for pattern analysis
  defp session_indicates_missed_pattern?(_session, event) do
    # In a real implementation, this would check historical data
    # Mock: simulate missed session detection
    days_since_last = get_days_since_last_session(event.patient_id)
    days_since_last >= @missed_sessions_threshold
  end

  defp session_indicates_device_issues?(session) do
    # Check for signs of technical difficulties
    session.duration_seconds < 30 or  # Very short sessions
    session.total_reps_completed == 0 or  # No reps recorded
    is_nil(session.device_info)  # Missing device data
  end

  defp is_high_pain_report?(feedback) do
    case get_pain_level(feedback) do
      level when is_integer(level) -> level >= @high_pain_threshold
      _ -> false
    end
  end

  defp is_concerning_pain_pattern?(feedback, event) do
    # Analyze if this pain report is part of a concerning trend
    pain_trend = get_pain_trend(event.patient_id)
    pain_trend == "worsening" or 
    (get_pain_level(feedback) > 3 and pain_trend == "stable")
  end

  defp consecutive_poor_form?(form_scores) do
    length(form_scores) >= @poor_form_session_count and
    Enum.all?(form_scores, fn score -> score < @poor_form_threshold end)
  end

  defp determine_pain_priority(pain_level) when pain_level >= 8, do: :high
  defp determine_pain_priority(pain_level) when pain_level >= 6, do: :medium
  defp determine_pain_priority(_), do: :low

  # Mock data access functions (in production, these would query projections)
  defp get_last_session_date(_patient_id) do
    DateTime.utc_now() |> DateTime.add(-4, :day)
  end

  defp get_days_since_last_session(_patient_id) do
    # Mock: simulate 4 days since last session
    4
  end

  defp count_failed_sessions(_patient_id) do
    # Mock: simulate 2 recent failed sessions
    2
  end

  defp get_device_info(event) do
    Map.get(event, :device_info, %{type: "unknown"})
  end

  defp get_recent_form_scores(_patient_id, _exercise_id) do
    # Mock: simulate 3 consecutive poor form scores
    [0.4, 0.3, 0.45]
  end

  defp get_pain_level(feedback) do
    case feedback.content do
      %{"pain_level" => level} when is_integer(level) -> level
      %{pain_level: level} when is_integer(level) -> level
      _ -> nil
    end
  end

  defp get_pain_location(feedback) do
    case feedback.content do
      %{"pain_location" => location} -> location
      %{pain_location: location} -> location
      _ -> "unspecified"
    end
  end

  defp get_pain_trend(_patient_id) do
    # Mock: simulate pain trend analysis
    "stable"  # Could be "improving", "stable", "worsening"
  end

  defp get_pain_pattern_duration(_patient_id) do
    # Mock: simulate days with pain pattern
    7
  end

  # Event parsing functions
  defp parse_exercise_session(event) do
    case ExerciseSession.new(event) do
      %ExerciseSession{} = session -> {:ok, session}
      _ -> {:error, "invalid_exercise_session"}
    end
  end

  defp parse_rep_observation(event) do
    case RepObservation.new(event) do
      %RepObservation{} = observation -> {:ok, observation}
      _ -> {:error, "invalid_rep_observation"}
    end
  end

  defp parse_feedback(event) do
    case Feedback.new(event) do
      %Feedback{} = feedback -> {:ok, feedback}
      _ -> {:error, "invalid_feedback"}
    end
  end

  @doc """
  Get alert generation statistics for monitoring.
  """
  def get_alert_stats do
    %{
      thresholds: %{
        missed_sessions_days: @missed_sessions_threshold,
        poor_form_score: @poor_form_threshold,
        high_pain_level: @high_pain_threshold,
        no_progress_days: @no_progress_days
      },
      rules_evaluated: get_rules_evaluated_count(),
      alerts_generated: get_alerts_generated_count(),
      last_evaluation_at: DateTime.utc_now()
    }
  end

  defp get_rules_evaluated_count do
    # In production, this would track actual metrics
    0
  end

  defp get_alerts_generated_count do
    # In production, this would track actual metrics
    0
  end
end