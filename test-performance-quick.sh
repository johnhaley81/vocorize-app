#!/bin/bash

# Quick Performance Test - Unit Tests Only
# This script provides a fast performance check for unit tests during development

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_performance() {
    echo -e "${PURPLE}[PERFORMANCE]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Vocorize Quick Performance Test       ${NC}" 
echo -e "${BLUE}========================================${NC}"
echo ""

# Check compilation first
print_status "Checking compilation..."
if ! xcodebuild -scheme Vocorize -destination 'platform=macOS,arch=arm64' build-for-testing > /tmp/quick_build.log 2>&1; then
    print_warning "Compilation failed. Check /tmp/quick_build.log for details."
    echo "Common issues:"
    echo "  - Fix syntax errors in test files"
    echo "  - Check import statements"
    echo "  - Verify test structure"
    exit 1
fi

print_success "Compilation successful"

# Measure unit test performance
print_performance "Running unit tests..."
start_time=$(date +%s)

VOCORIZE_TEST_MODE=unit VOCORIZE_TRACK_PERFORMANCE=true ./test.sh > /tmp/quick_unit_test.log 2>&1
exit_code=$?

end_time=$(date +%s)
duration=$((end_time - start_time))

# Extract metrics
passed_tests=$(grep -c "Test Case.*passed" /tmp/quick_unit_test.log 2>/dev/null || echo "0")
failed_tests=$(grep -c "Test Case.*failed" /tmp/quick_unit_test.log 2>/dev/null || echo "0")

echo ""
print_performance "Unit Test Results:"
print_performance "  Duration: ${duration}s (Target: <10s)"
print_performance "  Passed: $passed_tests tests"
print_performance "  Failed: $failed_tests tests"

if [ $exit_code -eq 0 ] && [ $duration -le 10 ]; then
    print_success "Unit tests passed performance target!"
    echo "  ✅ Fast execution (<10s)"
    echo "  ✅ All tests passing"
elif [ $exit_code -eq 0 ]; then
    print_warning "Unit tests passed but slower than target"
    echo "  ⚠️  Execution time: ${duration}s (target: <10s)"
    echo "  ✅ All tests passing"
else
    print_warning "Unit tests failed or had performance issues"
    echo "  ❌ Exit code: $exit_code"
    echo "  ⚠️  Duration: ${duration}s"
    echo "  📊 Passed: $passed_tests, Failed: $failed_tests"
fi

echo ""
echo "Quick test complete. For comprehensive analysis, run: ./performance-measurement.sh"