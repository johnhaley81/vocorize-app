# Task Completion Requirements for Vocorize

## Code Quality Checks

### Required Before Completing Any Task
1. **SwiftLint Check**
   ```bash
   swiftlint
   ```
   - Must pass without errors
   - Warnings should be addressed when reasonable
   - Use `swiftlint --fix` for auto-fixable issues

2. **Build Verification**
   ```bash
   xcodebuild -scheme Vocorize -configuration Release
   ```
   - Code must compile without errors
   - Warnings should be minimal and justified

3. **Test Execution**
   ```bash
   xcodebuild test -scheme Vocorize
   ```
   - All existing tests must pass
   - New functionality should include appropriate tests
   - Use Swift Testing framework (`@Test` and `#expect`)

## Code Review Checklist

### Architecture Compliance
- [ ] Follows TCA patterns for state management
- [ ] Uses dependency injection via `@Dependencies`
- [ ] Proper separation of concerns between Features, Clients, and Models
- [ ] No direct external dependencies in Features (use Clients)

### Code Quality
- [ ] Descriptive variable and function names
- [ ] Appropriate access control (`private`, `fileprivate`, `internal`)
- [ ] Minimal but meaningful comments
- [ ] Error handling using `Result` types where appropriate
- [ ] No force unwrapping without justification

### File Organization
- [ ] Files placed in correct directories
- [ ] Imports organized (system, third-party, internal)
- [ ] Use of `// MARK: -` for section organization
- [ ] Consistent naming conventions

## Git and Version Control

### Commit Requirements
- [ ] Descriptive commit messages using conventional format
- [ ] Atomic commits (one logical change per commit)
- [ ] Clean commit history (squash if necessary)
- [ ] All changes staged and committed

### Branch Management
- [ ] Working on appropriate feature/fix branch
- [ ] Based off latest main/develop branch
- [ ] No merge conflicts
- [ ] Ready for merge request if needed

## Platform Compatibility

### Xcode Version
- [ ] Built and tested with Xcode 15.x
- [ ] **Critical**: NOT using Xcode 16/Swift 6.0
- [ ] Dependencies resolved successfully

### macOS Compatibility
- [ ] Targets macOS 13+ minimum
- [ ] Apple Silicon specific features properly handled
- [ ] Appropriate entitlements configured

## Documentation Updates

### When Required
- [ ] Update CLAUDE.md if development processes change
- [ ] Update README.md for user-facing changes
- [ ] Update changelog for version releases
- [ ] Document new features or significant changes

## Testing Strategy

### Unit Tests
- [ ] New features have corresponding tests
- [ ] Tests use Swift Testing framework
- [ ] Mock dependencies using TCA's system
- [ ] Edge cases covered

### Integration Testing
- [ ] Build verification (`./build.sh` or Xcode)
- [ ] Manual testing of hotkey functionality
- [ ] Audio recording and transcription flow
- [ ] Permission handling verification

## Performance Considerations
- [ ] No memory leaks in audio recording
- [ ] Efficient WhisperKit model usage
- [ ] Responsive UI during transcription
- [ ] Minimal impact on system performance

## Security and Privacy
- [ ] Audio data handled securely
- [ ] No unauthorized data collection
- [ ] Proper entitlements and permissions
- [ ] Code signing requirements met

## Release Readiness (when applicable)
- [ ] Version numbers updated
- [ ] Changelog entries added
- [ ] Sparkle feed configuration verified
- [ ] Build and notarization successful