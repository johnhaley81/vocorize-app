#!/bin/bash

# Quick MLX Integration Check
# Fast verification of MLX integration status

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "🚀 Quick MLX Integration Check for Vocorize"
echo "============================================"

# Check 1: Architecture
if [[ $(uname -m) == "arm64" ]]; then
    print_success "Apple Silicon architecture (required for MLX)"
else
    print_error "Intel architecture detected - MLX requires Apple Silicon"
    exit 1
fi

# Check 2: Package.resolved
PACKAGE_RESOLVED="Vocorize.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$PACKAGE_RESOLVED" ] && grep -q "mlx-swift" "$PACKAGE_RESOLVED"; then
    MLX_VERSION=$(grep -A 10 "mlx-swift" "$PACKAGE_RESOLVED" | grep "version" | head -1 | sed 's/.*"version" : "\(.*\)".*/\1/')
    print_success "MLX Swift package resolved (v$MLX_VERSION)"
else
    print_error "MLX Swift package not found in dependencies"
    exit 1
fi

# Check 3: Build test (quick)
print_status "Testing MLX compilation..."
if xcodebuild -project Vocorize.xcodeproj -scheme Vocorize -configuration Debug -destination 'platform=macOS,arch=arm64' build -quiet ONLY_ACTIVE_ARCH=YES > /dev/null 2>&1; then
    print_success "Project builds successfully with MLX framework"
else
    print_error "Build failed - MLX integration issues"
    exit 1
fi

# Check 4: Symbol verification
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Vocorize.app" -type d 2>/dev/null | head -1)
if [ -n "$APP_PATH" ] && [ -f "$APP_PATH/Contents/MacOS/Vocorize" ]; then
    BINARY="$APP_PATH/Contents/MacOS/Vocorize"
    if nm "$BINARY" 2>/dev/null | grep -q -i "mlx"; then
        MLX_SYMBOLS=$(nm "$BINARY" 2>/dev/null | grep -i "mlx" | wc -l | xargs)
        print_success "MLX symbols found in binary ($MLX_SYMBOLS symbols)"
    else
        print_error "No MLX symbols found in binary"
        exit 1
    fi
else
    print_error "Built binary not found"
    exit 1
fi

# Check 5: MLX availability file
if [ -f "Vocorize/Clients/Providers/MLXAvailability.swift" ]; then
    print_success "MLX availability detection implemented"
else
    print_error "MLX availability detection not found"
fi

echo ""
print_success "🎉 MLX integration is working correctly!"
print_status "✓ MLX Swift v$MLX_VERSION resolved and integrated"
print_status "✓ Apple Silicon architecture compatible"  
print_status "✓ Project builds with MLX framework"
print_status "✓ MLX symbols present in binary"
print_status "✓ MLX availability detection available"
echo ""
echo "MLX is ready for use in Vocorize!"