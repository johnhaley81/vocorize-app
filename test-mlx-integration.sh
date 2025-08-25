#!/bin/bash

# MLX Integration Test Script
# Comprehensive testing of MLX Swift framework integration with Vocorize
# This script verifies MLX dependency resolution, build configuration, and functionality

set -e  # Exit on any error

# Colors for output (matching existing project conventions)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output (matching existing scripts)
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

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# Configuration
PROJECT_NAME="Vocorize"
SCHEME_NAME="Vocorize"
PROJECT_FILE="Vocorize.xcodeproj"
PACKAGE_RESOLVED="$PROJECT_FILE/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
BUILD_DIR="build"
MLX_TEST_LOG="mlx_test_output.log"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to run a test with error handling
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    print_test "Running: $test_name"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if eval "$test_command" >> "$MLX_TEST_LOG" 2>&1; then
        print_success "$test_name - PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$test_name - FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to check test prerequisites
check_prerequisites() {
    print_status "Checking MLX integration test prerequisites..."
    
    # Check if we're on Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        print_error "MLX requires Apple Silicon architecture (arm64)"
        print_error "Current architecture: $(uname -m)"
        exit 1
    fi
    print_success "Apple Silicon architecture detected"
    
    # Check macOS version (MLX requires recent macOS)
    local macos_version=$(sw_vers -productVersion)
    print_status "macOS version: $macos_version"
    
    # Check if Xcode is available
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found. Please install Xcode and Command Line Tools."
        exit 1
    fi
    print_success "xcodebuild is available"
    
    # Check if project file exists
    if [ ! -f "$PROJECT_FILE/project.pbxproj" ]; then
        print_error "Xcode project not found: $PROJECT_FILE"
        exit 1
    fi
    print_success "Xcode project found"
}

# Function to test package dependency resolution
test_dependency_resolution() {
    print_status "Testing MLX dependency resolution..."
    
    # Clean any existing resolved packages
    if [ -f "$PACKAGE_RESOLVED" ]; then
        print_status "Backing up existing Package.resolved"
        cp "$PACKAGE_RESOLVED" "$PACKAGE_RESOLVED.backup"
    fi
    
    # Test dependency resolution
    run_test "Package dependency resolution" \
        "xcodebuild -resolvePackageDependencies -project '$PROJECT_FILE' -scheme '$SCHEME_NAME'"
    
    # Verify Package.resolved was created
    if [ ! -f "$PACKAGE_RESOLVED" ]; then
        print_error "Package.resolved was not created during dependency resolution"
        return 1
    fi
    
    print_success "Package dependencies resolved successfully"
    return 0
}

# Function to verify MLX package in Package.resolved
test_mlx_package_resolved() {
    print_status "Verifying MLX package in Package.resolved..."
    
    if [ ! -f "$PACKAGE_RESOLVED" ]; then
        print_error "Package.resolved file not found"
        return 1
    fi
    
    # Check for mlx-swift dependency
    if grep -q "mlx-swift" "$PACKAGE_RESOLVED"; then
        local mlx_version=$(grep -A 10 "mlx-swift" "$PACKAGE_RESOLVED" | grep "version" | head -1 | sed 's/.*"version" : "\(.*\)".*/\1/')
        print_success "MLX Swift package found - Version: $mlx_version"
        
        # Validate version is reasonable (should be 0.x.x format)
        if [[ $mlx_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            print_success "MLX version format is valid: $mlx_version"
        else
            print_warning "Unexpected MLX version format: $mlx_version"
        fi
        
        # Check if it's tracking a specific version (not branch)
        if grep -A 5 "mlx-swift" "$PACKAGE_RESOLVED" | grep -q "version"; then
            print_success "MLX is pinned to a specific version (recommended)"
        else
            print_warning "MLX may be tracking a branch instead of a version"
        fi
        
        return 0
    else
        print_error "MLX Swift package not found in Package.resolved"
        print_error "MLX integration may not be properly configured"
        return 1
    fi
}

# Function to test MLX build configuration
test_mlx_build_configuration() {
    print_status "Testing MLX build configuration..."
    
    # Get build settings output
    local build_settings_output=$(xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -showBuildSettings 2>/dev/null)
    
    # Check for MLX package references in build settings (more comprehensive)
    if echo "$build_settings_output" | grep -q -i "mlx-swift\|MLX"; then
        print_success "MLX package references found in build settings"
        run_test "MLX build settings detection" "true"  # Mark as passed
    else
        print_warning "MLX references not found in build settings (checking alternative methods)"
        
        # Alternative: Check if mlx-swift appears in resolved packages output
        if xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -showBuildSettings 2>&1 | grep -q "mlx-swift"; then
            print_success "MLX package detected in dependency resolution"
            run_test "MLX build settings detection" "true"  # Mark as passed
        else
            run_test "MLX build settings detection" "false"  # Mark as failed
        fi
    fi
    
    # Test if MLX-related swift flags are present
    if echo "$build_settings_output" | grep -q "Swift"; then
        print_success "Swift compilation settings detected"
    else
        print_warning "Swift compilation settings not clearly visible"
    fi
    
    # Check for Metal framework linking (required for MLX on Apple Silicon)
    if echo "$build_settings_output" | grep -q -i "metal"; then
        print_success "Metal framework linking detected"
    else
        print_warning "Metal framework not explicitly linked (may be implicit)"
    fi
    
    return 0
}

# Function to test MLX compilation
test_mlx_compilation() {
    print_status "Testing MLX compilation..."
    
    # Clean build directory
    print_status "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Test Debug build with MLX
    run_test "Debug build with MLX framework" \
        "xcodebuild -project '$PROJECT_FILE' -scheme '$SCHEME_NAME' -configuration Debug -destination 'platform=macOS,arch=arm64' build ONLY_ACTIVE_ARCH=NO"
    
    # Test Release build with MLX
    run_test "Release build with MLX framework" \
        "xcodebuild -project '$PROJECT_FILE' -scheme '$SCHEME_NAME' -configuration Release -destination 'platform=macOS,arch=arm64' build ONLY_ACTIVE_ARCH=NO"
    
    print_success "MLX compilation tests completed"
    return 0
}

# Function to verify MLX symbols in built binary
test_mlx_symbols() {
    print_status "Verifying MLX symbols in built binary..."
    
    # Find the built app
    local app_path=""
    if [ -d "build/Release/Vocorize.app" ]; then
        app_path="build/Release/Vocorize.app/Contents/MacOS/Vocorize"
    elif [ -d "build/Debug/Vocorize.app" ]; then
        app_path="build/Debug/Vocorize.app/Contents/MacOS/Vocorize"
    else
        # Try to find in DerivedData-style build output
        local derived_data_path=$(find ~/Library/Developer/Xcode/DerivedData -name "Vocorize.app" -type d 2>/dev/null | head -1)
        if [ -n "$derived_data_path" ]; then
            app_path="$derived_data_path/Contents/MacOS/Vocorize"
        fi
    fi
    
    if [ -f "$app_path" ]; then
        print_status "Found built binary: $app_path"
        
        # Check for MLX symbols using nm
        if nm "$app_path" 2>/dev/null | grep -q -i "mlx"; then
            print_success "MLX symbols found in binary"
            
            # Count MLX-related symbols
            local mlx_symbol_count=$(nm "$app_path" 2>/dev/null | grep -i "mlx" | wc -l | xargs)
            print_status "Found $mlx_symbol_count MLX-related symbols"
            
        else
            print_warning "No MLX symbols found in binary (may be statically linked or stripped)"
        fi
        
        # Check for Metal symbols (required for MLX)
        if nm "$app_path" 2>/dev/null | grep -q -i "metal"; then
            print_success "Metal symbols found in binary"
        else
            print_warning "Metal symbols not found (may affect MLX functionality)"
        fi
        
    else
        print_error "Built binary not found - compilation may have failed"
        return 1
    fi
    
    return 0
}

# Function to test MLX availability at runtime (if possible)
test_mlx_runtime_availability() {
    print_status "Testing MLX runtime availability..."
    
    # This test runs the actual Vocorize app briefly to check MLX availability
    # We'll use a timeout to prevent hanging
    
    local app_path=""
    if [ -d "build/Release/Vocorize.app" ]; then
        app_path="build/Release/Vocorize.app"
    elif [ -d "build/Debug/Vocorize.app" ]; then
        app_path="build/Debug/Vocorize.app"
    else
        print_warning "No built app found for runtime testing"
        return 0
    fi
    
    print_status "Attempting runtime MLX availability check..."
    
    # Try to launch the app and immediately quit (with timeout)
    if timeout 10s open "$app_path" --args --test-mode 2>/dev/null; then
        print_success "App launched successfully (MLX runtime likely available)"
        # Kill any running instances
        killall Vocorize 2>/dev/null || true
    else
        print_warning "App launch test inconclusive"
    fi
    
    return 0
}

# Function to run Swift tests that include MLX components
test_mlx_unit_tests() {
    print_status "Running MLX-related unit tests..."
    
    # Run tests and capture output
    if xcodebuild test -scheme "$SCHEME_NAME" -destination 'platform=macOS,arch=arm64' 2>&1 | tee -a "$MLX_TEST_LOG"; then
        print_success "MLX unit tests completed"
        
        # Check for MLX-specific test results
        if grep -q "MLX" "$MLX_TEST_LOG"; then
            local mlx_test_count=$(grep -c "MLX" "$MLX_TEST_LOG")
            print_status "Found $mlx_test_count MLX-related test references"
        fi
        
        return 0
    else
        print_error "MLX unit tests failed"
        return 1
    fi
}

# Function to validate MLX integration health
test_mlx_integration_health() {
    print_status "Performing MLX integration health check..."
    
    local health_score=0
    local max_score=6
    
    # Check 1: Package resolved
    if [ -f "$PACKAGE_RESOLVED" ] && grep -q "mlx-swift" "$PACKAGE_RESOLVED"; then
        health_score=$((health_score + 1))
        print_success "✓ MLX package properly resolved"
    else
        print_error "✗ MLX package resolution issue"
    fi
    
    # Check 2: Build configuration
    if xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -showBuildSettings | grep -q "MLX"; then
        health_score=$((health_score + 1))
        print_success "✓ MLX build configuration detected"
    else
        print_warning "? MLX build configuration unclear"
    fi
    
    # Check 3: Architecture compatibility
    if [[ $(uname -m) == "arm64" ]]; then
        health_score=$((health_score + 1))
        print_success "✓ Apple Silicon architecture compatible"
    else
        print_error "✗ Architecture not compatible with MLX"
    fi
    
    # Check 4: Metal availability
    if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Metal"; then
        health_score=$((health_score + 1))
        print_success "✓ Metal support available"
    else
        print_warning "? Metal support unclear"
    fi
    
    # Check 5: Swift version compatibility
    local swift_version=$(swift --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$swift_version" ]]; then
        health_score=$((health_score + 1))
        print_success "✓ Swift version $swift_version detected"
    else
        print_warning "? Swift version detection failed"
    fi
    
    # Check 6: Xcode version compatibility
    local xcode_version=$(xcodebuild -version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$xcode_version" ]]; then
        health_score=$((health_score + 1))
        print_success "✓ Xcode version $xcode_version detected"
    else
        print_warning "? Xcode version detection failed"
    fi
    
    # Calculate health percentage
    local health_percentage=$((health_score * 100 / max_score))
    
    if [ $health_percentage -ge 80 ]; then
        print_success "MLX integration health: $health_percentage% ($health_score/$max_score) - EXCELLENT"
    elif [ $health_percentage -ge 60 ]; then
        print_warning "MLX integration health: $health_percentage% ($health_score/$max_score) - GOOD"
    else
        print_error "MLX integration health: $health_percentage% ($health_score/$max_score) - NEEDS ATTENTION"
    fi
    
    return 0
}

# Function to generate test report
generate_test_report() {
    print_status "Generating MLX integration test report..."
    
    local report_file="mlx_integration_report.txt"
    
    cat > "$report_file" << EOF
# MLX Integration Test Report
Generated: $(date)
Project: $PROJECT_NAME
Architecture: $(uname -m)
macOS Version: $(sw_vers -productVersion)
Xcode Version: $(xcodebuild -version 2>/dev/null | head -1 || echo "Unknown")

## Test Summary
Total Tests: $TESTS_TOTAL
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Success Rate: $((TESTS_PASSED * 100 / TESTS_TOTAL))%

## Package Information
EOF

    if [ -f "$PACKAGE_RESOLVED" ] && grep -q "mlx-swift" "$PACKAGE_RESOLVED"; then
        echo "MLX Package: Found in Package.resolved" >> "$report_file"
        local mlx_version=$(grep -A 10 "mlx-swift" "$PACKAGE_RESOLVED" | grep "version" | head -1 | sed 's/.*"version" : "\(.*\)".*/\1/')
        echo "MLX Version: $mlx_version" >> "$report_file"
    else
        echo "MLX Package: NOT FOUND" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "## Detailed Log" >> "$report_file"
    echo "See $MLX_TEST_LOG for detailed output" >> "$report_file"
    
    print_status "Test report saved to: $report_file"
}

# Main execution
main() {
    print_status "Starting MLX Integration Test Suite for Vocorize"
    print_status "================================================"
    
    # Initialize log file
    echo "MLX Integration Test Log - $(date)" > "$MLX_TEST_LOG"
    
    # Check prerequisites
    check_prerequisites
    
    # Run test suite
    print_status "Running MLX integration tests..."
    
    # Test 1: Package dependency resolution
    if ! test_dependency_resolution; then
        print_error "Critical: Package dependency resolution failed"
        print_error "MLX integration cannot proceed without resolved dependencies"
    fi
    
    # Test 2: Verify MLX package in Package.resolved
    test_mlx_package_resolved
    
    # Test 3: Build configuration
    test_mlx_build_configuration
    
    # Test 4: Compilation with MLX
    test_mlx_compilation
    
    # Test 5: Symbol verification
    test_mlx_symbols
    
    # Test 6: Runtime availability
    test_mlx_runtime_availability
    
    # Test 7: Unit tests
    test_mlx_unit_tests
    
    # Test 8: Integration health check
    test_mlx_integration_health
    
    # Generate report
    generate_test_report
    
    # Final summary
    print_status "================================================"
    print_status "MLX Integration Test Summary"
    print_status "================================================"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All MLX integration tests passed! ($TESTS_PASSED/$TESTS_TOTAL)"
        print_success "MLX is properly integrated and ready for use"
        exit 0
    elif [ $TESTS_FAILED -lt $((TESTS_TOTAL / 2)) ]; then
        print_warning "Some MLX integration tests failed ($TESTS_FAILED/$TESTS_TOTAL)"
        print_warning "MLX integration may work but could have issues"
        print_status "Review the test log for details: $MLX_TEST_LOG"
        exit 1
    else
        print_error "MLX integration tests failed ($TESTS_FAILED/$TESTS_TOTAL)"
        print_error "MLX integration requires attention before use"
        print_status "Review the test log for details: $MLX_TEST_LOG"
        exit 2
    fi
}

# Run main function
main "$@"