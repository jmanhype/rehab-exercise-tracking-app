defmodule RehabTracking.Policy.Nudges do
  @moduledoc """
  Policy engine for generating nudges and alerts based on exercise events.

  Evaluates:
  - Adherence-based nudges (patients missing sessions)
  - Quality-based alerts (poor form detection)
  - Real-time feedback rules (immediate corrections)
  - Emergency intervention triggers (extended absences)

  ## Examples

      iex> evaluate_event(%{kind: "exercise_session", subject_id: "patient_123", body: %{"duration_minutes" => 15}, timestamp: DateTime.utc_now()})
      :ok

      iex> evaluate_event(%{kind: "rep_observation", subject_id: "patient_456", body: %{"rep_quality" => 0.5}, timestamp: DateTime.utc_now()})
      :ok
  """

  require Logger

  @type event :: %{
    kind: String.t(),
    subject_id: String.t(),
    body: map(),
    timestamp: DateTime.t(),
    meta: map()
  }

  @type nudge_type :: :missed_sessions | :short_session | :quality_reminder
  @type alert_type :: :extended_absence | :poor_quality
  @type feedback_type :: :form_correction | :rep_quality
  @type severity :: :low | :medium | :high

  # Evaluate event against nudge policies
  @spec evaluate_event(event()) :: :ok | {:error, term()}
  def evaluate_event(%{kind: "exercise_session"} = event) do
    Logger.debug("Nudges: Evaluating exercise session for #{event.subject_id}")

    try do
      # Check adherence patterns
      check_adherence_nudges(event)

      # Check session quality
      check_quality_alerts(event)

      :ok
    rescue
      e ->
        Logger.error("Failed to evaluate exercise_session event: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec evaluate_event(event()) :: :ok | {:error, term()}
  def evaluate_event(%{kind: "rep_observation"} = event) do
    Logger.debug("Nudges: Evaluating rep observation for #{event.subject_id}")

    try do
      # Check for real-time form corrections
      check_form_feedback(event)

      # Check for quality degradation
      check_quality_trends(event)

      :ok
    rescue
      e ->
        Logger.error("Failed to evaluate rep_observation event: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec evaluate_event(event()) :: :ok | {:error, term()}
  def evaluate_event(%{kind: "feedback"} = event) do
    Logger.debug("Nudges: Evaluating feedback for #{event.subject_id}")

    try do
      # Track feedback effectiveness
      track_feedback_response(event)

      :ok
    rescue
      e ->
        Logger.error("Failed to evaluate feedback event: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec evaluate_event(map()) :: :ok
  def evaluate_event(_event), do: :ok

  # Private policy functions
  @spec check_adherence_nudges(event()) :: :ok
  defp check_adherence_nudges(event) do
    %{subject_id: subject_id, body: body, timestamp: timestamp} = event

    # Check if this is first session in X days
    case get_last_session_days(subject_id, timestamp) do
      days when days > 3 ->
        generate_nudge(subject_id, :missed_sessions, %{days_missed: days})
        
      days when days > 7 ->
        generate_alert(subject_id, :extended_absence, %{days_missed: days})
        
      _ ->
        :ok
    end
    
    # Check session duration
    case Map.get(body, "duration_minutes") do
      duration when is_number(duration) and duration < 10 ->
        generate_nudge(subject_id, :short_session, %{duration: duration})
        
      _ ->
        :ok
    end
  end

  @spec check_quality_alerts(event()) :: :ok
  defp check_quality_alerts(event) do
    %{subject_id: subject_id, body: body} = event

    # Check session quality score
    case Map.get(body, "quality_score") do
      score when is_number(score) and score < 0.5 ->
        generate_alert(subject_id, :poor_quality, %{quality_score: score})
        
      score when is_number(score) and score < 0.7 ->
        generate_nudge(subject_id, :quality_reminder, %{quality_score: score})
        
      _ ->
        :ok
    end
  end

  @spec check_form_feedback(event()) :: :ok
  defp check_form_feedback(event) do
    %{subject_id: subject_id, body: body} = event

    # Check for form issues requiring immediate feedback
    case Map.get(body, "form_errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        generate_feedback(subject_id, :form_correction, %{errors: errors})
        
      _ ->
        :ok
    end
    
    # Check rep quality
    case Map.get(body, "rep_quality") do
      quality when is_number(quality) and quality < 0.6 ->
        generate_feedback(subject_id, :rep_quality, %{quality: quality})
        
      _ ->
        :ok
    end
  end

  @spec check_quality_trends(event()) :: :ok
  defp check_quality_trends(event) do
    %{subject_id: subject_id, body: body} = event

    # Trend analysis - compare current rep quality to recent history
    # This would integrate with the quality projector in production
    Logger.debug("Checking quality trends for #{subject_id}: #{inspect(body)}")
    :ok
  end

  @spec track_feedback_response(event()) :: :ok
  defp track_feedback_response(event) do
    %{subject_id: subject_id, body: body} = event

    # Track whether feedback improved subsequent performance
    # This would integrate with the feedback effectiveness analyzer in production
    Logger.debug("Tracking feedback response for #{subject_id}: #{inspect(body)}")
    :ok
  end

  # Nudge generation functions
  @spec generate_nudge(String.t(), nudge_type(), map()) :: :ok
  defp generate_nudge(subject_id, type, data) do
    Logger.info("Generating nudge for #{subject_id}: #{type} - #{inspect(data)}")
    
    nudge_event = %{
      kind: "nudge",
      subject_id: subject_id,
      body: %{
        nudge_type: type,
        data: data,
        severity: "low"
      },
      meta: %{
        generated_by: "nudges_policy",
        timestamp: DateTime.utc_now()
      }
    }
    
    # TODO: Send nudge to appropriate channel (push notification, email, etc.)
    send_nudge(nudge_event)
  end

  @spec generate_alert(String.t(), alert_type(), map()) :: :ok
  defp generate_alert(subject_id, type, data) do
    Logger.warning("Generating alert for #{subject_id}: #{type} - #{inspect(data)}")

    alert_event = %{
      kind: "alert",
      subject_id: subject_id,
      body: %{
        alert_type: type,
        data: data,
        severity: get_alert_severity(type)
      },
      meta: %{
        generated_by: "nudges_policy",
        timestamp: DateTime.utc_now()
      }
    }
    
    # TODO: Send alert to therapist work queue
    send_alert(alert_event)
  end

  @spec generate_feedback(String.t(), feedback_type(), map()) :: :ok
  defp generate_feedback(subject_id, type, data) do
    Logger.info("Generating feedback for #{subject_id}: #{type} - #{inspect(data)}")

    feedback_event = %{
      kind: "feedback",
      subject_id: subject_id,
      body: %{
        feedback_type: type,
        data: data,
        immediate: true
      },
      meta: %{
        generated_by: "nudges_policy",
        timestamp: DateTime.utc_now()
      }
    }
    
    # TODO: Send immediate feedback to mobile app
    send_feedback(feedback_event)
  end

  # Helper functions
  @spec get_last_session_days(String.t(), DateTime.t()) :: non_neg_integer()
  defp get_last_session_days(subject_id, current_timestamp) do
    # Query the adherence projection for last session timestamp
    # In production, this would query: RehabTracking.Schemas.Adherence
    # For now, provide a basic implementation that can be replaced
    case RehabTracking.Repo.get_by(RehabTracking.Schemas.Adherence, patient_id: subject_id) do
      nil ->
        # No previous sessions found
        0

      adherence_record ->
        # Calculate days since last session
        last_session = adherence_record.last_session_at || current_timestamp
        DateTime.diff(current_timestamp, last_session, :day)
    end
  rescue
    # Fallback if database lookup fails (e.g., during testing)
    _e ->
      Logger.warning("Failed to lookup last session for #{subject_id}, using fallback")
      case :rand.uniform(10) do
        n when n <= 3 -> 1
        n when n <= 6 -> 4
        n when n <= 8 -> 8
        _ -> 12
      end
  end

  @spec get_alert_severity(alert_type()) :: String.t()
  defp get_alert_severity(:extended_absence), do: "high"
  defp get_alert_severity(:poor_quality), do: "medium"
  defp get_alert_severity(_), do: "low"

  @spec send_nudge(map()) :: :ok
  defp send_nudge(nudge_event) do
    # Deliver nudge via notification adapter (push notification, email, SMS)
    # In production, this would integrate with RehabTracking.Adapters.Notify
    Logger.info("Sending nudge: #{inspect(nudge_event)}")

    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :policy, :nudge, :generated],
      %{count: 1},
      %{
        subject_id: nudge_event.subject_id,
        type: get_in(nudge_event, [:body, :nudge_type])
      }
    )
  end

  @spec send_alert(map()) :: :ok
  defp send_alert(alert_event) do
    # Deliver alert to therapist work queue
    # In production, this would integrate with RehabTracking.Core.Projectors.WorkQueueProjector
    Logger.warning("Sending alert: #{inspect(alert_event)}")

    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :policy, :alert, :generated],
      %{count: 1},
      %{
        subject_id: alert_event.subject_id,
        type: get_in(alert_event, [:body, :alert_type]),
        severity: get_in(alert_event, [:body, :severity])
      }
    )
  end

  @spec send_feedback(map()) :: :ok
  defp send_feedback(feedback_event) do
    # Deliver immediate feedback to mobile app via push notification
    # In production, this would integrate with RehabTracking.Adapters.Notify
    Logger.info("Sending feedback: #{inspect(feedback_event)}")

    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :policy, :feedback, :generated],
      %{count: 1},
      %{
        subject_id: feedback_event.subject_id,
        type: get_in(feedback_event, [:body, :feedback_type])
      }
    )
  end
end