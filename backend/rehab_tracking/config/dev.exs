import Config

# Configure your database
config :rehab_tracking, RehabTracking.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rehab_tracking_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure EventStore for development
config :rehab_tracking, RehabTracking.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "postgres",
  password: "postgres",
  database: "rehab_tracking_eventstore_dev",
  hostname: "localhost",
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :rehab_tracking, RehabTrackingWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "rehab_tracking_dev_secret_key_base_needs_to_be_at_least_64_characters_long",
  watchers: []

# Watch static and templates for browser reloading.
config :rehab_tracking, RehabTrackingWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/rehab_tracking_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :rehab_tracking, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Include HEEx debug annotations as HTML comments in rendered markup
config :phoenix_live_view, :debug_heex_annotations, true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Configure JWT signing for development
config :joken, default_signer: "dev_jwt_secret_key_should_be_changed_in_production"

# Broadway configuration for development (using dummy producer)
config :rehab_tracking, RehabTracking.Core.BroadwayPipeline,
  producer: [
    module: {Broadway.DummyProducer, []}
  ]

# CORS settings for development
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:3001", "http://localhost:8080"],
  credentials: true