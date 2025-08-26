#!/bin/bash

# Vocorize Test Script
# Enhanced script for local development and CI/CD pipeline integration
# Supports different test modes: unit, integration, mixed, release

set -e

# Configuration
TEST_MODE="${VOCORIZE_TEST_MODE:-mixed}"  # unit, integration, mixed, release
TEST_TIMEOUT="${VOCORIZE_TEST_TIMEOUT:-NO}"  # YES, NO
VERBOSE="${VOCORIZE_VERBOSE:-false}"
PERFORMANCE_TRACKING="${VOCORIZE_TRACK_PERFORMANCE:-true}"
MLX_PROFILING="${VOCORIZE_MLX_PROFILING:-false}"  # Enable MLX performance profiling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_debug() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

print_performance() {
    echo -e "${CYAN}[PERFORMANCE]${NC} $1"
}

# Helper function to get test filters based on mode
get_test_filters() {
    case "$TEST_MODE" in
        "unit")
            echo "-only-testing:VocorizeTests/VocorizeTests" \
                 "-only-testing:VocorizeTests/WhisperKitProviderTests" \
                 "-only-testing:VocorizeTests/TranscriptionProviderTests" \
                 "-only-testing:VocorizeTests/TranscriptionClientProviderTests" \
                 "-only-testing:VocorizeTests/ModelConfigurationTests" \
                 "-only-testing:VocorizeTests/MLXProviderRegistrationTests" \
                 "-only-testing:VocorizeTests/MLXAvailabilityTests" \
                 "-only-testing:VocorizeTests/TranscriptionProviderFactoryTests"
            ;;
        "integration")
            echo "-only-testing:VocorizeTests/WhisperKitIntegrationTests" \
                 "-only-testing:VocorizeTests/MLXIntegrationTests" \
                 "-only-testing:VocorizeTests/ProviderSystemIntegrationTests" \
                 "-only-testing:VocorizeTests/MLXSystemCompatibilityTests" \
                 "-only-testing:VocorizeTests/MLXPerformanceTests"
            ;;
        "mixed")
            # Run all tests (default behavior)
            echo ""
            ;;
        "release")
            # Comprehensive test suite for release validation
            echo ""
            ;;
        *)
            print_warning "Unknown test mode: $TEST_MODE, running all tests"
            echo ""
            ;;
    esac
}

# Performance tracking
start_time=$(date +%s)
if [ "$PERFORMANCE_TRACKING" = "true" ]; then
    print_performance "Test execution started at $(date)"
fi

print_status "Running Vocorize Tests in '$TEST_MODE' mode..."
print_debug "Test timeout enabled: $TEST_TIMEOUT"
print_debug "Verbose logging: $VERBOSE"
print_debug "Performance tracking: $PERFORMANCE_TRACKING"

# Get test filters for the current mode
TEST_FILTERS=$(get_test_filters)
print_debug "Test filters: $TEST_FILTERS"
print_debug "MLX profiling enabled: $MLX_PROFILING"

# Build xcodebuild command
XCODEBUILD_CMD="xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64'"

# Add test filters if specified
if [ -n "$TEST_FILTERS" ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD $TEST_FILTERS"
fi

# Add timeout configuration
XCODEBUILD_CMD="$XCODEBUILD_CMD -test-timeouts-enabled $TEST_TIMEOUT"

# Add code signing configuration for CI
if [ -n "$CI" ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD CODE_SIGNING_ALLOWED=NO"
fi

print_debug "Executing: $XCODEBUILD_CMD"

# Run MLX performance profiling if enabled
if [ "$MLX_PROFILING" = "true" ] && [ "$TEST_MODE" != "unit" ]; then
    print_performance "Running MLX performance profiling..."
    MLX_PROFILE_MODE="quick"
    if [ "$TEST_MODE" = "integration" ]; then
        MLX_PROFILE_MODE="comprehensive"
    elif [ -n "$CI" ]; then
        MLX_PROFILE_MODE="ci"
    fi
    
    if [ -x "./scripts/profile-mlx-performance.sh" ]; then
        ./scripts/profile-mlx-performance.sh "$MLX_PROFILE_MODE" || print_warning "MLX profiling failed but continuing with tests"
    else
        print_warning "MLX profiling script not found or not executable"
    fi
fi

# Run tests and capture output
eval "$XCODEBUILD_CMD" 2>&1 | tee test_output.log

# Capture exit code
TEST_EXIT_CODE=$?

# Performance tracking
end_time=$(date +%s)
execution_time=$((end_time - start_time))

if [ "$PERFORMANCE_TRACKING" = "true" ]; then
    print_performance "Test execution completed in ${execution_time}s"
    
    # Extract performance metrics from test output if available
    if grep -q "Unit test performance" test_output.log; then
        UNIT_PERF=$(grep "Unit test performance" test_output.log | grep -o '[0-9]*\.[0-9]*s')
        print_performance "Unit test performance: $UNIT_PERF (target: <5s)"
    fi
    
    # Extract MLX performance metrics if available
    if grep -q "MLX.*Performance" test_output.log; then
        MLX_COLD_START=$(grep "Cold Start Time" test_output.log | head -1 | grep -o '[0-9]*\.[0-9]*s' || echo "N/A")
        MLX_MEMORY=$(grep "Memory Overhead" test_output.log | head -1 | grep -o '[0-9]*MB' || echo "N/A")
        MLX_GRADE=$(grep "Performance Grade" test_output.log | head -1 | sed 's/.*Performance Grade: //' || echo "N/A")
        
        print_performance "MLX cold start: $MLX_COLD_START (target: <15s)"
        print_performance "MLX memory overhead: $MLX_MEMORY (target: <200MB)"
        print_performance "MLX performance grade: $MLX_GRADE"
    fi
    
    # Set performance thresholds based on test mode
    case "$TEST_MODE" in
        "unit")
            if [ $execution_time -gt 300 ]; then  # 5 minutes
                print_warning "Unit tests took longer than expected: ${execution_time}s > 300s"
            fi
            ;;
        "integration")
            if [ $execution_time -gt 3600 ]; then  # 60 minutes
                print_warning "Integration tests took longer than expected: ${execution_time}s > 3600s"
            fi
            ;;
        "mixed")
            if [ $execution_time -gt 1800 ]; then  # 30 minutes
                print_warning "Mixed tests took longer than expected: ${execution_time}s > 1800s"
            fi
            ;;
        "release")
            if [ $execution_time -gt 7200 ]; then  # 120 minutes
                print_warning "Release tests took longer than expected: ${execution_time}s > 7200s"
            fi
            ;;
    esac
fi

# Analyze test results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    # Count successful tests
    PASSED_TESTS=$(grep -c "Test Case.*passed" test_output.log 2>/dev/null || echo "0")
    print_success "All tests passed! ($PASSED_TESTS tests completed)"
    
    # Test mode specific success messages
    case "$TEST_MODE" in
        "unit")
            print_status "✅ Fast unit tests completed - ready for PR merge"
            ;;
        "integration")
            print_status "✅ Integration tests completed - system validation successful"
            ;;
        "mixed")
            print_status "✅ Mixed test suite completed - comprehensive validation successful"
            ;;
        "release")
            print_status "✅ Release test suite completed - ready for deployment"
            ;;
    esac
else
    FAILED_TESTS=$(grep -c "Test Case.*failed" test_output.log 2>/dev/null || echo "0")
    PASSED_TESTS=$(grep -c "Test Case.*passed" test_output.log 2>/dev/null || echo "0")
    
    print_error "Some tests failed. ($PASSED_TESTS passed, $FAILED_TESTS failed)"
    
    # Extract and show failure summary
    echo -e "\n${YELLOW}Test Failures:${NC}"
    if grep "Test Case.*failed" test_output.log > /dev/null 2>&1; then
        grep "Test Case.*failed" test_output.log | head -10
        if [ $(grep -c "Test Case.*failed" test_output.log) -gt 10 ]; then
            echo "... and $(($(grep -c "Test Case.*failed" test_output.log) - 10)) more failures"
        fi
    else
        echo "No specific test failures found in output"
    fi
    
    # Show build errors if present
    if grep -q "error:" test_output.log; then
        echo -e "\n${RED}Build Errors:${NC}"
        grep "error:" test_output.log | head -5
    fi
    
    # Test mode specific failure guidance
    case "$TEST_MODE" in
        "unit")
            print_error "❌ Unit test failures block PR merge - fix before proceeding"
            ;;
        "integration")
            print_error "❌ Integration test failures - check model downloads and system config"
            ;;
        "mixed")
            print_error "❌ Mixed test failures - review both unit and integration issues"
            ;;
        "release")
            print_error "❌ Release test failures - deployment blocked until resolved"
            ;;
    esac
    
    echo -e "\n${BLUE}Troubleshooting:${NC}"
    echo "- Check test_output.log for detailed error messages"
    echo "- For integration test failures, verify model download permissions"
    echo "- For unit test failures, ensure MockWhisperKitProvider is working correctly"
    echo "- Run with VOCORIZE_VERBOSE=true for additional debug output"
    
    exit 1
fi

# Summary report
echo -e "\n${CYAN}=== Test Summary ===${NC}"
echo "Mode: $TEST_MODE"
echo "Duration: ${execution_time}s"
echo "Passed Tests: $PASSED_TESTS"
echo "Failed Tests: ${FAILED_TESTS:-0}"
echo "Log File: test_output.log"
if [ "$MLX_PROFILING" = "true" ]; then
    echo "MLX Profiling: enabled"
    if [ -d "performance-reports" ] && [ -n "$(ls -A performance-reports 2>/dev/null)" ]; then
        LATEST_REPORT=$(ls -t performance-reports/*.md | head -1 2>/dev/null || echo "")
        if [ -n "$LATEST_REPORT" ]; then
            echo "MLX Report: $LATEST_REPORT"
        fi
    fi
fi
if [ "$CI" ]; then
    echo "CI Environment: $CI"
fi
echo -e "${CYAN}===================${NC}"