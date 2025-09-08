# Quickstart: Rehab Exercise Tracking Core

**Feature**: 001-rehab-exercise-tracking  
**Version**: 0.1.0  
**Prerequisites**: Elixir 1.16+, PostgreSQL 15+, Docker (optional)

## 🚀 30-Second Setup

```bash
# Clone and setup
git clone <repository>
cd rehab-exercise-tracking
git checkout 001-rehab-exercise-tracking

# Install dependencies
mix deps.get
mix compile

# Setup database
mix ecto.create
mix ecto.migrate
mix event_store.init

# Run tests to verify setup
mix test

# Start server
iex -S mix phx.server
```

Server runs at: http://localhost:4000

## 🧪 Test Scenarios

### Scenario 1: Patient Completes Exercise Session

```bash
# 1. Log exercise session start
curl -X POST http://localhost:4000/api/v1/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "kind": "exercise_session",
    "subject_id": "patient_001",
    "exercise_id": "knee_flexion",
    "body": {
      "session_id": "session_001",
      "prescribed_exercise_id": "template_knee_01",
      "start_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
      "prescribed_reps": 15,
      "device_info": {
        "model": "iPhone 14",
        "app_version": "1.0.3"
      }
    },
    "meta": {
      "phi": true,
      "consent_id": "consent_001",
      "site_id": "clinic_main"
    }
  }'

# 2. Log individual rep observations
for i in {1..12}; do
  quality=$(echo "scale=2; 0.60 + $RANDOM/32768*0.35" | bc)
  curl -X POST http://localhost:4000/api/v1/events \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "kind": "rep_observation",
      "subject_id": "patient_001",
      "exercise_id": "knee_flexion",
      "body": {
        "rep_number": '$i',
        "quality_score": '$quality',
        "confidence_rating": 0.92,
        "duration_ms": 3200
      },
      "meta": {
        "phi": true,
        "consent_id": "consent_001",
        "correlation_id": "session_001"
      }
    }'
done

# 3. Complete session
curl -X POST http://localhost:4000/api/v1/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "kind": "exercise_session",
    "subject_id": "patient_001",
    "exercise_id": "knee_flexion",
    "body": {
      "session_id": "session_001",
      "end_time": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
      "completion_status": "completed",
      "completed_reps": 12,
      "overall_quality": 0.73
    }
  }'

# 4. Verify adherence projection
curl -X GET "http://localhost:4000/api/v1/projections/adherence?patient_id=patient_001" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Result**: 
- Session logged with 12/15 reps (80% completion)
- Quality score average ~0.73
- Adherence projection shows session counted

### Scenario 2: Quality Alert Generation

```bash
# 1. Simulate poor quality exercises over 7 days
for day in {0..6}; do
  for session in {1..2}; do
    curl -X POST http://localhost:4000/api/v1/events \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "kind": "exercise_session",
        "subject_id": "patient_002",
        "body": {
          "session_id": "session_'$day'_'$session'",
          "overall_quality": 0.65,
          "completed_reps": 10,
          "prescribed_reps": 15
        }
      }'
  done
done

# 2. Check quality projection
curl -X GET "http://localhost:4000/api/v1/projections/quality?patient_id=patient_002&window=7d" \
  -H "Authorization: Bearer $TOKEN"

# 3. Verify alert was generated
curl -X GET "http://localhost:4000/api/v1/projections/work-queue?therapist_id=therapist_001" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Result**:
- Quality average below 0.70 threshold
- Alert created with "quality_degradation" type
- Alert appears in therapist work queue as "high" priority

### Scenario 3: Missed Sessions Alert

```bash
# 1. Log last session 3 days ago
curl -X POST http://localhost:4000/api/v1/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "kind": "exercise_session",
    "subject_id": "patient_003",
    "body": {
      "session_id": "last_session",
      "end_time": "'$(date -u -d "3 days ago" +%Y-%m-%dT%H:%M:%SZ)'",
      "completion_status": "completed"
    }
  }'

# 2. Run alert processor (normally automatic)
mix rehab.process_alerts

# 3. Check for missed session alert
curl -X GET "http://localhost:4000/api/v1/alerts?patient_id=patient_003&alert_type=missed_sessions" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Result**:
- Alert generated for 2+ consecutive missed days
- Alert urgency set to "high"
- SLA deadline set to 24 hours

### Scenario 4: Therapist Reviews and Provides Feedback

```bash
# 1. Get patient event stream
curl -X GET "http://localhost:4000/api/v1/patients/patient_001/stream?limit=20" \
  -H "Authorization: Bearer $THERAPIST_TOKEN"

# 2. Review quality projection
curl -X GET "http://localhost:4000/api/v1/projections/quality?patient_id=patient_001&window=14d" \
  -H "Authorization: Bearer $THERAPIST_TOKEN"

# 3. Submit targeted feedback
curl -X POST http://localhost:4000/api/v1/feedback \
  -H "Authorization: Bearer $THERAPIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "patient_id": "patient_001",
    "therapist_id": "therapist_001",
    "feedback_type": "pattern",
    "content": "Great progress! Focus on keeping your knee aligned during the downward phase.",
    "priority": "medium"
  }'

# 4. Acknowledge alert
curl -X PATCH "http://localhost:4000/api/v1/alerts/alert_001" \
  -H "Authorization: Bearer $THERAPIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "resolved",
    "resolution_notes": "Provided guidance on form correction"
  }'
```

**Expected Result**:
- Patient stream shows all events
- Quality projection shows trends
- Feedback logged and linked to patient
- Alert marked as resolved

## 🔧 Development Tools

### Event Store Admin UI
```bash
# Access EventStore projections and streams
open http://localhost:2113
# Default credentials: admin/changeit
```

### Generate Test Data
```bash
mix rehab.seed --patients 10 --days 30
```

### Run Specific Test Suites
```bash
# Contract tests only
mix test test/contract

# Integration tests
mix test test/integration

# With coverage
mix test --cover
```

### Monitor Broadway Pipeline
```bash
# In IEx console
:observer.start()
# Navigate to Applications > rehab_tracking > Supervision Tree
```

## 📊 Performance Verification

### Load Test (1000 events/sec)
```bash
# Install k6
brew install k6

# Run load test
k6 run scripts/load_test.js --vus 10 --duration 30s
```

Expected metrics:
- p95 response time: < 200ms
- Projection lag: < 100ms
- Error rate: < 0.1%

### Verify Projections Performance
```elixir
# In IEx console
alias RehabTracking.Projections

# Time adherence calculation
:timer.tc(fn -> 
  Projections.Adherence.calculate("patient_001", :week) 
end)
# Should be < 20ms

# Time quality aggregation
:timer.tc(fn -> 
  Projections.Quality.aggregate("patient_001", days: 14) 
end)
# Should be < 50ms
```

## 🚨 Troubleshooting

### Events Not Processing
```bash
# Check Broadway pipeline status
mix rehab.pipeline.status

# Restart pipeline
mix rehab.pipeline.restart
```

### Projections Out of Sync
```bash
# Rebuild specific projection
mix rehab.projections.rebuild Adherence

# Rebuild all projections
mix rehab.projections.rebuild --all
```

### Database Connection Issues
```bash
# Verify PostgreSQL is running
pg_isready -h localhost -p 5432

# Check connection pool
mix rehab.db.status
```

## 📱 Mobile App Testing

### iOS Simulator
```bash
cd mobile/ios
pod install
npm run ios
```

### Android Emulator
```bash
cd mobile/android
./gradlew assembleDebug
npm run android
```

### Edge ML Model Testing
```javascript
// In mobile app console
MLModel.test({
  exercise: 'knee_flexion',
  video: 'test_video.mp4'
}).then(result => {
  console.log('Quality scores:', result.scores);
  console.log('Inference time:', result.inference_ms);
});
```

## 🔐 Security & Compliance

### Verify PHI Protection
```bash
# Attempt to access PHI without consent
curl -X GET "http://localhost:4000/api/v1/patients/patient_noconsent/stream" \
  -H "Authorization: Bearer $TOKEN"
# Expected: 403 Forbidden

# Verify audit logging
tail -f log/audit.log | grep PHI_ACCESS
```

### Test FHIR Export
```bash
# Export patient summary in FHIR format
curl -X GET "http://localhost:4000/api/v1/export/fhir/patient_001" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/fhir+json"
```

## 📈 Next Steps

1. **Configure EMR Integration**:
   ```elixir
   config :rehab_tracking, :emr_adapter,
     type: :epic,
     endpoint: "https://emr.hospital.example/api",
     credentials: {:system, "EMR_API_KEY"}
   ```

2. **Enable Real-time Notifications**:
   ```bash
   mix rehab.notifications.enable --channel websocket
   ```

3. **Deploy to Staging**:
   ```bash
   mix docker.build
   docker-compose up -d
   ```

---

**Support**: For issues, check `/docs/troubleshooting.md` or run `mix rehab.doctor`