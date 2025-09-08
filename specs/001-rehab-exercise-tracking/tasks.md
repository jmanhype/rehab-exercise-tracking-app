# Tasks: Rehab Exercise Tracking Core

**Input**: Design documents from `/specs/001-rehab-exercise-tracking/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Extract: Elixir 1.16, Phoenix 1.7, Commanded, EventStore, Broadway
   → Structure: backend/, frontend/, mobile/ios, mobile/android
2. Load optional design documents:
   → data-model.md: 5 event types, 4 projections
   → contracts/api.yaml: 6 endpoints
   → research.md: Broadway config, PHI strategy
3. Generate tasks by category:
   → Setup: Elixir project, EventStore, Broadway
   → Tests: 3 contract test files (already created)
   → Core: Event models, projections, facades
   → Integration: Broadway pipeline, EMR adapters
   → Polish: Performance tests, documentation
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T043)
6. Validate task completeness
7. Return: SUCCESS (43 tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Backend**: `backend/src/`, `backend/tests/`
- **Frontend**: `frontend/src/`, `frontend/tests/`
- **Mobile**: `mobile/ios/`, `mobile/android/`

## Phase 3.1: Setup & Infrastructure

- [ ] T001 Create backend project structure with directories: backend/{src,tests,config,priv}
- [ ] T002 Initialize Elixir project with mix new rehab_tracking --sup
- [ ] T003 Add dependencies to mix.exs: phoenix, commanded, eventstore, broadway, ecto
- [ ] T004 [P] Configure EventStore in config/config.exs with PostgreSQL adapter
- [ ] T005 [P] Configure Broadway pipeline in config/config.exs per research.md specs
- [ ] T006 [P] Setup test environment in config/test.exs with sandbox mode
- [ ] T007 Initialize database with mix ecto.create && mix event_store.init

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests (Already Created - Verify They Fail)
- [ ] T008 Verify backend/tests/contract/test_log_event_contract.exs fails with no implementation
- [ ] T009 Verify backend/tests/contract/test_get_stream_contract.exs fails with no implementation
- [ ] T010 Verify backend/tests/contract/test_projections_contract.exs fails with no implementation

### Integration Tests (New)
- [ ] T011 [P] Integration test: Patient exercise flow in backend/tests/integration/test_exercise_flow.exs
- [ ] T012 [P] Integration test: Quality alert generation in backend/tests/integration/test_quality_alerts.exs
- [ ] T013 [P] Integration test: Missed session alerts in backend/tests/integration/test_missed_sessions.exs
- [ ] T014 [P] Integration test: Therapist feedback workflow in backend/tests/integration/test_feedback_flow.exs
- [ ] T015 [P] Integration test: PHI consent enforcement in backend/tests/integration/test_phi_consent.exs

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Event Models
- [ ] T016 [P] ExerciseSession event in backend/src/core/events/exercise_session.ex
- [ ] T017 [P] RepObservation event in backend/src/core/events/rep_observation.ex
- [ ] T018 [P] Feedback event in backend/src/core/events/feedback.ex
- [ ] T019 [P] Alert event in backend/src/core/events/alert.ex
- [ ] T020 [P] Consent event in backend/src/core/events/consent.ex

### Projections
- [ ] T021 [P] Adherence projection in backend/src/core/projectors/adherence.ex
- [ ] T022 [P] Quality projection in backend/src/core/projectors/quality.ex
- [ ] T023 [P] WorkQueue projection in backend/src/core/projectors/work_queue.ex
- [ ] T024 [P] PatientSummary projection in backend/src/core/projectors/patient_summary.ex

### Core Services
- [ ] T025 EventLog service in backend/src/core/event_log.ex with Commanded integration
- [ ] T026 Facade module in backend/src/core/facade.ex with public API (log_event, get_stream, project)
- [ ] T027 [P] PHI encryption middleware in backend/src/core/middleware/phi_encryption.ex

### API Endpoints
- [ ] T028 POST /api/v1/events endpoint in backend/src/api/controllers/event_controller.ex
- [ ] T029 GET /api/v1/patients/:id/stream in backend/src/api/controllers/stream_controller.ex
- [ ] T030 GET /api/v1/projections/adherence in backend/src/api/controllers/projection_controller.ex
- [ ] T031 GET /api/v1/projections/quality in backend/src/api/controllers/projection_controller.ex
- [ ] T032 GET /api/v1/projections/work-queue in backend/src/api/controllers/projection_controller.ex
- [ ] T033 POST /api/v1/alerts in backend/src/api/controllers/alert_controller.ex
- [ ] T034 POST /api/v1/feedback in backend/src/api/controllers/feedback_controller.ex

## Phase 3.4: Integration & Adapters

### Broadway Pipeline
- [ ] T035 SensorDataProducer in backend/src/adapters/broadway/sensor_producer.ex
- [ ] T036 EventProcessor with batching in backend/src/adapters/broadway/event_processor.ex
- [ ] T037 Configure Broadway topology with 2 producers, 10 processors per research.md

### Plugin Behaviours
- [ ] T038 [P] FormScorer behaviour in backend/src/plugins/behaviours/form_scorer.ex
- [ ] T039 [P] SensorPlugin behaviour in backend/src/plugins/behaviours/sensor_plugin.ex
- [ ] T040 [P] EMRAdapter behaviour in backend/src/plugins/behaviours/emr_adapter.ex

### External Adapters
- [ ] T041 [P] FHIR adapter in backend/src/adapters/emr/fhir_adapter.ex with PatientSummary mapping
- [ ] T042 [P] Notification adapter in backend/src/adapters/notify/email_adapter.ex
- [ ] T043 [P] Auth adapter in backend/src/adapters/auth/jwt_adapter.ex with role-based access

## Phase 3.5: Polish & Performance

- [ ] T044 [P] Performance test: 1000 events/sec in backend/tests/performance/test_event_throughput.exs
- [ ] T045 [P] Performance test: <100ms projection lag in backend/tests/performance/test_projection_lag.exs
- [ ] T046 [P] Unit tests for event validation in backend/tests/unit/test_event_validation.exs
- [ ] T047 [P] Unit tests for PHI encryption in backend/tests/unit/test_phi_encryption.exs
- [ ] T048 [P] Generate API documentation with ExDoc
- [ ] T049 Run quickstart.md scenarios to validate end-to-end flow
- [ ] T050 Create deployment Docker configuration in backend/Dockerfile

## Dependencies

### Critical Path
- Setup (T001-T007) → Tests (T008-T015) → Implementation (T016-T043) → Polish (T044-T050)
- T025 (EventLog) blocks T026 (Facade)
- T026 (Facade) blocks all API endpoints (T028-T034)
- Event models (T016-T020) before projections (T021-T024)
- Broadway setup (T035-T037) can run parallel to core implementation

### Parallel Execution Groups
1. **Event Models** (T016-T020): All can run in parallel
2. **Projections** (T021-T024): All can run in parallel
3. **Behaviours** (T038-T040): All can run in parallel
4. **Adapters** (T041-T043): All can run in parallel
5. **Performance Tests** (T044-T047): All can run in parallel

## Parallel Execution Example

```bash
# Phase 3.2: Launch integration tests together
Task("Integration test exercise flow", "Create test in backend/tests/integration/test_exercise_flow.exs", "tester")
Task("Integration test quality alerts", "Create test in backend/tests/integration/test_quality_alerts.exs", "tester")
Task("Integration test missed sessions", "Create test in backend/tests/integration/test_missed_sessions.exs", "tester")
Task("Integration test feedback", "Create test in backend/tests/integration/test_feedback_flow.exs", "tester")

# Phase 3.3: Launch event models together
Task("Create ExerciseSession event", "Implement in backend/src/core/events/exercise_session.ex", "coder")
Task("Create RepObservation event", "Implement in backend/src/core/events/rep_observation.ex", "coder")
Task("Create Feedback event", "Implement in backend/src/core/events/feedback.ex", "coder")
Task("Create Alert event", "Implement in backend/src/core/events/alert.ex", "coder")
Task("Create Consent event", "Implement in backend/src/core/events/consent.ex", "coder")

# Phase 3.3: Launch projections together
Task("Create Adherence projection", "Implement in backend/src/core/projectors/adherence.ex", "coder")
Task("Create Quality projection", "Implement in backend/src/core/projectors/quality.ex", "coder")
Task("Create WorkQueue projection", "Implement in backend/src/core/projectors/work_queue.ex", "coder")
Task("Create PatientSummary projection", "Implement in backend/src/core/projectors/patient_summary.ex", "coder")
```

## Validation Checklist
*GATE: Checked before execution*

- [x] All contracts have corresponding tests (T008-T010)
- [x] All 5 event types have model tasks (T016-T020)
- [x] All 4 projections have implementation tasks (T021-T024)
- [x] All 6 API endpoints have implementation tasks (T028-T034)
- [x] All tests come before implementation (Phase 3.2 before 3.3)
- [x] Parallel tasks truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task

## Notes
- Broadway configuration: 2 producers, 10 processors, batch size 100
- PHI encryption at event envelope level, not in body
- Event store with one stream per patient
- Snapshot projections every 1000 events
- All performance targets from research.md included

---
*Generated from design documents in /specs/001-rehab-exercise-tracking/*
*Total tasks: 50 (15 parallel groups)*