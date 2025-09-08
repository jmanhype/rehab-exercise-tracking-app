defmodule RehabTrackingWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor for Phoenix and custom application metrics.
  """
  
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router.dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router.dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router.dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("rehab_tracking.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("rehab_tracking.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("rehab_tracking.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("rehab_tracking.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("rehab_tracking.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Event Store Metrics
      counter("rehab_tracking.events.ingested.total",
        tags: [:event_type],
        description: "Total events ingested into the event store"
      ),
      summary("rehab_tracking.events.processing_time",
        unit: {:native, :millisecond},
        tags: [:event_type],
        description: "Time spent processing events"
      ),

      # Broadway Pipeline Metrics
      counter("rehab_tracking.broadway.messages.processed.total",
        tags: [:status],
        description: "Total messages processed by Broadway pipeline"
      ),
      summary("rehab_tracking.broadway.message.processing_time",
        unit: {:native, :millisecond},
        description: "Time spent processing Broadway messages"
      ),

      # Projection Metrics
      counter("rehab_tracking.projections.updated.total",
        tags: [:projection_name],
        description: "Total projection updates"
      ),
      summary("rehab_tracking.projections.update_time",
        unit: {:native, :millisecond},
        tags: [:projection_name],
        description: "Time spent updating projections"
      ),

      # Custom API Metrics
      counter("rehab_tracking.api.requests.total",
        tags: [:method, :route, :status_class],
        description: "Total API requests"
      ),
      summary("rehab_tracking.api.request.duration",
        unit: {:native, :millisecond},
        tags: [:method, :route],
        description: "API request duration"
      ),

      # Authentication Metrics
      counter("rehab_tracking.auth.attempts.total",
        tags: [:result],
        description: "Authentication attempts"
      ),
      counter("rehab_tracking.auth.token.issued.total",
        description: "JWT tokens issued"
      ),

      # Rate Limiting Metrics
      counter("rehab_tracking.rate_limit.hits.total",
        tags: [:client_type],
        description: "Rate limit hits"
      ),

      # FHIR Metrics
      counter("rehab_tracking.fhir.requests.total",
        tags: [:resource_type, :operation],
        description: "FHIR API requests"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {RehabTrackingWeb, :count_users, []}
      {__MODULE__, :dispatch_custom_metrics, []}
    ]
  end

  def dispatch_custom_metrics do
    # Event store connection count
    :telemetry.execute([:rehab_tracking, :event_store, :connections], %{
      active: get_event_store_connections()
    })

    # Broadway pipeline status
    dispatch_broadway_metrics()

    # Memory usage breakdown
    memory_usage = :erlang.memory()
    :telemetry.execute([:rehab_tracking, :vm, :memory], memory_usage)
  end

  defp get_event_store_connections do
    try do
      case EventStore.ping(RehabTracking.EventStore) do
        :pong -> 1
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  defp dispatch_broadway_metrics do
    try do
      case Broadway.get_status(RehabTracking.Core.BroadwayPipeline) do
        %{} = status ->
          :telemetry.execute([:rehab_tracking, :broadway, :status], %{
            producers: length(Map.get(status, :producers, [])),
            processors: length(Map.get(status, :processors, [])),
            batchers: length(Map.get(status, :batchers, []))
          })
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end
end