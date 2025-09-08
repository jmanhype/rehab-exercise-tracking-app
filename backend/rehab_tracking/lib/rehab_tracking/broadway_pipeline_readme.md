# Broadway Pipeline Configuration

## Overview

The Broadway pipeline in `RehabTracking.BroadwayPipeline` is configured for high-throughput exercise event processing with the following specifications:

## Configuration

- **2 Producers** - For redundancy and fault tolerance
- **10 Processors** - For parallel event processing 
- **2 Batchers** - For batch aggregation
- **Batch Size**: 100 events per batch
- **Batch Timeout**: 1000ms (1 second)
- **Target Throughput**: 1000 events/second

## Event Types Supported

1. **exercise_session** - Complete exercise session data
2. **rep_observation** - Individual repetition quality data
3. **feedback** - User feedback and responses
4. **alert** - System-generated alerts
5. **consent** - Patient consent updates

## Processing Pipeline

```
Events → [Producer 1, Producer 2] → [10 Processors] → [Batcher 1, Batcher 2] → Projections
```

### Processors
- Validate event structure
- Route events by type
- Handle individual event processing
- Update projections in real-time

### Batchers
- Aggregate events for efficient bulk operations
- Process batches of 100 events or 1-second timeout
- Optimize database writes and projections

## Projections Updated

- **AdherenceProjector** - Patient exercise adherence rates
- **QualityProjector** - Exercise form quality scores
- **WorkQueueProjector** - Therapist work queue items

## Policy Engine

The `RehabTracking.Policy.Nudges` module evaluates events for:

- Adherence-based nudges
- Quality-based alerts
- Real-time form feedback
- Emergency intervention triggers

## API Endpoints

- `POST /api/v1/events` - Single event ingestion
- `POST /api/v1/events/batch` - Batch event ingestion
- `GET /api/v1/events/broadway/status` - Pipeline health check

## Environment Configuration

### Development/Test
- Uses `Broadway.DummyProducer` for testing
- Events processed in-memory

### Production
- Configure `SQS_QUEUE_URL` for AWS SQS producer
- Or use RabbitMQ/Kafka producers
- Set appropriate AWS credentials

## Monitoring

The pipeline emits telemetry events:

- `[:rehab_tracking, :broadway, :event, :processed]`
- `[:rehab_tracking, :broadway, :batch, :processed]`
- `[:rehab_tracking, :policy, :nudge, :generated]`
- `[:rehab_tracking, :policy, :alert, :generated]`

## Testing

Run tests with:
```bash
mix test test/rehab_tracking/broadway_pipeline_test.exs
```

## Health Monitoring

Check pipeline health:
```bash
curl http://localhost:4000/api/v1/events/broadway/status
```

Response includes:
- Producer status
- Processing metrics
- Configuration details
- Target throughput information