#!/bin/bash
#
# Test Configuration Runner
# Demonstrates different ways to run tests with the new configuration system
#

set -e

echo "🧪 Vocorize Test Configuration System"
echo "===================================="

# Function to run tests with specific configuration
run_test_config() {
    local mode=$1
    local description=$2
    local timeout=${3:-300}  # Default 5 minute timeout
    
    echo ""
    echo "📋 Running: $description"
    echo "   Mode: $mode"
    echo "   Timeout: ${timeout}s"
    echo "   Command: VOCORIZE_TEST_MODE=$mode xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64'"
    
    # Set timeout and run tests
    timeout $timeout env VOCORIZE_TEST_MODE=$mode xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64' | tee "test_output_${mode}.log"
    
    if [ $? -eq 0 ]; then
        echo "✅ $description completed successfully"
    else
        echo "❌ $description failed"
        return 1
    fi
}

# Parse command line arguments
MODE=${1:-"auto"}

case $MODE in
    "unit"|"mock")
        echo "🏃‍♂️ Running UNIT TESTS ONLY (fast, mocked providers)"
        run_test_config "unit" "Unit Tests with Mock Providers" 60
        ;;
    
    "integration"|"real")
        echo "🐢 Running INTEGRATION TESTS (slow, real providers)"
        echo "⚠️  This will download models and may take 10+ minutes"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_test_config "integration" "Integration Tests with Real Providers" 900  # 15 minutes
        else
            echo "Cancelled integration tests"
            exit 0
        fi
        ;;
    
    "both"|"all")
        echo "🔄 Running BOTH unit and integration tests"
        echo "This will run fast tests first, then slow tests"
        
        echo ""
        echo "Phase 1: Unit Tests (fast)"
        run_test_config "unit" "Unit Tests with Mock Providers" 120
        
        echo ""
        echo "Phase 2: Integration Tests (slow)"
        echo "⚠️  This will download models and may take 10+ minutes"
        read -p "Continue with integration tests? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_test_config "integration" "Integration Tests with Real Providers" 900
        else
            echo "Skipped integration tests"
        fi
        ;;
    
    "auto"|"default")
        echo "🤖 Running with AUTO-DETECTION (usually unit tests)"
        echo "The system will automatically choose mock or real providers"
        echo "based on test context and environment"
        
        xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64' | tee test_output_auto.log
        ;;
    
    "validate")
        echo "✅ Validating test configuration system"
        echo "Running specific tests to ensure configuration works correctly"
        
        # Run only the test configuration validation tests
        xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64' -only-testing:VocorizeTests/ExampleTestUsage | tee test_output_validation.log
        ;;
    
    "help"|"-h"|"--help")
        echo "Usage: $0 [mode]"
        echo ""
        echo "Modes:"
        echo "  unit        - Fast unit tests with mock providers (< 1 minute)"
        echo "  integration - Slow integration tests with real providers (5-15 minutes)"  
        echo "  both        - Run unit tests, then integration tests"
        echo "  auto        - Let the system auto-detect (default)"
        echo "  validate    - Run configuration validation tests only"
        echo "  help        - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 unit            # Fast tests only"
        echo "  $0 integration     # Comprehensive tests"
        echo "  $0 both            # Full test suite"
        echo "  $0                 # Auto-detection"
        echo ""
        echo "Environment Variables:"
        echo "  VOCORIZE_TEST_MODE=unit        Force unit test mode"
        echo "  VOCORIZE_TEST_MODE=integration Force integration test mode"
        echo "  UNIT_TESTS_ONLY=1              Skip all integration tests"
        ;;
    
    *)
        echo "❌ Unknown mode: $MODE"
        echo "Run '$0 help' for available options"
        exit 1
        ;;
esac

echo ""
echo "🎉 Test configuration run completed!"
echo "Check test_output_*.log files for detailed results"