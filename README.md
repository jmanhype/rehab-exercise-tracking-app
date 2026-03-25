# rehab-exercise-tracking-app

Event-sourced rehabilitation exercise tracking system. Elixir/Phoenix backend, Next.js therapist dashboard, React Native patient app.

## Status

Prototype. The Elixir backend has models, controllers, and event sourcing wiring in place. The Next.js frontend and React Native mobile app have basic screens. No releases, no deployment history.

| Component | State |
|---|---|
| Backend (Phoenix + Commanded) | Event sourcing wired; Broadway pipeline defined |
| Frontend (Next.js) | Dashboard, patient list, patient detail pages |
| Mobile (React Native + Expo) | 4 screens: login, exercise list, session, progress |
| Tests | 23 test files across backend/frontend/mobile |
| CI | No workflow files in repo |
| Docker | Compose file present |
| HIPAA compliance | PHI encryption code exists; not audited |

## What it does

Physical therapists assign home exercise programs. Patients perform exercises with a mobile app that captures movement data. The system:

1. Ingests sensor/pose events from mobile clients
2. Stores them in an event-sourced log (Commanded + EventStore on PostgreSQL)
3. Processes streams via Broadway (SQS or RabbitMQ)
4. Projects adherence, quality, and work-queue views
5. Serves a therapist dashboard showing patient compliance and form quality

### API endpoints

```
POST /api/v1/events              Ingest exercise events
GET  /api/v1/patients/:id/stream    Event stream for a patient
GET  /api/v1/patients/:id/adherence Adherence projection
GET  /api/v1/patients/:id/quality   Quality projection
GET  /api/v1/work-queue             Therapist task queue
POST /api/v1/auth/login             JWT authentication
```

## Stack

| Layer | Technology | Version |
|---|---|---|
| Backend | Elixir / Phoenix | 1.16 / 1.7 |
| Event sourcing | Commanded + EventStore | ~> 1.4 |
| Stream processing | Broadway | SQS or RabbitMQ producer |
| Database | PostgreSQL | 15+ |
| Frontend | Next.js | 14 |
| Mobile | React Native + Expo | -- |
| ML (planned) | MoveNet / MediaPipe | Pose estimation on device |

## Repository layout

```
backend/rehab_tracking/     Phoenix app with Commanded event sourcing
frontend/                   Next.js therapist dashboard
mobile/                     React Native patient app (Expo)
scripts/                    Load testing (k6/JS), task automation
specs/                      Data model, API contracts (OpenAPI YAML), plan docs
templates/                  Agent file templates
memory/                     Constitution/context docs
```

666 files total.

## Setup

Requires Elixir 1.16+, PostgreSQL 15+, Node.js 18+, Docker.

```bash
# Backend
cd backend/rehab_tracking
mix deps.get
mix ecto.setup
mix event_store.init
docker-compose up -d postgres redis
mix phx.server

# Frontend
cd frontend && npm install && npm run dev

# Mobile
cd mobile && npm install && npx expo start
```

## Performance targets

| Metric | Target |
|---|---|
| API response (p95) | < 200 ms |
| Event throughput | 1000/sec sustained |
| Projection lag | < 100 ms |
| Mobile inference | < 50 ms |

These are design targets. No benchmark results are published.

## Limitations

- ML inference (MoveNet/MediaPipe) is referenced in docs but no model files or inference code ships in the repo.
- HIPAA compliance claims (AES-256-GCM, consent tracking) exist in code but have not been independently audited.
- No CI pipeline. No test coverage reporting configured.
- Broadway producer config references SQS; local development requires substituting RabbitMQ or a mock.
- No license file.
- Production deployment checklist is entirely unchecked.

## License

Not specified.