defmodule RehabTracking.MixProject do
  use Mix.Project

  def project do
    [
      app: :rehab_tracking,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:commanded, "~> 1.4"},
      {:eventstore, "~> 1.4"},
      {:broadway, "~> 1.0"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:phoenix_ecto, "~> 4.4"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      
      # Integration dependencies
      {:joken, "~> 2.5"},               # JWT token handling
      {:httpoison, "~> 2.0"},           # HTTP client for FHIR/EMR
      {:uuid, "~> 1.1"},                # UUID generation
      {:broadway_sqs, "~> 0.7"},        # SQS adapter for Broadway
      # {:broadway_rabbitmq, "~> 0.8"},   # RabbitMQ adapter - disabled for OTP 28 compatibility
      {:gen_stage, "~> 1.0"},           # GenStage for Broadway
      {:telemetry, "~> 1.0"},           # Metrics and monitoring
      {:swoosh, "~> 1.8"},              # Email sending
      {:bcrypt_elixir, "~> 3.0"},       # Password hashing
      
      # Phoenix web dependencies 
      {:phoenix_live_dashboard, "~> 0.8"},
      {:phoenix_live_view, "~> 1.0"},   # LiveView components
      {:phoenix_html, "~> 4.0"},        # HTML helpers
      {:gettext, "~> 0.20"},           # Internationalization
      {:telemetry_metrics, "~> 1.0"},  # Metrics collection
      {:telemetry_poller, "~> 1.0"},   # Telemetry polling
      {:finch, "~> 0.13"},             # HTTP client
      {:cors_plug, "~> 3.0"},          # CORS support
      
      # Test dependencies
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
