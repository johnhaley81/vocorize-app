# Vocorize Project Overview

## Purpose
Vocorize is a macOS menu bar application that provides AI-powered voice-to-text transcription using OpenAI's Whisper models. Users activate transcription via customizable hotkeys, and the transcribed text can be automatically pasted into the active application.

## Key Features
- **Press-and-hold recording**: Hold hotkey while speaking, release to transcribe
- **Lock mode**: Double-tap hotkey to start recording, single tap to stop and transcribe
- Local processing with WhisperKit (no internet required, no data collection)
- Customizable hotkeys using the Sauce framework
- Audio feedback via sound effects
- Transcription history management
- Model download and management
- Auto-updates via Sparkle

## Platform Requirements
- macOS 13+ (Sonoma recommended)
- Apple Silicon Mac (M1 or later) only
- Microphone and accessibility permissions required
- Xcode 15.x (Swift 5.9) for development
- **Important**: Don't use Xcode 16/Swift 6.0 due to macro compatibility issues

## Tech Stack
- **Architecture**: Swift Composable Architecture (TCA)
- **UI**: SwiftUI with hot reloading via Inject
- **ML**: WhisperKit (Core ML) for transcription
- **Audio**: AVAudioRecorder for recording
- **Hotkeys**: Sauce framework for global keyboard event monitoring
- **Updates**: Sparkle framework
- **Testing**: Swift Testing framework

## Project Structure
```
Vocorize/
├── App/                    # Main app entry point and lifecycle
├── Clients/               # Core services (recording, transcription, pasteboard, hotkeys)
├── Features/              # TCA features (transcription, settings, history, stats)
├── Models/                # Data models and settings
├── Resources/             # Assets, sounds, language data, models.json
├── Views/                 # SwiftUI views
└── Assets.xcassets/       # App icons and images
```

## Architecture Components
### TCA Features (Reducers)
- `AppFeature`: Root feature coordinating app lifecycle
- `TranscriptionFeature`: Core recording and transcription logic
- `SettingsFeature`: User preferences and configuration
- `HistoryFeature`: Transcription history management
- `StatsFeature`: Usage statistics

### Dependency Clients
- `TranscriptionClient`: WhisperKit integration
- `RecordingClient`: AVAudioRecorder wrapper
- `PasteboardClient`: Clipboard operations
- `KeyEventMonitorClient`: Global hotkey monitoring

## Key Implementation Details
- Hotkey recording modes in `HotKeyProcessor.swift`
- On-demand model downloads via `ModelDownloadFeature`
- Sound effects via `SoundEffect.swift`
- `InvisibleWindow` for transcription indicator overlay
- Audio input and automation entitlements required