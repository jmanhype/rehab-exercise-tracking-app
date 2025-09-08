# Implementation Plan: Rehab Exercise Tracking Core

**Branch**: `001-rehab-exercise-tracking` | **Date**: 2025-09-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-rehab-exercise-tracking/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → Found: specs/001-rehab-exercise-tracking/spec.md
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context: web (backend API + therapist UI)
   → Set Structure Decision: Option 2 (web application)
3. Evaluate Constitution Check section below
   → Violations documented in Complexity Tracking
   → Justifications provided for multi-project approach
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → All technical choices validated with architectural input
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, CLAUDE.md
6. Re-evaluate Constitution Check section
   → Design aligned with library-first principles
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Task generation approach defined
8. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Event-sourced system for physical therapists to monitor home exercise quality and adherence with minimal workflow overhead. Built on Elixir/OTP with CQRS pattern, immutable event log, and plugin-based architecture for extensibility. Edge-first ML approach ensures privacy while Phoenix API gateway provides stable interface for mobile and web clients.

## Technical Context
**Language/Version**: Elixir 1.16 on BEAM/OTP 27  
**Primary Dependencies**: Phoenix 1.7, Commanded, EventStore, Broadway, Ecto  
**Storage**: PostgreSQL 15 (EventStore + projections), ETS (hot caches), S3/MinIO (media)  
**Testing**: ExUnit with contract tests, Wallaby for E2E  
**Target Platform**: Linux server (Docker/K8s), iOS/Android native apps, Web (Next.js)
**Project Type**: web - Backend API + Therapist UI + Mobile apps  
**Performance Goals**: <200ms p95 API response, 1000 events/sec ingest, <100ms projection lag  
**Constraints**: HIPAA compliance, PHI isolation, event immutability, offline-capable mobile  
**Scale/Scope**: 100 clinics, 10k patients, 100k events/day initial

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: 4 (api, therapist-ui, mobile-ios, mobile-android)
- Using framework directly? Yes (Phoenix, no wrappers)
- Single data model? Yes (events as domain primitive)
- Avoiding patterns? Yes (Repository pattern justified for event sourcing)

**Architecture**:
- EVERY feature as library? Yes (plugins + behaviours)
- Libraries listed:
  - Core.Facade: Public API surface (log_event, get_stream, project, emit_alert)
  - Core.EventLog: Event persistence layer
  - Core.Projectors: Read model builders (Adherence, Quality, WorkQueue)
  - Policy.Nudges: Alert and reminder rules
  - Adapters.*: External integrations (EMR, Notify, Auth, Storage)
  - Plugins.*: Extension points (SensorPlugin, FormScorer, etc.)
- CLI per library: Each exposes mix tasks with standard flags
- Library docs: llms.txt format included in each lib directory

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? Yes
- Git commits show tests before implementation? Yes
- Order: Contract→Integration→E2E→Unit strictly followed? Yes
- Real dependencies used? Yes (PostgreSQL, EventStore)
- Integration tests for: new libraries, contract changes, shared schemas? Yes
- FORBIDDEN: Implementation before test, skipping RED phase

**Observability**:
- Structured logging included? Yes (OpenTelemetry)
- Frontend logs → backend? Yes (unified stream)
- Error context sufficient? Yes (event metadata, trace IDs)

**Versioning**:
- Version number assigned? Yes (0.1.0)
- BUILD increments on every change? Yes
- Breaking changes handled? Yes (event schema versioning)

## Project Structure

### Documentation (this feature)
```
specs/001-rehab-exercise-tracking/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 2: Web application (selected based on Technical Context)
backend/
├── src/
│   ├── core/
│   │   ├── facade.ex
│   │   ├── event_log.ex
│   │   └── projectors/
│   ├── adapters/
│   ├── plugins/
│   └── api/
└── tests/
    ├── contract/
    ├── integration/
    └── unit/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

mobile/
├── ios/
│   └── RehabCore/
└── android/
    └── app/src/
```

**Structure Decision**: Option 2 - Web application with separate mobile apps

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - Commanded/EventStore best practices for healthcare
   - Broadway pipeline configuration for sensor streams
   - FHIR R4 integration patterns
   - On-device ML model deployment (MoveNet/MediaPipe)
   - PHI isolation strategies in event sourcing

2. **Generate and dispatch research agents**:
   ```
   Task: "Research Commanded/EventStore patterns for HIPAA compliance"
   Task: "Find Broadway best practices for high-throughput sensor data"
   Task: "Research FHIR R4 PatientSummary mappings"
   Task: "Investigate MoveNet/MediaPipe edge deployment"
   Task: "Research PHI flags in event metadata patterns"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: Event-sourced with immutable log
   - Rationale: Perfect audit trail, HIPAA compliance
   - Alternatives considered: Traditional CRUD (rejected: audit complexity)

**Output**: research.md with all technical decisions validated

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Event types: exercise_session, rep_observation, feedback, alert, consent
   - Event envelope: event_id, kind, ts, subject_id, exercise_id, body, meta
   - Projections: Adherence, Quality, WorkQueue
   - Validation rules: Quality threshold 0.70, alert SLAs

2. **Generate API contracts** from functional requirements:
   - POST /api/events - Log event
   - GET /api/patients/{id}/stream - Get event stream
   - GET /api/projections/{type} - Query projections
   - POST /api/alerts - Emit alert
   - Output OpenAPI schema to `/contracts/api.yaml`

3. **Generate contract tests** from contracts:
   - test_log_event_contract.exs
   - test_get_stream_contract.exs
   - test_projections_contract.exs
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Patient completes exercise → quality capture test
   - Quality below threshold → alert generation test
   - Therapist reviews data → projection query test

5. **Update CLAUDE.md incrementally**:
   - Add Elixir/Phoenix context
   - Add event sourcing patterns
   - Keep under 150 lines

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, CLAUDE.md

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each event type → model task [P]
- Each API endpoint → contract test task [P]
- Each projector → implementation task
- Each plugin behaviour → interface task [P]
- Mobile edge ML → deployment task

**Ordering Strategy**:
- TDD order: Tests before implementation
- Dependency order: Core → Projectors → Adapters → Plugins
- Mark [P] for parallel execution (independent modules)

**Estimated Output**: 30-35 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 4 projects | Mobile needs native for camera/ML performance | Web-only insufficient for edge ML requirements |
| Repository pattern | Event sourcing requires event store abstraction | Direct DB access breaks event immutability |
| Multiple adapters | Each integration has unique protocol | Single adapter would mix concerns |

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS (with justified exceptions)
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*