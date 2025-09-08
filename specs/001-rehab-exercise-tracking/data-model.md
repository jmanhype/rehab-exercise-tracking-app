# Data Model: Rehab Exercise Tracking Core

**Feature**: 001-rehab-exercise-tracking  
**Created**: 2025-09-08  
**Status**: Phase 1 Design

## Event Types

### Core Event Schema
All events follow this envelope structure:
```json
{
  "event_id": "evt_<uuid>",
  "kind": "exercise_session|rep_observation|feedback|alert|consent",
  "ts": "2025-09-08T10:30:00Z",
  "subject_id": "patient_<uuid>",
  "exercise_id": "exercise_<uuid>",
  "body": { /* Event-specific payload */ },
  "meta": {
    "phi": true|false,
    "consent_id": "consent_<uuid>",
    "site_id": "clinic_<uuid>",
    "version": 1,
    "correlation_id": "session_<uuid>"
  }
}
```

### 1. Exercise Session Event
Captures complete exercise period with start/end times.
```json
{
  "kind": "exercise_session",
  "body": {
    "session_id": "session_<uuid>",
    "prescribed_exercise_id": "template_<uuid>",
    "start_time": "2025-09-08T10:30:00Z",
    "end_time": "2025-09-08T10:45:00Z",
    "completion_status": "completed|partial|aborted",
    "prescribed_reps": 15,
    "completed_reps": 12,
    "overall_quality": 0.73,
    "device_info": {
      "model": "iPhone 14",
      "app_version": "1.0.3",
      "ml_model_version": "movenet_thunder_v2"
    }
  }
}
```

### 2. Rep Observation Event
Individual repetition data with quality scoring.
```json
{
  "kind": "rep_observation",
  "body": {
    "rep_number": 5,
    "quality_score": 0.85,
    "confidence_rating": 0.92,
    "duration_ms": 3200,
    "form_issues": [
      {
        "type": "knee_alignment",
        "severity": "minor",
        "keypoint_deviation": 0.15
      }
    ],
    "keypoints": [
      {"joint": "left_knee", "x": 0.45, "y": 0.72, "confidence": 0.94}
    ],
    "peak_velocity": 0.8,
    "range_of_motion": 78.5
  }
}
```

### 3. Feedback Event
Therapist guidance linked to sessions or patterns.
```json
{
  "kind": "feedback",
  "body": {
    "feedback_id": "feedback_<uuid>",
    "therapist_id": "therapist_<uuid>",
    "feedback_type": "session|pattern|general",
    "target_session_id": "session_<uuid>",
    "content": "Focus on keeping your knee aligned over your toes",
    "priority": "high|medium|low",
    "delivered_at": "2025-09-08T14:00:00Z",
    "acknowledged_at": null
  }
}
```

### 4. Alert Event
Triage notifications for therapist attention.
```json
{
  "kind": "alert",
  "body": {
    "alert_id": "alert_<uuid>",
    "alert_type": "quality_degradation|missed_sessions|improvement",
    "urgency": "critical|high|medium|low",
    "trigger_criteria": {
      "metric": "quality_7day_avg",
      "threshold": 0.70,
      "actual_value": 0.62,
      "duration_days": 7
    },
    "context": {
      "recent_sessions": 5,
      "missed_sessions": 2,
      "quality_trend": "declining"
    },
    "sla_deadline": "2025-09-09T10:00:00Z",
    "assigned_to": "therapist_<uuid>",
    "resolution_status": "pending|acknowledged|resolved"
  }
}
```

### 5. Consent Event
Patient authorization for data collection.
```json
{
  "kind": "consent",
  "body": {
    "consent_id": "consent_<uuid>",
    "consent_type": "data_collection|data_retention|ml_training",
    "granted": true,
    "scope": {
      "exercises": ["all"],
      "data_types": ["quality", "adherence", "video_pose"],
      "retention_days": 365,
      "allow_research": false
    },
    "effective_from": "2025-09-08T00:00:00Z",
    "expires_at": "2026-09-08T00:00:00Z",
    "signature_method": "electronic",
    "revocable": true
  }
}
```

## Projections (Read Models)

### 1. Adherence Projection
```elixir
defmodule Core.Projections.Adherence do
  defstruct [
    :patient_id,
    :week_start,
    :prescribed_sessions,
    :completed_sessions,
    :partial_sessions,
    :missed_sessions,
    :adherence_percentage,
    :rolling_7day_avg,
    :rolling_28day_avg,
    :last_session_date,
    :consecutive_missed_days,
    :updated_at
  ]
end
```

### 2. Quality Projection
```elixir
defmodule Core.Projections.Quality do
  defstruct [
    :patient_id,
    :exercise_id,
    :observation_window,
    :total_reps,
    :quality_scores,
    :average_quality,
    :critical_issues_count,
    :critical_issues_percentage,
    :quality_trend,  # :improving | :stable | :declining
    :percentile_25,
    :percentile_50,
    :percentile_75,
    :form_issue_frequency,
    :updated_at
  ]
end
```

### 3. WorkQueue Projection
```elixir
defmodule Core.Projections.WorkQueue do
  defstruct [
    :therapist_id,
    :queue_items,  # List of prioritized tasks
    :critical_count,
    :high_count,
    :medium_count,
    :low_count,
    :avg_response_time_hours,
    :sla_at_risk,  # Items approaching deadline
    :updated_at
  ]
  
  defmodule QueueItem do
    defstruct [
      :item_id,
      :patient_id,
      :patient_name,
      :item_type,  # :alert | :review | :feedback_needed
      :urgency,
      :description,
      :created_at,
      :sla_deadline,
      :context_data
    ]
  end
end
```

### 4. PatientSummary Projection
```elixir
defmodule Core.Projections.PatientSummary do
  defstruct [
    :patient_id,
    :enrollment_date,
    :prescribed_exercises,
    :current_adherence,
    :current_quality,
    :trend_14day,
    :trend_28day,
    :total_sessions,
    :total_reps,
    :last_session,
    :next_scheduled,
    :active_alerts,
    :pending_feedback,
    :therapist_notes,
    :risk_score,  # 0.0 - 1.0
    :updated_at
  ]
end
```

## Validation Rules

### Quality Thresholds
- **Critical Issue**: Quality score < 0.50 for individual rep
- **Alert Trigger**: 7-day average < 0.70 OR 30% reps with critical issues
- **Improvement Recognition**: 7-day average > 0.85 for 14+ days

### Adherence Thresholds
- **Missed Session Alert**: 2 consecutive days missed
- **Weekly Alert**: < 50% completion over 7 days
- **Excellence Recognition**: > 90% adherence for 28 days

### SLA Requirements
- **Critical Alerts**: Response within 4 hours
- **High Priority**: Response within 24 hours
- **Medium Priority**: Response within 48 hours
- **Low Priority**: Response within 7 days

## State Transitions

### Session States
```
scheduled → in_progress → completed
         ↓            ↓
      missed      partial/aborted
```

### Alert States
```
created → pending → acknowledged → in_review → resolved
                 ↓              ↓
              escalated     dismissed
```

### Consent States
```
requested → granted → active → expiring → renewed
         ↓                   ↓
      denied             revoked
```

## Relationships

### Entity Relationships
- **Patient** ← has many → **Sessions**
- **Session** ← contains many → **RepObservations**
- **Patient** ← has many → **Consents**
- **Patient** ← triggers → **Alerts**
- **Therapist** ← assigned to → **Alerts**
- **Therapist** ← provides → **Feedback**
- **Exercise** ← performed in → **Sessions**
- **Session** ← receives → **Feedback**

### Event Stream Relationships
- Events are immutable and append-only
- Each patient has their own event stream
- Projections are rebuilt from event streams
- Snapshots created every 1000 events for performance

## Data Retention Policies

### Event Retention
- **PHI Events**: As per consent agreement (default 365 days)
- **Non-PHI Events**: Indefinite (anonymized after consent expiry)
- **Alert Events**: 90 days after resolution
- **System Events**: 30 days

### Projection Retention
- **Active Patients**: Real-time updates
- **Inactive > 30 days**: Archived to cold storage
- **Inactive > 365 days**: Anonymized aggregates only

## Privacy & Compliance

### PHI Handling
- PHI flag at event envelope level
- Encryption at rest (AES-256-GCM)
- Encryption in transit (TLS 1.3)
- Audit trail for all PHI access
- Consent required for all PHI operations

### HIPAA Compliance
- Minimum necessary principle enforced
- Role-based access control (RBAC)
- Automatic de-identification after retention period
- Break-glass access with audit logging
- Data portability via FHIR export

---
*Generated from specifications in spec.md and research.md*