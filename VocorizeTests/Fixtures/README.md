# Test Fixtures

This directory contains test fixtures for fast, predictable testing of the WhisperKit transcription system.

## Overview

The fixtures provide:
- **Realistic test data** that matches production formats
- **Instant loading** without network calls or large file operations
- **Predictable results** for consistent testing
- **Comprehensive coverage** of various scenarios

## File Structure

```
Fixtures/
├── TestModels.json           # Model metadata and configuration
├── ExpectedTranscriptions.json  # Transcription results for test audio
├── MockPaths.json            # File system paths for model storage
├── Audio/                    # Generated test audio files
├── TestFixtures.swift        # Fixture loading utilities
├── AudioGenerator.swift      # Audio file generation
├── MockWhisperKitProvider.swift  # Mock provider implementation
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

// Test transcription
let audioURL = TestFixtures.getTestAudioURL(filename: "hello_world.wav")
let result = try await provider.transcribe(
    audioURL: audioURL,
    modelName: "openai_whisper-base",
    options: DecodingOptions(),
    progressCallback: { _ in }
)
```

### Generating Test Audio

```swift
// Generate all test audio files
try TestFixtures.ensureTestAudioFilesExist()

// Or generate manually
try AudioGenerator.generateAllTestAudio()
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

### Audio Files

Generated test audio includes:
- `silence.wav` - Pure silence (1 second)
- `hello_world.wav` - Speech-like tones (2.5 seconds)
- `quick_brown_fox.wav` - Complex sentence simulation (3.2 seconds)
- `numbers_123.wav` - Number sequence (2.8 seconds)
- `multilingual_sample.wav` - Mixed language simulation (2.0 seconds)
- `noisy_audio.wav` - Audio with background noise (3.5 seconds)
- `long_sentence.wav` - Extended content (8.5 seconds)

### Error Scenarios

The fixtures include error test files:
- `corrupted_audio.wav` - Invalid WAV format
- `unsupported_format.mp3` - Unsupported audio format
- `empty_audio.wav` - Zero duration audio
- `too_long_audio.wav` - Exceeds maximum duration

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
- Audio files are minimal (< 100KB each)
- No network operations required
- Instant loading and processing

## Maintenance

### Adding New Models

1. Add model entry to `TestModels.json`
2. Add path information to `MockPaths.json`
3. Update test configuration arrays
4. Add expected results if needed

### Adding New Audio

1. Add filename to required files list in `TestFixtures.swift`
2. Add generation code to `AudioGenerator.swift`
3. Add expected transcription to `ExpectedTranscriptions.json`

### Updating Expectations

1. Modify transcription results in `ExpectedTranscriptions.json`
2. Adjust model-specific modifiers as needed
3. Update error scenarios for new test cases

## Integration with Tests

The fixtures integrate with the test suite through:

1. **TestFixtures** - Centralized loading and access
2. **MockWhisperKitProvider** - Drop-in replacement for real provider
3. **AudioGenerator** - On-demand test audio creation
4. **Automatic setup** - Files generated as needed during test runs

This ensures tests run quickly while maintaining realistic behavior and comprehensive coverage.