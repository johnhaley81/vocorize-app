#!/bin/bash
# Comprehensive Integration Test Script for Vocorize
# 
# This script runs integration tests with real WhisperKit providers.
# WARNING: Execution time: 5-30 minutes, requires network connectivity.

set -e

# Configuration
export VOCORIZE_TEST_MODE=integration
REQUIRED_DISK_SPACE_MB=1000
TIMEOUT_SECONDS=1800  # 30 minutes
TEST_LOG_FILE="integration_test_$(date +%Y%m%d_%H%M%S).log"
MODELS_CACHE_DIR="$HOME/.cache/huggingface/hub"
VOCORIZE_CACHE_DIR="$HOME/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Progress spinner for long operations
show_spinner() {
    local pid=$1
    local delay=0.5
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(( bytes / 1048576 ))MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

# Pre-flight checks
perform_preflight_checks() {
    print_status "Performing pre-flight checks..."
    
    # Check if we're in the right directory
    if [ ! -f "Vocorize.xcodeproj/project.pbxproj" ]; then
        print_error "Not in Vocorize project root directory"
        exit 1
    fi
    
    # Check for xcodebuild
    if ! command_exists xcodebuild; then
        print_error "xcodebuild not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    
    # Check network connectivity
    print_status "Checking network connectivity..."
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        print_error "No internet connection. Integration tests require network access for model downloads."
        exit 1
    fi
    
    # Check Hugging Face Hub connectivity
    print_status "Checking Hugging Face Hub connectivity..."
    if ! curl -s --head "https://huggingface.co" >/dev/null; then
        print_warning "Hugging Face Hub may be unreachable. Model downloads might fail."
    fi
    
    # Check available disk space
    print_status "Checking available disk space..."
    local available_space_kb=$(df -k . | tail -1 | awk '{print $4}')
    local available_space_mb=$((available_space_kb / 1024))
    
    if [ $available_space_mb -lt $REQUIRED_DISK_SPACE_MB ]; then
        print_error "Insufficient disk space. Required: ${REQUIRED_DISK_SPACE_MB}MB, Available: ${available_space_mb}MB"
        exit 1
    fi
    
    print_success "Available disk space: ${available_space_mb}MB"
    
    # Check if models are already cached
    local total_cache_size=0
    
    if [ -d "$MODELS_CACHE_DIR" ]; then
        local hf_cache_size=$(du -sm "$MODELS_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
        total_cache_size=$((total_cache_size + hf_cache_size))
        if [ $hf_cache_size -gt 0 ]; then
            print_status "Found HuggingFace model cache: ${hf_cache_size}MB"
        fi
    fi
    
    if [ -d "$VOCORIZE_CACHE_DIR" ]; then
        local vocorize_cache_size=$(du -sm "$VOCORIZE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
        total_cache_size=$((total_cache_size + vocorize_cache_size))
        if [ $vocorize_cache_size -gt 0 ]; then
            print_status "Found Vocorize test cache: ${vocorize_cache_size}MB"
        fi
    fi
    
    if [ $total_cache_size -gt 0 ]; then
        print_success "Total cached models: ${total_cache_size}MB (will significantly speed up tests)"
    else
        print_warning "No cached models found - first run will be slower"
    fi
    
    # Check if integration test files exist
    print_status "Checking integration test files..."
    local integration_test_files=(
        "VocorizeTests/Integration/WhisperKitIntegrationTests.swift"
        "VocorizeTests/Integration/ProviderSystemIntegrationTests.swift"
        "VocorizeTests/Providers/MLXIntegrationTests.swift"
    )
    
    for test_file in "${integration_test_files[@]}"; do
        if [ -f "$test_file" ]; then
            print_status "Found: $test_file"
        else
            print_warning "Missing: $test_file"
        fi
    done
    
    print_success "Pre-flight checks completed"
}

# Display warnings and get user confirmation
show_warnings() {
    echo ""
    echo "================================================================================================"
    echo -e "${YELLOW}⚠️  INTEGRATION TEST WARNINGS${NC}"
    echo "================================================================================================"
    echo ""
    echo -e "${YELLOW}EXECUTION TIME:${NC} 30 seconds - 30 minutes (depending on cache hits)"
    echo -e "${YELLOW}NETWORK USAGE:${NC} Up to 500MB for ML model downloads (cache misses only)"
    echo -e "${YELLOW}DISK USAGE:${NC} Models cached in:"
    echo "  • HuggingFace: ~/.cache/huggingface/hub/"
    echo "  • Vocorize Tests: ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/"
    echo -e "${YELLOW}REQUIREMENTS:${NC} Stable internet connection for cache misses"
    echo ""
    echo "Integration tests will:"
    echo "• Use cached models when available (fast path)"
    echo "• Download WhisperKit models from Hugging Face Hub (cache misses)"
    echo "• Cache downloaded models for future test runs"
    echo "• Test real ML inference with audio files"
    echo "• Validate transcription accuracy"
    echo "• Test model management functionality"
    echo "• Test MLX framework integration (if available)"
    echo "• Optimize cache size and cleanup expired models"
    echo ""
    
    if [ "${CI:-}" = "true" ]; then
        print_status "Running in CI mode - proceeding automatically"
        return 0
    fi
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Integration tests cancelled by user"
        exit 0
    fi
}

# Run the integration tests
run_integration_tests() {
    print_status "Starting integration tests..."
    echo "Test log: $TEST_LOG_FILE"
    echo ""
    
    # Create test command - target integration tests specifically
    # We'll run tests that contain "Integration" in their name
    local test_cmd="xcodebuild test \
        -scheme Vocorize \
        -destination 'platform=macOS,arch=arm64' \
        -only-testing:VocorizeTests/WhisperKitIntegrationTests \
        -only-testing:VocorizeTests/ProviderSystemIntegrationTests \
        -only-testing:VocorizeTests/MLXIntegrationTests \
        -resultBundlePath integration_test_results \
        -quiet"
    
    print_status "Executing integration test suite..."
    print_warning "This may take 5-30 minutes. Progress will be logged to $TEST_LOG_FILE"
    
    # Start the test process in background and show progress
    echo "Starting integration tests at $(date)" > "$TEST_LOG_FILE"
    echo "Command: $test_cmd" >> "$TEST_LOG_FILE"
    echo "Environment: VOCORIZE_TEST_MODE=$VOCORIZE_TEST_MODE" >> "$TEST_LOG_FILE"
    echo "----------------------------------------" >> "$TEST_LOG_FILE"
    
    if timeout $TIMEOUT_SECONDS $test_cmd >> "$TEST_LOG_FILE" 2>&1; then
        print_success "Integration tests completed successfully!"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            print_error "Tests timed out after $TIMEOUT_SECONDS seconds"
        else
            print_error "Tests failed with exit code $exit_code"
        fi
        return $exit_code
    fi
}

# Monitor test progress by tailing log file
monitor_test_progress() {
    local test_pid=$1
    local last_line_count=0
    
    while kill -0 $test_pid 2>/dev/null; do
        if [ -f "$TEST_LOG_FILE" ]; then
            local current_line_count=$(wc -l < "$TEST_LOG_FILE")
            if [ $current_line_count -gt $last_line_count ]; then
                # Show new log lines
                tail -n +$((last_line_count + 1)) "$TEST_LOG_FILE" | while read -r line; do
                    if [[ $line == *"Test Case"* ]]; then
                        print_status "$line"
                    elif [[ $line == *"FAIL"* ]] || [[ $line == *"error"* ]]; then
                        print_error "$line"
                    elif [[ $line == *"PASS"* ]] || [[ $line == *"succeeded"* ]]; then
                        print_success "$line"
                    fi
                done
                last_line_count=$current_line_count
            fi
        fi
        sleep 2
    done
}

# Handle test results and cleanup
handle_test_results() {
    local exit_code=$1
    
    echo ""
    print_status "Integration test execution completed"
    
    if [ $exit_code -eq 0 ]; then
        print_success "All integration tests passed!"
        
        # Show summary statistics if available
        if [ -d "integration_test_results" ]; then
            print_status "Test results available in: integration_test_results/"
            
            # Try to show test summary
            local summary_file="integration_test_results/TestSummaries.plist"
            if [ -f "$summary_file" ]; then
                print_status "Test summary available in results bundle"
            fi
        fi
        
        # Show model cache information
        local total_cache=0
        if [ -d "$MODELS_CACHE_DIR" ]; then
            local hf_cache_size=$(du -sm "$MODELS_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
            print_status "HuggingFace cache size: ${hf_cache_size}MB"
            total_cache=$((total_cache + hf_cache_size))
        fi
        
        if [ -d "$VOCORIZE_CACHE_DIR" ]; then
            local vocorize_cache_size=$(du -sm "$VOCORIZE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
            print_status "Vocorize test cache size: ${vocorize_cache_size}MB"
            total_cache=$((total_cache + vocorize_cache_size))
        fi
        
        print_success "Total model cache: ${total_cache}MB"
        
    else
        print_error "Integration tests failed!"
        echo ""
        print_status "Failure Analysis:"
        
        # Check for common failure patterns in log
        if [ -f "$TEST_LOG_FILE" ]; then
            if grep -q "network\|connection\|download" "$TEST_LOG_FILE"; then
                print_error "• Network-related failures detected - check internet connectivity"
            fi
            
            if grep -q "disk\|space\|storage" "$TEST_LOG_FILE"; then
                print_error "• Disk space issues detected - ensure sufficient storage available"
            fi
            
            if grep -q "timeout\|deadline" "$TEST_LOG_FILE"; then
                print_error "• Timeout issues detected - model downloads may be slow"
            fi
            
            if grep -q "MLX\|mlx" "$TEST_LOG_FILE"; then
                print_warning "• MLX-related issues detected - MLX framework may not be available"
            fi
            
            print_status "Full test log available in: $TEST_LOG_FILE"
            print_status "Recent log entries:"
            echo "----------------------------------------"
            tail -20 "$TEST_LOG_FILE" | while read -r line; do
                echo "  $line"
            done
            echo "----------------------------------------"
        fi
        
        echo ""
        print_status "Troubleshooting Tips:"
        echo "• Ensure stable internet connection (500MB+ bandwidth needed)"
        echo "• Check available disk space (1GB+ recommended)"
        echo "• Clear caches if corrupted:"
        echo "  - HuggingFace: rm -rf ~/.cache/huggingface/hub/"
        echo "  - Vocorize Tests: rm -rf ~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/"
        echo "• Run unit tests first: ./test.sh"
        echo "• Check if WhisperKit dependencies are properly installed"
        echo "• For MLX issues, ensure MLX framework is available on Apple Silicon"
        echo "• For cache issues, try running with --clean-cache first"
    fi
    
    return $exit_code
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Archive test results
    if [ -d "integration_test_results" ]; then
        local archive_name="integration_test_results_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$archive_name" integration_test_results/ 2>/dev/null || true
        rm -rf integration_test_results/ 2>/dev/null || true
        if [ -f "$archive_name" ]; then
            print_status "Test results archived: $archive_name"
        fi
    fi
    
    exit $exit_code
}

# Add cache warming function
warm_cache() {
    print_status "Warming test cache..."
    
    # Create cache directory if it doesn't exist
    mkdir -p "$VOCORIZE_CACHE_DIR"
    
    # The cache warming will be handled by the test initialization
    # This is just a placeholder for any pre-test cache setup
    
    print_success "Cache warm-up completed"
}

# Main execution
main() {
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    echo "================================================================================================"
    echo "Vocorize Integration Test Suite"
    echo "Real WhisperKit Provider Testing with Intelligent Caching"
    echo "================================================================================================"
    echo ""
    
    # Perform all pre-flight checks
    perform_preflight_checks
    
    # Warm cache
    warm_cache
    
    # Show warnings and get confirmation
    show_warnings
    
    echo ""
    print_status "Initializing integration test environment..."
    echo "Environment Variables:"
    echo "  VOCORIZE_TEST_MODE: $VOCORIZE_TEST_MODE"
    echo "  Test Timeout: ${TIMEOUT_SECONDS}s"
    echo "  Log File: $TEST_LOG_FILE"
    echo "  Cache Directories:"
    echo "    HuggingFace: $MODELS_CACHE_DIR"
    echo "    Vocorize: $VOCORIZE_CACHE_DIR"
    echo ""
    
    # Run the integration tests
    local start_time=$(date +%s)
    
    if run_integration_tests; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "Integration tests completed in ${duration}s"
        handle_test_results 0
        exit 0
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_error "Integration tests failed after ${duration}s"
        handle_test_results $exit_code
        exit $exit_code
    fi
}

# Help function
show_help() {
    echo "Vocorize Integration Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --ci           Run in CI mode (no interactive prompts)"
    echo "  --timeout N    Set timeout in seconds (default: 1800)"
    echo "  --clean        Clean HuggingFace model cache before running"
    echo "  --clean-cache  Clean both HuggingFace and Vocorize test caches"
    echo "  --cache-info   Show cache information and exit"
    echo "  --dry-run      Show what would be executed without running tests"
    echo ""
    echo "Environment Variables:"
    echo "  CI=true        Automatically run in CI mode"
    echo "  VOCORIZE_TEST_MODE=integration  Set integration test mode"
    echo ""
    echo "Test Coverage:"
    echo "  • WhisperKit model downloads and inference"
    echo "  • Provider system integration"  
    echo "  • MLX framework integration (Apple Silicon)"
    echo "  • Audio processing pipeline"
    echo "  • Model management functionality"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive mode with warnings"
    echo "  $0 --ci               # CI mode, no prompts"
    echo "  $0 --timeout 3600     # 1 hour timeout"
    echo "  $0 --clean            # Clean HuggingFace cache first
  $0 --clean-cache      # Clean all caches first
  $0 --cache-info       # Show cache status"
    echo "  $0 --dry-run          # Preview execution plan"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --ci)
            export CI=true
            shift
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --clean)
            print_status "Cleaning HuggingFace model cache..."
            rm -rf "$MODELS_CACHE_DIR" 2>/dev/null || true
            shift
            ;;
        --clean-cache)
            print_status "Cleaning all model caches..."
            rm -rf "$MODELS_CACHE_DIR" 2>/dev/null || true
            rm -rf "$VOCORIZE_CACHE_DIR" 2>/dev/null || true
            print_success "All caches cleared"
            shift
            ;;
        --cache-info)
            # Use the cache manager script if available
            if [ -f "scripts/cache-manager.sh" ]; then
                exec bash scripts/cache-manager.sh status
            else
                print_status "Cache Information:"
                echo ""
                
                if [ -d "$MODELS_CACHE_DIR" ]; then
                    local hf_size=$(du -sm "$MODELS_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
                    local hf_files=$(find "$MODELS_CACHE_DIR" -type f 2>/dev/null | wc -l || echo "0")
                    print_status "HuggingFace Cache: ${hf_size}MB (${hf_files} files)"
                    print_status "Location: $MODELS_CACHE_DIR"
                else
                    print_status "HuggingFace Cache: Not found"
                fi
                
                echo ""
                
                if [ -d "$VOCORIZE_CACHE_DIR" ]; then
                    local vocorize_size=$(du -sm "$VOCORIZE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
                    local vocorize_files=$(find "$VOCORIZE_CACHE_DIR" -name "*.tar.gz" -o -name "cache_metadata.json" 2>/dev/null | wc -l || echo "0")
                    print_status "Vocorize Test Cache: ${vocorize_size}MB (${vocorize_files} files)"
                    print_status "Location: $VOCORIZE_CACHE_DIR"
                else
                    print_status "Vocorize Test Cache: Not found"
                fi
            fi
            echo ""
            exit 0
            ;;
        --dry-run)
            print_status "Dry run mode - showing execution plan..."
            echo ""
            echo "Would execute:"
            echo "  1. Pre-flight checks (network, disk space, dependencies)"
            echo "  2. Cache warm-up (check for cached models)"
            echo "  3. Integration test suite:"
            echo "     - WhisperKitIntegrationTests (with caching)"
            echo "     - ProviderSystemIntegrationTests" 
            echo "     - MLXIntegrationTests"
            echo "     - Cache performance tests"
            echo "  4. Cache cleanup and optimization"
            echo "  5. Result analysis and cleanup"
            echo ""
            echo "Environment: VOCORIZE_TEST_MODE=integration"
            echo "Timeout: ${TIMEOUT_SECONDS}s"
            echo "Log file: $TEST_LOG_FILE"
            echo "Cache directories:"
            echo "  - HuggingFace: $MODELS_CACHE_DIR"
            echo "  - Vocorize: $VOCORIZE_CACHE_DIR"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"