import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const eventIngestionRate = new Rate('event_ingestion_success');
const projectionLag = new Trend('projection_lag_ms');
const errorRate = new Rate('errors');
const throughputCounter = new Counter('events_processed');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '3m', target: 100 },  // Scale to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],        // 95% under 200ms
    http_req_failed: ['rate<0.001'],         // Error rate < 0.1%
    event_ingestion_success: ['rate>0.99'],  // 99% success rate
    projection_lag_ms: ['p(95)<100'],        // Projection lag < 100ms
  },
};

// Test data generators
function generatePatientId() {
  return `patient_${Math.floor(Math.random() * 1000).toString().padStart(3, '0')}`;
}

function generateSessionId() {
  return `session_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}

function generateExerciseEvent(patientId, sessionId, eventType, repNumber = null) {
  const baseEvent = {
    kind: eventType,
    subject_id: patientId,
    exercise_id: "knee_flexion",
    meta: {
      phi: true,
      consent_id: `consent_${patientId}`,
      site_id: "clinic_main",
      correlation_id: sessionId
    }
  };

  switch (eventType) {
    case 'exercise_session':
      return {
        ...baseEvent,
        body: {
          session_id: sessionId,
          prescribed_exercise_id: "template_knee_01",
          start_time: new Date().toISOString(),
          prescribed_reps: 15,
          device_info: {
            model: "iPhone 14",
            app_version: "1.0.3"
          }
        }
      };

    case 'rep_observation':
      return {
        ...baseEvent,
        body: {
          rep_number: repNumber,
          quality_score: Math.random() * 0.35 + 0.60, // 0.60-0.95
          confidence_rating: Math.random() * 0.10 + 0.90, // 0.90-1.00
          duration_ms: Math.floor(Math.random() * 1000) + 2500 // 2.5-3.5s
        }
      };

    case 'session_complete':
      return {
        ...baseEvent,
        kind: 'exercise_session',
        body: {
          session_id: sessionId,
          end_time: new Date().toISOString(),
          completion_status: "completed",
          completed_reps: Math.floor(Math.random() * 5) + 10, // 10-15 reps
          overall_quality: Math.random() * 0.25 + 0.65 // 0.65-0.90
        }
      };
  }
}

// Authentication token (replace with actual token for real tests)
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'test-token';
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

const headers = {
  'Authorization': `Bearer ${AUTH_TOKEN}`,
  'Content-Type': 'application/json',
};

export default function () {
  const patientId = generatePatientId();
  const sessionId = generateSessionId();

  // Scenario 1: High-frequency event ingestion (simulates 1000 events/sec target)
  group('Event Ingestion Load Test', () => {
    // Start exercise session
    let sessionStart = http.post(`${BASE_URL}/api/v1/events`, 
      JSON.stringify(generateExerciseEvent(patientId, sessionId, 'exercise_session')), 
      { headers }
    );
    
    check(sessionStart, {
      'session start status is 201': (r) => r.status === 201,
      'session start response time < 200ms': (r) => r.timings.duration < 200,
    });

    if (sessionStart.status === 201) {
      throughputCounter.add(1);
      eventIngestionRate.add(1);
    } else {
      errorRate.add(1);
    }

    // Generate rep observations (burst of events)
    const repCount = Math.floor(Math.random() * 6) + 10; // 10-15 reps
    for (let i = 1; i <= repCount; i++) {
      let repEvent = http.post(`${BASE_URL}/api/v1/events`,
        JSON.stringify(generateExerciseEvent(patientId, sessionId, 'rep_observation', i)),
        { headers }
      );

      check(repEvent, {
        'rep observation status is 201': (r) => r.status === 201,
        'rep observation response time < 100ms': (r) => r.timings.duration < 100,
      });

      if (repEvent.status === 201) {
        throughputCounter.add(1);
        eventIngestionRate.add(1);
      } else {
        errorRate.add(1);
      }

      // Small delay to simulate realistic timing between reps
      sleep(0.1);
    }

    // Complete session
    let sessionEnd = http.post(`${BASE_URL}/api/v1/events`,
      JSON.stringify(generateExerciseEvent(patientId, sessionId, 'session_complete')),
      { headers }
    );

    check(sessionEnd, {
      'session complete status is 201': (r) => r.status === 201,
      'session complete response time < 200ms': (r) => r.timings.duration < 200,
    });

    if (sessionEnd.status === 201) {
      throughputCounter.add(1);
      eventIngestionRate.add(1);
    } else {
      errorRate.add(1);
    }
  });

  // Scenario 2: Concurrent projection queries (simulates therapist dashboards)
  group('Projection Query Performance', () => {
    sleep(0.5); // Allow events to process

    const projectionStartTime = Date.now();

    // Query adherence projection
    let adherenceQuery = http.get(
      `${BASE_URL}/api/v1/projections/adherence?patient_id=${patientId}`,
      { headers }
    );

    check(adherenceQuery, {
      'adherence query status is 200': (r) => r.status === 200,
      'adherence query response time < 100ms': (r) => r.timings.duration < 100,
    });

    // Query quality projection
    let qualityQuery = http.get(
      `${BASE_URL}/api/v1/projections/quality?patient_id=${patientId}&window=7d`,
      { headers }
    );

    check(qualityQuery, {
      'quality query status is 200': (r) => r.status === 200,
      'quality query response time < 150ms': (r) => r.timings.duration < 150,
    });

    // Query work queue (therapist view)
    let workQueueQuery = http.get(
      `${BASE_URL}/api/v1/projections/work-queue?therapist_id=therapist_001`,
      { headers }
    );

    check(workQueueQuery, {
      'work queue query status is 200': (r) => r.status === 200,
      'work queue query response time < 200ms': (r) => r.timings.duration < 200,
    });

    // Calculate projection lag
    const projectionEndTime = Date.now();
    const lag = projectionEndTime - projectionStartTime;
    projectionLag.add(lag);
  });

  // Scenario 3: Mixed workload simulation (realistic usage pattern)
  group('Mixed Workload Simulation', () => {
    // Simulate different user types with weighted distribution
    const userType = Math.random();

    if (userType < 0.7) {
      // 70% - Patient completing exercises
      const quickSessionId = generateSessionId();
      
      // Start session
      http.post(`${BASE_URL}/api/v1/events`, 
        JSON.stringify(generateExerciseEvent(patientId, quickSessionId, 'exercise_session')), 
        { headers }
      );

      // 3-5 quick reps
      const quickReps = Math.floor(Math.random() * 3) + 3;
      for (let i = 1; i <= quickReps; i++) {
        http.post(`${BASE_URL}/api/v1/events`,
          JSON.stringify(generateExerciseEvent(patientId, quickSessionId, 'rep_observation', i)),
          { headers }
        );
      }

      // End session
      http.post(`${BASE_URL}/api/v1/events`,
        JSON.stringify(generateExerciseEvent(patientId, quickSessionId, 'session_complete')),
        { headers }
      );

      throughputCounter.add(quickReps + 2);

    } else if (userType < 0.9) {
      // 20% - Therapist querying data
      http.get(`${BASE_URL}/api/v1/patients/${patientId}/stream?limit=10`, { headers });
      http.get(`${BASE_URL}/api/v1/projections/quality?patient_id=${patientId}&window=14d`, { headers });
      
    } else {
      // 10% - Admin queries and alerts
      http.get(`${BASE_URL}/api/v1/projections/work-queue?therapist_id=therapist_001`, { headers });
      http.get(`${BASE_URL}/api/v1/alerts?alert_type=quality_degradation`, { headers });
    }
  });

  // Throttle to maintain realistic load patterns
  sleep(Math.random() * 2 + 1); // 1-3 second intervals
}

// Setup function runs once per VU at the beginning
export function setup() {
  console.log('Starting load test...');
  console.log(`Target URL: ${BASE_URL}`);
  console.log(`Auth Token: ${AUTH_TOKEN ? 'Set' : 'Using default test token'}`);
  
  // Warmup request
  const warmup = http.get(`${BASE_URL}/health`, { timeout: '10s' });
  if (warmup.status !== 200) {
    console.warn('Health check failed. Service may not be ready.');
  }
  
  return { startTime: Date.now() };
}

// Teardown function runs once after all VUs finish
export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`Load test completed in ${duration} seconds`);
}

// Handle summary for custom reporting
export function handleSummary(data) {
  return {
    'load_test_results.json': JSON.stringify(data, null, 2),
    stdout: `
========================================
REHAB TRACKING LOAD TEST SUMMARY
========================================

Total Requests: ${data.metrics.http_reqs.count}
Failed Requests: ${data.metrics.http_req_failed.count} (${(data.metrics.http_req_failed.rate * 100).toFixed(2)}%)
Events Processed: ${data.metrics.events_processed ? data.metrics.events_processed.count : 'N/A'}

Response Times:
- Average: ${data.metrics.http_req_duration.med.toFixed(2)}ms
- 95th percentile: ${data.metrics['http_req_duration{expected_response:true}'].values['p(95)'].toFixed(2)}ms
- 99th percentile: ${data.metrics['http_req_duration{expected_response:true}'].values['p(99)'].toFixed(2)}ms

Targets Met:
- P95 < 200ms: ${data.metrics['http_req_duration{expected_response:true}'].values['p(95)'] < 200 ? '✅ PASS' : '❌ FAIL'}
- Error rate < 0.1%: ${data.metrics.http_req_failed.rate < 0.001 ? '✅ PASS' : '❌ FAIL'}
- Throughput: ${data.metrics.http_reqs.rate.toFixed(2)} req/s

Broadway Pipeline Performance:
- Event ingestion success rate: ${data.metrics.event_ingestion_success ? (data.metrics.event_ingestion_success.rate * 100).toFixed(2) + '%' : 'N/A'}
- Projection lag P95: ${data.metrics.projection_lag_ms ? data.metrics.projection_lag_ms.values['p(95)'].toFixed(2) + 'ms' : 'N/A'}

========================================
    `,
  };
}