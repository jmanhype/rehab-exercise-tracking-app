# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configure the primary database repository
config :rehab_tracking, RehabTracking.Repo,
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "rehab_tracking_#{config_env()}",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure the EventStore
config :rehab_tracking, RehabTracking.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "postgres",
  password: "postgres",
  database: "rehab_tracking_eventstore_#{config_env()}",
  hostname: "localhost",
  pool_size: 10

# Configure the Commanded application
config :rehab_tracking, RehabTracking.Core.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: RehabTracking.EventStore
  ],
  pubsub: :local,
  registry: :local

# Configure the primary Ecto repo
config :rehab_tracking,
  ecto_repos: [RehabTracking.Repo],
  event_stores: [RehabTracking.EventStore]

# Configures the endpoint
config :rehab_tracking, RehabTrackingWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: RehabTrackingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RehabTracking.PubSub,
  live_view: [signing_salt: "rehab_salt"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :patient_id, :event_type]

# Configure Phoenix JSON library
config :phoenix, :json_library, Jason

# Configure Joken for JWT token handling
config :joken, default_signer: "rehab_tracking_secret"

# Configure Telemetry Poller
config :telemetry_poller, :default, period: 10_000

# Broadway configuration is imported from separate file
# See config/broadway.exs for detailed pipeline settings

# Configure CORS
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:3001"],
  credentials: true,
  headers: ["Authorization", "Content-Type", "Accept", "Origin", 
            "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken",
            "Keep-Alive", "X-Requested-With", "If-Modified-Since", 
            "X-CSRF-Token"]

# Import Broadway configuration
import_config "broadway.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"