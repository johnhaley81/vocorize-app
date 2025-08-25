#!/bin/bash

#
# Integration Test Runner for WhisperKit Comprehensive Testing
# This script runs the integration test suite with real providers
#

set -e

echo "🧪 Starting WhisperKit Integration Test Suite"
echo "================================================"
echo ""

# Set environment for integration testing
export VOCORIZE_TEST_MODE=integration

# Check if we're in the right directory
if [ ! -f "Vocorize.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Run this script from the project root directory"
    exit 1
fi

echo "📊 Test Configuration:"
echo "   Mode: Integration (Real Providers)"
echo "   Expected Time: 10-30 minutes"
echo "   Network: Required for model downloads"
echo ""

# Warn about test duration
read -p "⚠️  Integration tests may take 10-30 minutes. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test run cancelled."
    exit 0
fi

echo "🚀 Running integration tests..."
echo ""

# Run the integration test suite specifically
xcodebuild test \
    -scheme Vocorize \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:VocorizeTests/WhisperKitIntegrationTests \
    2>&1 | tee integration_test_results.log

# Check test results
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Integration tests completed successfully!"
    echo ""
    echo "📝 Test Report:"
    echo "   - All real provider interactions tested"
    echo "   - Model download/loading validation complete"
    echo "   - Network error handling verified"
    echo "   - Performance benchmarks recorded"
else
    echo ""
    echo "❌ Integration tests failed!"
    echo ""
    echo "📝 Troubleshooting:"
    echo "   - Check network connectivity for model downloads"
    echo "   - Verify disk space for model storage"
    echo "   - Check integration_test_results.log for details"
    exit 1
fi

echo ""
echo "📊 For unit tests (fast, mock-based), run:"
echo "   ./test.sh"
echo ""
echo "📋 For both test suites, run:"
echo "   ./test.sh && ./VocorizeTests/run_integration_tests.sh"