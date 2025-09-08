import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :rehab_tracking, RehabTracking.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rehab_tracking_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure EventStore for testing
config :rehab_tracking, RehabTracking.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  username: "postgres", 
  password: "postgres",
  database: "rehab_tracking_eventstore_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool_size: 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rehab_tracking, RehabTrackingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "rehab_tracking_test_secret_key_base_needs_to_be_at_least_64_characters_long",
  server: false

# In test we don't send emails.
config :rehab_tracking, RehabTracking.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure JWT signing for test
config :joken, default_signer: "test_jwt_secret_key_for_testing_only"

# Broadway configuration for test (using test adapter)
config :rehab_tracking, RehabTracking.Core.BroadwayPipeline,
  producer: [
    module: {Broadway.DummyProducer, []}
  ]