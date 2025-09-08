defmodule RehabTracking.BroadwayPipeline do
  @moduledoc """
  Broadway pipeline for processing exercise events at high throughput.
  
  Configuration:
  - 2 producers for redundancy
  - 10 processors for parallelism
  - 2 batchers for aggregation
  - Batch size: 100 events
  - Batch timeout: 1000ms
  - Target throughput: 1000 events/sec
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias RehabTracking.Core.Projectors.AdherenceProjector
  alias RehabTracking.Core.Projectors.QualityProjector
  alias RehabTracking.Core.Projectors.WorkQueueProjector
  alias RehabTracking.Policy.Nudges

  @producer_module Broadway.DummyProducer
  @receive_interval 1000

  def start_link(opts) do
    Broadway.start_link(__MODULE__, opts)
  end

  @impl true
  def handle_message(_processor_name, message, _context) do
    try do
      # Extract event data from message
      event_data = extract_event_data(message.data)
      
      # Validate event structure
      case validate_event(event_data) do
        {:ok, validated_event} ->
          # Process the event
          process_event(validated_event)
          
          # Mark message as successful
          Message.ack(message)
          
        {:error, reason} ->
          Logger.warning("Invalid event received: #{inspect(reason)}")
          Message.fail(message, reason)
      end
    rescue
      error ->
        Logger.error("Error processing message: #{inspect(error)}")
        Message.fail(message, error)
    end
  end

  @impl true
  def handle_batch(_batcher_name, messages, _batch_info, _context) do
    Logger.info("Processing batch of #{length(messages)} events")
    
    # Extract events from messages
    events = Enum.map(messages, &extract_event_data(&1.data))
    
    try do
      # Process batch of events
      process_event_batch(events)
      
      # All messages succeeded
      messages
    rescue
      error ->
        Logger.error("Error processing batch: #{inspect(error)}")
        
        # Mark all messages as failed
        Enum.map(messages, &Message.fail(&1, error))
    end
  end

  @impl true
  def handle_failed(_messages, _context) do
    # Failed messages are handled by individual processors
    # Could implement dead letter queue here
    []
  end

  # Configuration for Broadway pipeline
  defp broadway_config do
    [
      name: __MODULE__,
      producer: [
        module: {get_producer_module(), [
          receive_interval: @receive_interval
        ]},
        stages: 2  # 2 producers for redundancy
      ],
      processors: [
        default: [
          stages: 10,  # 10 processors for parallelism
          max_demand: 50
        ]
      ],
      batchers: [
        default: [
          stages: 2,              # 2 batchers for aggregation
          batch_size: 100,        # 100 events per batch
          batch_timeout: 1_000    # 1000ms timeout
        ]
      ],
      context: %{}
    ]
  end

  # Get producer module based on environment
  defp get_producer_module do
    case Application.get_env(:rehab_tracking, :broadway_producer) do
      :sqs -> Broadway.SQSProducer
      :rabbit_mq -> BroadwayRabbitMQ.Producer
      :kafka -> BroadwayKafka.Producer
      _ -> @producer_module  # Default to dummy producer for development
    end
  end

  # Extract event data from raw message
  defp extract_event_data(raw_data) when is_binary(raw_data) do
    Jason.decode!(raw_data)
  end
  
  defp extract_event_data(data) when is_map(data), do: data
  
  defp extract_event_data(data) do
    Logger.warning("Unknown message format: #{inspect(data)}")
    %{}
  end

  # Validate event structure
  defp validate_event(%{"kind" => kind, "subject_id" => subject_id, "body" => body} = event) 
       when is_binary(kind) and is_binary(subject_id) and is_map(body) do
    {:ok, %{
      kind: kind,
      subject_id: subject_id,
      body: body,
      meta: Map.get(event, "meta", %{}),
      timestamp: Map.get(event, "timestamp", DateTime.utc_now())
    }}
  end
  
  defp validate_event(event) do
    {:error, "Invalid event structure: #{inspect(event)}"}
  end

  # Process individual event
  defp process_event(%{kind: "exercise_session"} = event) do
    Logger.debug("Processing exercise session event for subject: #{event.subject_id}")
    
    # Update projections
    AdherenceProjector.handle_event(event)
    QualityProjector.handle_event(event)
    WorkQueueProjector.handle_event(event)
    
    # Check for nudge policies
    Nudges.evaluate_event(event)
    
    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :broadway, :event, :processed],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end
  
  defp process_event(%{kind: "rep_observation"} = event) do
    Logger.debug("Processing rep observation event for subject: #{event.subject_id}")
    
    # Update quality projections
    QualityProjector.handle_event(event)
    
    # Check for real-time feedback policies
    Nudges.evaluate_event(event)
    
    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :broadway, :event, :processed],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end
  
  defp process_event(%{kind: "feedback"} = event) do
    Logger.debug("Processing feedback event for subject: #{event.subject_id}")
    
    # Update work queue projections
    WorkQueueProjector.handle_event(event)
    
    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :broadway, :event, :processed],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end
  
  defp process_event(%{kind: "alert"} = event) do
    Logger.debug("Processing alert event for subject: #{event.subject_id}")
    
    # Update work queue projections
    WorkQueueProjector.handle_event(event)
    
    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :broadway, :event, :processed],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end
  
  defp process_event(%{kind: "consent"} = event) do
    Logger.debug("Processing consent event for subject: #{event.subject_id}")
    
    # Update adherence projections (affects data visibility)
    AdherenceProjector.handle_event(event)
    
    # Emit telemetry
    :telemetry.execute(
      [:rehab_tracking, :broadway, :event, :processed],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end
  
  defp process_event(event) do
    Logger.warning("Unknown event kind: #{event.kind}")
    
    # Emit telemetry for unknown events
    :telemetry.execute(
      [:rehab_tracking, :broadway, :event, :unknown],
      %{count: 1},
      %{kind: event.kind, subject_id: event.subject_id}
    )
  end

  # Process batch of events (for batch operations)
  defp process_event_batch(events) do
    # Group events by type for efficient batch processing
    events_by_type = Enum.group_by(events, &Map.get(&1, "kind"))
    
    # Process each type in batch
    Enum.each(events_by_type, fn {kind, type_events} ->
      case kind do
        "exercise_session" ->
          AdherenceProjector.handle_batch(type_events)
          QualityProjector.handle_batch(type_events)
          
        "rep_observation" ->
          QualityProjector.handle_batch(type_events)
          
        "feedback" ->
          WorkQueueProjector.handle_batch(type_events)
          
        "alert" ->
          WorkQueueProjector.handle_batch(type_events)
          
        "consent" ->
          AdherenceProjector.handle_batch(type_events)
          
        _ ->
          Logger.warning("Unknown batch event kind: #{kind}")
      end
    end)
    
    # Emit batch telemetry
    :telemetry.execute(
      [:rehab_tracking, :broadway, :batch, :processed],
      %{count: length(events)},
      %{batch_size: length(events)}
    )
  end

  # Child spec for supervision tree
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [broadway_config() ++ opts]},
      type: :supervisor,
      restart: :permanent
    }
  end

  # Health check for Broadway pipeline
  def health_check do
    case Broadway.producer_names(__MODULE__) do
      [] -> {:error, :no_producers}
      producers ->
        # Check if all producers are alive
        alive_producers = Enum.count(producers, &Process.alive?/1)
        total_producers = length(producers)
        
        if alive_producers == total_producers do
          {:ok, %{
            status: :healthy,
            producers: total_producers,
            alive_producers: alive_producers
          }}
        else
          {:error, %{
            status: :degraded,
            producers: total_producers,
            alive_producers: alive_producers
          }}
        end
    end
  end

  # Get pipeline metrics
  def metrics do
    %{
      config: %{
        producers: 2,
        processors: 10,
        batchers: 2,
        batch_size: 100,
        batch_timeout: 1000
      },
      target_throughput: "1000 events/sec"
    }
  end
end