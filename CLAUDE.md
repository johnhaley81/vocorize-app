# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vocorize is a macOS menu bar application that provides AI-powered voice-to-text transcription using OpenAI's Whisper models. Users activate transcription via customizable hotkeys, and the transcribed text can be automatically pasted into the active application.

## Build & Development Commands

```bash
# Build the app
xcodebuild -scheme Vocorize -configuration Release

# Run tests
xcodebuild test -scheme Vocorize -destination 'platform=macOS,arch=arm64'

# Test Scripts (Optimized Infrastructure)
./test.sh                    # All tests (auto-detects unit/integration)
./test-unit.sh               # Fast unit tests with mock providers (10s)
./test-integration.sh        # Integration tests with caching (30s-5min)
./performance-measurement.sh # Performance benchmarking and validation
./scripts/cache-manager.sh   # Model cache management and optimization

# Cache Management
./test-integration.sh --cache-info    # Show cache status
./test-integration.sh --clean-cache   # Clear all caches
./scripts/cache-manager.sh status     # Detailed cache information
./scripts/cache-manager.sh clean      # Clean all model caches

# Open in Xcode (recommended for development)
open Vocorize.xcodeproj
```

## Architecture

The app uses **The Composable Architecture (TCA)** for state management. Key architectural components:

### Features (TCA Reducers)
- `AppFeature`: Root feature coordinating the app lifecycle
- `TranscriptionFeature`: Core recording and transcription logic
- `SettingsFeature`: User preferences and configuration
- `HistoryFeature`: Transcription history management

### Dependency Clients
- `TranscriptionClient`: WhisperKit integration for ML transcription
- `RecordingClient`: AVAudioRecorder wrapper for audio capture
- `PasteboardClient`: Clipboard operations
- `KeyEventMonitorClient`: Global hotkey monitoring via Sauce framework

### Test Infrastructure
- `MockWhisperKitProvider`: Fast mock provider for unit tests (no ML overhead)
- `CachedWhisperKitProvider`: Model caching for integration tests (90%+ faster)
- `TestProviderFactory`: Unified provider creation with environment detection
- `ModelCacheManager`: Intelligent model caching system (2GB default limit)
- `MLXAvailability`: Conditional MLX framework support detection

### Key Dependencies
- **WhisperKit**: Core ML transcription (tracking main branch)
- **MLX**: Apple Silicon ML optimization (optional, conditional loading)
- **MLXNN**: Neural network library for MLX (optional)
- **Sauce**: Keyboard event monitoring
- **Sparkle**: Auto-updates (feed: https://vocorize-updates.s3.amazonaws.com/appcast.xml)
- **Swift Composable Architecture**: State management
- **Inject**: Hot Reloading for SwiftUI

## Important Implementation Details

1. **Hotkey Recording Modes**: The app supports both press-and-hold and double-tap recording modes, implemented in `HotKeyProcessor.swift`

2. **Model Management**: Whisper models are downloaded on-demand via `ModelDownloadFeature`. Available models are defined in `Resources/Data/models.json`

3. **Sound Effects**: Audio feedback is provided via `SoundEffect.swift` using files in `Resources/Audio/`

4. **Window Management**: Uses an `InvisibleWindow` for the transcription indicator overlay

5. **Permissions**: Requires audio input and automation entitlements (see `Vocorize.entitlements`)

6. **MLX Integration**: Conditional MLX framework support with runtime detection for Apple Silicon optimization

## Testing

Tests use Swift Testing framework with comprehensive optimization infrastructure:

### Test Types & Performance
- **Unit Tests**: `./test-unit.sh` - Fast execution (10s) using mock providers
- **Integration Tests**: `./test-integration.sh` - Real ML testing (30s-5min with caching)
- **Performance Tests**: `./performance-measurement.sh` - Benchmark and validate optimizations

### Test Environment Configuration
```bash
export VOCORIZE_TEST_MODE=unit          # Use mock providers, no ML overhead
export VOCORIZE_TEST_MODE=integration   # Use real providers with caching
```

### Model Caching System
- **Cache Location**: `~/Library/Developer/Xcode/DerivedData/VocorizeTests/ModelCache/`
- **Cache Benefits**: 5-25 minute time savings per test run
- **Cache Limits**: 2GB default, configurable with automatic LRU cleanup
- **Cache Management**: `./scripts/cache-manager.sh` for maintenance and optimization

### Test Providers
- **MockWhisperKitProvider**: Instant responses for unit testing
- **CachedWhisperKitProvider**: Intelligent model caching for integration tests
- **MLXProvider**: Conditional loading with runtime availability detection

### Troubleshooting
- **Cache Issues**: `./scripts/cache-manager.sh verify` and `clean`
- **Performance Problems**: `./performance-measurement.sh` for analysis
- **MLX Issues**: Framework detection and conditional loading prevents crashes