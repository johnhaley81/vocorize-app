#!/bin/bash
# Cache Performance Demonstration Script
# 
# Demonstrates the performance improvement provided by the model caching system
# Shows before/after comparison of test execution times

set -e

# Configuration
export VOCORIZE_TEST_MODE=integration
MODELS_CACHE_DIR="$HOME/.cache/huggingface/hub"
VOCORIZE_CACHE_DIR="$HOME/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}================================================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================================================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if in correct directory
check_environment() {
    if [ ! -f "Vocorize.xcodeproj/project.pbxproj" ]; then
        print_error "Not in Vocorize project root directory"
        exit 1
    fi
    
    if ! command -v xcodebuild >/dev/null 2>&1; then
        print_error "xcodebuild not found. Please install Xcode Command Line Tools."
        exit 1
    fi
}

# Get cache size
get_cache_size() {
    local total_size=0
    
    if [ -d "$MODELS_CACHE_DIR" ]; then
        local hf_size=$(du -sm "$MODELS_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
        total_size=$((total_size + hf_size))
    fi
    
    if [ -d "$VOCORIZE_CACHE_DIR" ]; then
        local vocorize_size=$(du -sm "$VOCORIZE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
        total_size=$((total_size + vocorize_size))
    fi
    
    echo $total_size
}

# Run a single integration test
run_single_test() {
    local test_name="$1"
    local start_time=$(date +%s)
    
    print_status "Running test: $test_name"
    
    if xcodebuild test \
        -scheme Vocorize \
        -destination 'platform=macOS,arch=arm64' \
        -only-testing:"VocorizeTests/$test_name" \
        -quiet >/dev/null 2>&1; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "Test completed in ${duration}s"
        return $duration
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_error "Test failed after ${duration}s"
        return $duration
    fi
}

# Clear all caches
clear_all_caches() {
    print_status "Clearing all caches..."
    rm -rf "$MODELS_CACHE_DIR" 2>/dev/null || true
    rm -rf "$VOCORIZE_CACHE_DIR" 2>/dev/null || true
    print_success "All caches cleared"
}

# Show cache status
show_cache_status() {
    local total_size=$(get_cache_size)
    
    if [ $total_size -gt 0 ]; then
        print_status "Cache Status: ${total_size}MB total"
        
        if [ -d "$MODELS_CACHE_DIR" ]; then
            local hf_size=$(du -sm "$MODELS_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
            print_status "  HuggingFace: ${hf_size}MB"
        fi
        
        if [ -d "$VOCORIZE_CACHE_DIR" ]; then
            local vocorize_size=$(du -sm "$VOCORIZE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
            print_status "  Vocorize: ${vocorize_size}MB"
            
            if [ -f "$VOCORIZE_CACHE_DIR/cache_metadata.json" ]; then
                local model_count=$(python3 -c "
import json
try:
    with open('$VOCORIZE_CACHE_DIR/cache_metadata.json', 'r') as f:
        data = json.load(f)
    print(len(data))
except:
    print(0)
" 2>/dev/null)
                print_status "  Cached Models: $model_count"
            fi
        fi
    else
        print_warning "No caches found"
    fi
}

# Main demonstration
main() {
    print_header "Vocorize Model Cache Performance Demonstration"
    
    print_status "This script demonstrates the performance improvement from model caching"
    print_status "It will run the same test twice: once without cache, once with cache"
    echo ""
    
    read -p "Do you want to continue? This will take 5-15 minutes. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Demo cancelled by user"
        exit 0
    fi
    
    check_environment
    
    # Test configuration
    local test_name="WhisperKitIntegrationTests/realModelDownload_downloadsTinyModelFromHuggingFace"
    
    print_header "Phase 1: Cold Cache Test (No Cache)"
    
    # Clear all caches to ensure cold start
    clear_all_caches
    show_cache_status
    
    print_status "Running test without cache (this will be slow)..."
    local cold_time=$(run_single_test "$test_name")
    
    print_status "Cache status after first run:"
    show_cache_status
    
    print_header "Phase 2: Warm Cache Test (With Cache)"
    
    print_status "Running same test with cache (this should be much faster)..."
    local warm_time=$(run_single_test "$test_name")
    
    print_status "Final cache status:"
    show_cache_status
    
    print_header "Performance Comparison Results"
    
    echo "Test Results:"
    echo "  Cold Cache (first run): ${cold_time}s"
    echo "  Warm Cache (second run): ${warm_time}s"
    echo ""
    
    if [ $warm_time -lt $cold_time ]; then
        local improvement=$((cold_time - warm_time))
        local percentage=$(((cold_time - warm_time) * 100 / cold_time))
        
        print_success "Cache Performance Improvement:"
        print_success "  Time saved: ${improvement}s"
        print_success "  Speed improvement: ${percentage}%"
        print_success "  Cache is working effectively!"
        
        if [ $improvement -gt 60 ]; then
            print_success "  \u2705 Excellent improvement (>1 minute saved)"
        elif [ $improvement -gt 30 ]; then
            print_success "  \u2705 Good improvement (>30 seconds saved)"
        else
            print_warning "  \u26a0\ufe0f Modest improvement (<30 seconds saved)"
        fi
    else
        print_warning "No performance improvement detected"
        print_warning "This might indicate:"
        print_warning "  - Cache is not working properly"
        print_warning "  - Model was already cached from previous runs"
        print_warning "  - Network is very fast for this model"
    fi
    
    echo ""
    print_header "Cache System Analysis"
    
    local final_cache_size=$(get_cache_size)
    
    if [ $final_cache_size -gt 0 ]; then
        print_status "Cache Efficiency Analysis:"
        print_status "  Cache Size: ${final_cache_size}MB"
        print_status "  Models Cached: Available for future runs"
        print_status "  Expected Future Performance: ~${warm_time}s per run"
        print_status "  Time Savings for CI/CD: ${improvement}s per test run"
        
        echo ""
        print_success "Cache system is functioning correctly!"
        print_success "Future integration test runs will be significantly faster"
    else
        print_error "Cache appears to be empty after tests"
        print_error "This indicates a problem with the caching system"
    fi
    
    echo ""
    print_status "To manage caches in the future:"
    print_status "  Show cache status: scripts/cache-manager.sh status"
    print_status "  Clean caches: scripts/cache-manager.sh clean"
    print_status "  Verify cache: scripts/cache-manager.sh verify"
    
    echo ""
    print_header "Demo Completed"
    print_success "The model caching system demonstration is complete"
    
    if [ $warm_time -lt $cold_time ]; then
        print_success "Your integration tests will now run ${improvement}s faster!"
    fi
}

# Run the demonstration
main "$@"