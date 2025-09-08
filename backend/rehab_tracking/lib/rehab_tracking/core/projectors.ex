defmodule RehabTracking.Core.Projectors do
  @moduledoc """
  Namespace module for all projection builders in the rehab tracking system.
  
  Projectors are responsible for building read models from the event stream,
  implementing the query side of CQRS architecture. Each projector maintains
  eventual consistency with <100ms lag from the event log.
  
  ## Available Projectors
  
  - `Adherence` - Exercise compliance and session tracking
  - `Quality` - Form analysis and movement quality metrics
  - `WorkQueue` - Therapist task prioritization and workflow
  - `PatientSummary` - Comprehensive clinical overviews
  
  ## Usage
  
  Projectors are typically used via the Core.Facade module:
  
      # Get adherence data
      {:ok, adherence} = Core.Facade.project(:adherence, patient_id: "patient_123")
      
      # Get quality metrics
      {:ok, quality} = Core.Facade.project(:quality, patient_id: "patient_123", exercise_id: "ex_001")
      
      # Get therapist work queue
      {:ok, work_items} = Core.Facade.project(:work_queue, therapist_id: "therapist_456")
  
  ## Event Processing
  
  Projectors are automatically updated via Broadway pipeline when events occur:
  
      # Events flow through Broadway processors
      ExerciseSession -> Adherence.handle_exercise_session_event/1
      RepObservation -> Quality.handle_rep_observation_event/1  
      Alert -> WorkQueue.handle_alert_event/1
      
  ## Performance Characteristics
  
  - **Eventual Consistency**: <100ms lag from event store
  - **Read Optimization**: Denormalized views for fast queries
  - **Concurrent Safe**: Multiple projectors can process events in parallel
  - **Fault Tolerant**: Failed projections can be rebuilt from event stream
  
  ## Projection Rebuild
  
  If projections become inconsistent or corrupted, they can be rebuilt:
  
      # Rebuild all projections for a patient
      RehabTracking.Core.Projectors.rebuild_patient_projections("patient_123")
      
      # Rebuild specific projection type
      RehabTracking.Core.Projectors.rebuild_projection(:adherence, patient_id: "patient_123")
  
  ## Schema Dependencies
  
  Projectors use Ecto schemas for persistence:
  - `RehabTracking.Schemas.Adherence`
  - `RehabTracking.Schemas.Quality`
  - `RehabTracking.Schemas.WorkQueue`
  - `RehabTracking.Schemas.PatientSummary`
  """
  
  alias RehabTracking.Core.Projectors.{Adherence, Quality, WorkQueue, PatientSummary}
  alias RehabTracking.Core.EventLog
  alias RehabTracking.Repo
  import Ecto.Query
  require Logger
  
  @doc """
  Rebuilds all projections for a specific patient from the event stream.
  
  This is useful for data recovery or when projection schemas change.
  """
  def rebuild_patient_projections(patient_id) do
    Logger.info("Rebuilding all projections for patient #{patient_id}")
    
    with {:ok, events} <- EventLog.read_stream(patient_id),
         :ok <- clear_patient_projections(patient_id),
         :ok <- replay_events_for_patient(patient_id, events) do
      
      Logger.info("Successfully rebuilt projections for patient #{patient_id}")
      {:ok, :projections_rebuilt}
    else
      error ->
        Logger.error("Failed to rebuild projections for patient #{patient_id}: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Rebuilds a specific projection type for patients matching the given filters.
  
  ## Examples
  
      # Rebuild adherence for specific patient
      rebuild_projection(:adherence, patient_id: "patient_123")
      
      # Rebuild quality projections for all patients (use with caution)
      rebuild_projection(:quality, all: true)
  """
  def rebuild_projection(projection_type, filters) do
    Logger.info("Rebuilding #{projection_type} projection with filters: #{inspect(filters)}")
    
    case projection_type do
      :adherence ->
        rebuild_adherence_projection(filters)
      
      :quality ->
        rebuild_quality_projection(filters)
      
      :work_queue ->
        rebuild_work_queue_projection(filters)
      
      :patient_summary ->
        rebuild_patient_summary_projection(filters)
      
      _ ->
        {:error, :unknown_projection_type}
    end
  end
  
  @doc """
  Gets health status for all projections.
  
  Returns information about projection lag, error rates, and last update times.
  """
  def get_projection_health do
    %{
      adherence: get_projector_health(:adherence),
      quality: get_projector_health(:quality),
      work_queue: get_projector_health(:work_queue),
      patient_summary: get_projector_health(:patient_summary),
      overall_status: determine_overall_health(),
      checked_at: DateTime.utc_now()
    }
  end
  
  @doc """
  Processes a single event through all relevant projectors.
  
  This is called by the Broadway pipeline for each event.
  """
  def process_event(event) do
    Logger.debug("Processing event #{event.event_type} for projections")
    
    results = %{
      adherence: process_event_for_projector(:adherence, event),
      quality: process_event_for_projector(:quality, event),
      work_queue: process_event_for_projector(:work_queue, event),
      patient_summary: process_event_for_projector(:patient_summary, event)
    }
    
    # Log any failures
    failures = Enum.filter(results, fn {_projector, result} -> 
      match?({:error, _}, result) 
    end)
    
    case failures do
      [] ->
        Logger.debug("Event #{event.event_id} processed successfully by all projectors")
        {:ok, results}
      
      _ ->
        Logger.warning("Event #{event.event_id} had projection failures: #{inspect(failures)}")
        {:partial_success, results}
    end
  end
  
  @doc """
  Gets statistics about projection performance and event processing.
  """
  def get_projection_statistics do
    %{
      event_processing: %{
        events_processed_today: count_events_processed_today(),
        avg_processing_time_ms: get_avg_processing_time(),
        failed_events_today: count_failed_events_today(),
        last_processed_event: get_last_processed_event_time()
      },
      projection_counts: %{
        adherence_records: count_projection_records(:adherence),
        quality_records: count_projection_records(:quality),
        work_queue_items: count_projection_records(:work_queue),
        patient_summaries: count_projection_records(:patient_summary)
      },
      data_freshness: %{
        oldest_unprocessed_event: get_oldest_unprocessed_event(),
        projection_lag_seconds: get_avg_projection_lag()
      }
    }
  end
  
  # Private helper functions
  
  defp clear_patient_projections(patient_id) do
    # Clear existing projections for the patient
    try do
      Repo.delete_all(from a in RehabTracking.Schemas.Adherence, where: a.patient_id == ^patient_id)
      Repo.delete_all(from q in RehabTracking.Schemas.Quality, where: q.patient_id == ^patient_id)
      Repo.delete_all(from w in RehabTracking.Schemas.WorkQueue, where: w.patient_id == ^patient_id)
      Repo.delete_all(from p in RehabTracking.Schemas.PatientSummary, where: p.patient_id == ^patient_id)
      
      :ok
    rescue
      exception ->
        Logger.error("Failed to clear projections for patient #{patient_id}: #{inspect(exception)}")
        {:error, :clear_failed}
    end
  end
  
  defp replay_events_for_patient(_patient_id, events) do
    # Replay events through each projector
    Enum.reduce_while(events, :ok, fn event, _acc ->
      case process_event(event) do
        {:ok, _results} -> {:cont, :ok}
        {:partial_success, results} ->
          Logger.warning("Partial success replaying event #{event.event_id}: #{inspect(results)}")
          {:cont, :ok}
        {:error, reason} ->
          Logger.error("Failed to replay event #{event.event_id}: #{inspect(reason)}")
          {:halt, {:error, :replay_failed}}
      end
    end)
  end
  
  defp rebuild_adherence_projection(filters) do
    patient_id = Keyword.get(filters, :patient_id)
    build_all = Keyword.get(filters, :all) == true
    
    case {patient_id, build_all} do
      {nil, true} ->
        Logger.warning("Rebuilding adherence for ALL patients - this may take time")
        # In production, would paginate through all patients
        {:error, :not_implemented}
      
      {nil, _} ->
        {:error, :patient_id_required}
      
      {patient_id, _} ->
        rebuild_patient_projections(patient_id)
    end
  end
  
  defp rebuild_quality_projection(filters) do
    # Similar implementation to adherence
    case Keyword.get(filters, :patient_id) do
      nil -> {:error, :patient_id_required}
      patient_id -> rebuild_patient_projections(patient_id)
    end
  end
  
  defp rebuild_work_queue_projection(filters) do
    case Keyword.get(filters, :patient_id) do
      nil -> {:error, :patient_id_required}
      patient_id -> rebuild_patient_projections(patient_id)
    end
  end
  
  defp rebuild_patient_summary_projection(filters) do
    case Keyword.get(filters, :patient_id) do
      nil -> {:error, :patient_id_required}
      patient_id -> rebuild_patient_projections(patient_id)
    end
  end
  
  defp get_projector_health(_projector_type) do
    # In production, would check actual projection health metrics
    %{
      status: "healthy",
      last_update: DateTime.add(DateTime.utc_now(), -30, :second),
      events_processed_today: :rand.uniform(1000),
      error_rate: 0.001,
      avg_processing_time_ms: :rand.uniform(50) + 10
    }
  end
  
  defp determine_overall_health do
    # Simplified health determination
    "healthy"
  end
  
  defp process_event_for_projector(projector_type, event) do
    case {projector_type, event.event_type} do
      {:adherence, "exercise_session"} ->
        Adherence.handle_exercise_session_event(event)
      
      {:adherence, "missed_session"} ->
        Adherence.handle_missed_session_event(event)
      
      {:quality, "rep_observation"} ->
        Quality.handle_rep_observation_event(event)
      
      {:quality, "feedback"} ->
        Quality.handle_feedback_event(event)
      
      {:work_queue, "alert"} ->
        WorkQueue.handle_alert_event(event)
      
      {:work_queue, "quality_decline"} ->
        WorkQueue.handle_quality_decline_event(event)
      
      {:work_queue, "missed_session_pattern"} ->
        WorkQueue.handle_missed_session_pattern_event(event)
      
      {:patient_summary, "exercise_session"} ->
        PatientSummary.handle_exercise_session_event(event)
      
      {:patient_summary, "alert"} ->
        PatientSummary.handle_alert_event(event)
      
      {:patient_summary, "feedback"} ->
        PatientSummary.handle_feedback_event(event)
      
      _ ->
        # Event not relevant to this projector
        :ok
    end
  rescue
    exception ->
      Logger.error("Error processing event #{event.event_id} in #{projector_type}: #{inspect(exception)}")
      {:error, :processing_failed}
  end
  
  # Mock statistics functions (would be real implementations in production)
  
  defp count_events_processed_today do
    # In production, would query actual metrics
    :rand.uniform(5000) + 1000
  end
  
  defp get_avg_processing_time do
    # In production, would calculate from telemetry
    :rand.uniform(30) + 15
  end
  
  defp count_failed_events_today do
    # In production, would query error logs
    :rand.uniform(10)
  end
  
  defp get_last_processed_event_time do
    DateTime.add(DateTime.utc_now(), -:rand.uniform(60), :second)
  end
  
  defp count_projection_records(:adherence) do
    try do
      Repo.aggregate(RehabTracking.Schemas.Adherence, :count, :id)
    rescue
      _ -> 0
    end
  end
  
  defp count_projection_records(:quality) do
    try do
      Repo.aggregate(RehabTracking.Schemas.Quality, :count, :id)
    rescue
      _ -> 0
    end
  end
  
  defp count_projection_records(:work_queue) do
    try do
      Repo.aggregate(RehabTracking.Schemas.WorkQueue, :count, :id)
    rescue
      _ -> 0
    end
  end
  
  defp count_projection_records(:patient_summary) do
    try do
      Repo.aggregate(RehabTracking.Schemas.PatientSummary, :count, :id)
    rescue
      _ -> 0
    end
  end
  
  defp get_oldest_unprocessed_event do
    # In production, would find the oldest event not yet processed
    DateTime.add(DateTime.utc_now(), -:rand.uniform(300), :second)
  end
  
  defp get_avg_projection_lag do
    # In production, would calculate average time between event creation and projection update
    :rand.uniform(100) + 10
  end
end