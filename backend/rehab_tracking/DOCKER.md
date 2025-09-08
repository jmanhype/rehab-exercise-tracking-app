# Docker Deployment Guide

## Quick Start

To get the Rehab Exercise Tracking System running with Docker:

```bash
# 1. Start all services
docker-compose up -d

# 2. Check the health of the application
curl http://localhost:4000/health

# 3. View logs
docker-compose logs -f app
```

The application will be available at: **http://localhost:4000**

## Services

This Docker setup includes the following services:

### Core Application
- **app** - Phoenix/Elixir application (port 4000)
  - Health endpoint: http://localhost:4000/health
  - Detailed health: http://localhost:4000/health/detailed

### Databases
- **postgres** - PostgreSQL 15 for main database and EventStore (port 5432)
- **redis** - Redis for caching and sessions (port 6379)

### Message Queue
- **rabbitmq** - RabbitMQ for Broadway message processing (ports 5672, 15672)
  - Management UI: http://localhost:15672 (guest/guest)

### Monitoring
- **prometheus** - Metrics collection (port 9090)
  - UI: http://localhost:9090
- **grafana** - Metrics visualization (port 3000)
  - UI: http://localhost:3000 (admin/admin)

## File Structure

```
├── Dockerfile                 # Multi-stage build for Phoenix app
├── docker-compose.yml         # Service orchestration
├── .dockerignore             # Files to exclude from Docker build
├── config/
│   ├── prod.exs              # Production configuration
│   └── runtime.exs           # Runtime environment variables
├── priv/repo/
│   └── init.sql              # Database initialization
├── scripts/
│   ├── start.sh              # Docker startup script
│   └── test_docker.sh        # Docker setup testing
└── monitoring/
    └── prometheus.yml        # Prometheus configuration
```

## Environment Variables

The following environment variables are configured in docker-compose.yml:

### Application
- `MIX_ENV=dev` - Elixir environment
- `PORT=4000` - Phoenix server port
- `PHX_SERVER=true` - Start Phoenix server
- `SECRET_KEY_BASE` - Phoenix secret (auto-generated for dev)

### Database
- `DATABASE_URL` - Main PostgreSQL connection
- `EVENTSTORE_URL` - EventStore PostgreSQL connection

### External Services
- `REDIS_URL` - Redis connection for caching
- `RABBITMQ_URL` - RabbitMQ connection for message processing

## Health Checks

The application includes comprehensive health checks:

### Basic Health Check
```bash
curl http://localhost:4000/health
```

Returns basic status and version information.

### Detailed Health Check
```bash
curl http://localhost:4000/health/detailed
```

Returns detailed status of all system components:
- Database connectivity
- EventStore connectivity  
- Redis connectivity (if configured)
- RabbitMQ connectivity (if configured)
- Memory usage
- Process count

### Docker Health Checks
```bash
# Check container health
docker-compose ps

# View health check logs
docker-compose logs app | grep health
```

## Commands

### Development Commands
```bash
# Start all services
docker-compose up -d

# Start with logs visible
docker-compose up

# Restart just the app
docker-compose restart app

# Rebuild app after code changes
docker-compose build app && docker-compose up -d app

# Run Elixir commands in the container
docker-compose exec app iex -S mix

# Run mix commands
docker-compose exec app mix deps.get
docker-compose exec app mix test
```

### Production Commands
```bash
# Build for production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Scale the application
docker-compose up -d --scale app=3
```

### Maintenance Commands
```bash
# View logs
docker-compose logs -f app
docker-compose logs -f postgres

# Execute shell in container
docker-compose exec app /bin/bash

# Database operations
docker-compose exec postgres psql -U postgres -d rehab_tracking_dev

# Clean up
docker-compose down
docker-compose down -v  # Remove volumes too
```

## Testing the Setup

Run the test script to validate your Docker configuration:

```bash
./scripts/test_docker.sh
```

This script will:
1. Validate docker-compose.yml configuration
2. Test Docker image building
3. Pull required images
4. Test service creation
5. Clean up test containers

## Troubleshooting

### Common Issues

**Port already in use:**
```bash
# Check what's using the port
lsof -i :4000

# Stop existing services
docker-compose down
```

**Database connection issues:**
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres

# Check database health
docker-compose exec postgres pg_isready -U postgres
```

**Out of memory:**
```bash
# Check container memory usage
docker stats

# Increase Docker Desktop memory allocation
# Docker Desktop -> Settings -> Resources -> Memory
```

**Permission denied errors:**
```bash
# Fix script permissions
chmod +x scripts/*.sh

# Check Docker socket permissions
ls -la /var/run/docker.sock
```

### Debugging

**View container logs:**
```bash
docker-compose logs -f app
```

**Enter container for debugging:**
```bash
docker-compose exec app /bin/bash
```

**Check container health:**
```bash
docker-compose ps
docker inspect rehab_app
```

**Monitor resource usage:**
```bash
docker stats
```

## Development Workflow

### Making Changes

1. **Code Changes**: Make changes to your Elixir code
2. **Hot Reload**: The development container supports hot reloading
3. **Restart**: For config changes, restart the container:
   ```bash
   docker-compose restart app
   ```

### Database Changes

1. **Migrations**: Run migrations in the container:
   ```bash
   docker-compose exec app mix ecto.migrate
   ```

2. **Reset Database**:
   ```bash
   docker-compose exec app mix ecto.reset
   ```

### Adding Dependencies

1. **Update mix.exs** in your host machine
2. **Install dependencies**:
   ```bash
   docker-compose exec app mix deps.get
   docker-compose restart app
   ```

## Security Considerations

- Default passwords are used for development
- Change all passwords for production deployment
- Use Docker secrets for sensitive configuration
- Enable SSL/TLS for production
- Configure proper firewall rules
- Regularly update base images

## Performance Optimization

### Production Settings
- Use `target: production` in Dockerfile
- Set proper resource limits in docker-compose.yml
- Enable connection pooling
- Configure proper cache settings

### Monitoring
- Use Prometheus metrics for monitoring
- Set up Grafana dashboards
- Monitor resource usage with Docker stats
- Set up log aggregation

## Backup and Recovery

### Database Backup
```bash
# Create backup
docker-compose exec postgres pg_dump -U postgres rehab_tracking_dev > backup.sql

# Restore backup
docker-compose exec -T postgres psql -U postgres rehab_tracking_dev < backup.sql
```

### Volume Backup
```bash
# Backup volumes
docker run --rm -v rehab_tracking_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

## Support

For issues with the Docker setup:
1. Run the test script: `./scripts/test_docker.sh`
2. Check the logs: `docker-compose logs -f`
3. Verify your Docker installation
4. Check system resources (memory, disk space)

The application should start successfully and be available at http://localhost:4000 with all health checks passing.