defmodule RehabTracking.MixProject do
  use Mix.Project

  def project do
    [
      app: :rehab_tracking,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        "test.cover": :test,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RehabTracking.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:phoenix_ecto, "~> 4.4"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:uuid, "~> 1.1"},                # UUID generation
      {:telemetry, "~> 1.0"},           # Metrics and monitoring
      {:swoosh, "~> 1.8"},              # Email sending
      {:bcrypt_elixir, "~> 3.0"},       # Password hashing
      {:httpoison, "~> 2.0"},           # HTTP client for FHIR
      
      # Auth
      {:joken, "~> 2.6"},
      
      # Event sourcing and CQRS dependencies
      {:commanded, "~> 1.4"},           # CQRS/Event Sourcing framework
      {:eventstore, "~> 1.4"},         # Event store for Commanded
      {:commanded_eventstore_adapter, "~> 1.4"}, # EventStore adapter for Commanded
      {:commanded_ecto_projections, "~> 1.3"}, # Ecto projections for Commanded
      
      # Broadway stream processing
      {:broadway, "~> 1.0"},               # Core Broadway
      # {:broadway_sqs, "~> 0.7", optional: true},       # Commented out - OTP version issue
      # {:broadway_rabbitmq, "~> 0.8", optional: true},  # Commented out - OTP version issue
      
      # Phoenix web dependencies 
      {:phoenix_live_view, "~> 1.0"},   # LiveView components
      {:phoenix_html, "~> 4.0"},        # HTML helpers
      {:phoenix_live_dashboard, "~> 0.8"},
      {:gettext, "~> 0.20"},           # Internationalization
      {:telemetry_metrics, "~> 1.0"},  # Metrics collection
      {:telemetry_poller, "~> 1.0"},   # Telemetry polling
      {:cors_plug, "~> 3.0"},          # CORS support
      
      # Test dependencies
      {:mox, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.18", only: :test}, # Code coverage
      
      # Security/quality (dev/test only)
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}, # Security analysis
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # Setup commands
      setup: ["deps.get", "ecto.setup", "event_store.init"],
      
      # Database commands
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      
      # EventStore commands  
      "event_store.init": ["event_store.create", "event_store.init"],
      "event_store.reset": ["event_store.drop", "event_store.init"],
      
      # Test commands
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      smoke: ["run priv/smoke/smoke.exs"],
      
      # Development health check
      doctor: ["compile --warnings-as-errors", "test --max-failures 1"],
      
      # Code quality
      quality: ["format --check-formatted", "sobelow", "credo --strict"],
      
      # Coverage
      "test.cover": ["coveralls.html"],
      
      # Development data
      seed: ["run priv/repo/seeds.exs"],
      "seed.test": ["run priv/repo/test_seeds.exs"],
      
      # Rehab-specific commands
      "rehab.smoke": ["run priv/smoke/smoke.exs"],
      "rehab.seed": ["run -e \"RehabTracking.Simulator.generate_bulk_data(5, 14)\""],
      "test.load": ["run -e \"RehabTracking.Simulator.generate_bulk_data(100, 7)\""],
      "test.burst": ["run -e \"RehabTracking.Simulator.generate_sensor_burst(\\\"patient_123\\\", \\\"squats\\\", 1000)\""],
      "test.edges": ["run -e \"RehabTracking.Simulator.generate_edge_cases(\\\"patient_test\\\")\""]
    ]
  end
end