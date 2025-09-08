# Claude Code Configuration - Rehab Exercise Tracking Core

## Project Overview

Event-sourced rehabilitation exercise tracking system built with Elixir/OTP for physical therapists to monitor patient home exercise quality and adherence. Uses CQRS pattern with immutable event log and Broadway for stream processing.

## Tech Stack

- **Language**: Elixir 1.16 on BEAM/OTP 27
- **Framework**: Phoenix 1.7
- **Event Store**: Commanded + EventStore (PostgreSQL 15)
- **Stream Processing**: Broadway with SQS/RabbitMQ adapters
- **Database**: PostgreSQL (events + projections), ETS (hot cache)
- **Testing**: ExUnit, Wallaby (E2E)
- **Mobile**: iOS/Android with edge ML (MoveNet/MediaPipe)

## Architecture Patterns

### Event Sourcing
- Immutable append-only event log
- One stream per patient for isolation
- Events: exercise_session, rep_observation, feedback, alert, consent
- PHI flags at envelope level, not in body
- Snapshot every 1000 events

### CQRS with Projections
- Write: Events through Commanded
- Read: Projections (Adherence, Quality, WorkQueue)
- Eventual consistency with <100ms lag
- Projection rebuild from event stream

### Broadway Pipeline Config
```elixir
# Optimal for 1000 events/sec
producers: 2      # Redundancy
processors: 10    # Parallelism  
batchers: 2       # Aggregation
batch_size: 100
batch_timeout: 1s
```

## Core Modules

### Event Pipeline
- `Core.Facade` - Public API (log_event, get_stream, project)
- `Core.EventLog` - Event persistence
- `Core.Projectors.*` - Read model builders
- `Policy.Nudges` - Alert rules

### Adapters (Plugins)
- `Adapters.EMR` - FHIR R4 integration
- `Adapters.Notify` - Alert delivery
- `Adapters.Auth` - Authentication
- `Adapters.Storage` - S3/MinIO

### Behaviours
```elixir
@behaviour FormScorer    # Exercise quality scoring
@behaviour SensorPlugin   # Device data ingestion
@behaviour EMRAdapter    # Healthcare system integration
```

## Testing Strategy

### Test Order (TDD)
1. Contract tests - API schemas
2. Integration tests - Event flows
3. E2E tests - User scenarios
4. Unit tests - Business logic

### Key Test Commands
```bash
mix test test/contract     # API contracts
mix test test/integration  # Event flows
mix test --cover          # With coverage
mix rehab.seed            # Generate test data
```

## Performance Targets

- API Response: <200ms p95
- Event Ingest: 1000/sec sustained
- Projection Lag: <100ms
- Mobile Inference: <50ms

## Security & Compliance

### PHI Handling
- Event-level PHI flags
- AES-256-GCM encryption
- Consent tracking per event
- Audit trail immutable
- HIPAA compliant

### Access Control
```elixir
# Role-based with break-glass
@roles [:patient, :therapist, :admin, :emergency]
```

## Development Workflow

### Quick Commands
```bash
iex -S mix phx.server     # Start with REPL
mix rehab.doctor          # Diagnose issues
mix event_store.init      # Setup event store
:observer.start()         # Monitor Broadway
```

### Event Examples
```elixir
# Log exercise session
Core.Facade.log_event(%{
  kind: "exercise_session",
  subject_id: "patient_123",
  body: %{...},
  meta: %{phi: true, consent_id: "..."}
})

# Query projection
Core.Facade.project(:adherence, 
  patient_id: "patient_123",
  window: :week
)
```

## Deployment Topology

### Phase 1 (Pilot)
- Single PostgreSQL
- 2 API servers
- 50GB storage

### Phase 2 (100 clinics)
- Read replicas
- 4-6 API servers
- Event archival

### Phase 3 (1000 clinics)
- Multi-region
- Event sharding
- ClickHouse analytics

## Recent Changes

1. **Broadway Configuration** - Optimized for 1000 events/sec with batch size 100
2. **PHI Isolation** - Moved PHI flags to event envelope metadata
3. **FHIR Mapping** - Added PatientSummary to Observation adapter

## Known Issues

- Broadway backpressure tuning for sensor bursts
- Projection rebuild performance >1M events
- Mobile ML model drift detection

---
*Updated: 2025-09-08 | Feature: 001-rehab-exercise-tracking*