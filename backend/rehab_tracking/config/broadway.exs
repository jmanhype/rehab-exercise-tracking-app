import Config

# Broadway Pipeline Configuration
# Optimized for 1000 events/sec throughput

config :rehab_tracking, RehabTracking.BroadwayPipeline,
  # Producer configuration
  producers: [
    count: 2,  # 2 producers for redundancy
    receive_interval: 1000  # 1 second polling interval
  ],
  
  # Processor configuration  
  processors: [
    count: 10,  # 10 processors for parallelism
    max_demand: 50  # Max events per processor
  ],
  
  # Batcher configuration
  batchers: [
    count: 2,  # 2 batchers for aggregation
    batch_size: 100,  # 100 events per batch
    batch_timeout: 1000  # 1000ms timeout
  ]

# Environment-specific producer settings
case config_env() do
  :dev ->
    config :rehab_tracking, :broadway_producer, :dummy
    
  :test ->
    config :rehab_tracking, :broadway_producer, :dummy
    
  :prod ->
    # Use SQS in production
    config :rehab_tracking, :broadway_producer, :sqs
    
    config :rehab_tracking, :sqs,
      queue_url: System.get_env("SQS_QUEUE_URL"),
      region: System.get_env("AWS_REGION", "us-east-1"),
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")
end

# Telemetry configuration
config :rehab_tracking, :telemetry,
  broadway_events: [
    [:rehab_tracking, :broadway, :event, :processed],
    [:rehab_tracking, :broadway, :batch, :processed],
    [:rehab_tracking, :broadway, :event, :unknown]
  ],
  
  policy_events: [
    [:rehab_tracking, :policy, :nudge, :generated],
    [:rehab_tracking, :policy, :alert, :generated],
    [:rehab_tracking, :policy, :feedback, :generated]
  ]

# Performance targets
config :rehab_tracking, :performance_targets,
  target_throughput: 1000,  # events per second
  max_latency: 100,  # milliseconds
  batch_processing_time: 50  # milliseconds per batch