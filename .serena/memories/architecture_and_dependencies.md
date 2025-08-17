# Architecture and Dependencies for Vocorize

## Core Architecture Pattern: The Composable Architecture (TCA)

### TCA Features Structure
Each feature follows this pattern:
```swift
// State
struct FeatureState: Equatable {
    // Feature-specific state properties
}

// Action
enum FeatureAction: Equatable {
    // User actions, system events, delegate actions
}

// Reducer
struct FeatureReducer: ReducerProtocol {
    var body: some ReducerProtocol<State, Action> {
        // Business logic and state transitions
    }
}
```

### Current TCA Features
1. **AppFeature** (`Features/App/`)
   - Root feature coordinating app lifecycle
   - Manages global state and coordination between features

2. **TranscriptionFeature** (`Features/Transcription/`)
   - Core recording and transcription logic
   - Handles hotkey events and audio processing
   - Coordinates with recording and transcription clients

3. **SettingsFeature** (`Features/Settings/`)
   - User preferences and configuration
   - Hotkey customization
   - Model selection and download

4. **HistoryFeature** (`Features/History/`)
   - Transcription history management
   - Storage and retrieval of past transcriptions

5. **StatsFeature** (`Features/Stats/`)
   - Usage statistics and analytics
   - Performance metrics

## Dependency Clients

### TranscriptionClient
- **Purpose**: WhisperKit integration for ML transcription
- **Location**: `Clients/TranscriptionClient.swift`
- **Key functionality**: Model loading, transcription processing

### RecordingClient
- **Purpose**: AVAudioRecorder wrapper for audio capture
- **Location**: `Clients/RecordingClient.swift`  
- **Key functionality**: Audio recording, permission management

### PasteboardClient
- **Purpose**: Clipboard operations
- **Location**: `Clients/PasteboardClient.swift`
- **Key functionality**: Text pasting to active applications

### KeyEventMonitorClient
- **Purpose**: Global hotkey monitoring via Sauce framework
- **Location**: `Clients/KeyEventMonitorClient.swift`
- **Key functionality**: Keyboard event capture, hotkey detection

### SoundEffect
- **Purpose**: Audio feedback system
- **Location**: `Clients/SoundEffect.swift`
- **Key functionality**: Playing notification sounds

## External Dependencies

### Core ML and Audio Processing
- **WhisperKit**: OpenAI Whisper models for Core ML
  - Version: Tracking main branch
  - Purpose: Local speech-to-text transcription
  - Platform: Apple Silicon only

### User Interface
- **SwiftUI**: Native UI framework
- **Inject**: Hot reloading for development
  - Purpose: Faster UI iteration during development

### System Integration
- **Sauce**: Keyboard event monitoring
  - Purpose: Global hotkey detection and management
  - Platform: macOS specific

- **Sparkle**: Auto-update framework
  - Update feed: https://vocorize-updates.s3.amazonaws.com/appcast.xml
  - Purpose: Automatic app updates

### Development and Testing
- **Swift Composable Architecture**: State management
  - Version: Latest stable
  - Purpose: Unidirectional data flow and testability

- **Swift Testing**: Testing framework
  - Purpose: Unit and integration testing
  - Replaces XCTest in this project

## Data Flow Architecture

### Hotkey Processing Flow
1. `KeyEventMonitorClient` captures global keyboard events
2. `HotKeyProcessor` in `TranscriptionFeature` processes events
3. Determines recording mode (press-and-hold vs double-tap lock)
4. Triggers recording via `RecordingClient`
5. Audio sent to `TranscriptionClient` for processing
6. Results pasted via `PasteboardClient`

### Model Management Flow
1. `ModelDownloadFeature` manages Whisper model downloads
2. Models defined in `Resources/Data/models.json`
3. Downloaded models stored locally for offline use
4. `TranscriptionClient` loads appropriate model for transcription

## Window and UI Architecture

### InvisibleWindow
- **Purpose**: Transcription indicator overlay
- **Implementation**: Transparent window for status display
- **Location**: Custom window management code

### Menu Bar Integration
- **Type**: NSStatusItem based menu bar app
- **UI**: SwiftUI views in menu bar popover
- **State**: Managed through TCA features

## Security and Permissions

### Required Entitlements
- **Audio Input**: Microphone access for recording
- **Automation**: Accessibility permissions for text pasting
- **File**: `Vocorize.entitlements` configuration

### Code Signing
- Apple Development certificates required
- Automatic signing via Xcode project settings
- Notarization for distribution builds

## File and Resource Management

### Audio Resources
- **Location**: `Resources/Audio/`
- **Purpose**: Sound effects for user feedback
- **Format**: System-compatible audio files

### Model Configuration
- **Location**: `Resources/Data/models.json`
- **Purpose**: Available Whisper model definitions
- **Content**: Model metadata, download URLs, requirements

### Localization
- **File**: `Localizable.xcstrings`
- **Support**: Multi-language string resources
- **Integration**: SwiftUI automatic localization