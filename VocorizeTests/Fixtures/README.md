# Test Fixtures

This directory contains test fixtures for fast, predictable testing of the WhisperKit transcription system.

## Overview

The fixtures provide:
- **Filename-based mock responses** from ExpectedTranscriptions.json
- **Instant loading** without network calls or file operations
- **Predictable results** for consistent testing
- **No actual audio files required** - MockWhisperKitProvider uses only filenames

## File Structure

```
Fixtures/
├── TestModels.json           # Model metadata and configuration
├── ExpectedTranscriptions.json  # Filename→response mapping for mock testing
├── MockPaths.json            # File system paths for model storage
├── TestFixtures.swift        # Fixture loading utilities
├── MockWhisperKitProvider.swift  # Mock provider implementation
├── ExampleUsage.swift        # Example test code
└── README.md                 # This file
```

## Usage

### Loading Fixtures

```swift
// Load model data
let models = try TestFixtures.loadTestModels()
let fastModels = try TestFixtures.getFastTestModels()
let recommendedModel = try TestFixtures.getRecommendedTestModel()

// Load transcription expectations
let expected = try TestFixtures.getExpectedTranscription(audioFileName: "hello_world.wav")

// Load path information
let mockPath = try TestFixtures.getMockPath(modelName: "openai_whisper-base")
```

### Using Mock Provider

```swift
// Create mock provider
let provider = try MockWhisperKitProvider()

// Configure for testing
provider.setSimulateNetworkDelay(false) // Instant operations
provider.mockDownloadedModels(["openai_whisper-base"])
provider.mockLoadedModels(["openai_whisper-base"])

// Test transcription (URL can be any path with target filename)
let audioURL = URL(fileURLWithPath: "/tmp/hello_world.wav") // Only filename matters
let result = try await provider.transcribe(
    audioURL: audioURL,
    modelName: "openai_whisper-base",
    options: DecodingOptions(),
    progressCallback: { _ in }
) // Returns "Hello, world!" from ExpectedTranscriptions.json
```

### Filename-Based Testing

```swift
// Get supported filenames (no actual files needed)
let supportedFiles = TestFixtures.getSupportedTestAudioFilenames()
// Returns: ["silence.wav", "hello_world.wav", "quick_brown_fox.wav", ...]

// Create test URL with any path - only filename is used
let testURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("hello_world.wav")
```

## Test Data

### Models

The fixture includes 6 test models:
- **openai_whisper-tiny**: Fastest, lowest accuracy (test compatible)
- **openai_whisper-base**: Balanced, recommended (test compatible)  
- **openai_whisper-small**: Higher accuracy, multilingual (test compatible)
- **openai_whisper-medium**: High accuracy, slower (not test compatible)
- **openai_whisper-large-v3**: Highest accuracy, slowest (not test compatible)
- **mlx-community/whisper-large-v3-turbo**: MLX optimized (test compatible)

### Supported Filenames

MockWhisperKitProvider recognizes these filenames and returns predefined responses:
- `silence.wav` → Returns empty string ("")
- `hello_world.wav` → Returns "Hello, world!"
- `quick_brown_fox.wav` → Returns "The quick brown fox jumps over the lazy dog."
- `numbers_123.wav` → Returns "One, two, three."
- `multilingual_sample.wav` → Returns "Hello, hola, bonjour."
- `noisy_audio.wav` → Returns "This is noisy audio."
- `long_sentence.wav` → Returns a longer text sample

### Error Scenarios

These filenames trigger specific errors:
- `corrupted_audio.wav` → Throws AudioDecodingFailed error
- `unsupported_format.mp3` → Throws UnsupportedAudioFormat error
- `empty_audio.wav` → Throws EmptyAudioFile error
- `too_long_audio.wav` → Throws AudioTooLong error

## Configuration

### Test Models

Each model includes:
- Display name and internal identifier
- Provider type (whisperkit/mlx)
- Performance ratings (accuracy/speed stars)
- Size and resource requirements
- Language support information
- Test compatibility flag

### Expected Results

Transcription results include:
- Expected text output
- Confidence scores
- Language detection
- Segmentation information
- Model-specific variations

### Mock Paths

File system simulation includes:
- Model storage locations
- Configuration file paths
- Download URLs
- Device limitations

## Performance

All fixtures are designed for speed:
- JSON files total < 50KB
- No actual audio files needed
- No network operations required
- Instant loading and processing
- Zero file I/O for mock transcription

## Maintenance

### Adding New Models

1. Add model entry to `TestModels.json`
2. Add path information to `MockPaths.json`
3. Update test configuration arrays
4. Add expected results if needed

### Adding New Mock Responses

1. Add filename to `getSupportedTestAudioFilenames()` in `TestFixtures.swift`
2. Add expected transcription to `ExpectedTranscriptions.json`
3. No actual audio files needed - MockWhisperKitProvider uses filename only

### Updating Expectations

1. Modify transcription results in `ExpectedTranscriptions.json`
2. Adjust model-specific modifiers as needed
3. Update error scenarios for new test cases

## Integration with Tests

The fixtures integrate with the test suite through:

1. **TestFixtures** - Centralized loading and filename management
2. **MockWhisperKitProvider** - Drop-in replacement that uses filename-based responses
3. **ExpectedTranscriptions.json** - Maps filenames to mock transcription results
4. **Zero setup required** - No files to generate or manage

This ensures tests run instantly while maintaining realistic behavior patterns and comprehensive coverage.