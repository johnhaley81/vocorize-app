#!/bin/bash

# Vocorize Test Script
# Simple script to run tests with cleaner output

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_status "Running Vocorize Tests..."

# Run tests and capture output
# Disabled test timeouts to accommodate MLX framework initialization
xcodebuild test \
    -scheme Vocorize \
    -destination 'platform=macOS,arch=arm64' \
    -test-timeouts-enabled NO \
    2>&1 | tee test_output.log

# Check if tests passed
if [ $? -eq 0 ]; then
    print_success "All tests passed!"
else
    print_error "Some tests failed. Check test_output.log for details."
    # Extract and show just the failure summary
    echo -e "\n${YELLOW}Test Failures:${NC}"
    grep "Test case.*failed" test_output.log || echo "No specific test failures found in output"
    exit 1
fi