#!/bin/bash
# Intelligent Cache Management Script for Vocorize CI/CD Workflows
# 
# This script provides unified cache management across all workflows with:
# - 3-layer caching strategy (Swift packages, ML models, build artifacts)
# - Intelligent cache key management for maximum hit rates
# - 2GB cache size limits with LRU cleanup
# - Cache restore key hierarchies optimized for each workflow type
# - Cache invalidation during transitions

set -e

# Configuration
SCRIPT_VERSION="1.0.0"
CACHE_SIZE_LIMIT_GB=2
CACHE_SIZE_LIMIT_BYTES=$((CACHE_SIZE_LIMIT_GB * 1024 * 1024 * 1024))

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[CACHE-SETUP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[CACHE-SETUP]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[CACHE-SETUP]${NC} $1"
}

log_error() {
    echo -e "${RED}[CACHE-SETUP]${NC} $1"
}

log_performance() {
    echo -e "${PURPLE}[CACHE-PERF]${NC} $1"
}

log_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Cache paths - standardized across all workflows
SWIFT_CACHE_PATHS=(
    ".build"
    "~/Library/Developer/Xcode/DerivedData"
    "~/Library/Caches/org.swift.swiftpm"
)

ML_MODEL_CACHE_PATHS=(
    "~/Library/Caches/whisperkit"
    "~/.cache/huggingface"
    "~/Library/Caches/mlx-community"
    "~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache"
)

BUILD_ARTIFACT_CACHE_PATHS=(
    "build"
    "*.xcarchive"
    "DerivedData/Build"
    "performance-reports"
)

# Generate optimal cache key for Swift packages
generate_swift_cache_key() {
    local workflow_type="$1"
    local runner_os="$2"
    local xcode_version="$3"
    
    # Primary key includes Package.resolved hash and Xcode version
    local package_hash=$(shasum -a 256 Package.resolved Vocorize.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null | shasum -a 256 | cut -d' ' -f1 | head -c 12)
    local xcode_short="${xcode_version//./}"
    
    echo "${runner_os}-swift-${workflow_type}-xcode${xcode_short}-${package_hash}"
}

# Generate optimal cache key for ML models
generate_ml_cache_key() {
    local workflow_type="$1"
    local runner_os="$2"
    local model_set="$3"
    local cache_version="$4"
    
    # Include model set and cache version for targeted invalidation
    echo "${runner_os}-models-${workflow_type}-${model_set}-v${cache_version}"
}

# Generate optimal cache key for build artifacts
generate_build_cache_key() {
    local workflow_type="$1"
    local runner_os="$2"
    local build_config="$3"
    
    # Include source code hash for build artifact invalidation
    local source_hash=$(find Vocorize VocorizeTests -name "*.swift" -type f -exec shasum -a 256 {} \; 2>/dev/null | shasum -a 256 | cut -d' ' -f1 | head -c 12)
    
    echo "${runner_os}-build-${workflow_type}-${build_config}-${source_hash}"
}

# Create cache restore key hierarchy
create_restore_keys() {
    local primary_key="$1"
    local workflow_type="$2"
    local runner_os="$3"
    
    # Extract components from primary key
    local base_key="${primary_key%%-*}"
    local type_key="${base_key}-${workflow_type}"
    
    # Create hierarchical fallback keys for maximum hit rate
    echo "${primary_key}"
    echo "${type_key}"
    echo "${base_key}"
}

# Setup Swift Package Manager cache
setup_swift_cache() {
    local workflow_type="$1"
    local runner_os="$2"
    local xcode_version="$3"
    
    log_header "Swift Package Manager Cache Setup"
    
    # Generate optimal cache keys
    local primary_key=$(generate_swift_cache_key "$workflow_type" "$runner_os" "$xcode_version")
    local restore_keys=$(create_restore_keys "$primary_key" "$workflow_type" "$runner_os")
    
    log_info "Primary cache key: $primary_key"
    log_info "Cache paths: ${SWIFT_CACHE_PATHS[*]}"
    
    # Export for workflow use
    echo "SWIFT_CACHE_KEY=$primary_key" >> $GITHUB_OUTPUT
    echo "SWIFT_CACHE_PATHS=${SWIFT_CACHE_PATHS[*]}" >> $GITHUB_OUTPUT
    echo "SWIFT_RESTORE_KEYS<<EOF" >> $GITHUB_OUTPUT
    echo "$restore_keys" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT
    
    # Create cache directories
    for path in "${SWIFT_CACHE_PATHS[@]}"; do
        # Expand tilde if present
        expanded_path="${path/#\~/$HOME}"
        mkdir -p "$expanded_path" 2>/dev/null || true
    done
    
    log_success "Swift cache configuration completed"
}

# Setup ML model cache
setup_ml_cache() {
    local workflow_type="$1"
    local runner_os="$2"
    local model_set="${3:-none}"
    local cache_version="${4:-1}"
    
    log_header "ML Model Cache Setup"
    
    # Skip ML cache for unit-only workflows
    if [[ "$workflow_type" == "pr-validation" ]] && [[ "$model_set" == "none" ]]; then
        log_info "Skipping ML cache for unit-only workflow"
        echo "ML_CACHE_ENABLED=false" >> $GITHUB_OUTPUT
        return 0
    fi
    
    # Generate optimal cache keys
    local primary_key=$(generate_ml_cache_key "$workflow_type" "$runner_os" "$model_set" "$cache_version")
    local restore_keys=$(create_restore_keys "$primary_key" "$workflow_type" "$runner_os")
    
    log_info "Primary cache key: $primary_key"
    log_info "Model set: $model_set"
    log_info "Cache paths: ${ML_MODEL_CACHE_PATHS[*]}"
    
    # Export for workflow use
    echo "ML_CACHE_KEY=$primary_key" >> $GITHUB_OUTPUT
    echo "ML_CACHE_PATHS=${ML_MODEL_CACHE_PATHS[*]}" >> $GITHUB_OUTPUT
    echo "ML_RESTORE_KEYS<<EOF" >> $GITHUB_OUTPUT
    echo "$restore_keys" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT
    echo "ML_CACHE_ENABLED=true" >> $GITHUB_OUTPUT
    
    # Create cache directories
    for path in "${ML_MODEL_CACHE_PATHS[@]}"; do
        # Expand tilde if present
        expanded_path="${path/#\~/$HOME}"
        mkdir -p "$expanded_path" 2>/dev/null || true
    done
    
    log_success "ML cache configuration completed"
}

# Setup build artifact cache
setup_build_cache() {
    local workflow_type="$1"
    local runner_os="$2"
    local build_config="${3:-Debug}"
    
    log_header "Build Artifact Cache Setup"
    
    # Generate optimal cache keys
    local primary_key=$(generate_build_cache_key "$workflow_type" "$runner_os" "$build_config")
    local restore_keys=$(create_restore_keys "$primary_key" "$workflow_type" "$runner_os")
    
    log_info "Primary cache key: $primary_key"
    log_info "Build config: $build_config"
    log_info "Cache paths: ${BUILD_ARTIFACT_CACHE_PATHS[*]}"
    
    # Export for workflow use
    echo "BUILD_CACHE_KEY=$primary_key" >> $GITHUB_OUTPUT
    echo "BUILD_CACHE_PATHS=${BUILD_ARTIFACT_CACHE_PATHS[*]}" >> $GITHUB_OUTPUT
    echo "BUILD_RESTORE_KEYS<<EOF" >> $GITHUB_OUTPUT
    echo "$restore_keys" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT
    
    # Create cache directories
    for path in "${BUILD_ARTIFACT_CACHE_PATHS[@]}"; do
        # Skip glob patterns for directory creation
        if [[ "$path" != *"*"* ]]; then
            mkdir -p "$path" 2>/dev/null || true
        fi
    done
    
    log_success "Build cache configuration completed"
}

# Check cache sizes and cleanup if needed
manage_cache_sizes() {
    log_header "Cache Size Management"
    
    local total_size=0
    
    # Calculate total cache size
    for path_group in "${SWIFT_CACHE_PATHS[@]}" "${ML_MODEL_CACHE_PATHS[@]}" "${BUILD_ARTIFACT_CACHE_PATHS[@]}"; do
        expanded_path="${path_group/#\~/$HOME}"
        if [ -d "$expanded_path" ]; then
            local dir_size=$(du -sb "$expanded_path" 2>/dev/null | cut -f1 || echo "0")
            total_size=$((total_size + dir_size))
        fi
    done
    
    local total_size_gb=$(echo "scale=2; $total_size / 1024 / 1024 / 1024" | bc)
    log_info "Total cache size: ${total_size_gb}GB"
    
    if [ "$total_size" -gt "$CACHE_SIZE_LIMIT_BYTES" ]; then
        log_warning "Cache size exceeds ${CACHE_SIZE_LIMIT_GB}GB limit"
        cleanup_lru_cache
    else
        log_success "Cache size within limits"
    fi
    
    # Export cache metrics
    echo "CACHE_TOTAL_SIZE_GB=$total_size_gb" >> $GITHUB_OUTPUT
    echo "CACHE_SIZE_OK=$([[ $total_size -le $CACHE_SIZE_LIMIT_BYTES ]] && echo "true" || echo "false")" >> $GITHUB_OUTPUT
}

# LRU cache cleanup
cleanup_lru_cache() {
    log_info "Performing LRU cache cleanup..."
    
    # Priority cleanup order:
    # 1. Old build artifacts (least critical)
    # 2. Unused model caches
    # 3. Old Swift package caches
    
    # Cleanup old build artifacts first
    find . -name "*.xcarchive" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    find . -name "build" -type d -mtime +3 -exec rm -rf {} \; 2>/dev/null || true
    
    # Cleanup old model caches
    find ~/Library/Caches/whisperkit -type d -mtime +14 -exec rm -rf {} \; 2>/dev/null || true
    find ~/.cache/huggingface -type d -mtime +14 -exec rm -rf {} \; 2>/dev/null || true
    
    # Use cache-manager.sh for intelligent cleanup if available
    if [ -f "scripts/cache-manager.sh" ]; then
        log_info "Using cache-manager.sh for intelligent cleanup"
        bash scripts/cache-manager.sh optimize
    fi
    
    log_success "LRU cleanup completed"
}

# Optimize cache for specific workflow patterns
optimize_for_workflow() {
    local workflow_type="$1"
    
    log_header "Workflow-Specific Optimization"
    
    case "$workflow_type" in
        "pr-validation")
            # Fast feedback - aggressive Swift caching, no ML models
            log_info "Optimizing for PR validation: aggressive Swift caching"
            echo "CACHE_STRATEGY=aggressive-swift" >> $GITHUB_OUTPUT
            echo "CACHE_PRIORITY=speed" >> $GITHUB_OUTPUT
            ;;
        "main-validation")
            # Balanced - Swift + critical ML models
            log_info "Optimizing for main validation: balanced caching"
            echo "CACHE_STRATEGY=balanced" >> $GITHUB_OUTPUT
            echo "CACHE_PRIORITY=reliability" >> $GITHUB_OUTPUT
            ;;
        "nightly-tests")
            # Comprehensive - all caches, persistent storage
            log_info "Optimizing for nightly tests: comprehensive caching"
            echo "CACHE_STRATEGY=comprehensive" >> $GITHUB_OUTPUT
            echo "CACHE_PRIORITY=coverage" >> $GITHUB_OUTPUT
            ;;
        "release-validation")
            # Complete validation - minimal caching for clean builds
            log_info "Optimizing for release validation: minimal caching"
            echo "CACHE_STRATEGY=minimal" >> $GITHUB_OUTPUT
            echo "CACHE_PRIORITY=correctness" >> $GITHUB_OUTPUT
            ;;
        *)
            log_warning "Unknown workflow type: $workflow_type"
            echo "CACHE_STRATEGY=default" >> $GITHUB_OUTPUT
            echo "CACHE_PRIORITY=balanced" >> $GITHUB_OUTPUT
            ;;
    esac
    
    log_success "Workflow optimization completed"
}

# Generate cache metrics and analytics
generate_cache_metrics() {
    log_header "Cache Analytics"
    
    # Calculate cache efficiency metrics
    local swift_cache_size=0
    local ml_cache_size=0
    local build_cache_size=0
    
    for path in "${SWIFT_CACHE_PATHS[@]}"; do
        expanded_path="${path/#\~/$HOME}"
        if [ -d "$expanded_path" ]; then
            local size=$(du -sb "$expanded_path" 2>/dev/null | cut -f1 || echo "0")
            swift_cache_size=$((swift_cache_size + size))
        fi
    done
    
    for path in "${ML_MODEL_CACHE_PATHS[@]}"; do
        expanded_path="${path/#\~/$HOME}"
        if [ -d "$expanded_path" ]; then
            local size=$(du -sb "$expanded_path" 2>/dev/null | cut -f1 || echo "0")
            ml_cache_size=$((ml_cache_size + size))
        fi
    done
    
    for path in "${BUILD_ARTIFACT_CACHE_PATHS[@]}"; do
        if [[ "$path" != *"*"* ]] && [ -d "$path" ]; then
            local size=$(du -sb "$path" 2>/dev/null | cut -f1 || echo "0")
            build_cache_size=$((build_cache_size + size))
        fi
    done
    
    # Convert to MB for readability
    local swift_mb=$((swift_cache_size / 1024 / 1024))
    local ml_mb=$((ml_cache_size / 1024 / 1024))
    local build_mb=$((build_cache_size / 1024 / 1024))
    local total_mb=$((swift_mb + ml_mb + build_mb))
    
    log_performance "Cache breakdown:"
    log_performance "  Swift packages: ${swift_mb}MB"
    log_performance "  ML models: ${ml_mb}MB"
    log_performance "  Build artifacts: ${build_mb}MB"
    log_performance "  Total: ${total_mb}MB"
    
    # Export metrics for workflow use
    echo "SWIFT_CACHE_SIZE_MB=$swift_mb" >> $GITHUB_OUTPUT
    echo "ML_CACHE_SIZE_MB=$ml_mb" >> $GITHUB_OUTPUT
    echo "BUILD_CACHE_SIZE_MB=$build_mb" >> $GITHUB_OUTPUT
    echo "TOTAL_CACHE_SIZE_MB=$total_mb" >> $GITHUB_OUTPUT
    
    # Calculate estimated time savings
    local estimated_savings_min=0
    if [ $swift_mb -gt 50 ]; then
        estimated_savings_min=$((estimated_savings_min + 2))
    fi
    if [ $ml_mb -gt 100 ]; then
        estimated_savings_min=$((estimated_savings_min + 15))
    fi
    if [ $build_mb -gt 50 ]; then
        estimated_savings_min=$((estimated_savings_min + 5))
    fi
    
    log_performance "Estimated time savings: ${estimated_savings_min} minutes"
    echo "CACHE_TIME_SAVINGS_MIN=$estimated_savings_min" >> $GITHUB_OUTPUT
    
    log_success "Cache analytics completed"
}

# Validate cache integrity
validate_cache_integrity() {
    log_header "Cache Integrity Validation"
    
    local integrity_issues=0
    
    # Check for corrupted Swift packages
    if [ -d ".build" ]; then
        # Look for incomplete builds
        if find .build -name "*.incomplete" -o -name "*.lock" | grep -q .; then
            log_warning "Found incomplete Swift package builds"
            integrity_issues=$((integrity_issues + 1))
        fi
    fi
    
    # Check for corrupted ML models using existing cache-manager
    if [ -f "scripts/cache-manager.sh" ]; then
        if ! bash scripts/cache-manager.sh verify > /dev/null 2>&1; then
            log_warning "ML model cache integrity issues detected"
            integrity_issues=$((integrity_issues + 1))
        fi
    fi
    
    # Check for corrupted build artifacts
    if find . -name "*.xcarchive" -type d -exec test -f {}/Info.plist \; 2>/dev/null | head -1; then
        log_info "Build archives appear valid"
    else
        if find . -name "*.xcarchive" -type d | head -1; then
            log_warning "Found invalid build archives"
            integrity_issues=$((integrity_issues + 1))
        fi
    fi
    
    if [ $integrity_issues -eq 0 ]; then
        log_success "Cache integrity validation passed"
        echo "CACHE_INTEGRITY_OK=true" >> $GITHUB_OUTPUT
    else
        log_warning "Found $integrity_issues cache integrity issues"
        echo "CACHE_INTEGRITY_OK=false" >> $GITHUB_OUTPUT
        echo "CACHE_INTEGRITY_ISSUES=$integrity_issues" >> $GITHUB_OUTPUT
    fi
}

# Main setup function
setup_cache() {
    local workflow_type="$1"
    local runner_os="${2:-macos}"
    local xcode_version="${3:-15.4}"
    local model_set="${4:-none}"
    local build_config="${5:-Debug}"
    local cache_version="${6:-1}"
    
    log_header "Intelligent Cache Setup v${SCRIPT_VERSION}"
    
    log_info "Configuration:"
    log_info "  Workflow: $workflow_type"
    log_info "  Runner OS: $runner_os"
    log_info "  Xcode: $xcode_version"
    log_info "  Model Set: $model_set"
    log_info "  Build Config: $build_config"
    log_info "  Cache Version: $cache_version"
    
    # Setup each cache layer
    setup_swift_cache "$workflow_type" "$runner_os" "$xcode_version"
    setup_ml_cache "$workflow_type" "$runner_os" "$model_set" "$cache_version"
    setup_build_cache "$workflow_type" "$runner_os" "$build_config"
    
    # Management and optimization
    manage_cache_sizes
    optimize_for_workflow "$workflow_type"
    generate_cache_metrics
    validate_cache_integrity
    
    log_success "Intelligent cache setup completed successfully"
}

# Cache invalidation for transitions
invalidate_transition_cache() {
    local from_branch="$1"
    local to_branch="$2"
    
    log_header "Cache Invalidation for Branch Transition"
    
    log_info "Transition: $from_branch → $to_branch"
    
    # Invalidate Swift caches on major transitions
    if [[ "$from_branch" == "develop" && "$to_branch" == "main" ]] || 
       [[ "$from_branch" == "feature/"* && "$to_branch" == "main" ]]; then
        log_info "Major transition detected - clearing Swift build cache"
        rm -rf .build 2>/dev/null || true
        rm -rf build 2>/dev/null || true
    fi
    
    # Keep ML model caches - they're expensive to rebuild
    log_info "Preserving ML model caches (expensive to rebuild)"
    
    log_success "Cache invalidation completed"
}

# Show help
show_help() {
    cat << EOF
Intelligent Cache Management Script for Vocorize CI/CD

USAGE:
    $0 setup <workflow-type> [options]
    $0 invalidate <from-branch> <to-branch>
    $0 help

COMMANDS:
    setup       Setup intelligent caching for a workflow
    invalidate  Invalidate caches for branch transitions
    help        Show this help message

WORKFLOW TYPES:
    pr-validation      Fast feedback with aggressive Swift caching
    main-validation    Balanced Swift + critical ML model caching  
    nightly-tests      Comprehensive caching for all test suites
    release-validation Minimal caching for clean validation

SETUP OPTIONS:
    --runner-os <os>        Runner OS (default: macos)
    --xcode-version <ver>   Xcode version (default: 15.4)
    --model-set <set>       ML model set (default: none)
    --build-config <cfg>    Build configuration (default: Debug)
    --cache-version <ver>   Cache version for invalidation (default: 1)

EXAMPLES:
    # PR validation with fast Swift caching
    $0 setup pr-validation --xcode-version 16.2

    # Main branch with critical models
    $0 setup main-validation --model-set critical --cache-version 2

    # Nightly tests with comprehensive caching
    $0 setup nightly-tests --model-set all --build-config Release

    # Cache invalidation for branch transition
    $0 invalidate feature/my-branch main

FEATURES:
    ✅ 3-layer caching: Swift packages, ML models, build artifacts
    ✅ Intelligent cache keys for maximum hit rates
    ✅ 2GB size limits with LRU cleanup
    ✅ Workflow-specific optimization
    ✅ Cache integrity validation
    ✅ Performance analytics
    ✅ Branch transition management

OUTPUTS (for GitHub Actions):
    SWIFT_CACHE_KEY, SWIFT_CACHE_PATHS, SWIFT_RESTORE_KEYS
    ML_CACHE_KEY, ML_CACHE_PATHS, ML_RESTORE_KEYS
    BUILD_CACHE_KEY, BUILD_CACHE_PATHS, BUILD_RESTORE_KEYS
    CACHE_STRATEGY, CACHE_PRIORITY
    CACHE_TOTAL_SIZE_GB, CACHE_TIME_SAVINGS_MIN
    CACHE_INTEGRITY_OK, ML_CACHE_ENABLED

For more information, see: .github/CI_PIPELINE_GUIDE.md
EOF
}

# Parse command line arguments
parse_arguments() {
    local command="$1"
    shift
    
    case "$command" in
        "setup")
            local workflow_type="$1"
            shift
            
            if [ -z "$workflow_type" ]; then
                log_error "Workflow type is required for setup command"
                show_help
                exit 1
            fi
            
            # Parse options
            local runner_os="macos"
            local xcode_version="15.4"
            local model_set="none"
            local build_config="Debug"
            local cache_version="1"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --runner-os)
                        runner_os="$2"
                        shift 2
                        ;;
                    --xcode-version)
                        xcode_version="$2"
                        shift 2
                        ;;
                    --model-set)
                        model_set="$2"
                        shift 2
                        ;;
                    --build-config)
                        build_config="$2"
                        shift 2
                        ;;
                    --cache-version)
                        cache_version="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            setup_cache "$workflow_type" "$runner_os" "$xcode_version" "$model_set" "$build_config" "$cache_version"
            ;;
        "invalidate")
            local from_branch="$1"
            local to_branch="$2"
            
            if [ -z "$from_branch" ] || [ -z "$to_branch" ]; then
                log_error "Both from and to branches are required for invalidate command"
                exit 1
            fi
            
            invalidate_transition_cache "$from_branch" "$to_branch"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v bc > /dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    if ! command -v shasum > /dev/null 2>&1; then
        missing_deps+=("shasum")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies before running this script"
        exit 1
    fi
}

# Initialize GITHUB_OUTPUT if not in GitHub Actions
if [ -z "$GITHUB_OUTPUT" ]; then
    export GITHUB_OUTPUT="/tmp/github_output_$$"
    touch "$GITHUB_OUTPUT"
fi

# Main execution
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    parse_arguments "$@"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi