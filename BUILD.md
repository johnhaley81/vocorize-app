# Local Build Guide for Vocorize

This guide explains how to build, sign, notarize, and distribute Vocorize locally instead of using GitHub Actions.

## Prerequisites

### 1. Apple Developer Account
- Active Apple Developer Program membership
- Apple Development certificate installed in Keychain Access
- App-specific password for notarization

### 2. Development Environment
- macOS 15.0 or later
- Xcode 16.2 or later
- Homebrew installed

### 3. Required Tools
The build scripts will automatically install these if missing:
- `create-dmg` (for creating DMG installers)
- `xcbeautify` (optional, for prettier build output)

## Setup

### 1. Create Environment File
Copy the template and fill in your details:

```bash
cp env.template .env
```

Edit `.env` with your actual values:

```bash
# Version Information
VERSION=0.2.5
BUILD_NUMBER=38

# Apple Developer Information
DEVELOPMENT_TEAM=QC99C9JE59
TEAM_ID=QC99C9JE59

# Apple ID for Notarization
APPLE_ID=your-apple-id@example.com
APPLE_ID_PASSWORD=your-app-specific-password
```

### 2. Make Scripts Executable
```bash
chmod +x build.sh
```

## Building

### Full Release Build
For production releases with notarization:

```bash
./build.sh
```

This will:
- Build and sign the app
- Create DMG and ZIP files
- Submit DMG for Apple notarization
- Verify notarization
- Create distribution package with release notes

## Output Files

After a successful build, you'll find these files in `build/distribution/`:

- `Vocorize-v0.2.5.dmg` - DMG installer (recommended for distribution)
- `Vocorize-v0.2.5.zip` - ZIP archive
- `changelog.txt` - Extracted changelog for this version
- `RELEASE_NOTES.md` - Complete release notes

## Troubleshooting

### Code Signing Issues
If you get code signing errors:

1. Check that your Apple Development certificate is installed:
   ```bash
   security find-identity -v -p codesigning
   ```

2. Make sure your development team ID is correct in `.env`

3. Verify Xcode can access your keychain

### Notarization Issues
If notarization fails:

1. Check your Apple ID and app-specific password
2. Ensure your Apple ID has the correct permissions
3. Check the notarization logs for specific errors

### Build Issues
If the build fails:

1. Clean the project: `xcodebuild clean`
2. Check that all Swift Package Manager dependencies are resolved
3. Verify Xcode version compatibility

## Manual Steps (Alternative)

If you prefer to run steps manually:

### 1. Update Version Numbers
```bash
# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.2.5" Vocorize/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 38" Vocorize/Info.plist

# Update project.pbxproj
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = 0.2.5;/g" Vocorize.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = 38;/g" Vocorize.xcodeproj/project.pbxproj
```

### 2. Build and Archive
```bash
xcodebuild clean archive \
  -project Vocorize.xcodeproj \
  -scheme Vocorize \
  -configuration Release \
  -archivePath build/Vocorize.xcarchive \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM=QC99C9JE59 \
  ONLY_ACTIVE_ARCH=NO
```

### 3. Export Archive
```bash
xcodebuild -exportArchive \
  -archivePath build/Vocorize.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

### 4. Create DMG
```bash
cd build/export
create-dmg \
  --volname "Vocorize 0.2.5" \
  --volicon "Vocorize.app/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Vocorize.app" 150 185 \
  --hide-extension "Vocorize.app" \
  --app-drop-link 450 185 \
  --no-internet-enable \
  "Vocorize-v0.2.5.dmg" \
  "Vocorize.app"
```

### 5. Notarize (Optional)
```bash
xcrun notarytool submit Vocorize-v0.2.5.dmg \
  --apple-id your-apple-id@example.com \
  --password your-app-specific-password \
  --team-id QC99C9JE59 \
  --wait

xcrun stapler staple Vocorize-v0.2.5.dmg
```

## Distribution

### GitHub Release
To create a GitHub release:

1. Tag the release:
   ```bash
   git tag v0.2.5
   git push origin v0.2.5
   ```

2. Go to GitHub → Releases → Create new release
3. Upload the DMG and ZIP files
4. Add release notes from `build/distribution/RELEASE_NOTES.md`

### Sparkle Updates
If you're using Sparkle for auto-updates:

1. Upload files to your hosting service (R2, S3, etc.)
2. Update your `appcast.xml` file
3. Sign the appcast with your Sparkle private key

## Security Notes

- Never commit your `.env` file to version control
- Keep your certificates and passwords secure
- Use app-specific passwords for notarization
- Regularly rotate your credentials

## Support

If you encounter issues:

1. Check the build logs for specific error messages
2. Verify all prerequisites are met
3. Ensure your Apple Developer account is active
4. Check that your certificates haven't expired 