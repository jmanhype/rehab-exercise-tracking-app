defmodule RehabTracking.Core.Projectors.QualityProjector do
  @moduledoc """
  Projector for exercise quality-related events.

  Maintains read models for:
  - Exercise form quality scores (0.0-1.0 normalized)
  - Rep observation aggregations (average, min, max per session)
  - Quality trend analysis (improvement/degradation over time)

  ## Event Processing

  Subscribes to:
  - `exercise_session` - Aggregates quality metrics for entire session
  - `rep_observation` - Tracks individual rep quality and form errors

  ## Quality Metrics

  - **Form Score**: ML-derived score from pose estimation (MoveNet/MediaPipe)
  - **Consistency**: Standard deviation of rep quality within session
  - **Trend**: Moving average of quality scores over time window

  ## Examples

      iex> handle_event(%{kind: "rep_observation", subject_id: "p123", body: %{"rep_quality" => 0.85}, timestamp: DateTime.utc_now()})
      :ok
  """

  require Logger

  @type event :: %{
    kind: String.t(),
    subject_id: String.t(),
    body: map(),
    timestamp: DateTime.t()
  }

  # Handle individual events
  @spec handle_event(event()) :: :ok | {:error, term()}
  def handle_event(%{kind: "exercise_session"} = event) do
    Logger.debug("QualityProjector: Processing exercise session for #{event.subject_id}")

    try do
      # Update session quality metrics
      update_session_quality(event.subject_id, event.body, event.timestamp)

      :ok
    rescue
      e ->
        Logger.error("Failed to process exercise_session event in quality projector: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec handle_event(event()) :: :ok | {:error, term()}
  def handle_event(%{kind: "rep_observation"} = event) do
    Logger.debug("QualityProjector: Processing rep observation for #{event.subject_id}")

    try do
      # Update rep-level quality metrics
      update_rep_quality(event.subject_id, event.body, event.timestamp)
      update_quality_trends(event.subject_id, event.body)

      :ok
    rescue
      e ->
        Logger.error("Failed to process rep_observation event in quality projector: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec handle_event(map()) :: :ok
  def handle_event(_event), do: :ok

  # Handle batch of events for efficiency
  @spec handle_batch(list(event())) :: :ok | {:error, term()}
  def handle_batch(events) when is_list(events) do
    Logger.debug("QualityProjector: Processing batch of #{length(events)} events")

    try do
      # Group events by subject and type for efficient batch processing
      grouped_events =
        events
        |> Enum.group_by(&Map.get(&1, "subject_id"))
        |> Enum.map(fn {subject_id, subject_events} ->
          {subject_id, Enum.group_by(subject_events, &Map.get(&1, "kind"))}
        end)

      Enum.each(grouped_events, fn {subject_id, events_by_type} ->
        process_subject_quality_events(subject_id, events_by_type)
      end)

      :ok
    rescue
      e ->
        Logger.error("Failed to process quality event batch: #{inspect(e)}")
        {:error, e}
    end
  end

  # Private functions
  @spec update_session_quality(String.t(), map(), DateTime.t()) :: :ok
  defp update_session_quality(subject_id, session_body, timestamp) do
    # Calculate aggregate quality metrics for the session:
    # - Average quality score across all reps
    # - Consistency (standard deviation)
    # - Form error frequency
    Logger.debug("Updating session quality for #{subject_id} at #{timestamp}")
    Logger.debug("Session data: #{inspect(session_body)}")

    # In production, this would:
    # 1. Extract quality_score from session_body
    # 2. Calculate aggregate metrics
    # 3. Upsert into quality_projections table
    :ok
  end

  @spec update_rep_quality(String.t(), map(), DateTime.t()) :: :ok
  defp update_rep_quality(subject_id, rep_body, timestamp) do
    # Store individual rep quality score and form errors
    # Used for detailed analysis and feedback generation
    Logger.debug("Updating rep quality for #{subject_id} at #{timestamp}")
    Logger.debug("Rep data: #{inspect(rep_body)}")

    # In production, this would:
    # 1. Extract rep_quality and form_errors from rep_body
    # 2. Store in rep_observations table
    # 3. Update rolling averages
    :ok
  end

  @spec update_quality_trends(String.t(), map()) :: :ok
  defp update_quality_trends(subject_id, rep_body) do
    # Calculate moving average quality trend (e.g., last 10 reps)
    # Detect degradation patterns that trigger alerts
    Logger.debug("Updating quality trends for #{subject_id}")
    Logger.debug("Rep data for trends: #{inspect(rep_body)}")

    # In production, this would:
    # 1. Fetch recent rep quality scores
    # 2. Calculate moving average
    # 3. Detect significant degradation (>20% drop)
    # 4. Update trend indicators in projection
    :ok
  end

  @spec process_subject_quality_events(String.t(), map()) :: :ok
  defp process_subject_quality_events(subject_id, events_by_type) do
    Logger.debug("Processing quality events for subject #{subject_id}")

    # Process exercise sessions in batch
    if exercise_sessions = Map.get(events_by_type, "exercise_session") do
      process_session_batch(subject_id, exercise_sessions)
    end

    # Process rep observations in batch
    if rep_observations = Map.get(events_by_type, "rep_observation") do
      process_rep_batch(subject_id, rep_observations)
    end

    :ok
  end

  @spec process_session_batch(String.t(), list(event())) :: :ok
  defp process_session_batch(subject_id, sessions) do
    Logger.debug("Batch processing #{length(sessions)} sessions for #{subject_id}")
    Enum.each(sessions, &handle_event/1)
    :ok
  end

  @spec process_rep_batch(String.t(), list(event())) :: :ok
  defp process_rep_batch(subject_id, reps) do
    Logger.debug("Batch processing #{length(reps)} reps for #{subject_id}")
    Enum.each(reps, &handle_event/1)
    :ok
  end
end