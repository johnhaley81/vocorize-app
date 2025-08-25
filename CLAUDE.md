# CLAUDE.md

## Stack
- macOS app with SwiftUI + The Composable Architecture (TCA)
- WhisperKit ML transcription + MLX optimization (conditional)
- AVAudioRecorder + Sauce hotkey monitoring
- Swift Testing framework + model caching

## Commands
- `./test.sh` - All tests (auto-detects unit/integration)
- `VocorizeTests/scripts/test-unit.sh` - Fast mock tests (10s)
- `VocorizeTests/scripts/test-integration.sh` - Real ML tests with caching (30s-5min)
- `xcodebuild -scheme Vocorize -configuration Release` - Build app
- `open Vocorize.xcodeproj` - Xcode development

## Architecture
- **TCA Features**: AppFeature → TranscriptionFeature/SettingsFeature/HistoryFeature
- **Clients**: TranscriptionClient (WhisperKit) + RecordingClient + PasteboardClient + KeyEventMonitorClient
- **Test Infrastructure**: MockWhisperKitProvider + CachedWhisperKitProvider + ModelCacheManager
- **Dependencies**: WhisperKit + MLX/MLXNN (optional) + Sauce + Sparkle + TCA

## Business Logic
- Hotkey activation: press-and-hold OR double-tap modes (`HotKeyProcessor.swift`)
- Model download: on-demand via `ModelDownloadFeature` (specs in `Resources/Data/models.json`)
- Audio feedback: `SoundEffect.swift` → `Resources/Audio/`
- Overlay UI: `InvisibleWindow` for transcription indicator
- Permissions: audio input + automation (see `Vocorize.entitlements`)
- MLX: runtime detection prevents crashes on unsupported systems

## Testing
- **Environment**: `VOCORIZE_TEST_MODE=unit|integration`
- **Cache**: `~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/` (2GB limit, LRU cleanup)
- **Providers**: Mock (instant) vs Cached (90%+ faster integration)
- **Performance**: `VocorizeTests/scripts/performance-measurement.sh` for benchmarking
- **Cache Management**: `./scripts/cache-manager.sh status|clean|verify`