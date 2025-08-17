# Suggested Development Commands for Vocorize

## Build Commands

### Development Build (Recommended)
```bash
# Open in Xcode for development
open Vocorize.xcodeproj

# Build via command line
xcodebuild -scheme Vocorize -configuration Release

# Resolve dependencies
xcodebuild -resolvePackageDependencies -project Vocorize.xcodeproj -scheme Vocorize
```

### Test Build (Local, no notarization)
```bash
# Quick local build for testing
./build-test.sh
```

### Full Release Build (Production)
```bash
# Complete build with signing and notarization
# Requires .env file with proper credentials
./build.sh
```

## Testing Commands
```bash
# Run tests via Xcode
xcodebuild test -scheme Vocorize

# Run tests in Xcode (recommended)
# Select Vocorize scheme and press ⌘U
```

## Code Quality Commands

### SwiftLint (Linting)
```bash
# Install SwiftLint if not present
brew install swiftlint

# Run linting
swiftlint

# Auto-fix issues
swiftlint --fix
```

### Code Style
The project uses SwiftLint configuration in `.swiftlint.yml` with custom rules for TCA patterns.

## Development Workflow Commands

### Xcode Version Management
```bash
# Set Xcode 15 as active (required)
sudo xcode-select -s /Applications/Xcode_15.app

# Switch back to Xcode 16 if needed later
sudo xcode-select -s /Applications/Xcode.app
```

### Git Commands
```bash
git status
git add .
git commit -m "message"
git push
```

### Debugging Commands
```bash
# Check certificates
security find-identity -v -p codesigning

# Check entitlements
codesign -d --entitlements - /path/to/Vocorize.app
```

## System Utilities (macOS/Darwin)
```bash
# List files
ls -la

# Find files
find . -name "*.swift"

# Search in files
grep -r "pattern" .

# Process management
ps aux | grep Vocorize
killall Vocorize

# System info
uname -a
sw_vers
```

## Project-Specific Scripts
- `build.sh` - Full production build with notarization
- `build-test.sh` - Quick local test build
- Both scripts handle dependencies, code signing, and packaging