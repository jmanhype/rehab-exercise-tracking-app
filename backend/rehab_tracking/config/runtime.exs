import Config

# Runtime configuration for Rehab Tracking System
# This file is executed during runtime, not compile time
# Environment variables are read here for security

# The secret key base is used to sign/encrypt cookies and other secrets.
# A default value is used in config/dev.exs and config/test.exs but you
# want to use a real secret in production.
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

# Database URL for runtime
database_url =
  System.get_env("DATABASE_URL") ||
    "ecto://postgres:postgres@localhost:5432/rehab_tracking_prod"

# EventStore URL for runtime  
eventstore_url =
  System.get_env("EVENTSTORE_URL") ||
    "postgres://postgres:postgres@localhost:5432/rehab_eventstore_prod"

config :rehab_tracking, RehabTracking.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: System.get_env("DATABASE_SSL") in ["true", "1"],
  prepare: :named,
  parameters: [
    plan_cache_mode: "force_custom_plan"
  ]

config :rehab_tracking, RehabTracking.EventStore,
  url: eventstore_url,
  pool_size: String.to_integer(System.get_env("EVENTSTORE_POOL_SIZE") || "10")

# Phoenix Endpoint configuration
config :rehab_tracking, RehabTrackingWeb.Endpoint,
  http: [
    # Enable IPv6 and bind on all interfaces.
    # Set it to {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: secret_key_base,
  url: [
    scheme: System.get_env("PHX_SCHEME") || "https",
    host: System.get_env("PHX_HOST") || "localhost",
    port: String.to_integer(System.get_env("PHX_PORT") || "443")
  ],
  force_ssl: [
    rewrite_on: [:x_forwarded_host, :x_forwarded_port, :x_forwarded_proto],
    host: nil,
    hsts: true
  ],
  check_origin: [
    System.get_env("PHX_HOST") || "localhost",
    "//localhost"
  ]

# Redis configuration for caching and sessions
redis_url = System.get_env("REDIS_URL") || "redis://localhost:6379"

config :rehab_tracking, :redis,
  url: redis_url

# RabbitMQ configuration for Broadway
rabbitmq_url = System.get_env("RABBITMQ_URL") || "amqp://guest:guest@localhost:5672"

config :rehab_tracking, :rabbitmq,
  url: rabbitmq_url

# Email configuration
config :rehab_tracking, RehabTracking.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY") || ""

# PHI Encryption configuration
config :rehab_tracking,
  phi_encryption_key: System.get_env("PHI_ENCRYPTION_KEY") ||
    raise """
    environment variable PHI_ENCRYPTION_KEY is missing.
    This is required for PHI encryption in production.
    Generate one with: openssl rand -base64 32
    """

# JWT configuration for authentication
config :joken, default_signer: System.get_env("JWT_SECRET") || secret_key_base

# Logging configuration
log_level = System.get_env("LOG_LEVEL") || "info"
config :logger, level: String.to_atom(log_level)

# Telemetry and monitoring
config :rehab_tracking, :telemetry,
  prometheus_enabled: System.get_env("PROMETHEUS_ENABLED") in ["true", "1"],
  metrics_port: String.to_integer(System.get_env("METRICS_PORT") || "9090")

# External service configurations
config :rehab_tracking, :fhir,
  base_url: System.get_env("FHIR_BASE_URL"),
  client_id: System.get_env("FHIR_CLIENT_ID"),
  client_secret: System.get_env("FHIR_CLIENT_SECRET")

config :rehab_tracking, :s3,
  bucket: System.get_env("S3_BUCKET"),
  region: System.get_env("S3_REGION") || "us-east-1",
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

# Development overrides (only in dev/test environments)
if config_env() in [:dev, :test] do
  # Use simpler configurations for development
  config :rehab_tracking, RehabTrackingWeb.Endpoint,
    force_ssl: false,
    check_origin: false
    
  config :rehab_tracking, RehabTracking.Repo,
    ssl: false
    
  config :rehab_tracking, RehabTracking.EventStore,
    ssl: false
end

# Environment-specific overrides
case config_env() do
  :prod ->
    # Production-specific runtime config
    config :rehab_tracking,
      audit_log_enabled: true,
      rate_limiting_enabled: true,
      session_timeout: 3600

  :dev ->
    # Development-specific runtime config
    config :rehab_tracking,
      audit_log_enabled: false,
      rate_limiting_enabled: false,
      session_timeout: 86_400

  :test ->
    # Test-specific runtime config
    config :rehab_tracking,
      audit_log_enabled: false,
      rate_limiting_enabled: false,
      session_timeout: 3600
end