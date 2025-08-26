# Mock Provider Development Guide

> **Developer Tip**: Use `export VOCORIZE_TEST_MODE=unit` before running tests to automatically get 10-30 second test execution instead of 5-10 minutes.

This guide explains the mock provider architecture in Vocorize, designed to enable fast unit testing without ML model dependencies.

## 🎯 Overview

Mock providers eliminate the primary bottleneck in unit testing: ML model initialization and inference. By providing configurable, predictable responses, mock providers enable:

- **Fast Test Execution**: 10-30 second test runs vs 5-10 minutes
- **Deterministic Testing**: Predictable responses for reliable test assertions
- **Offline Testing**: No network dependencies for model downloads
- **Resource Efficiency**: Minimal memory and CPU usage

## Architecture

### Core Components

#### MockWhisperKitProvider
**Location**: `VocorizeTests/Support/MockProviders/MockWhisperKitProvider.swift`

Primary mock implementation that provides:
- Instant transcription responses
- Configurable success/failure patterns
- Performance simulation (delays, memory usage)
- State management for complex test scenarios

#### TestProviderFactory
**Location**: `VocorizeTests/Support/TestProviderFactory.swift`

Factory pattern implementation that:
- Automatically selects appropriate provider based on test mode
- Provides unified interface for all provider types
- Handles environment detection and configuration
- Supports provider switching for different test scenarios

#### MockConfiguration
**Location**: `VocorizeTests/Support/MockProviders/MockConfiguration.swift`

Configuration system for customizing mock behavior:
- Response patterns and timing
- Error simulation and failure rates
- Memory and performance characteristics
- State transition patterns

## Provider Selection Logic

### Automatic Selection
The test infrastructure automatically selects providers based on environment:

```swift
// Automatic provider selection
let provider = TestProviderFactory.createProvider(for: .whisperKit)

// Returns MockWhisperKitProvider when:
// - VOCORIZE_TEST_MODE=unit
// - Running in unit test context
// - No real models available

// Returns CachedWhisperKitProvider when:
// - VOCORIZE_TEST_MODE=integration
// - Running integration tests
// - Real models needed for validation
```

### Manual Override
Force specific provider for testing scenarios:

```swift
// Force mock provider (useful for debugging)
let mockProvider = TestProviderFactory.createMockProvider()

// Force real provider (integration testing)
let realProvider = TestProviderFactory.createRealProvider()
```

## Mock Provider Configuration

### Basic Configuration

```swift
let config = MockConfiguration(
    responseDelay: 0.1,              // 100ms response time
    successRate: 1.0,                // 100% success rate
    transcriptionResponses: [
        "Hello world",
        "This is a test",
        "Mock transcription response"
    ]
)

let mockProvider = MockWhisperKitProvider(configuration: config)
```

### Advanced Configuration

```swift
let advancedConfig = MockConfiguration(
    // Performance simulation
    responseDelay: 0.5,              // 500ms to simulate real processing
    memoryUsage: 50_000_000,         // 50MB simulated memory usage
    
    // Error patterns
    successRate: 0.9,                // 90% success rate
    errorTypes: [
        .modelNotLoaded,
        .audioProcessingFailed,
        .networkTimeout
    ],
    errorDistribution: [0.5, 0.3, 0.2], // Error type probabilities
    
    // Response patterns
    transcriptionResponses: [
        "Primary response",
        "Secondary response", 
        "Fallback response"
    ],
    responsePattern: .sequential,     // or .random, .weighted
    
    // State simulation
    initializationDelay: 2.0,        // 2s mock initialization
    supportsMultipleRequests: true,  // Concurrent request handling
    maxConcurrentRequests: 3
)
```

## Mock Response Patterns

### Sequential Responses
Cycle through responses in order:

```swift
let config = MockConfiguration(
    transcriptionResponses: ["First", "Second", "Third"],
    responsePattern: .sequential
)

// First call: "First"
// Second call: "Second"  
// Third call: "Third"
// Fourth call: "First" (cycles back)
```

### Random Responses
Select responses randomly:

```swift
let config = MockConfiguration(
    transcriptionResponses: ["Hello", "World", "Test"],
    responsePattern: .random
)

// Each call returns random response from array
```

### Weighted Responses
Responses with different probabilities:

```swift
let config = MockConfiguration(
    transcriptionResponses: ["Common", "Uncommon", "Rare"],
    responsePattern: .weighted,
    weights: [0.7, 0.2, 0.1]  // 70%, 20%, 10% probability
)
```

### Context-Aware Responses
Responses based on input characteristics:

```swift
let config = MockConfiguration(
    contextAwareResponses: [
        .audioLength(0..<2.0): "Short audio",
        .audioLength(2.0..<10.0): "Medium audio", 
        .audioLength(10.0...): "Long audio"
    ]
)
```

## Error Simulation

### Error Types
Simulate different failure scenarios:

```swift
enum MockTranscriptionError: Error {
    case modelNotLoaded
    case audioProcessingFailed
    case networkTimeout
    case insufficientMemory
    case invalidAudioFormat
    case modelCorrupted
}
```

### Error Patterns
Configure when and how errors occur:

```swift
let config = MockConfiguration(
    successRate: 0.8,                // 80% success, 20% error
    errorPattern: .intermittent,     // Errors occur sporadically
    errorRecovery: true,             // Can recover from errors
    maxConsecutiveErrors: 2          // Max 2 errors in a row
)
```

### Conditional Errors
Errors based on specific conditions:

```swift
let config = MockConfiguration(
    conditionalErrors: [
        .memoryPressure: .insufficientMemory,
        .networkUnavailable: .networkTimeout,
        .invalidInput: .audioProcessingFailed
    ]
)
```

## Performance Simulation

### Realistic Timing
Simulate real provider performance characteristics:

```swift
let config = MockConfiguration(
    // Simulate model loading time (one-time cost)
    initializationDelay: 3.0,
    
    // Simulate transcription processing time
    responseDelay: 0.5,
    
    // Variable delays based on input
    variableDelay: true,
    delayRange: 0.3...1.0            // 300ms-1s range
)
```

### Memory Simulation
Track and simulate memory usage:

```swift
let config = MockConfiguration(
    memoryUsage: 100_000_000,        // 100MB base usage
    memoryGrowth: 10_000_000,        // +10MB per active request
    maxMemoryUsage: 500_000_000,     // 500MB limit
    memoryCleanup: true              // Automatic cleanup
)
```

### Resource Constraints
Simulate resource limitations:

```swift
let config = MockConfiguration(
    maxConcurrentRequests: 2,        // Limit concurrent processing
    queueingEnabled: true,           // Queue overflow requests
    backpressure: true,              // Apply backpressure when overloaded
    resourceExhaustion: 0.05         // 5% chance of resource exhaustion
)
```

## State Management

### Stateful Mock Providers
Maintain state across requests:

```swift
class StatefulMockProvider: MockWhisperKitProvider {
    private var sessionCount = 0
    private var totalProcessingTime = 0.0
    
    override func transcribe(audio: AudioData) async throws -> TranscriptionResult {
        sessionCount += 1
        let result = try await super.transcribe(audio: audio)
        totalProcessingTime += result.processingTime
        return result
    }
    
    func getStatistics() -> ProviderStatistics {
        return ProviderStatistics(
            sessionCount: sessionCount,
            totalProcessingTime: totalProcessingTime,
            averageProcessingTime: totalProcessingTime / Double(sessionCount)
        )
    }
}
```

### State Transitions
Model different provider states:

```swift
enum ProviderState {
    case uninitialized
    case initializing
    case ready
    case processing
    case error(Error)
    case shutdown
}

let config = MockConfiguration(
    initialState: .uninitialized,
    stateTransitions: [
        .uninitialized: [.initializing],
        .initializing: [.ready, .error(.modelNotLoaded)],
        .ready: [.processing, .shutdown],
        .processing: [.ready, .error(.audioProcessingFailed)],
        .error: [.initializing, .shutdown],
        .shutdown: []
    ]
)
```

## Test Integration

### Unit Test Examples

```swift
@Test("Mock provider responds quickly")
func testMockProviderPerformance() async throws {
    let config = MockConfiguration(
        responseDelay: 0.1,
        transcriptionResponses: ["Test response"]
    )
    let provider = MockWhisperKitProvider(configuration: config)
    
    let startTime = Date()
    let result = try await provider.transcribe(audio: testAudioData)
    let duration = Date().timeIntervalSince(startTime)
    
    #expect(result.text == "Test response")
    #expect(duration < 0.2) // Ensure fast response
}

@Test("Mock provider simulates errors correctly")
func testMockProviderErrorHandling() async throws {
    let config = MockConfiguration(
        successRate: 0.0, // Always fail
        errorTypes: [.modelNotLoaded]
    )
    let provider = MockWhisperKitProvider(configuration: config)
    
    do {
        _ = try await provider.transcribe(audio: testAudioData)
        #fail("Expected error but succeeded")
    } catch MockTranscriptionError.modelNotLoaded {
        // Expected error
    } catch {
        #fail("Unexpected error type: \(error)")
    }
}
```

### Integration with TestProviderFactory

```swift
@Test("Provider factory selects mock in unit test mode")
func testProviderFactoryMockSelection() async throws {
    // Set unit test environment
    ProcessInfo.processInfo.setValue("unit", forKey: "VOCORIZE_TEST_MODE")
    
    let provider = TestProviderFactory.createProvider(for: .whisperKit)
    
    // Verify mock provider is selected
    #expect(provider is MockWhisperKitProvider)
    
    // Test mock behavior
    let result = try await provider.transcribe(audio: testAudioData)
    #expect(result.text.isNotEmpty)
}
```

## Debugging and Development

### Mock Provider Logging
Enable detailed logging for debugging:

```swift
let config = MockConfiguration(
    enableLogging: true,
    logLevel: .debug,
    logCategories: [.requests, .responses, .errors, .performance]
)

// Logs will show:
// [MockProvider] Request received: AudioData(duration: 2.5s)
// [MockProvider] Processing with 100ms delay
// [MockProvider] Response: "Mock transcription"
// [MockProvider] Performance: 0.105s total time
```

### Visual Debugging
Use mock provider inspector for visual debugging:

```swift
let inspector = MockProviderInspector(provider: mockProvider)
inspector.enableVisualization(true)

// Shows real-time provider state, request/response patterns
// Useful for understanding mock behavior during test development
```

### Performance Profiling
Profile mock provider performance:

```swift
let profiler = MockProviderProfiler()
profiler.startProfiling(provider: mockProvider)

// Run tests...

let profile = profiler.generateReport()
print("Mock provider performance profile:")
print("  Average response time: \(profile.averageResponseTime)")
print("  Memory usage: \(profile.memoryUsage)")
print("  Error rate: \(profile.errorRate)")
```

## Best Practices

### Mock Configuration
1. **Realistic Delays**: Use realistic response times for accurate performance testing
2. **Error Simulation**: Include error scenarios to test error handling
3. **State Management**: Use stateful mocks for complex workflows
4. **Resource Simulation**: Simulate memory and processing constraints

### Test Organization
1. **Provider Isolation**: Use separate mock instances for different test scenarios
2. **Configuration Sharing**: Share common configurations across similar tests
3. **Clean State**: Reset mock state between tests to avoid interference
4. **Performance Validation**: Verify mock providers meet performance targets

### Development Workflow
1. **Start with Mocks**: Develop and test logic with mock providers first
2. **Validate with Real**: Confirm behavior with real providers in integration tests
3. **Performance Comparison**: Compare mock vs real provider performance
4. **Regression Testing**: Use mocks to detect performance regressions quickly

## Troubleshooting

### Common Issues

#### Mock Provider Not Selected
**Symptoms**: Real provider used when mock expected
**Solutions**:
```bash
# Check environment variable
echo $VOCORIZE_TEST_MODE

# Set explicitly for unit tests
export VOCORIZE_TEST_MODE=unit

# Verify in test
#expect(ProcessInfo.processInfo.environment["VOCORIZE_TEST_MODE"] == "unit")
```

#### Mock Responses Not Matching
**Symptoms**: Unexpected transcription results
**Solutions**:
```swift
// Check mock configuration
let config = MockConfiguration(
    transcriptionResponses: ["Expected response"],
    responsePattern: .sequential
)

// Enable logging to debug response selection
config.enableLogging = true
```

#### Performance Issues with Mocks
**Symptoms**: Mock providers slower than expected
**Solutions**:
```swift
// Reduce simulated delays
let config = MockConfiguration(
    responseDelay: 0.01,    // 10ms instead of default
    initializationDelay: 0  // No initialization delay
)

// Disable performance simulation for pure logic testing
config.simulatePerformance = false
```

## Future Enhancements

### Planned Features
- **AI-Generated Responses**: Use ML to generate realistic transcription variations
- **Audio Analysis**: Mock responses based on actual audio characteristics  
- **Network Simulation**: Simulate network conditions and latency
- **Behavioral Learning**: Learn from real provider behavior to improve mocks

### Advanced Patterns
- **Provider Proxying**: Mix mock and real providers for hybrid testing
- **Recording Mode**: Record real provider interactions for mock replay
- **A/B Testing**: Compare mock vs real provider behavior automatically
- **Mutation Testing**: Automatically generate edge cases for mock testing

## Conclusion

The mock provider system enables:
- **Fast Development Cycles**: 90%+ reduction in test execution time
- **Reliable Testing**: Deterministic, predictable behavior
- **Comprehensive Coverage**: Test error conditions and edge cases
- **Resource Efficiency**: Minimal system resource usage

This foundation supports rapid development while maintaining comprehensive test coverage and enabling complex testing scenarios that would be difficult or impossible with real providers.