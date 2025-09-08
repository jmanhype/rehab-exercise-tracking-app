defmodule RehabTracking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RehabTrackingWeb.Telemetry,
      
      # Start the Ecto repository
      RehabTracking.Repo,
      
      # Start the EventStore for event sourcing (temporarily disabled)
      # RehabTracking.EventStore,
      
      # Start the Commanded application for CQRS/Event Sourcing (temporarily disabled)
      # RehabTracking.Core.CommandedApp,
      
      # Start the Broadway pipeline for event processing (disabled for minimal setup)
      # RehabTracking.Core.BroadwayPipeline,
      
      # Start the PubSub system
      {Phoenix.PubSub, name: RehabTracking.PubSub},
      
      # Start Finch for HTTP client requests (temporarily disabled - missing dependency)
      # {Finch, name: RehabTracking.Finch},
      
      # Start the Endpoint (http/https)
      RehabTrackingWeb.Endpoint,
      
      # Start additional services
      {Task.Supervisor, name: RehabTracking.TaskSupervisor},
      {Registry, keys: :unique, name: RehabTracking.Registry},
      
      # Rate limiting ETS table initialization
      {Task, fn -> 
        case :ets.whereis(:rate_limit_buckets) do
          :undefined ->
            :ets.new(:rate_limit_buckets, [:named_table, :public, :set, {:write_concurrency, true}])
          _ -> :ok
        end
      end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RehabTracking.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RehabTrackingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end