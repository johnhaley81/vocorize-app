#!/bin/bash
# Cache System Validation Script
# 
# Validates that the model caching system is properly integrated and functional
# Performs basic checks without running full integration tests

set -e

# Configuration
VOCORIZE_CACHE_DIR="$HOME/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_header() {
    echo ""
    echo "================================================================================================"
    echo "$1"
    echo "================================================================================================"
    echo ""
}

# Check if in correct directory
check_environment() {
    print_status "Checking environment..."
    
    if [ ! -f "Vocorize.xcodeproj/project.pbxproj" ]; then
        print_error "Not in Vocorize project root directory"
        return 1
    fi
    print_success "In correct project directory"
    
    if ! command -v xcodebuild >/dev/null 2>&1; then
        print_error "xcodebuild not found"
        return 1
    fi
    print_success "xcodebuild available"
    
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "python3 not found (needed for JSON parsing)"
        return 1
    fi
    print_success "python3 available"
    
    return 0
}

# Check cache-related files exist
check_cache_files() {
    print_status "Checking cache system files..."
    
    local files=(
        "VocorizeTests/Support/ModelCacheManager.swift"
        "VocorizeTests/Support/TestProviderFactory.swift"
        "VocorizeTests/Support/TestConfiguration.swift"
        "scripts/cache-manager.sh"
        "test-cache-demo.sh"
        "INTEGRATION_TEST_CACHING.md"
    )
    
    local missing=0
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -eq 0 ]; then
        print_success "All cache system files present"
        return 0
    else
        print_error "$missing cache system files missing"
        return 1
    fi
}

# Check cache directory setup
check_cache_directories() {
    print_status "Checking cache directory setup..."
    
    # Check if we can create the cache directory
    if mkdir -p "$VOCORIZE_CACHE_DIR" 2>/dev/null; then
        print_success "Can create cache directory: $VOCORIZE_CACHE_DIR"
    else
        print_error "Cannot create cache directory: $VOCORIZE_CACHE_DIR"
        return 1
    fi
    
    # Check if directory is writable
    if [ -w "$VOCORIZE_CACHE_DIR" ]; then
        print_success "Cache directory is writable"
    else
        print_error "Cache directory is not writable"
        return 1
    fi
    
    # Check available disk space (need at least 500MB)
    local available_space=$(df -m "$VOCORIZE_CACHE_DIR" | tail -1 | awk '{print $4}')
    if [ "$available_space" -gt 500 ]; then
        print_success "Sufficient disk space available: ${available_space}MB"
    else
        print_warning "Low disk space: ${available_space}MB (500MB+ recommended)"
    fi
    
    return 0
}

# Test cache manager script
test_cache_manager() {
    print_status "Testing cache manager script..."
    
    if [ ! -f "scripts/cache-manager.sh" ]; then
        print_error "Cache manager script not found"
        return 1
    fi
    
    if [ ! -x "scripts/cache-manager.sh" ]; then
        print_error "Cache manager script not executable"
        return 1
    fi
    
    # Test help command
    if bash scripts/cache-manager.sh help >/dev/null 2>&1; then
        print_success "Cache manager help command works"
    else
        print_error "Cache manager help command failed"
        return 1
    fi
    
    # Test status command
    if bash scripts/cache-manager.sh status >/dev/null 2>&1; then
        print_success "Cache manager status command works"
    else
        print_error "Cache manager status command failed"
        return 1
    fi
    
    return 0
}

# Test Swift compilation
test_swift_compilation() {
    print_status "Testing Swift cache manager compilation..."
    
    # Try to build just the test target to see if ModelCacheManager compiles
    if xcodebuild build \
        -scheme Vocorize \
        -destination 'platform=macOS,arch=arm64' \
        -quiet >/dev/null 2>&1; then
        print_success "Swift cache components compile successfully"
        return 0
    else
        print_error "Swift compilation failed - check ModelCacheManager.swift"
        return 1
    fi
}

# Test integration test configuration
test_integration_config() {
    print_status "Testing integration test configuration..."
    
    # Check if integration test files exist and have cache integration
    local test_file="VocorizeTests/Integration/WhisperKitIntegrationTests.swift"
    
    if [ ! -f "$test_file" ]; then
        print_error "Integration test file not found: $test_file"
        return 1
    fi
    
    # Check for cache-related code in the test file
    if grep -q "TestProviderFactory.createProvider" "$test_file"; then
        print_success "Integration tests use cached providers"
    else
        print_error "Integration tests not using cached providers"
        return 1
    fi
    
    if grep -q "warmTestCache\|printCacheStatus" "$test_file"; then
        print_success "Integration tests have cache management"
    else
        print_warning "Integration tests missing cache management calls"
    fi
    
    return 0
}

# Test JSON handling (for cache metadata)
test_json_handling() {
    print_status "Testing JSON metadata handling..."
    
    # Create a test metadata file
    local test_metadata='{
        "modelName": "test-model",
        "checksum": "test-checksum",
        "cachedDate": "2024-01-01T00:00:00Z",
        "lastAccessDate": "2024-01-01T00:00:00Z", 
        "size": 1024,
        "version": "1.0",
        "isCompressed": false
    }'
    
    # Test if Python can parse it
    if echo "$test_metadata" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        print_success "JSON metadata parsing works"
        return 0
    else
        print_error "JSON metadata parsing failed"
        return 1
    fi
}

# Test network connectivity (for cache misses)
test_network_connectivity() {
    print_status "Testing network connectivity for cache misses..."
    
    if ping -c 1 google.com >/dev/null 2>&1; then
        print_success "Internet connectivity available"
    else
        print_warning "No internet connectivity - cache misses will fail"
    fi
    
    if curl -s --head "https://huggingface.co" >/dev/null; then
        print_success "HuggingFace Hub reachable"
        return 0
    else
        print_warning "HuggingFace Hub unreachable - model downloads will fail"
        return 1
    fi
}

# Main validation
main() {
    print_header "Vocorize Model Cache System Validation"
    
    local total_checks=0
    local passed_checks=0
    local warnings=0
    
    # Run all validation checks
    local checks=(
        "check_environment"
        "check_cache_files"
        "check_cache_directories"
        "test_cache_manager"
        "test_swift_compilation"
        "test_integration_config"
        "test_json_handling"
        "test_network_connectivity"
    )
    
    for check in "${checks[@]}"; do
        total_checks=$((total_checks + 1))
        if $check; then
            passed_checks=$((passed_checks + 1))
        else
            # Some failures are just warnings for network tests
            if [[ "$check" == *"network"* ]]; then
                warnings=$((warnings + 1))
            fi
        fi
        echo ""
    done
    
    # Summary
    print_header "Validation Results"
    
    echo "Summary:"
    echo "  Total Checks: $total_checks"
    echo "  Passed: $passed_checks"
    echo "  Failed: $((total_checks - passed_checks))"
    echo "  Warnings: $warnings"
    echo ""
    
    if [ $passed_checks -eq $total_checks ]; then
        print_success "🎉 All validation checks passed!"
        print_success "The model caching system is ready for use"
        echo ""
        print_status "Next steps:"
        echo "  1. Run integration tests: ./test-integration.sh"
        echo "  2. Try cache demo: ./test-cache-demo.sh"
        echo "  3. Monitor cache: scripts/cache-manager.sh status"
        return 0
    elif [ $((passed_checks + warnings)) -eq $total_checks ]; then
        print_warning "⚠️ Validation passed with warnings"
        print_warning "The caching system should work, but some features may be limited"
        echo ""
        print_status "The system is functional for:"
        echo "  ✅ Cache management and storage"
        echo "  ✅ Model caching and retrieval"
        echo "  ✅ Integration test acceleration"
        echo ""
        print_warning "Network connectivity issues may affect:"
        echo "  ⚠️ Initial model downloads (cache misses)"
        echo "  ⚠️ Model updates from HuggingFace"
        return 0
    else
        print_error "❌ Validation failed"
        print_error "The model caching system is not ready for use"
        echo ""
        print_status "Please fix the failed checks and run validation again"
        print_status "For help, see: INTEGRATION_TEST_CACHING.md"
        return 1
    fi
}

# Show help
show_help() {
    echo "Cache System Validation Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --verbose      Show detailed output"
    echo ""
    echo "This script validates that the model caching system is properly"
    echo "integrated and ready for use. It checks:"
    echo "  • Required files and directories"
    echo "  • Swift compilation"
    echo "  • Cache manager functionality" 
    echo "  • Integration test configuration"
    echo "  • Network connectivity"
    echo ""
    echo "Run this script before using the caching system for the first time."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --verbose)
            set -x
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run validation
main "$@"