#!/bin/bash

# Vocorize Local Build Script
# This script builds, signs, notarizes, and distributes Vocorize locally

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
    print_warning "No .env file found. Please ensure all required environment variables are set."
fi

# Configuration
PROJECT_NAME="Vocorize"
SCHEME_NAME="Vocorize"
PROJECT_FILE="Vocorize.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Vocorize.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_NAME="Vocorize-v${VERSION:-0.2.5}.dmg"
ZIP_NAME="Vocorize-v${VERSION:-0.2.5}.zip"

# Required environment variables
REQUIRED_VARS=(
    "VERSION"
    "BUILD_NUMBER"
    "DEVELOPMENT_TEAM"
    "APPLE_ID"
    "APPLE_ID_PASSWORD"
    "TEAM_ID"
)

# Optional Sparkle environment variables
OPTIONAL_SPARKLE_VARS=(
    "R2_ACCESS_KEY_ID"
    "R2_SECRET_ACCESS_KEY"
    "R2_ENDPOINT"
    "R2_BUCKET"
    "SPARKLE_PRIVATE_KEY"
)

# Check for required environment variables
check_env_vars() {
    print_status "Checking required environment variables..."
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Missing required environment variable: $var"
            print_error "Please set it in your .env file or environment"
            exit 1
        fi
    done
    
    print_success "All required environment variables are set"
}

# Check if Sparkle is configured
check_sparkle_config() {
    print_status "Checking Sparkle configuration..."
    
    SPARKLE_ENABLED=true
    for var in "${OPTIONAL_SPARKLE_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            print_warning "Missing Sparkle environment variable: $var"
            SPARKLE_ENABLED=false
        fi
    done
    
    if [ "$SPARKLE_ENABLED" = true ]; then
        print_success "Sparkle is configured and will be used for updates"
    else
        print_warning "Sparkle is not fully configured - skipping update generation"
        print_warning "Set R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT, R2_BUCKET, and SPARKLE_PRIVATE_KEY to enable"
    fi
}

# Update version numbers
update_versions() {
    print_status "Updating version numbers..."
    
    # Update Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Vocorize/Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" Vocorize/Info.plist
    
    # Update project.pbxproj
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" Vocorize.xcodeproj/project.pbxproj
    sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" Vocorize.xcodeproj/project.pbxproj
    
    print_success "Version updated to $VERSION ($BUILD_NUMBER)"
}

# Update Sparkle feed URL if configured
update_sparkle_feed() {
    if [ "$SPARKLE_ENABLED" = true ]; then
        print_status "Updating Sparkle feed URL..."
        
        # Extract account ID from R2 endpoint
        ACCOUNT_ID=$(echo "$R2_ENDPOINT" | sed 's|https://||' | sed 's|\.r2\.cloudflarestorage\.com||')
        
        # Update the feed URL in Info.plist
        FEED_URL="https://$R2_BUCKET.$ACCOUNT_ID.r2.cloudflarestorage.com/releases/appcast.xml"
        /usr/libexec/PlistBuddy -c "Set :SUFeedURL $FEED_URL" Vocorize/Info.plist
        
        print_success "Sparkle feed URL updated to: $FEED_URL"
    fi
}

# Clean build directory
clean_build() {
    print_status "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    print_success "Build directory cleaned"
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Check if create-dmg is installed
    if ! command -v create-dmg &> /dev/null; then
        print_status "Installing create-dmg..."
        brew install create-dmg
    fi
    
    # Check if xcbeautify is installed (optional, for prettier output)
    if ! command -v xcbeautify &> /dev/null; then
        print_warning "xcbeautify not found. Install with: brew install xcbeautify"
    fi
    
    print_success "Dependencies checked"
}

# Setup code signing
setup_signing() {
    print_status "Setting up code signing..."
    
    # Check if certificate is available
    if ! security find-identity -v -p codesigning | grep -q "Apple Development"; then
        print_error "No Apple Development certificate found in keychain"
        print_error "Please install your certificate in Keychain Access"
        exit 1
    fi
    
    print_success "Code signing setup complete"
}

# Resolve dependencies
resolve_dependencies() {
    print_status "Resolving Swift Package Manager dependencies..."
    xcodebuild -resolvePackageDependencies \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME"
    print_success "Dependencies resolved"
}

# Build and archive
build_archive() {
    print_status "Building and archiving $PROJECT_NAME..."
    
    xcodebuild clean archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'platform=macOS,arch=arm64' \
        CODE_SIGN_IDENTITY="Apple Development" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        ONLY_ACTIVE_ARCH=NO \
        | xcbeautify 2>/dev/null || xcodebuild clean archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'platform=macOS,arch=arm64' \
        CODE_SIGN_IDENTITY="Apple Development" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        ONLY_ACTIVE_ARCH=NO
    
    print_success "Archive created at $ARCHIVE_PATH"
}

# Export archive
export_archive() {
    print_status "Exporting archive..."
    
    # Create export options plist
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
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist ExportOptions.plist
    
    print_success "Archive exported to $EXPORT_PATH"
}

# Create DMG
create_dmg() {
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
    
    print_success "DMG created: $EXPORT_PATH/$DMG_NAME"
}

# Create ZIP archive
create_zip() {
    print_status "Creating ZIP archive..."
    
    cd "$EXPORT_PATH"
    zip -r "$ZIP_NAME" Vocorize.app
    cd - > /dev/null
    
    print_success "ZIP created: $EXPORT_PATH/$ZIP_NAME"
}

# Notarize DMG
notarize_dmg() {
    print_status "Submitting DMG for notarization..."
    
    cd "$EXPORT_PATH"
    
    # Submit for notarization
    xcrun notarytool submit "$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait
    
    # Staple the notarization
    xcrun stapler staple "$DMG_NAME"
    
    cd - > /dev/null
    
    print_success "DMG notarized and stapled"
}

# Verify notarization
verify_notarization() {
    print_status "Verifying notarization..."
    
    cd "$EXPORT_PATH"
    
    # Check if notarization was successful
    if xcrun stapler validate "$DMG_NAME"; then
        print_success "Notarization verified successfully"
    else
        print_error "Notarization verification failed"
        exit 1
    fi
    
    cd - > /dev/null
}

# Generate changelog
generate_changelog() {
    print_status "Generating changelog..."
    
    if [ -f "Vocorize/Resources/changelog.md" ]; then
        # Extract content for this version
        CHANGELOG=$(awk "/^## v$VERSION/{flag=1; next} /^## v[0-9]/{flag=0} flag" Vocorize/Resources/changelog.md)
        
        if [ -z "$CHANGELOG" ]; then
            CHANGELOG="- Various improvements and bug fixes"
        fi
        
        echo "$CHANGELOG" > "$BUILD_DIR/changelog.txt"
        print_success "Changelog generated"
    else
        echo "- Initial release" > "$BUILD_DIR/changelog.txt"
        print_warning "No changelog.md found, using default"
    fi
}

# Create distribution directory
create_distribution() {
    print_status "Creating distribution package..."
    
    DIST_DIR="$BUILD_DIR/distribution"
    mkdir -p "$DIST_DIR"
    
    # Copy files
    cp "$EXPORT_PATH/$DMG_NAME" "$DIST_DIR/"
    cp "$EXPORT_PATH/$ZIP_NAME" "$DIST_DIR/"
    cp "$BUILD_DIR/changelog.txt" "$DIST_DIR/"
    
    # Create release notes
    cat > "$DIST_DIR/RELEASE_NOTES.md" << EOF
# Vocorize v$VERSION

## What's New

$(cat "$BUILD_DIR/changelog.txt")

## Installation

1. Download \`$DMG_NAME\`
2. Open the DMG file
3. Drag Vocorize.app to your Applications folder
4. Launch Vocorize from Applications

## Requirements

- macOS 15.0 or later
- Apple Silicon Mac (M1 or later)

## Verification

This release is signed and notarized by Apple.

## Files

- \`$DMG_NAME\` - DMG installer (recommended)
- \`$ZIP_NAME\` - ZIP archive
- \`changelog.txt\` - Detailed changelog

## Build Information

- Version: $VERSION
- Build: $BUILD_NUMBER
- Build Date: $(date)
- Developer Team: $DEVELOPMENT_TEAM
EOF
    
    print_success "Distribution package created at $DIST_DIR"
}

# Generate Sparkle appcast
generate_sparkle_appcast() {
    if [ "$SPARKLE_ENABLED" != true ]; then
        print_warning "Skipping Sparkle appcast generation (not configured)"
        return
    fi
    
    print_status "Generating Sparkle appcast..."
    
    # Create temporary directory for Sparkle tools
    SPARKLE_TEMP_DIR="$BUILD_DIR/sparkle_temp"
    mkdir -p "$SPARKLE_TEMP_DIR"
    
    # Save private key to temporary file
    echo "$SPARKLE_PRIVATE_KEY" > "$SPARKLE_TEMP_DIR/private_key.pem"
    
    # Create appcast entry
    cd "$SPARKLE_TEMP_DIR"
    
    # Download Sparkle's generate_appcast tool if not available
    if ! command -v generate_appcast &> /dev/null; then
        print_status "Downloading Sparkle generate_appcast tool..."
        curl -L -o generate_appcast "https://github.com/sparkle-project/Sparkle/releases/latest/download/generate_appcast"
        chmod +x generate_appcast
    fi
    
    # Generate appcast entry
    ./generate_appcast \
        --private-key private_key.pem \
        --download-url-prefix "https://$R2_BUCKET.$R2_ENDPOINT/releases/" \
        --verbose \
        "$EXPORT_PATH/$DMG_NAME"
    
    # Clean up private key
    rm -f private_key.pem
    
    cd - > /dev/null
    
    print_success "Sparkle appcast entry generated"
}

# Upload to R2 and update appcast
upload_to_r2() {
    if [ "$SPARKLE_ENABLED" != true ]; then
        print_warning "Skipping R2 upload (Sparkle not configured)"
        return
    fi
    
    print_status "Uploading files to R2..."
    
    # Install AWS CLI if not available
    if ! command -v aws &> /dev/null; then
        print_status "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
        sudo installer -pkg AWSCLIV2.pkg -target /
        rm -f AWSCLIV2.pkg
    fi
    
    # Configure AWS CLI for R2
    aws configure set aws_access_key_id "$R2_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$R2_SECRET_ACCESS_KEY"
    aws configure set default.region auto
    
    # Upload files to R2
    cd "$EXPORT_PATH"
    aws s3 cp "$DMG_NAME" "s3://$R2_BUCKET/releases/" --endpoint-url "$R2_ENDPOINT"
    aws s3 cp "$ZIP_NAME" "s3://$R2_BUCKET/releases/" --endpoint-url "$R2_ENDPOINT"
    cd - > /dev/null
    
    # Upload appcast entry if generated
    if [ -f "$BUILD_DIR/sparkle_temp/Vocorize.xml" ]; then
        aws s3 cp "$BUILD_DIR/sparkle_temp/Vocorize.xml" "s3://$R2_BUCKET/releases/" --endpoint-url "$R2_ENDPOINT"
        print_success "Appcast entry uploaded to R2"
    fi
    
    print_success "Files uploaded to R2 successfully"
    print_status "Update URL: https://$R2_BUCKET.$R2_ENDPOINT/releases/appcast.xml"
}

# Main build process
main() {
    print_status "Starting Vocorize build process..."
    print_status "Version: $VERSION"
    print_status "Build: $BUILD_NUMBER"
    
    check_env_vars
    check_sparkle_config
    update_versions
    update_sparkle_feed # Call the new function here
    clean_build
    install_dependencies
    setup_signing
    resolve_dependencies
    build_archive
    export_archive
    create_dmg
    create_zip
    notarize_dmg
    verify_notarization
    generate_changelog
    create_distribution
    generate_sparkle_appcast
    upload_to_r2
    
    print_success "Build completed successfully!"
    print_status "Distribution files are in: $BUILD_DIR/distribution/"
    print_status "DMG: $BUILD_DIR/distribution/$DMG_NAME"
    print_status "ZIP: $BUILD_DIR/distribution/$ZIP_NAME"
    
    if [ "$SPARKLE_ENABLED" = true ]; then
        print_success "Sparkle update published!"
        print_status "Users will be notified of this update automatically"
    fi
}

# Run main function
main "$@" 