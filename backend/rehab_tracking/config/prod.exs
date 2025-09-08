import Config

# Production configuration for Rehab Tracking System
# This file contains production-specific settings

# Database configuration for production
config :rehab_tracking, RehabTracking.Repo,
  # URL will be set in runtime.exs from environment variables
  pool_size: 15,
  queue_target: 50,
  queue_interval: 1000,
  timeout: 15_000,
  connect_timeout: 10_000,
  handshake_timeout: 5_000,
  pool_timeout: 5_000,
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    cacerts: :public_key.cacerts_get(),
    server_name_indication: to_charlist(System.get_env("DB_HOST", "localhost")),
    customize_hostname_check: [
      match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ]

# EventStore configuration for production
config :rehab_tracking, RehabTracking.EventStore,
  pool_size: 15,
  queue_target: 50,
  queue_interval: 1000,
  timeout: 15_000,
  connect_timeout: 10_000,
  handshake_timeout: 5_000,
  pool_timeout: 5_000,
  ssl: true

# Phoenix configuration for production
config :rehab_tracking, RehabTrackingWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  version: Application.spec(:rehab_tracking, :vsn)

# Configures Swoosh API Client for email delivery in production
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Disable development routes in production
config :rehab_tracking, dev_routes: false

# Runtime configuration will be loaded from config/runtime.exs
# Do not configure secrets here, use runtime.exs instead

# Logging configuration for production
config :logger,
  level: :info,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Broadway configuration optimized for production
config :rehab_tracking, :broadway,
  producer: [
    module: BroadwayRabbitMQ.Producer,
    concurrency: 4
  ],
  processors: [
    default: [concurrency: 20]
  ],
  batchers: [
    default: [
      concurrency: 4,
      batch_size: 200,
      batch_timeout: 2000
    ]
  ]

# Security configurations
config :rehab_tracking,
  phi_encryption_key: {:system, "PHI_ENCRYPTION_KEY"},
  audit_log_enabled: true,
  session_timeout: 3600,
  max_login_attempts: 3,
  login_lockout_duration: 900

# Telemetry and monitoring
config :telemetry_poller, :default, period: 5_000

# CORS configuration for production
config :cors_plug,
  origin: ~r/^https:\/\/(.+\.)?yourdomain\.com$/,
  max_age: 86_400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]