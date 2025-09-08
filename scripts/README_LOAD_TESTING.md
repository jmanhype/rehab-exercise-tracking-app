# Load Testing Suite for Rehab Exercise Tracking

This directory contains comprehensive load testing tools for the Rehab Exercise Tracking system, designed to validate performance targets of 1000 events/sec with p95 response times under 200ms.

## Quick Start

```bash
# Install k6 (if not already installed)
brew install k6  # macOS
# or
sudo apt install k6  # Ubuntu

# Run all tests
./run_tests.sh

# Run specific test type
./run_tests.sh smoke    # Quick validation
./run_tests.sh load     # Main performance test
./run_tests.sh broadway # Broadway pipeline test
```

## Files Overview

### Core Test Files

- **`load_test.js`** - Main k6 load test script
  - Targets 1000 events/sec throughput
  - Tests event ingestion, projection queries, mixed workloads
  - Validates p95 < 200ms, error rate < 0.1%

- **`broadway_load_test.js`** - Broadway pipeline-specific testing
  - Tests event batching and processing
  - Validates projection lag < 100ms
  - Simulates sensor data bursts and backpressure scenarios

- **`run_tests.sh`** - Test orchestration script
  - Automated test execution with prerequisite checks
  - Supports multiple test types and environments
  - Generates performance reports

- **`load_test_config.json`** - Configuration file
  - Test scenarios and thresholds
  - Environment settings
  - Performance targets

## Test Scenarios

### 1. Event Ingestion Load Test
Based on quickstart.md scenarios, simulates:
- Exercise session starts
- Real-time rep observations 
- Session completions
- Validates Broadway pipeline processing

### 2. Projection Query Performance
Tests concurrent access to projections:
- Adherence calculations
- Quality aggregations  
- Therapist work queues
- Patient event streams

### 3. Mixed Workload Simulation
Realistic usage patterns:
- 70% patients completing exercises
- 20% therapists querying data
- 10% admin/alert queries

### 4. Broadway Pipeline Stress Testing
- Sustained load (normal operation)
- Burst load (sensor data spikes)
- Capacity ramping (finding limits)
- Backpressure handling

## Performance Targets

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| API Response Time (p95) | < 200ms | < 500ms |
| Error Rate | < 0.1% | < 1% |
| Events/Second | 1000+ | 500+ |
| Projection Lag (p95) | < 100ms | < 1000ms |
| Broadway Batch Latency | < 1s | < 2s |

## Usage Examples

### Basic Performance Test
```bash
# Test against local development server
./run_tests.sh load

# Test against staging environment
BASE_URL=https://staging.example.com ./run_tests.sh load
```

### Broadway Pipeline Testing
```bash
# Run Broadway-specific tests
k6 run broadway_load_test.js --vus 50 --duration 5m

# Test with different scenarios
k6 run broadway_load_test.js -e K6_SCENARIO=burst_load
```

### Custom Configuration
```bash
# Use custom auth token
AUTH_TOKEN=your_jwt_token ./run_tests.sh smoke

# Test specific scenario
k6 run load_test.js --vus 100 --duration 10m \
  --env BASE_URL=http://localhost:4000 \
  --env AUTH_TOKEN=test-token
```

### Results Analysis
```bash
# Generate detailed report
./run_tests.sh all

# Cleanup old results (older than 7 days)
./run_tests.sh cleanup

# View latest results
ls -la scripts/load_test_results/
```

## Test Data Patterns

The tests generate realistic data matching your quickstart scenarios:

### Exercise Session Pattern
```json
{
  "kind": "exercise_session",
  "subject_id": "patient_001",
  "body": {
    "session_id": "session_123",
    "prescribed_reps": 15,
    "device_info": {"model": "iPhone 14"}
  },
  "meta": {
    "phi": true,
    "consent_id": "consent_001"
  }
}
```

### Rep Observation Pattern
```json
{
  "kind": "rep_observation", 
  "body": {
    "rep_number": 1,
    "quality_score": 0.73,
    "confidence_rating": 0.92,
    "duration_ms": 3200
  }
}
```

## Broadway Pipeline Validation

The tests specifically validate your Broadway configuration:
- **Batch Size**: 100 events (configurable)
- **Processors**: 10 concurrent processors
- **Timeout**: 1 second batch timeout
- **Throughput**: 1000 events/sec target

### Key Broadway Metrics
- Event processing success rate
- Batch processing latency
- Projection synchronization lag
- Backpressure event count
- Queue depth monitoring

## Interpreting Results

### Success Indicators ✅
```
P95 Response Time: 156ms (target: <200ms) ✅
Error Rate: 0.03% (target: <0.1%) ✅
Events/Second: 1247 (target: >1000) ✅
Projection Lag: 67ms (target: <100ms) ✅
```

### Failure Indicators ❌
```
P95 Response Time: 312ms (target: <200ms) ❌
Error Rate: 0.8% (target: <0.1%) ❌
Events/Second: 634 (target: >1000) ❌
```

### Troubleshooting Common Issues

**High Response Times**
- Check PostgreSQL connection pool settings
- Review Broadway processor configuration
- Monitor system resources (CPU, memory)

**High Error Rates**
- Verify authentication tokens
- Check database connectivity
- Review application logs

**Low Throughput**
- Increase Broadway processor count
- Optimize database queries
- Check network bandwidth

**High Projection Lag**
- Review projection rebuild strategy
- Check database indexing
- Monitor event processing backlog

## Integration with Monitoring

The tests generate metrics compatible with:
- **Grafana** dashboards (JSON output)
- **ELK Stack** (structured logging)
- **Prometheus** (custom metrics export)
- **New Relic** (APM integration)

## CI/CD Integration

Example GitHub Actions workflow:
```yaml
- name: Run Load Tests
  run: |
    ./scripts/run_tests.sh smoke
    if [ $? -eq 0 ]; then
      echo "Performance tests passed"
    else
      echo "Performance degradation detected"
      exit 1
    fi
```

## Security Considerations

- Tests use configurable authentication tokens
- PHI data is simulated (not real patient data)
- Audit logs are generated for compliance
- Rate limiting is respected

## Support and Troubleshooting

1. **Prerequisites not met**: Run `./run_tests.sh help` for setup instructions
2. **Service not running**: Ensure `iex -S mix phx.server` is running
3. **Permission errors**: Check script permissions: `chmod +x run_tests.sh`
4. **k6 not found**: Install k6: `brew install k6` or visit https://k6.io

For detailed analysis, install `jq` for JSON processing:
```bash
brew install jq  # macOS
sudo apt install jq  # Ubuntu
```

## Contributing

When adding new test scenarios:
1. Follow existing pattern in `load_test.js`
2. Add configuration to `load_test_config.json`
3. Update thresholds in `run_tests.sh`
4. Test locally before submitting PR
5. Document new scenarios in this README

---

**Generated**: 2025-09-08  
**Version**: 1.0.0  
**Contact**: See project documentation for support