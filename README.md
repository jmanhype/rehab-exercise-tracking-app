# Rehab Exercise Tracking System

An event-sourced rehabilitation exercise tracking platform for physical therapists to monitor patient home exercise quality and adherence. Built with Elixir/Phoenix, React Native, and Next.js.

## 🏥 Overview

This system enables physical therapists to remotely monitor their patients' home exercise programs through mobile sensor data, providing real-time feedback on exercise form quality and adherence tracking.

### Key Features

- **Real-time Exercise Tracking** - Mobile apps with edge ML for movement analysis
- **Event Sourcing Architecture** - Immutable audit trail with CQRS projections
- **HIPAA Compliant** - PHI encryption and consent management
- **Therapist Dashboard** - Work queue and patient monitoring interface
- **High Throughput** - Processes 1000+ events/second with Broadway
- **Quality Analysis** - ML-powered form assessment and correction suggestions

## 🏗️ Architecture

### Core Technologies

- **Backend**: Elixir 1.16 / Phoenix 1.7 / OTP 27
- **Event Store**: PostgreSQL 15 with Commanded
- **Stream Processing**: Broadway with SQS/RabbitMQ
- **Frontend**: Next.js 14 (therapist dashboard)
- **Mobile**: React Native with Expo
- **ML Models**: MoveNet/MediaPipe for pose estimation
- **Infrastructure**: Docker, Kubernetes ready

### System Design

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│Mobile Apps  │────▶│  API Gateway │────▶│Event Store  │
└─────────────┘     └──────────────┘     └─────────────┘
                            │                     │
                            ▼                     ▼
                    ┌──────────────┐     ┌─────────────┐
                    │  Broadway    │────▶│ Projections │
                    │  Pipeline    │     └─────────────┘
                    └──────────────┘
```

## 🚀 Getting Started

### Prerequisites

- Elixir 1.16+
- PostgreSQL 15+
- Node.js 18+
- Docker & Docker Compose

### Quick Start

1. **Clone the repository**
```bash
git clone https://github.com/jmanhype/rehab-exercise-tracking-app.git
cd rehab-exercise-tracking-app
```

2. **Setup Backend**
```bash
cd backend/rehab_tracking
mix deps.get
mix ecto.setup
mix event_store.init
```

3. **Start Services**
```bash
docker-compose up -d postgres redis
mix phx.server
```

4. **Setup Frontend**
```bash
cd frontend/therapist-dashboard
npm install
npm run dev
```

5. **Setup Mobile**
```bash
cd mobile/patient-app
npm install
npx expo start
```

## 📊 Database Schema

### Event Sourcing Tables
- `events` - Immutable event log
- `event_streams` - Stream metadata
- `snapshots` - Periodic state snapshots

### Projection Tables
- `adherence_projections` - Exercise compliance tracking
- `quality_projections` - Form quality analysis
- `work_queue_projections` - Therapist task management
- `user_authentication` - User accounts and PHI consent

## 🔧 Configuration

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost/rehab_tracking_dev
EVENT_STORE_URL=postgresql://user:pass@localhost/rehab_events_dev

# Authentication
JWT_SECRET=your-secret-key
PHI_ENCRYPTION_KEY=your-encryption-key

# External Services
AWS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs.amazonaws.com/...
S3_BUCKET=rehab-tracking-media

# Feature Flags
ENABLE_ML_INFERENCE=true
ENABLE_REAL_TIME_ALERTS=true
```

## 🧪 Testing

```bash
# Run all tests
mix test

# Run specific test suites
mix test test/contract     # API contracts
mix test test/integration  # Event flows
mix test test/e2e         # End-to-end scenarios

# Generate test data
mix rehab.seed

# Check coverage
mix test --cover
```

## 📈 Performance

### Targets
- API Response: <200ms p95
- Event Processing: 1000/sec sustained
- Projection Lag: <100ms
- Mobile Inference: <50ms

### Broadway Configuration
```elixir
config :rehab_tracking, RehabTracking.Broadway,
  producer: [
    module: {BroadwaySQS.Producer, queue_url: System.get_env("SQS_QUEUE_URL")},
    concurrency: 2
  ],
  processors: [
    default: [concurrency: 10]
  ],
  batchers: [
    default: [
      batch_size: 100,
      batch_timeout: 1000,
      concurrency: 2
    ]
  ]
```

## 🔒 Security & Compliance

### HIPAA Compliance
- AES-256-GCM encryption for PHI
- Consent tracking per patient
- Audit trail with break-glass access
- Role-based access control (RBAC)

### Authentication
- JWT tokens with refresh rotation
- Session management with Redis
- Multi-factor authentication support
- Emergency access protocols

## 🚢 Deployment

### Docker
```bash
docker build -t rehab-tracking:latest .
docker run -p 4000:4000 rehab-tracking:latest
```

### Production Checklist
- [ ] Configure SSL certificates
- [ ] Setup database backups
- [ ] Configure monitoring (Prometheus/Grafana)
- [ ] Setup log aggregation (ELK stack)
- [ ] Configure rate limiting
- [ ] Setup CDN for static assets
- [ ] Configure auto-scaling policies

## 📚 API Documentation

### Core Endpoints

```bash
# Patient Events
POST /api/v1/events
GET  /api/v1/patients/:id/stream
GET  /api/v1/patients/:id/adherence
GET  /api/v1/patients/:id/quality

# Therapist Workflow
GET  /api/v1/work-queue
POST /api/v1/work-queue/:id/complete
GET  /api/v1/patients
GET  /api/v1/alerts

# Authentication
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Acknowledgments

- MoveNet/MediaPipe teams for pose estimation models
- Commanded framework for event sourcing in Elixir
- Broadway team for stream processing capabilities

## 📞 Support

- **Documentation**: [https://github.com/jmanhype/rehab-exercise-tracking-app/wiki](https://github.com/jmanhype/rehab-exercise-tracking-app/wiki)
- **Issues**: [https://github.com/jmanhype/rehab-exercise-tracking-app/issues](https://github.com/jmanhype/rehab-exercise-tracking-app/issues)
- **Email**: support@rehabtracking.example.com

---

Built with ❤️ for improving patient rehabilitation outcomes