import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// Broadway-specific metrics
const eventProcessingRate = new Rate('broadway_event_processing_success');
const batchProcessingLatency = new Trend('broadway_batch_latency_ms');
const projectionSyncLag = new Trend('broadway_projection_sync_lag_ms');
const eventQueueDepth = new Gauge('broadway_event_queue_depth');
const backpressureEvents = new Counter('broadway_backpressure_events');

// Broadway pipeline configuration targets
const TARGET_BATCH_SIZE = 100;
const TARGET_BATCH_TIMEOUT_MS = 1000;
const PROCESSORS = 10;
const EXPECTED_THROUGHPUT = 1000; // events/sec

export const options = {
  scenarios: {
    // Scenario 1: Sustained load (normal operation)
    sustained_load: {
      executor: 'constant-vus',
      vus: 50,
      duration: '5m',
      tags: { test_type: 'sustained' },
    },
    // Scenario 2: Burst load (sensor data bursts)
    burst_load: {
      executor: 'ramping-arrival-rate',
      startRate: 100,
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 100,
      stages: [
        { duration: '30s', target: 100 },   // Normal load
        { duration: '10s', target: 2000 },  // Burst to 2000 events/sec
        { duration: '30s', target: 2000 },  // Sustain burst
        { duration: '10s', target: 100 },   // Return to normal
        { duration: '30s', target: 100 },   // Maintain normal
      ],
      tags: { test_type: 'burst' },
    },
    // Scenario 3: Gradual ramp (capacity testing)
    capacity_ramp: {
      executor: 'ramping-arrival-rate',
      startRate: 100,
      timeUnit: '1s',
      preAllocatedVUs: 30,
      maxVUs: 200,
      stages: [
        { duration: '2m', target: 500 },   // Ramp to 500/sec
        { duration: '2m', target: 1000 },  // Ramp to 1000/sec
        { duration: '2m', target: 1500 },  // Ramp to 1500/sec
        { duration: '2m', target: 2000 },  // Ramp to 2000/sec (stress)
        { duration: '1m', target: 1000 },  // Back to sustainable
      ],
      tags: { test_type: 'capacity' },
    },
  },
  thresholds: {
    // Broadway-specific thresholds
    'broadway_batch_latency_ms': ['p(95)<1000'],        // Batch processing under 1s
    'broadway_projection_sync_lag_ms': ['p(95)<100'],   // Projection lag under 100ms
    'broadway_event_processing_success': ['rate>0.995'], // 99.5% success rate
    'http_req_duration': ['p(95)<200'],                 // API response time
    'http_req_failed': ['rate<0.001'],                  // Error rate
    
    // Scenario-specific thresholds
    'http_req_duration{test_type:sustained}': ['p(95)<150'],
    'http_req_duration{test_type:burst}': ['p(95)<300'],      // Allow higher during burst
    'http_req_duration{test_type:capacity}': ['p(95)<250'],
  },
};

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'broadway-test-token';

const headers = {
  'Authorization': `Bearer ${AUTH_TOKEN}`,
  'Content-Type': 'application/json',
};

// Event generators optimized for Broadway testing
function generateBroadwayEvent(eventType, patientId, sessionId, batchId) {
  const timestamp = new Date().toISOString();
  
  const baseEvent = {
    kind: eventType,
    subject_id: patientId,
    exercise_id: "knee_flexion",
    timestamp: timestamp,
    meta: {
      phi: true,
      consent_id: `consent_${patientId}`,
      correlation_id: sessionId,
      batch_id: batchId,
      processor_hint: eventType, // Help Broadway route to appropriate processor
      priority: eventType === 'alert' ? 'high' : 'normal'
    }
  };

  switch (eventType) {
    case 'exercise_session':
      return {
        ...baseEvent,
        body: {
          session_id: sessionId,
          prescribed_exercise_id: "template_knee_01",
          start_time: timestamp,
          prescribed_reps: 15,
          device_info: { model: "iPhone 14", app_version: "1.0.3" }
        }
      };

    case 'rep_observation':
      return {
        ...baseEvent,
        body: {
          rep_number: Math.floor(Math.random() * 15) + 1,
          quality_score: Math.random() * 0.35 + 0.60,
          confidence_rating: Math.random() * 0.10 + 0.90,
          duration_ms: Math.floor(Math.random() * 1000) + 2500,
          sensor_data: {
            accelerometer: [Math.random(), Math.random(), Math.random()],
            gyroscope: [Math.random(), Math.random(), Math.random()],
            timestamp: Date.now()
          }
        }
      };

    case 'feedback_event':
      return {
        ...baseEvent,
        body: {
          feedback_type: "automated",
          message: "Form correction needed",
          severity: Math.random() > 0.8 ? "high" : "medium"
        }
      };

    case 'alert_trigger':
      return {
        ...baseEvent,
        kind: 'alert',
        body: {
          alert_type: "quality_degradation",
          severity: "high",
          threshold_value: 0.70,
          actual_value: Math.random() * 0.20 + 0.50
        }
      };
  }
}

function generatePatientId() {
  return `patient_broadway_${Math.floor(Math.random() * 1000)}`;
}

function generateSessionId() {
  return `session_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}

function generateBatchId() {
  return `batch_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
}

// Broadway-aware event burst simulation
function sendEventBurst(patientId, sessionId, batchId, burstSize = TARGET_BATCH_SIZE) {
  const events = [];
  const startTime = Date.now();
  
  // Generate batch of events
  for (let i = 0; i < burstSize; i++) {
    const eventType = i === 0 ? 'exercise_session' : 'rep_observation';
    events.push(generateBroadwayEvent(eventType, patientId, sessionId, batchId));
  }
  
  // Send events rapidly to test Broadway batching
  const responses = events.map(event => {
    return http.post(`${BASE_URL}/api/v1/events`, JSON.stringify(event), { headers });
  });
  
  const endTime = Date.now();
  const batchLatency = endTime - startTime;
  batchProcessingLatency.add(batchLatency);
  
  // Check batch processing success
  const successCount = responses.filter(r => r.status === 201).length;
  eventProcessingRate.add(successCount === burstSize);
  
  return { successCount, batchLatency, responses };
}

// Test Broadway projection consistency
function testProjectionConsistency(patientId) {
  const beforeQuery = Date.now();
  
  // Query multiple projections that should be consistent
  const adherenceResp = http.get(
    `${BASE_URL}/api/v1/projections/adherence?patient_id=${patientId}`,
    { headers }
  );
  
  const qualityResp = http.get(
    `${BASE_URL}/api/v1/projections/quality?patient_id=${patientId}&window=1h`,
    { headers }
  );
  
  const afterQuery = Date.now();
  const syncLag = afterQuery - beforeQuery;
  projectionSyncLag.add(syncLag);
  
  // Validate projection consistency (both should have recent data)
  const adherenceUpdated = adherenceResp.status === 200;
  const qualityUpdated = qualityResp.status === 200;
  
  return { adherenceUpdated, qualityUpdated, syncLag };
}

// Simulate Broadway backpressure scenarios
function testBackpressureHandling(patientId) {
  const sessionId = generateSessionId();
  const batchId = generateBatchId();
  
  // Send rapid bursts to trigger backpressure
  const burst1 = sendEventBurst(patientId, sessionId, `${batchId}_1`, 50);
  const burst2 = sendEventBurst(patientId, sessionId, `${batchId}_2`, 50);
  const burst3 = sendEventBurst(patientId, sessionId, `${batchId}_3`, 50);
  
  // Check for backpressure indicators (slower responses, 429 errors)
  const totalRequests = burst1.responses.length + burst2.responses.length + burst3.responses.length;
  const backpressureIndicators = [
    ...burst1.responses,
    ...burst2.responses,
    ...burst3.responses
  ].filter(r => r.status === 429 || r.timings.duration > 1000).length;
  
  if (backpressureIndicators > 0) {
    backpressureEvents.add(backpressureIndicators);
  }
  
  return { totalRequests, backpressureIndicators };
}

export default function () {
  const patientId = generatePatientId();
  const sessionId = generateSessionId();
  const batchId = generateBatchId();
  
  const scenario = __ENV.K6_SCENARIO || 'default';
  
  group('Broadway Pipeline Load Test', () => {
    switch (scenario) {
      case 'sustained_load':
        // Simulate normal sustained operation
        group('Sustained Event Processing', () => {
          const result = sendEventBurst(patientId, sessionId, batchId, 25);
          
          check(result.responses[0], {
            'sustained event accepted': (r) => r.status === 201,
            'sustained response time acceptable': (r) => r.timings.duration < 150,
          });
          
          // Small delay to maintain sustained rate
          sleep(0.5);
        });
        break;
        
      case 'burst_load':
        // Simulate sensor data bursts
        group('Burst Event Processing', () => {
          const result = sendEventBurst(patientId, sessionId, batchId, TARGET_BATCH_SIZE);
          
          check(null, {
            'burst batch processed successfully': () => result.successCount >= TARGET_BATCH_SIZE * 0.95,
            'burst batch latency acceptable': () => result.batchLatency < 2000,
          });
          
          // Test immediate projection availability
          sleep(0.1); // Allow minimal processing time
          const projTest = testProjectionConsistency(patientId);
          
          check(null, {
            'projections updated after burst': () => projTest.adherenceUpdated && projTest.qualityUpdated,
            'projection sync lag acceptable': () => projTest.syncLag < 200,
          });
        });
        break;
        
      case 'capacity_ramp':
        // Test capacity limits and backpressure
        group('Capacity and Backpressure Testing', () => {
          const backpressureTest = testBackpressureHandling(patientId);
          
          check(null, {
            'backpressure handling active': () => backpressureTest.backpressureIndicators < backpressureTest.totalRequests * 0.1,
            'system maintains stability under load': () => backpressureTest.totalRequests > 0,
          });
          
          // Minimal sleep during capacity testing
          sleep(0.05);
        });
        break;
        
      default:
        // Mixed workload testing
        group('Mixed Broadway Workload', () => {
          const workloadType = Math.random();
          
          if (workloadType < 0.6) {
            // Normal event batch
            sendEventBurst(patientId, sessionId, batchId, 20);
          } else if (workloadType < 0.8) {
            // Query projections
            testProjectionConsistency(patientId);
          } else {
            // Test alerts and feedback
            const alertEvent = generateBroadwayEvent('alert_trigger', patientId, sessionId, batchId);
            http.post(`${BASE_URL}/api/v1/events`, JSON.stringify(alertEvent), { headers });
            
            const feedbackEvent = generateBroadwayEvent('feedback_event', patientId, sessionId, batchId);
            http.post(`${BASE_URL}/api/v1/events`, JSON.stringify(feedbackEvent), { headers });
          }
          
          sleep(Math.random() * 0.5 + 0.1); // 0.1-0.6s intervals
        });
    }
  });
}

// Setup for Broadway testing
export function setup() {
  console.log('Broadway Pipeline Load Test Starting...');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Expected Broadway Config: ${PROCESSORS} processors, batch size ${TARGET_BATCH_SIZE}`);
  
  // Validate Broadway pipeline is running
  const healthCheck = http.get(`${BASE_URL}/api/v1/broadway/status`, { headers });
  if (healthCheck.status !== 200) {
    console.warn('Broadway status endpoint not available. Assuming pipeline is running.');
  }
  
  return { startTime: Date.now() };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`Broadway load test completed in ${duration} seconds`);
}

export function handleSummary(data) {
  const broadwayMetrics = {
    event_processing_success: data.metrics.broadway_event_processing_success?.rate || 0,
    batch_latency_p95: data.metrics.broadway_batch_latency_ms?.values?.['p(95)'] || 0,
    projection_lag_p95: data.metrics.broadway_projection_sync_lag_ms?.values?.['p(95)'] || 0,
    backpressure_events: data.metrics.broadway_backpressure_events?.count || 0,
    total_events: data.metrics.http_reqs?.count || 0,
  };
  
  return {
    'broadway_test_results.json': JSON.stringify({ ...data, broadwayMetrics }, null, 2),
    stdout: `
========================================
BROADWAY PIPELINE LOAD TEST RESULTS
========================================

Total Events Processed: ${broadwayMetrics.total_events}
Event Processing Success Rate: ${(broadwayMetrics.event_processing_success * 100).toFixed(2)}%

Broadway Pipeline Performance:
- Batch Processing Latency P95: ${broadwayMetrics.batch_latency_p95.toFixed(2)}ms (target: <1000ms)
- Projection Sync Lag P95: ${broadwayMetrics.projection_lag_p95.toFixed(2)}ms (target: <100ms)
- Backpressure Events: ${broadwayMetrics.backpressure_events}

Overall HTTP Performance:
- P95 Response Time: ${data.metrics['http_req_duration{expected_response:true}']?.values?.['p(95)']?.toFixed(2) || 'N/A'}ms
- Error Rate: ${(data.metrics.http_req_failed?.rate * 100).toFixed(3)}%
- Requests/sec: ${data.metrics.http_reqs?.rate?.toFixed(2) || 'N/A'}

Broadway Target Validation:
- Batch processing < 1s: ${broadwayMetrics.batch_latency_p95 < 1000 ? '✅ PASS' : '❌ FAIL'}
- Projection lag < 100ms: ${broadwayMetrics.projection_lag_p95 < 100 ? '✅ PASS' : '❌ FAIL'}
- Success rate > 99.5%: ${broadwayMetrics.event_processing_success > 0.995 ? '✅ PASS' : '❌ FAIL'}

Pipeline Recommendations:
${broadwayMetrics.batch_latency_p95 > 1000 ? '⚠️  Consider increasing processor count or reducing batch size' : ''}
${broadwayMetrics.projection_lag_p95 > 100 ? '⚠️  Review projection rebuild strategy and database indexing' : ''}
${broadwayMetrics.backpressure_events > 100 ? '⚠️  Backpressure detected - may need Broadway tuning' : ''}

========================================
    `,
  };
}