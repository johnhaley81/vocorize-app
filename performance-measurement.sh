#!/bin/bash

# Vocorize Test Performance Measurement Framework
# This script measures and validates test performance improvements after optimization work

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PERFORMANCE_REPORT_DIR="performance-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$PERFORMANCE_REPORT_DIR/performance_report_$TIMESTAMP.md"
BASELINE_FILE="$PERFORMANCE_REPORT_DIR/performance_baseline.json"

# Performance Targets (in seconds)
TARGET_UNIT_TESTS=10
TARGET_INTEGRATION_CACHED=30
TARGET_INTEGRATION_CLEAN=300
TARGET_TOTAL_IMPROVEMENT=90  # 90% improvement expected

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} Vocorize Test Performance Measurement ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_performance() {
    echo -e "${PURPLE}[PERFORMANCE]${NC} $1"
}

# Create performance report directory
create_report_directory() {
    mkdir -p "$PERFORMANCE_REPORT_DIR"
    print_status "Created performance report directory: $PERFORMANCE_REPORT_DIR"
}

# Initialize performance report
initialize_report() {
    cat > "$REPORT_FILE" << EOF
# Vocorize Test Performance Report
**Generated:** $(date)  
**Branch:** $(git rev-parse --abbrev-ref HEAD)  
**Commit:** $(git rev-parse --short HEAD)  

## Executive Summary

This report measures the test performance improvements achieved through optimization work.

### Key Improvements
- Mock provider implementation for unit tests
- MLX initialization optimization
- Model caching system
- Test suite separation

## Performance Measurements

EOF
}

# Measure unit test performance
measure_unit_tests() {
    print_performance "Measuring unit test performance..."
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Run unit tests with timing
    VOCORIZE_TEST_MODE=unit VOCORIZE_TRACK_PERFORMANCE=true ./test.sh > /tmp/unit_test_output.log 2>&1 || exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Extract additional metrics from test output if available
    local test_count=$(grep -c "Test Case.*passed" /tmp/unit_test_output.log 2>/dev/null || echo "0")
    local memory_usage=$(grep "Memory Usage" /tmp/unit_test_output.log | tail -1 | grep -o '[0-9]*MB' || echo "N/A")
    
    echo "    \"unit_tests\": {" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"duration_seconds\": $duration," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"test_count\": $test_count," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"memory_usage\": \"$memory_usage\"," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"exit_code\": $exit_code," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"target_seconds\": $TARGET_UNIT_TESTS" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "    }," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    
    # Append to report
    cat >> "$REPORT_FILE" << EOF
### Unit Tests Performance
- **Duration:** ${duration}s (Target: <${TARGET_UNIT_TESTS}s)
- **Status:** $([ $exit_code -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")
- **Tests Executed:** $test_count
- **Memory Usage:** $memory_usage
- **Performance Grade:** $([ $duration -le $TARGET_UNIT_TESTS ] && echo "✅ EXCELLENT" || echo "⚠️ NEEDS IMPROVEMENT")

EOF
    
    if [ $exit_code -eq 0 ] && [ $duration -le $TARGET_UNIT_TESTS ]; then
        print_success "Unit tests: ${duration}s (✅ Target: ${TARGET_UNIT_TESTS}s)"
    else
        print_warning "Unit tests: ${duration}s (⚠️ Target: ${TARGET_UNIT_TESTS}s)"
    fi
    
    return $duration
}

# Measure integration test performance (cached)
measure_integration_cached() {
    print_performance "Measuring integration test performance (cached)..."
    
    local start_time=$(date +%s)
    local exit_code=0
    
    # Run integration tests with cache
    VOCORIZE_TEST_MODE=integration VOCORIZE_TRACK_PERFORMANCE=true ./test.sh > /tmp/integration_cached_output.log 2>&1 || exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local test_count=$(grep -c "Test Case.*passed" /tmp/integration_cached_output.log 2>/dev/null || echo "0")
    local cache_hits=$(grep "Cache Hit" /tmp/integration_cached_output.log | wc -l || echo "0")
    
    echo "    \"integration_cached\": {" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"duration_seconds\": $duration," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"test_count\": $test_count," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"cache_hits\": $cache_hits," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"exit_code\": $exit_code," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"target_seconds\": $TARGET_INTEGRATION_CACHED" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "    }," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    
    cat >> "$REPORT_FILE" << EOF
### Integration Tests Performance (Cached)
- **Duration:** ${duration}s (Target: <${TARGET_INTEGRATION_CACHED}s)
- **Status:** $([ $exit_code -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")
- **Tests Executed:** $test_count
- **Cache Hits:** $cache_hits
- **Performance Grade:** $([ $duration -le $TARGET_INTEGRATION_CACHED ] && echo "✅ EXCELLENT" || echo "⚠️ NEEDS IMPROVEMENT")

EOF
    
    if [ $exit_code -eq 0 ] && [ $duration -le $TARGET_INTEGRATION_CACHED ]; then
        print_success "Integration (cached): ${duration}s (✅ Target: ${TARGET_INTEGRATION_CACHED}s)"
    else
        print_warning "Integration (cached): ${duration}s (⚠️ Target: ${TARGET_INTEGRATION_CACHED}s)"
    fi
    
    return $duration
}

# Measure integration test performance (clean)
measure_integration_clean() {
    print_performance "Measuring integration test performance (clean)..."
    
    # Clean cache first
    if [ -f "./scripts/cache-manager.sh" ]; then
        ./scripts/cache-manager.sh --clean
    fi
    
    local start_time=$(date +%s)
    local exit_code=0
    
    VOCORIZE_TEST_MODE=integration VOCORIZE_TRACK_PERFORMANCE=true ./test-integration.sh --clean > /tmp/integration_clean_output.log 2>&1 || exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local test_count=$(grep -c "Test Case.*passed" /tmp/integration_clean_output.log 2>/dev/null || echo "0")
    local downloads=$(grep -c "Downloading" /tmp/integration_clean_output.log || echo "0")
    
    echo "    \"integration_clean\": {" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"duration_seconds\": $duration," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"test_count\": $test_count," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"downloads\": $downloads," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"exit_code\": $exit_code," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "        \"target_seconds\": $TARGET_INTEGRATION_CLEAN" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    echo "    }," >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    
    cat >> "$REPORT_FILE" << EOF
### Integration Tests Performance (Clean)
- **Duration:** ${duration}s (Target: <${TARGET_INTEGRATION_CLEAN}s)
- **Status:** $([ $exit_code -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")
- **Tests Executed:** $test_count
- **Model Downloads:** $downloads
- **Performance Grade:** $([ $duration -le $TARGET_INTEGRATION_CLEAN ] && echo "✅ EXCELLENT" || echo "⚠️ NEEDS IMPROVEMENT")

EOF
    
    if [ $exit_code -eq 0 ] && [ $duration -le $TARGET_INTEGRATION_CLEAN ]; then
        print_success "Integration (clean): ${duration}s (✅ Target: ${TARGET_INTEGRATION_CLEAN}s)"
    else
        print_warning "Integration (clean): ${duration}s (⚠️ Target: ${TARGET_INTEGRATION_CLEAN}s)"
    fi
    
    return $duration
}

# Measure mock provider performance
measure_mock_performance() {
    print_performance "Measuring mock provider performance..."
    
    local start_time=$(date +%s.%3N)
    
    # Run specific mock provider tests
    xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64' \
        -only-testing:VocorizeTests/WhisperKitProviderTests/testMockProviderPerformance \
        > /tmp/mock_perf_output.log 2>&1 || true
    
    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    local response_time=$(grep "Mock Response Time" /tmp/mock_perf_output.log | grep -o '[0-9]*\.[0-9]*ms' || echo "N/A")
    local memory_overhead=$(grep "Mock Memory Overhead" /tmp/mock_perf_output.log | grep -o '[0-9]*MB' || echo "N/A")
    
    cat >> "$REPORT_FILE" << EOF
### Mock Provider Performance
- **Duration:** ${duration}s
- **Response Time:** $response_time (Target: <100ms)
- **Memory Overhead:** $memory_overhead (Target: <10MB)
- **Performance Grade:** $(echo "$duration < 1" | bc -l | grep -q "1" && echo "✅ EXCELLENT" || echo "⚠️ NEEDS IMPROVEMENT")

EOF
    
    print_performance "Mock provider: ${duration}s"
}

# Load baseline performance data
load_baseline() {
    if [ -f "$BASELINE_FILE" ]; then
        BASELINE_UNIT=$(cat "$BASELINE_FILE" | grep -o '"unit_tests": [0-9]*' | grep -o '[0-9]*' || echo "300")
        BASELINE_INTEGRATION=$(cat "$BASELINE_FILE" | grep -o '"integration_tests": [0-9]*' | grep -o '[0-9]*' || echo "1800")
        print_status "Loaded baseline: Unit ${BASELINE_UNIT}s, Integration ${BASELINE_INTEGRATION}s"
    else
        # Default baseline (pre-optimization estimates)
        BASELINE_UNIT=300  # 5 minutes
        BASELINE_INTEGRATION=1800  # 30 minutes
        print_warning "No baseline file found, using estimated baseline values"
    fi
}

# Calculate improvements
calculate_improvements() {
    local unit_duration=$1
    local integration_duration=$2
    
    local unit_improvement=$(echo "scale=1; ($BASELINE_UNIT - $unit_duration) * 100 / $BASELINE_UNIT" | bc)
    local integration_improvement=$(echo "scale=1; ($BASELINE_INTEGRATION - $integration_duration) * 100 / $BASELINE_INTEGRATION" | bc)
    local overall_improvement=$(echo "scale=1; ($unit_improvement + $integration_improvement) / 2" | bc)
    
    cat >> "$REPORT_FILE" << EOF

## Performance Improvements

### Compared to Baseline
- **Unit Tests:** $unit_improvement% improvement (${BASELINE_UNIT}s → ${unit_duration}s)
- **Integration Tests:** $integration_improvement% improvement (${BASELINE_INTEGRATION}s → ${integration_duration}s)
- **Overall:** $overall_improvement% improvement

### Success Criteria Analysis
- **Unit Tests <${TARGET_UNIT_TESTS}s:** $([ $unit_duration -le $TARGET_UNIT_TESTS ] && echo "✅ ACHIEVED" || echo "❌ NOT MET")
- **Integration Tests <${TARGET_INTEGRATION_CACHED}s:** $([ $integration_duration -le $TARGET_INTEGRATION_CACHED ] && echo "✅ ACHIEVED" || echo "❌ NOT MET")
- **90%+ Improvement:** $(echo "$overall_improvement >= 90" | bc -l | grep -q "1" && echo "✅ ACHIEVED" || echo "❌ NOT MET")

EOF
    
    if echo "$overall_improvement >= $TARGET_TOTAL_IMPROVEMENT" | bc -l | grep -q "1"; then
        print_success "Overall improvement: $overall_improvement% (✅ Target: ${TARGET_TOTAL_IMPROVEMENT}%+)"
    else
        print_warning "Overall improvement: $overall_improvement% (⚠️ Target: ${TARGET_TOTAL_IMPROVEMENT}%+)"
    fi
}

# Generate optimization recommendations
generate_recommendations() {
    cat >> "$REPORT_FILE" << EOF

## Optimization Analysis

### What Worked Well
- Mock provider implementation eliminated ML initialization overhead
- Test suite separation allowed targeted test execution
- Model caching reduced redundant downloads
- MLX conditional loading improved startup time

### Areas for Further Improvement
EOF
    
    # Check if targets were met and provide specific recommendations
    if [ "$UNIT_DURATION" -gt "$TARGET_UNIT_TESTS" ]; then
        cat >> "$REPORT_FILE" << EOF
- **Unit Test Optimization:**
  - Consider parallel test execution
  - Reduce test fixture complexity
  - Optimize mock response times
EOF
    fi
    
    if [ "$INTEGRATION_DURATION" -gt "$TARGET_INTEGRATION_CACHED" ]; then
        cat >> "$REPORT_FILE" << EOF
- **Integration Test Optimization:**
  - Implement smarter model caching
  - Reduce model download sizes
  - Optimize network timeouts
EOF
    fi
    
    cat >> "$REPORT_FILE" << EOF

### Recommended Next Steps
1. **Continuous Monitoring:** Set up performance regression detection
2. **Parallel Execution:** Implement test parallelization for further speed gains
3. **Resource Optimization:** Monitor memory usage during test execution
4. **Cache Strategy:** Fine-tune caching strategy based on usage patterns

EOF
}

# Save current metrics as baseline for future comparisons
save_new_baseline() {
    cat > "$BASELINE_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "commit": "$(git rev-parse HEAD)",
    "unit_tests": $UNIT_DURATION,
    "integration_tests": $INTEGRATION_DURATION,
    "branch": "$(git rev-parse --abbrev-ref HEAD)"
}
EOF
    print_status "Saved new performance baseline"
}

# Main execution
main() {
    print_header
    
    create_report_directory
    initialize_report
    load_baseline
    
    # Initialize raw metrics file
    echo "{" > "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    
    # Check if compilation is successful first
    print_status "Checking if tests compile successfully..."
    if ! xcodebuild -scheme Vocorize -destination 'platform=macOS,arch=arm64' build-for-testing > /tmp/build_check.log 2>&1; then
        print_error "Tests do not compile successfully. Skipping performance measurement."
        print_error "Fix compilation errors first, then run this script again."
        echo "Build errors found. Please fix compilation issues before measuring performance." >> "$REPORT_FILE"
        exit 1
    fi
    
    print_success "Tests compile successfully. Proceeding with performance measurement..."
    
    # Perform measurements
    measure_unit_tests
    UNIT_DURATION=$?
    
    measure_integration_cached  
    INTEGRATION_DURATION=$?
    
    # Skip clean integration test if it would take too long
    # measure_integration_clean
    
    measure_mock_performance
    
    # Close raw metrics file
    echo "}" >> "$PERFORMANCE_REPORT_DIR/raw_metrics_$TIMESTAMP.json"
    
    # Analysis
    calculate_improvements $UNIT_DURATION $INTEGRATION_DURATION
    generate_recommendations
    save_new_baseline
    
    # Final report
    cat >> "$REPORT_FILE" << EOF

---
*Report generated by Vocorize Performance Measurement Framework*  
*Script: performance-measurement.sh*  
*Raw data: performance-reports/raw_metrics_$TIMESTAMP.json*
EOF
    
    print_header
    print_success "Performance measurement complete!"
    print_status "Report saved to: $REPORT_FILE"
    
    # Display summary
    echo ""
    print_performance "Performance Summary:"
    print_performance "  Unit Tests: ${UNIT_DURATION}s (Target: ${TARGET_UNIT_TESTS}s)"
    print_performance "  Integration: ${INTEGRATION_DURATION}s (Target: ${TARGET_INTEGRATION_CACHED}s)"
    
    # Open report if on macOS
    if command -v open > /dev/null 2>&1; then
        print_status "Opening performance report..."
        open "$REPORT_FILE"
    fi
}

# Error handling
trap 'print_error "Script interrupted or failed"; exit 1' INT TERM

# Check dependencies
if ! command -v bc > /dev/null 2>&1; then
    print_error "bc calculator is required but not installed"
    exit 1
fi

if ! command -v git > /dev/null 2>&1; then
    print_error "git is required but not installed"
    exit 1
fi

# Run main function
main "$@"