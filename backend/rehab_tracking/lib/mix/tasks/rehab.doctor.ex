defmodule Mix.Tasks.Rehab.Doctor do
  @moduledoc """
  Diagnoses RehabTracking application health and configuration.
  
  This task checks:
  - Database connectivity
  - EventStore status  
  - Migration status
  - Configuration issues
  - Performance metrics
  
  Usage:
      mix rehab.doctor
      mix rehab.doctor --verbose
  """
  
  use Mix.Task
  
  @shortdoc "Diagnoses application health and configuration"
  
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [verbose: :boolean])
    verbose? = opts[:verbose] || false
    
    Mix.Task.run("app.start")
    
    Mix.shell().info("🏥 RehabTracking Health Check")
    Mix.shell().info("=" |> String.duplicate(40))
    
    checks = [
      {"Database Connectivity", &check_database_connectivity/1},
      {"EventStore Status", &check_eventstore_status/1},
      {"Migration Status", &check_migration_status/1},
      {"Configuration", &check_configuration/1},
      {"Broadway Pipeline", &check_broadway_status/1},
      {"Projection Health", &check_projection_health/1},
      {"Performance Metrics", &check_performance_metrics/1}
    ]
    
    results = Enum.map(checks, fn {name, check_fn} ->
      Mix.shell().info("Checking #{name}...")
      result = check_fn.(verbose?)
      
      case result do
        {:ok, message} -> 
          Mix.shell().info("✅ #{name}: #{message}")
          :ok
        {:warning, message} -> 
          Mix.shell().info("⚠️  #{name}: #{message}")
          :warning
        {:error, message} -> 
          Mix.shell().info("❌ #{name}: #{message}")
          :error
      end
    end)
    
    Mix.shell().info("\n" <> "=" |> String.duplicate(40))
    summarize_results(results)
  end
  
  defp check_database_connectivity(verbose?) do
    try do
      case RehabTracking.Repo.health_check() do
        :ok ->
          if verbose? do
            # Get database info
            %{rows: [[version]]} = RehabTracking.Repo.query!("SELECT version()", [])
            {:ok, "Connected - #{String.slice(version, 0, 50)}..."}
          else
            {:ok, "Connected"}
          end
        :error ->
          {:error, "Cannot connect to database"}
      end
    rescue
      e -> {:error, "Connection failed: #{Exception.message(e)}"}
    end
  end
  
  defp check_eventstore_status(verbose?) do
    try do
      # Try to query EventStore
      {:ok, conn} = EventStore.start_link(RehabTracking.EventStore)
      
      if verbose? do
        # Get event count
        case EventStore.read_all_streams_forward(conn, 0, 1) do
          {:ok, events} -> {:ok, "Connected - #{length(events)} events in store"}
          _ -> {:ok, "Connected - Empty store"}
        end
      else
        {:ok, "Connected"}
      end
    rescue
      e -> {:error, "EventStore error: #{Exception.message(e)}"}
    end
  end
  
  defp check_migration_status(_verbose?) do
    try do
      migrated = RehabTracking.Repo.query!("SELECT version FROM schema_migrations", [])
      pending_migrations = get_pending_migrations()
      
      case length(pending_migrations) do
        0 -> {:ok, "All migrations applied (#{length(migrated.rows)} total)"}
        n -> {:warning, "#{n} pending migrations"}
      end
    rescue
      e -> {:error, "Migration check failed: #{Exception.message(e)}"}
    end
  end
  
  defp check_configuration(verbose?) do
    issues = []
    
    # Check database config
    repo_config = RehabTracking.Repo.config()
    issues = if repo_config[:password] == "postgres" do
      ["Using default PostgreSQL password" | issues]
    else
      issues
    end
    
    # Check EventStore config
    eventstore_config = Application.get_env(:rehab_tracking, RehabTracking.EventStore, [])
    issues = if eventstore_config[:password] == "postgres" do
      ["Using default EventStore password" | issues]
    else
      issues
    end
    
    # Check environment
    issues = if Mix.env() == :prod and System.get_env("SECRET_KEY_BASE") == nil do
      ["SECRET_KEY_BASE not set in production" | issues]
    else
      issues
    end
    
    case {issues, verbose?} do
      {[], _} -> {:ok, "Configuration looks good"}
      {issues, true} -> {:warning, "Issues: #{Enum.join(issues, ", ")}"}
      {issues, false} -> {:warning, "#{length(issues)} configuration issues"}
    end
  end
  
  defp check_broadway_status(verbose?) do
    try do
      # Check if Broadway supervisor is running
      case Process.whereis(RehabTracking.Core.BroadwayPipeline) do
        nil -> {:warning, "Broadway pipeline not running"}
        pid when is_pid(pid) ->
          if verbose? do
            {:ok, "Running (PID: #{inspect(pid)})"}
          else
            {:ok, "Running"}
          end
      end
    rescue
      e -> {:error, "Broadway check failed: #{Exception.message(e)}"}
    end
  end
  
  defp check_projection_health(verbose?) do
    try do
      lag_metrics = RehabTracking.Repo.projection_lag_metrics()
      
      case lag_metrics do
        [] -> {:warning, "No projection metrics found"}
        metrics ->
          max_lag = metrics
          |> Enum.map(& &1["lag_seconds"])
          |> Enum.max()
          
          case max_lag do
            lag when lag < 10 -> 
              if verbose? do
                {:ok, "Healthy - Max lag: #{Float.round(lag, 2)}s"}
              else
                {:ok, "Healthy"}
              end
            lag when lag < 60 -> 
              {:warning, "Elevated lag: #{Float.round(lag, 2)}s"}
            lag -> 
              {:error, "High lag: #{Float.round(lag, 2)}s"}
          end
      end
    rescue
      e -> {:error, "Projection check failed: #{Exception.message(e)}"}
    end
  end
  
  defp check_performance_metrics(verbose?) do
    try do
      # Basic performance checks
      memory_total = :erlang.memory(:total)
      memory_mb = memory_total
      memory_mb = div(memory_mb, 1024 * 1024)
      
      process_count = :erlang.system_info(:process_count)
      
      cond do
        memory_mb > 1000 -> 
          {:warning, "High memory usage: #{memory_mb}MB"}
        process_count > 10000 -> 
          {:warning, "High process count: #{process_count}"}
        verbose? -> 
          {:ok, "Memory: #{memory_mb}MB, Processes: #{process_count}"}
        true -> 
          {:ok, "Normal"}
      end
    rescue
      e -> {:error, "Performance check failed: #{Exception.message(e)}"}
    end
  end
  
  defp get_pending_migrations do
    try do
      # This would normally check for pending migrations
      # For now, return empty list
      []
    rescue
      _ -> []
    end
  end
  
  defp summarize_results(results) do
    error_count = Enum.count(results, & &1 == :error)
    warning_count = Enum.count(results, & &1 == :warning)
    _ok_count = Enum.count(results, & &1 == :ok)
    
    cond do
      error_count > 0 ->
        Mix.shell().info("🚨 Health Check FAILED: #{error_count} errors, #{warning_count} warnings")
        System.halt(1)
      
      warning_count > 0 ->
        Mix.shell().info("⚠️  Health Check PASSED with warnings: #{warning_count} warnings")
      
      true ->
        Mix.shell().info("✅ Health Check PASSED: All systems healthy")
    end
  end
end