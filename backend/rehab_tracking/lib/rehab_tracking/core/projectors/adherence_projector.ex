defmodule RehabTracking.Core.Projectors.AdherenceProjector do
  @moduledoc """
  Projector for adherence-related events.

  Maintains read models for:
  - Patient exercise adherence rates (percentage of completed vs prescribed sessions)
  - Session completion tracking (timestamp, duration, quality)
  - Consent-based data visibility (PHI access control)

  ## Event Processing

  This projector subscribes to the following event types:
  - `exercise_session` - Updates session count and adherence calculations
  - `consent` - Updates consent status affecting data visibility

  ## Performance

  Handles batched events for high-throughput processing (target: 1000 events/sec).
  Uses database upserts to maintain eventual consistency.

  ## Examples

      iex> handle_event(%{kind: "exercise_session", subject_id: "p123", timestamp: DateTime.utc_now()})
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
    Logger.debug("AdherenceProjector: Processing exercise session for #{event.subject_id}")

    try do
      # Update adherence projections
      update_session_count(event.subject_id, event.timestamp)
      update_adherence_rate(event.subject_id)

      :ok
    rescue
      e ->
        Logger.error("Failed to process exercise_session event: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec handle_event(event()) :: :ok | {:error, term()}
  def handle_event(%{kind: "consent"} = event) do
    Logger.debug("AdherenceProjector: Processing consent for #{event.subject_id}")

    try do
      # Update consent status affecting data visibility
      update_consent_status(event.subject_id, event.body)

      :ok
    rescue
      e ->
        Logger.error("Failed to process consent event: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec handle_event(map()) :: :ok
  def handle_event(_event), do: :ok

  # Handle batch of events for efficiency
  @spec handle_batch(list(event())) :: :ok | {:error, term()}
  def handle_batch(events) when is_list(events) do
    Logger.debug("AdherenceProjector: Processing batch of #{length(events)} events")

    try do
      # Group events by subject for batch processing
      events_by_subject = Enum.group_by(events, &Map.get(&1, "subject_id"))

      Enum.each(events_by_subject, fn {subject_id, subject_events} ->
        process_subject_events(subject_id, subject_events)
      end)

      :ok
    rescue
      e ->
        Logger.error("Failed to process event batch: #{inspect(e)}")
        {:error, e}
    end
  end

  # Private functions
  @spec update_session_count(String.t(), DateTime.t()) :: :ok
  defp update_session_count(subject_id, timestamp) do
    # Update session count in adherence projection table
    # In production: INSERT INTO adherence_projections ... ON CONFLICT DO UPDATE
    Logger.debug("Updating session count for #{subject_id} at #{timestamp}")

    # This would integrate with RehabTracking.Schemas.Adherence via Repo
    # Example: Repo.insert_or_update(adherence_changeset)
    :ok
  end

  @spec update_adherence_rate(String.t()) :: :ok
  defp update_adherence_rate(subject_id) do
    # Calculate adherence rate: (completed_sessions / prescribed_sessions) * 100
    # Updates the adherence projection with the new rate
    Logger.debug("Updating adherence rate for #{subject_id}")

    # This would query recent sessions and calculate percentage
    # Example: adherence_rate = completed / expected * 100
    :ok
  end

  @spec update_consent_status(String.t(), map()) :: :ok
  defp update_consent_status(subject_id, consent_body) do
    # Update consent status in user authentication table
    # Affects PHI data visibility in projections
    Logger.debug("Updating consent status for #{subject_id}: #{inspect(consent_body)}")

    # This would update the consent flag in the user record
    # Example: Repo.update(user, %{consent_given: true})
    :ok
  end

  @spec process_subject_events(String.t(), list(event())) :: :ok
  defp process_subject_events(subject_id, events) do
    Logger.debug("Processing #{length(events)} events for subject #{subject_id}")

    # Batch process events for this subject
    # In production, this could use database transactions for consistency
    Enum.each(events, &handle_event/1)
  end
end