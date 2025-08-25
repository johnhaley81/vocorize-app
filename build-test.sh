#!/bin/bash

# Vocorize Test Build Script
# This script builds and signs Vocorize locally without notarization

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    print_status "Loading environment variables from .env file"
    export $(cat .env | grep -v '^#' | xargs)
else
    print_warning "No .env file found. Using default values."
    export VERSION=${VERSION:-0.2.5}
    export BUILD_NUMBER=${BUILD_NUMBER:-38}
    export DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-QC99C9JE59}
fi

# Configuration
PROJECT_NAME="Vocorize"
SCHEME_NAME="Vocorize"
PROJECT_FILE="Vocorize.xcodeproj"
BUILD_DIR="build"
EXPORT_PATH="$BUILD_DIR/export"
DMG_NAME="Vocorize-v${VERSION}.dmg"
ZIP_NAME="Vocorize-v${VERSION}.zip"

# Clean build directory
print_status "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Install dependencies
print_status "Installing dependencies..."
if ! command -v create-dmg &> /dev/null; then
    print_status "Installing create-dmg..."
    brew install create-dmg
fi

# Setup code signing
print_status "Setting up code signing..."
if ! security find-identity -v -p codesigning | grep -q "Apple Development"; then
    print_error "No Apple Development certificate found in keychain"
    print_error "Please install your certificate in Keychain Access"
    exit 1
fi

# Resolve dependencies
print_status "Resolving Swift Package Manager dependencies..."
xcodebuild -resolvePackageDependencies \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME"

# Verify MLX framework availability
print_status "Verifying MLX Swift framework..."
MLX_FOUND=false

# Check Package.resolved for mlx-swift
PACKAGE_RESOLVED="$PROJECT_FILE/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ -f "$PACKAGE_RESOLVED" ]; then
    if grep -q "mlx-swift" "$PACKAGE_RESOLVED"; then
        print_success "MLX Swift package found in Package.resolved"
        MLX_FOUND=true
    else
        print_warning "MLX Swift package not found in Package.resolved"
    fi
else
    print_warning "Package.resolved file not found"
fi

# Check build settings for MLX references
if xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -showBuildSettings | grep -q "MLX"; then
    print_success "MLX Swift framework detected in build settings"
    MLX_FOUND=true
else
    print_warning "MLX Swift framework not found in build settings"
fi

# Final MLX verification status
if [ "$MLX_FOUND" = true ]; then
    print_success "MLX Swift framework verification completed successfully"
else
    print_error "MLX Swift framework verification failed"
    print_error "This may cause build issues with ML functionality"
fi

# Build and archive
print_status "Building and archiving $PROJECT_NAME..."
xcodebuild clean archive \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/Vocorize.xcarchive" \
    -destination 'platform=macOS,arch=arm64' \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    ONLY_ACTIVE_ARCH=NO

# Export archive
print_status "Exporting archive..."
cat > ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/Vocorize.xcarchive" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist

# Create DMG
print_status "Creating DMG installer..."
cd "$EXPORT_PATH"
create-dmg \
    --volname "Vocorize $VERSION" \
    --volicon "Vocorize.app/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Vocorize.app" 150 185 \
    --hide-extension "Vocorize.app" \
    --app-drop-link 450 185 \
    --no-internet-enable \
    --hdiutil-quiet \
    "$DMG_NAME" \
    "Vocorize.app"
cd - > /dev/null

# Create ZIP
print_status "Creating ZIP archive..."
cd "$EXPORT_PATH"
zip -r "$ZIP_NAME" Vocorize.app
cd - > /dev/null

# Create distribution directory
print_status "Creating distribution package..."
DIST_DIR="$BUILD_DIR/distribution"
mkdir -p "$DIST_DIR"
cp "$EXPORT_PATH/$DMG_NAME" "$DIST_DIR/"
cp "$EXPORT_PATH/$ZIP_NAME" "$DIST_DIR/"

print_success "Test build completed successfully!"
print_status "Distribution files are in: $BUILD_DIR/distribution/"
print_status "DMG: $BUILD_DIR/distribution/$DMG_NAME"
print_status "ZIP: $BUILD_DIR/distribution/$ZIP_NAME"
print_warning "Note: This build is NOT notarized. Use build.sh for full release builds." 