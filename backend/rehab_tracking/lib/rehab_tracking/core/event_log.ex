defmodule RehabTracking.Core.EventLog do
  @moduledoc """
  Event persistence wrapper providing a clean interface to the underlying event store.
  
  Abstracts away Commanded/EventStore implementation details and provides:
  - Event validation and enrichment
  - Stream management with patient isolation
  - Snapshot management (every 1000 events)
  - PHI handling and audit trails
  - Event statistics and monitoring
  """
  
  require Logger
  
  @snapshot_frequency 1000
  
  # Event validation
  @doc """
  Validates an event structure and content.
  """
  def validate_event(event) do
    case event do
      %{event_type: event_type, patient_id: patient_id, body: body} 
      when is_binary(event_type) and is_binary(patient_id) and is_map(body) ->
        validate_event_content(event_type, body)
      
      _ -> 
        false
    end
  end
  
  # Stream operations
  @doc """
  Appends an event to a patient's stream with automatic enrichment.
  
  Each patient has their own isolated stream for data privacy and scaling.
  Events are enriched with metadata including PHI flags and consent tracking.
  """
  def append_to_stream(patient_id, event) do
    stream_name = patient_stream_name(patient_id)
    enriched_event = enrich_event(event, patient_id)
    
    try do
      # In production, this would use Commanded.aggregate_uuid/3
      # For now, we simulate the EventStore append operation
      Logger.info("Appending event to stream #{stream_name}: #{inspect(enriched_event.event_type)}")
      
      # Check if snapshot is needed
      case stream_version(patient_id) do
        version when rem(version, @snapshot_frequency) == 0 ->
          create_snapshot(patient_id, version)
        _ ->
          :ok
      end
      
      # Simulate successful append
      {:ok, enriched_event}
      
    rescue
      exception ->
        Logger.error("Failed to append event to stream #{stream_name}: #{inspect(exception)}")
        {:error, :append_failed}
    end
  end
  
  @doc """
  Reads events from a patient's stream with optional filtering.
  
  Options:
  - :from_version - Start reading from specific version
  - :count - Maximum number of events to read
  - :event_type - Filter by specific event type
  - :since - Filter events since timestamp
  """
  def read_stream(patient_id, opts \\ []) do
    stream_name = patient_stream_name(patient_id)
    
    try do
      # In production, this would use EventStore.read_stream_forward/3
      # For now, we simulate reading events
      Logger.debug("Reading stream #{stream_name} with options: #{inspect(opts)}")
      
      # Mock events based on the request
      mock_events = generate_mock_events(patient_id, opts)
      {:ok, mock_events}
      
    rescue
      exception ->
        Logger.error("Failed to read stream #{stream_name}: #{inspect(exception)}")
        {:error, :read_failed}
    end
  end
  
  @doc """
  Gets the current version (event count) of a patient's stream.
  """
  def stream_version(patient_id) do
    stream_name = patient_stream_name(patient_id)
    
    try do
      # In production, this would query EventStore for actual stream version
      # For now, simulate a version number
      Logger.debug("Getting version for stream #{stream_name}")
      
      # Mock version (in real implementation, would query EventStore)
      42
      
    rescue
      exception ->
        Logger.error("Failed to get stream version for #{stream_name}: #{inspect(exception)}")
        0
    end
  end
  
  @doc """
  Checks if a patient stream exists.
  """
  def stream_exists?(patient_id) do
    stream_name = patient_stream_name(patient_id)
    
    # In production, would check EventStore
    Logger.debug("Checking if stream #{stream_name} exists")
    true  # Mock: assume stream exists
  end
  
  # Snapshot management
  @doc """
  Creates a snapshot of the current patient state at the given version.
  """
  def create_snapshot(patient_id, version) do
    Logger.info("Creating snapshot for patient #{patient_id} at version #{version}")
    
    # In production, this would:
    # 1. Build current state from all events up to version
    # 2. Serialize and store snapshot
    # 3. Mark as recovery point
    
    {:ok, :snapshot_created}
  end
  
  @doc """
  Loads the latest snapshot for a patient, if available.
  """
  def load_snapshot(patient_id) do
    Logger.debug("Loading snapshot for patient #{patient_id}")
    
    # In production, would load from snapshot store
    # For now, return no snapshot found
    {:error, :no_snapshot}
  end
  
  # Event statistics and monitoring
  @doc """
  Gets event store statistics for monitoring and health checks.
  """
  def event_statistics do
    try do
      # In production, would query EventStore for actual metrics
      stats = %{
        total_events: 15_432,
        total_streams: 1_234,
        avg_events_per_stream: 12.5,
        events_last_24h: 2_156,
        storage_size_mb: 45.2,
        oldest_event: DateTime.add(DateTime.utc_now(), -30, :day),
        latest_event: DateTime.utc_now(),
        connection_pool_size: 10,
        active_connections: 3
      }
      
      {:ok, stats}
      
    rescue
      exception ->
        Logger.error("Failed to get event statistics: #{inspect(exception)}")
        {:error, :stats_unavailable}
    end
  end
  
  @doc """
  Gets performance metrics for the event log.
  """
  def performance_metrics do
    %{
      avg_write_latency_ms: 12.3,
      avg_read_latency_ms: 8.7,
      writes_per_second: 45.2,
      reads_per_second: 123.4,
      last_measured_at: DateTime.utc_now()
    }
  end
  
  # Stream management helpers
  defp patient_stream_name(patient_id) do
    "patient_#{patient_id}"
  end
  
  defp enrich_event(event, patient_id) do
    base_event = Map.merge(event, %{
      event_id: UUID.uuid4(),
      patient_id: patient_id,
      occurred_at: DateTime.utc_now(),
      version: get_next_version(patient_id)
    })
    
    # Add PHI and consent tracking metadata
    metadata = %{
      phi: contains_phi?(event),
      consent_verified: has_valid_consent?(patient_id),
      audit_trail: %{
        source: "core_api",
        user_id: get_current_user_id(),
        ip_address: get_current_ip(),
        request_id: get_request_id()
      }
    }
    
    Map.put(base_event, :metadata, metadata)
  end
  
  defp validate_event_content("exercise_session", body) do
    required_fields = [:exercise_id, :session_type, :started_at]
    has_required_fields?(body, required_fields)
  end
  
  defp validate_event_content("rep_observation", body) do
    required_fields = [:exercise_id, :rep_number, :form_score]
    has_required_fields?(body, required_fields) and
    is_number(body.form_score) and body.form_score >= 0 and body.form_score <= 1
  end
  
  defp validate_event_content("feedback", body) do
    required_fields = [:feedback_type, :content]
    has_required_fields?(body, required_fields)
  end
  
  defp validate_event_content("alert", body) do
    required_fields = [:alert_type, :priority, :title]
    has_required_fields?(body, required_fields) and
    body.priority in [:low, :medium, :high, :urgent]
  end
  
  defp validate_event_content("consent", body) do
    required_fields = [:consent_type, :granted, :consent_date]
    has_required_fields?(body, required_fields) and
    is_boolean(body.granted)
  end
  
  defp validate_event_content(_event_type, _body), do: true
  
  defp has_required_fields?(body, required_fields) do
    Enum.all?(required_fields, fn field -> 
      Map.has_key?(body, field) and not is_nil(Map.get(body, field))
    end)
  end
  
  defp contains_phi?(event) do
    # Simple PHI detection - in production would be more sophisticated
    phi_indicators = ["name", "email", "phone", "ssn", "dob", "address"]
    event_string = Jason.encode!(event)
    
    Enum.any?(phi_indicators, fn indicator ->
      String.contains?(String.downcase(event_string), indicator)
    end)
  end
  
  defp has_valid_consent?(patient_id) do
    # In production, would check consent records
    Logger.debug("Checking consent for patient #{patient_id}")
    true  # Mock: assume consent is valid
  end
  
  defp get_next_version(patient_id) do
    stream_version(patient_id) + 1
  end
  
  defp get_current_user_id do
    # In production, would extract from Phoenix.Token or similar
    Process.get(:current_user_id, "system")
  end
  
  defp get_current_ip do
    # In production, would extract from Plug.Conn
    Process.get(:current_ip, "127.0.0.1")
  end
  
  defp get_request_id do
    # In production, would use Logger.metadata or Plug.RequestId
    Process.get(:request_id, UUID.uuid4())
  end
  
  defp generate_mock_events(patient_id, opts) do
    count = Keyword.get(opts, :count, 10)
    event_type = Keyword.get(opts, :event_type)
    
    base_events = [
      %{
        event_id: UUID.uuid4(),
        event_type: "exercise_session",
        patient_id: patient_id,
        body: %{
          exercise_id: "ex_001",
          session_type: "home_exercise",
          started_at: DateTime.add(DateTime.utc_now(), -3600, :second),
          completed_at: DateTime.add(DateTime.utc_now(), -3300, :second),
          total_reps_completed: 12,
          duration_seconds: 300
        },
        occurred_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        version: 41
      },
      %{
        event_id: UUID.uuid4(),
        event_type: "rep_observation",
        patient_id: patient_id,
        body: %{
          exercise_id: "ex_001",
          rep_number: 5,
          form_score: 0.85,
          confidence: 0.92,
          joint_angles: %{shoulder: 145, elbow: 90, wrist: 0}
        },
        occurred_at: DateTime.add(DateTime.utc_now(), -3400, :second),
        version: 42
      }
    ]
    
    events = case event_type do
      nil -> base_events
      type -> Enum.filter(base_events, fn event -> event.event_type == type end)
    end
    
    Enum.take(events, count)
  end
end