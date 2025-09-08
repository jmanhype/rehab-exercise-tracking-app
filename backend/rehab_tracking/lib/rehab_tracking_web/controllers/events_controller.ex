defmodule RehabTrackingWeb.EventsController do
  use RehabTrackingWeb, :controller

  require Logger

  @doc """
  Endpoint for ingesting exercise events into the Broadway pipeline.
  
  Accepts JSON events with structure:
  {
    "kind": "exercise_session|rep_observation|feedback|alert|consent", 
    "subject_id": "patient_123",
    "body": {...},
    "meta": {...}
  }
  """
  def create(conn, event_params) do
    case validate_event(event_params) do
      {:ok, validated_event} ->
        # In a real implementation, this would publish to SQS/RabbitMQ
        # For now, we'll simulate by logging
        Logger.info("Event ingested: #{inspect(validated_event)}")
        
        # Simulate Broadway processing
        simulate_broadway_processing(validated_event)
        
        conn
        |> put_status(:created)
        |> json(%{
          status: "accepted",
          event_id: generate_event_id(),
          message: "Event queued for processing"
        })
        
      {:error, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          errors: errors
        })
    end
  end

  @doc """
  Get Broadway pipeline status and metrics
  """
  def status(conn, _params) do
    health = RehabTracking.BroadwayPipeline.health_check()
    metrics = RehabTracking.BroadwayPipeline.metrics()
    
    conn
    |> json(%{
      pipeline_health: health,
      metrics: metrics,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Batch endpoint for ingesting multiple events
  """
  def create_batch(conn, %{"events" => events}) when is_list(events) do
    results = Enum.map(events, fn event ->
      case validate_event(event) do
        {:ok, validated_event} ->
          Logger.info("Batch event ingested: #{inspect(validated_event)}")
          simulate_broadway_processing(validated_event)
          %{status: "accepted", event_id: generate_event_id()}
          
        {:error, errors} ->
          %{status: "error", errors: errors}
      end
    end)
    
    accepted_count = Enum.count(results, &(&1.status == "accepted"))
    error_count = Enum.count(results, &(&1.status == "error"))
    
    status_code = if error_count == 0, do: :created, else: :multi_status
    
    conn
    |> put_status(status_code)
    |> json(%{
      status: "batch_processed",
      accepted: accepted_count,
      errors: error_count,
      results: results
    })
  end

  def create_batch(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      status: "error",
      message: "Expected 'events' array in request body"
    })
  end

  # Private functions
  defp validate_event(%{"kind" => kind, "subject_id" => subject_id, "body" => body} = event) 
       when is_binary(kind) and is_binary(subject_id) and is_map(body) do
    
    cond do
      kind not in ["exercise_session", "rep_observation", "feedback", "alert", "consent"] ->
        {:error, ["Invalid event kind: #{kind}"]}
        
      String.trim(subject_id) == "" ->
        {:error, ["subject_id cannot be empty"]}
        
      map_size(body) == 0 ->
        {:error, ["body cannot be empty"]}
        
      true ->
        {:ok, %{
          kind: kind,
          subject_id: subject_id,
          body: body,
          meta: Map.get(event, "meta", %{}),
          timestamp: DateTime.utc_now()
        }}
    end
  end

  defp validate_event(event) when is_map(event) do
    missing_fields = []
    
    missing_fields = if Map.has_key?(event, "kind"), do: missing_fields, else: ["kind" | missing_fields]
    missing_fields = if Map.has_key?(event, "subject_id"), do: missing_fields, else: ["subject_id" | missing_fields]
    missing_fields = if Map.has_key?(event, "body"), do: missing_fields, else: ["body" | missing_fields]
    
    {:error, ["Missing required fields: #{Enum.join(missing_fields, ", ")}"]}
  end

  defp validate_event(_event) do
    {:error, ["Event must be a JSON object"]}
  end

  defp simulate_broadway_processing(event) do
    # In development, simulate what Broadway would do
    Logger.info("Simulating Broadway processing for event: #{event.kind}")
    
    # Emit telemetry as if Broadway processed it
    :telemetry.execute(
      [:rehab_tracking, :api, :event, :ingested],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end

  defp generate_event_id do
    UUID.uuid4()
  end
end