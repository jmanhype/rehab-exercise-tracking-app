#!/bin/bash

# Rehab Exercise Tracking - k6 Load Testing Script
# Targets: 1000 events/sec, p95 < 200ms, Error rate < 0.1%

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${BASE_URL:-http://localhost:4000}"
AUTH_TOKEN="${AUTH_TOKEN:-}"
RESULTS_DIR="${SCRIPT_DIR}/load_test_results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if k6 is installed
    if ! command -v k6 &> /dev/null; then
        error "k6 is not installed. Please install it first:"
        echo "  macOS: brew install k6"
        echo "  Ubuntu: sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69"
        echo "  Other: https://k6.io/docs/get-started/installation/"
        exit 1
    fi
    
    # Check if service is running
    log "Checking service health at ${BASE_URL}..."
    if ! curl -s -f "${BASE_URL}/health" &> /dev/null; then
        warning "Service health check failed. Make sure the service is running."
        echo "  Start with: iex -S mix phx.server"
        echo "  Or use docker: docker-compose up -d"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "Service is healthy"
    fi
    
    # Create results directory
    mkdir -p "${RESULTS_DIR}"
}

# Generate authentication token for testing
generate_test_token() {
    if [[ -z "${AUTH_TOKEN}" ]]; then
        warning "No AUTH_TOKEN provided. Using test token."
        warning "For production testing, set AUTH_TOKEN environment variable."
        export AUTH_TOKEN="test-token-$(date +%s)"
    fi
}

# Run smoke test (quick validation)
run_smoke_test() {
    log "Running smoke test (30 seconds, 5 users)..."
    
    k6 run \
        --vus 5 \
        --duration 30s \
        --env BASE_URL="${BASE_URL}" \
        --env AUTH_TOKEN="${AUTH_TOKEN}" \
        --out json="${RESULTS_DIR}/smoke_test_$(date +%Y%m%d_%H%M%S).json" \
        "${SCRIPT_DIR}/load_test.js"
    
    if [[ $? -eq 0 ]]; then
        success "Smoke test passed"
        return 0
    else
        error "Smoke test failed"
        return 1
    fi
}

# Run load test (main test targeting 1000 events/sec)
run_load_test() {
    log "Running main load test (targeting 1000 events/sec)..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local json_output="${RESULTS_DIR}/load_test_${timestamp}.json"
    local summary_output="${RESULTS_DIR}/load_test_summary_${timestamp}.txt"
    
    k6 run \
        --vus 100 \
        --duration 10m \
        --env BASE_URL="${BASE_URL}" \
        --env AUTH_TOKEN="${AUTH_TOKEN}" \
        --out json="${json_output}" \
        "${SCRIPT_DIR}/load_test.js" | tee "${summary_output}"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        success "Load test completed successfully"
        log "Results saved to: ${json_output}"
        log "Summary saved to: ${summary_output}"
    else
        error "Load test failed with exit code: ${exit_code}"
    fi
    
    return $exit_code
}

# Run stress test (push beyond normal limits)
run_stress_test() {
    log "Running stress test (150 users for 15 minutes)..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local json_output="${RESULTS_DIR}/stress_test_${timestamp}.json"
    
    k6 run \
        --vus 150 \
        --duration 15m \
        --env BASE_URL="${BASE_URL}" \
        --env AUTH_TOKEN="${AUTH_TOKEN}" \
        --out json="${json_output}" \
        "${SCRIPT_DIR}/load_test.js"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        success "Stress test completed"
    else
        warning "Stress test showed performance degradation (expected under extreme load)"
    fi
    
    return $exit_code
}

# Run Broadway pipeline specific test
run_broadway_test() {
    log "Running Broadway pipeline burst test..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local json_output="${RESULTS_DIR}/broadway_test_${timestamp}.json"
    
    # Simulate sensor data bursts (common in mobile exercise apps)
    k6 run \
        --vus 50 \
        --iterations 5000 \
        --env BASE_URL="${BASE_URL}" \
        --env AUTH_TOKEN="${AUTH_TOKEN}" \
        --out json="${json_output}" \
        "${SCRIPT_DIR}/load_test.js"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        success "Broadway pipeline test completed"
        log "Check projection lag metrics in results"
    else
        error "Broadway pipeline test failed"
    fi
    
    return $exit_code
}

# Analyze results
analyze_results() {
    log "Analyzing test results..."
    
    local latest_result=$(ls -t "${RESULTS_DIR}"/load_test_*.json | head -n1)
    
    if [[ -f "${latest_result}" ]]; then
        log "Latest result: ${latest_result}"
        
        # Extract key metrics using jq if available
        if command -v jq &> /dev/null; then
            local p95_duration=$(jq -r '.metrics."http_req_duration{expected_response:true}".values."p(95)"' "${latest_result}")
            local error_rate=$(jq -r '.metrics.http_req_failed.rate' "${latest_result}")
            local total_requests=$(jq -r '.metrics.http_reqs.count' "${latest_result}")
            local avg_rps=$(jq -r '.metrics.http_reqs.rate' "${latest_result}")
            
            echo
            echo "=== PERFORMANCE ANALYSIS ==="
            echo "Total Requests: ${total_requests}"
            echo "Average RPS: ${avg_rps}"
            echo "P95 Response Time: ${p95_duration}ms (target: <200ms)"
            echo "Error Rate: ${error_rate} (target: <0.001)"
            
            # Performance targets validation
            if (( $(echo "${p95_duration} < 200" | bc -l) )); then
                success "✅ P95 response time target met"
            else
                warning "❌ P95 response time target missed"
            fi
            
            if (( $(echo "${error_rate} < 0.001" | bc -l) )); then
                success "✅ Error rate target met"
            else
                warning "❌ Error rate target missed"
            fi
            
            # Estimate events per second capability
            local events_per_req=4  # Approximation: session start + reps + session end
            local events_per_sec=$(echo "${avg_rps} * ${events_per_req}" | bc -l)
            echo "Estimated events/sec capacity: ${events_per_sec}"
            
            if (( $(echo "${events_per_sec} >= 1000" | bc -l) )); then
                success "✅ Target 1000 events/sec achieved"
            else
                warning "⚠️  Target 1000 events/sec not achieved (got ${events_per_sec})"
            fi
        else
            warning "jq not installed. Install for detailed analysis: brew install jq"
        fi
    else
        warning "No test results found for analysis"
    fi
}

# Generate performance report
generate_report() {
    log "Generating performance report..."
    
    local report_file="${RESULTS_DIR}/performance_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "${report_file}" << EOF
# Rehab Exercise Tracking - Load Test Report

**Generated:** $(date)  
**Target URL:** ${BASE_URL}  
**Test Duration:** Various scenarios (see details below)

## Test Scenarios

### 1. Smoke Test
- **Purpose:** Quick validation of basic functionality
- **Configuration:** 5 users, 30 seconds
- **Target:** Basic connectivity and response validation

### 2. Load Test
- **Purpose:** Validate performance under normal load
- **Configuration:** 100 users, 10 minutes
- **Targets:** 
  - P95 response time < 200ms
  - Error rate < 0.1%
  - Sustained 1000 events/sec

### 3. Stress Test
- **Purpose:** Identify breaking point and degradation patterns
- **Configuration:** 150 users, 15 minutes
- **Expected:** Performance degradation acceptable

### 4. Broadway Pipeline Test
- **Purpose:** Validate event processing pipeline under burst load
- **Configuration:** 50 users, 5000 iterations
- **Focus:** Projection lag and event processing

## Key Metrics

- **Response Times:** p95, p99, average
- **Throughput:** requests/second, events/second
- **Error Rates:** HTTP errors, application errors
- **Broadway Performance:** Projection lag, event processing rate

## Performance Targets

✅ **PASS Criteria:**
- P95 response time < 200ms
- Error rate < 0.1%
- Sustained 1000 events/sec
- Projection lag < 100ms

❌ **FAIL Criteria:**
- P95 response time > 300ms
- Error rate > 1%
- Cannot sustain 500 events/sec

## Results

$(ls -la "${RESULTS_DIR}")

## Recommendations

1. **If targets not met:**
   - Check Broadway pipeline configuration
   - Review PostgreSQL connection pool settings
   - Monitor system resources (CPU, memory, I/O)
   - Consider scaling database connections

2. **For production deployment:**
   - Run tests with production-like data volumes
   - Test with multiple geographic regions
   - Validate with actual PHI encryption overhead
   - Test EMR integration performance impact

3. **Monitoring in production:**
   - Set up alerts for p95 > 200ms
   - Monitor projection lag continuously
   - Track error rates and patterns
   - Monitor Broadway pipeline health

EOF

    success "Performance report generated: ${report_file}"
}

# Cleanup old results
cleanup_old_results() {
    log "Cleaning up results older than 7 days..."
    find "${RESULTS_DIR}" -name "*.json" -mtime +7 -delete
    find "${RESULTS_DIR}" -name "*.txt" -mtime +7 -delete
    find "${RESULTS_DIR}" -name "*.md" -mtime +7 -delete
    success "Cleanup completed"
}

# Main function
main() {
    echo
    echo "========================================"
    echo "Rehab Exercise Tracking - Load Testing"
    echo "========================================"
    echo
    
    local test_type="${1:-all}"
    
    check_prerequisites
    generate_test_token
    
    case "${test_type}" in
        "smoke")
            run_smoke_test
            ;;
        "load")
            run_load_test
            analyze_results
            ;;
        "stress")
            run_stress_test
            ;;
        "broadway")
            run_broadway_test
            ;;
        "all")
            log "Running complete test suite..."
            
            # Run tests in sequence
            if run_smoke_test; then
                log "Smoke test passed, proceeding with load test..."
                if run_load_test; then
                    log "Load test passed, running Broadway pipeline test..."
                    run_broadway_test
                    
                    # Optional stress test (ask user)
                    echo
                    read -p "Run stress test? This may take 15 minutes (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        run_stress_test
                    fi
                else
                    error "Load test failed. Skipping remaining tests."
                    exit 1
                fi
            else
                error "Smoke test failed. Aborting test suite."
                exit 1
            fi
            
            analyze_results
            generate_report
            ;;
        "cleanup")
            cleanup_old_results
            exit 0
            ;;
        "help"|"-h"|"--help")
            cat << EOF

Usage: $0 [TEST_TYPE]

TEST_TYPE options:
    smoke     - Quick validation test (5 users, 30s)
    load      - Main performance test (100 users, 10m)
    stress    - Stress test (150 users, 15m)
    broadway  - Broadway pipeline burst test
    all       - Run complete test suite (default)
    cleanup   - Remove old test results
    help      - Show this help message

Environment Variables:
    BASE_URL     - Target URL (default: http://localhost:4000)
    AUTH_TOKEN   - Authentication token (auto-generated if not set)

Examples:
    $0                    # Run all tests
    $0 smoke             # Quick smoke test only
    BASE_URL=https://staging.example.com $0 load

Results are saved to: ${RESULTS_DIR}/

EOF
            exit 0
            ;;
        *)
            error "Unknown test type: ${test_type}"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    echo
    success "Load testing completed!"
    log "Results available in: ${RESULTS_DIR}/"
    echo
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Test interrupted by user${NC}"; exit 130' INT

# Run main function with all arguments
main "$@"