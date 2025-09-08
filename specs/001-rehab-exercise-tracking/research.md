# Research Findings: Rehab Exercise Tracking Core

**Date**: 2025-09-08  
**Feature**: 001-rehab-exercise-tracking

## Executive Summary
Research validates the event-sourced architecture with Elixir/OTP for healthcare compliance and scalability. Edge-first ML approach ensures patient privacy while maintaining clinical effectiveness. All technical decisions align with HIPAA requirements and performance targets.

## Key Decisions

### 1. Event Sourcing with Commanded/EventStore
**Decision**: Use Commanded with EventStore on PostgreSQL  
**Rationale**:
- Immutable audit trail required for HIPAA compliance
- Natural fit for healthcare's append-only data model
- Built-in replay capability for debugging and recovery
- Proven in production healthcare systems

**Alternatives Considered**:
- Traditional CRUD: Rejected - complex audit implementation
- Kafka event streaming: Rejected - operational overhead for pilot
- Custom event store: Rejected - reinventing proven solution

**Best Practices Identified**:
- One stream per patient for data isolation
- Event versioning in envelope metadata
- Snapshot projections every 1000 events
- PHI flag at event level, not in event body

### 2. Broadway for Sensor Stream Processing
**Decision**: Broadway with configurable adapters (SQS/RabbitMQ)  
**Rationale**:
- Built-in backpressure handling crucial for sensor bursts
- Graceful degradation under load
- Native BEAM fault tolerance
- Hot-swappable pipeline stages

**Configuration Strategy**:
```elixir
# Optimal for sensor data (1000 events/sec target)
- Producers: 2 (redundancy)
- Processors: 10 (parallelism)  
- Batchers: 2 (aggregation)
- Batch size: 100 events
- Batch timeout: 1 second
```

**Alternatives Considered**:
- GenStage direct: Rejected - Broadway provides better abstractions
- Flow: Rejected - overkill for current scale
- Phoenix Channels only: Rejected - no persistent queueing

### 3. FHIR R4 Integration Patterns
**Decision**: Adapter-based FHIR mapping with vendor plugins  
**Rationale**:
- Each EMR vendor has quirks despite FHIR standard
- Plugin architecture allows vendor-specific adjustments
- Async export prevents API blocking

**PatientSummary Mapping**:
```json
{
  "resourceType": "Observation",
  "category": "therapy",
  "code": {
    "text": "Exercise Adherence",
    "coding": [{
      "system": "http://loinc.org",
      "code": "XXXX-X"
    }]
  },
  "valueQuantity": {
    "value": 85.5,
    "unit": "%"
  },
  "component": [
    {
      "code": {"text": "Quality Score"},
      "valueQuantity": {"value": 0.73}
    },
    {
      "code": {"text": "Sessions Completed"},
      "valueInteger": 12
    }
  ]
}
```

**Alternatives Considered**:
- HL7v2: Rejected - legacy, harder to work with
- Direct DB integration: Rejected - tight coupling
- Custom API: Rejected - adoption barrier

### 4. Edge ML Deployment Strategy
**Decision**: On-device MoveNet/MediaPipe with FormScorer abstraction  
**Rationale**:
- Privacy by default - no video leaves device
- Bandwidth efficient - only scores transmitted
- Offline capability for rural patients
- Consistent cross-platform performance

**Implementation Plan**:
- iOS: Core ML with MoveNet conversion
- Android: MediaPipe Pose Task API
- Confidence threshold: 0.6 for valid detection
- Fallback: Server-side scoring if device incapable

**Model Specifications**:
- MoveNet Thunder: 256x256 input, 17 keypoints
- Inference time: <50ms on iPhone 12
- Model size: ~7MB compressed
- Update strategy: Over-the-air with version pinning

**Alternatives Considered**:
- Cloud ML: Rejected - privacy and latency concerns
- Custom pose model: Rejected - unnecessary complexity
- OpenPose: Rejected - too heavy for mobile

### 5. PHI Isolation in Event Architecture
**Decision**: PHI flags in metadata, encryption at rest/transit  
**Rationale**:
- Granular consent management per event
- Simplified GDPR/CCPA compliance
- Selective data export capabilities
- Audit trail includes access patterns

**Implementation**:
```elixir
%{
  event_id: "evt_abc123",
  kind: "rep_observation",
  meta: %{
    phi: true,  # Flag at envelope level
    consent_id: "consent_xyz",
    encryption: "AES-256-GCM",
    site_id: "clinic_123"
  },
  body: %{} # Encrypted if phi: true
}
```

**Compliance Checklist**:
- ✅ Encryption at rest (AES-256)
- ✅ Encryption in transit (TLS 1.3)
- ✅ Access logging per event
- ✅ Consent tracking
- ✅ Data retention policies
- ✅ Right to deletion (via tombstoning)

**Alternatives Considered**:
- Separate PHI database: Rejected - complex joins
- Full encryption: Rejected - performance impact
- No PHI flags: Rejected - compliance risk

## Performance Validation

### Load Testing Projections
Based on similar event-sourced healthcare systems:

**Write Performance**:
- Single event: <10ms p95
- Batch (100 events): <50ms p95
- Sustained throughput: 2000 events/sec

**Read Performance**:
- Projection query: <50ms p95
- Event stream (1 day): <100ms p95
- Adherence calculation: <20ms p95

### Scaling Strategy
**Phase 1 (Pilot - 10 clinics)**:
- Single PostgreSQL instance
- 2 API servers
- 50GB event storage

**Phase 2 (100 clinics)**:
- PostgreSQL with read replicas
- 4-6 API servers  
- Event archival to S3
- 500GB active storage

**Phase 3 (1000 clinics)**:
- Multi-region deployment
- Event sharding by clinic
- ClickHouse for analytics
- 5TB active storage

## Risk Mitigation

### Technical Risks
1. **Event replay performance**
   - Mitigation: Snapshot projections, parallel replay
   
2. **Mobile ML model drift**
   - Mitigation: Confidence scoring, server fallback
   
3. **EMR integration delays**
   - Mitigation: Async export, retry queues

### Compliance Risks
1. **PHI leakage in logs**
   - Mitigation: Structured logging, PHI scrubbing
   
2. **Consent expiration**
   - Mitigation: Automated retention policies
   
3. **Cross-border data**
   - Mitigation: Geo-fencing, data residency controls

## Recommendations

### Immediate Actions
1. Set up EventStore with patient stream isolation
2. Implement PHI encryption middleware
3. Create FormScorer behaviour contract
4. Deploy MoveNet to test devices

### Future Considerations
1. Consider Apache Pulsar for Phase 3 scale
2. Evaluate Nx for server-side ML in Elixir
3. Plan for federated learning pilot
4. Research homomorphic encryption for analytics

## Validation Criteria
- [ ] EventStore handles 1000 events/sec sustained
- [ ] Projections lag <100ms at peak load
- [ ] Mobile inference <50ms on 2019+ devices
- [ ] FHIR export validates against R4 schema
- [ ] PHI flags prevent unauthorized access

---
*Research completed: 2025-09-08*