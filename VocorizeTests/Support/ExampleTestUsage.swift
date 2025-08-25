//
//  ExampleTestUsage.swift
//  VocorizeTests
//
//  Example demonstrations of how to use the test configuration system
//  Shows patterns for both unit tests (fast) and integration tests (slow)
//

import Dependencies
import Foundation
import WhisperKit
import XCTest
@testable import Vocorize
import Testing

/// Example test structure showing how to use TestConfiguration system
struct ExampleTestUsage {
    
    // MARK: - Automatic Configuration Tests
    
    /// Example unit test that automatically uses appropriate providers
    /// Will be fast (mock) or slow (real) based on test environment
    @Test
    func automaticConfiguration_transcription() async throws {
        // Print current configuration for debugging
        VocorizeTestConfiguration.printConfiguration()
        
        try await withDependencies {
            $0.transcription = .autoTestValue
        } operation: {
            @Dependency(\.transcription) var transcription
            
            let testAudioURL = createTestAudioFile()
            let result = try await transcription.transcribe(
                testAudioURL,
                "tiny",
                DecodingOptions(),
                { _ in }
            )
            
            #expect(!result.isEmpty, "Should receive transcription result")
            
            if VocorizeTestConfiguration.shouldUseMockProviders {
                #expect(result.contains("Mock"), "Mock providers should return mock results")
            }
        }
    }
    
    // MARK: - Explicit Mock Tests (Always Fast)
    
    /// Example test that explicitly uses mocks for guaranteed fast execution
    /// Use this pattern for tests that must be fast regardless of environment
    @Test
    func explicitMock_modelDownload() async throws {
        try await withDependencies {
            $0.transcription = .quickMockTestValue
        } operation: {
            @Dependency(\.transcription) var transcription
            
            let startTime = Date()
            
            // This should complete very quickly with mock provider
            try await transcription.downloadModel("base") { progress in
                // Mock provider simulates progress
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed < 1.0, "Mock download should complete in < 1 second")
        }
    }
    
    // MARK: - Explicit Integration Tests (Always Real)
    
    /// Example integration test that explicitly uses real providers
    /// Use this pattern for comprehensive end-to-end testing
    /// WARNING: This will be slow and requires network access
    @Test(.timeLimit(.minutes(10))) // Set appropriate timeout for real operations
    func explicitIntegration_realModelCheck() async throws {
        // Skip if explicitly running unit tests only
        guard !ProcessInfo.processInfo.environment.keys.contains("UNIT_TESTS_ONLY") else {
            throw XCTSkip("Skipping integration test - UNIT_TESTS_ONLY environment set")
        }
        
        try await withDependencies {
            $0.transcription = .integrationTestValue
        } operation: {
            @Dependency(\.transcription) var transcription
            
            // This uses real WhisperKit APIs and may download models
            let models = try await transcription.getRecommendedModels()
            
            #expect(!models.default.isEmpty, "Should have a default recommendation")
            #expect(!models.supported.isEmpty, "Should have supported models")
            
            // Check that we get real model names, not mock data
            #expect(!models.default.contains("Mock"), "Integration test should not use mock data")
        }
    }
    
    // MARK: - Provider-Specific Tests
    
    /// Example test focusing on WhisperKit provider only
    @Test
    func whisperKitOnly_providerSpecificTest() async throws {
        let client = await TranscriptionClient.whisperKitOnlyTestValue()
        
        try await withDependencies {
            $0.transcription = client
        } operation: {
            @Dependency(\.transcription) var transcription
            
            let models = try await transcription.getAvailableModels()
            
            // Should only contain WhisperKit models
            if VocorizeTestConfiguration.shouldUseMockProviders {
                #expect(models.allSatisfy { !$0.contains("mlx") }, "Should not contain MLX models")
            }
        }
    }
    
    /// Example test focusing on MLX provider only
    @Test
    func mlxOnly_providerSpecificTest() async throws {
        let client = await TranscriptionClient.mlxOnlyTestValue()
        
        try await withDependencies {
            $0.transcription = client
        } operation: {
            @Dependency(\.transcription) var transcription
            
            let models = try await transcription.getAvailableModels()
            
            if VocorizeTestConfiguration.shouldUseMockProviders {
                // Mock MLX provider returns mock models
                #expect(!models.isEmpty, "MLX provider should have models")
            }
        }
    }
    
    // MARK: - Custom Factory Tests
    
    /// Example test with custom provider factory setup
    @Test
    func customFactory_isolatedTest() async throws {
        // Start with empty factory
        let factory = await TestProviderFactory.createIsolatedFactory()
        
        // Manually register exactly what we need
        let mockProvider = MockTranscriptionProvider()
        await factory.registerProvider(mockProvider, for: .whisperKit)
        
        let client = TranscriptionClient.testValue(with: factory)
        
        try await withDependencies {
            $0.transcription = client
        } operation: {
            @Dependency(\.transcription) var transcription
            
            let isDownloaded = await transcription.isModelDownloaded("tiny")
            #expect(isDownloaded == false, "Mock provider returns false for model downloads")
        }
    }
    
    // MARK: - Environment-Based Test Control
    
    /// Example test that demonstrates environment variable control
    @Test
    func environmentControl_testModeOverride() async throws {
        // Save original state
        let originalMode = VocorizeTestConfiguration.currentTestMode
        
        // Test with explicit unit mode
        VocorizeTestConfiguration.setTestMode(.unit)
        #expect(VocorizeTestConfiguration.shouldUseMockProviders == true)
        #expect(VocorizeTestConfiguration.shouldUseRealProviders == false)
        
        // Test with explicit integration mode
        VocorizeTestConfiguration.setTestMode(.integration)
        #expect(VocorizeTestConfiguration.shouldUseMockProviders == false)
        #expect(VocorizeTestConfiguration.shouldUseRealProviders == true)
        
        // Restore original mode
        if originalMode != VocorizeTestConfiguration.currentTestMode {
            VocorizeTestConfiguration.setTestMode(originalMode)
        }
    }
    
    // MARK: - Performance Validation Tests
    
    /// Example test that validates expected performance characteristics
    @Test
    func performanceValidation_mockVsReal() async throws {
        let startTime = Date()
        
        try await withDependencies {
            $0.transcription = .autoTestValue
        } operation: {
            @Dependency(\.transcription) var transcription
            
            try await transcription.downloadModel("tiny") { _ in }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        if VocorizeTestConfiguration.shouldUseMockProviders {
            #expect(elapsed < 2.0, "Mock operations should complete quickly")
        } else {
            print("⚠️ Integration test took \\(elapsed) seconds - this is expected for real provider")
        }
    }
}

// MARK: - Test Utilities

extension ExampleTestUsage {
    
    /// Creates a temporary audio file for testing
    /// This would typically be in a shared test utilities file
    private func createTestAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test-audio-\\(UUID().uuidString).wav")
        
        // Create a minimal WAV file for testing
        // In real tests, you might use actual audio files or generate proper test audio
        let dummyData = Data([0x52, 0x49, 0x46, 0x46]) // "RIFF" header start
        try? dummyData.write(to: audioURL)
        
        return audioURL
    }
}

// MARK: - Documentation Examples

/*
 
 ## Usage Patterns Summary
 
 ### 1. Default Fast Mocking (Recommended for most unit tests)
 ```swift
 try await withDependencies {
     $0.transcription = .testValue  // Fast inline mock, no provider system
 } operation: {
     // Your test code here - executes in < 1 second
 }
 ```
 
 ### 2. Automatic Configuration (Respects test environment)
 ```swift
 try await withDependencies {
     $0.transcription = .autoTestValue  // Mock for unit tests, real for integration
 } operation: {
     // Your test code here
 }
 ```
 
 ### 3. Mock Provider Testing (When you need provider-level features)
 ```swift
 let mockClient = await TranscriptionClient.mockTestValue()
 try await withDependencies {
     $0.transcription = mockClient  // Uses MockWhisperKitProvider through factory
 } operation: {
     // Your test code here
 }
 ```
 
 ### 3. Explicit Integration (When you need real behavior)
 ```swift
 try await withDependencies {
     $0.transcription = .integrationTestValue  // Always real (slow)
 } operation: {
     // Your test code here - will be slow but comprehensive
 }
 ```
 
 ### 4. Provider-Specific Testing
 ```swift
 let client = await TranscriptionClient.whisperKitOnlyTestValue()
 try await withDependencies {
     $0.transcription = client
 } operation: {
     // Test only WhisperKit behavior
 }
 ```
 
 ### 5. Environment Control
 ```bash
 # Run with mocks (fast)
 VOCORIZE_TEST_MODE=unit xcodebuild test
 
 # Run with real providers (slow but comprehensive)
 VOCORIZE_TEST_MODE=integration xcodebuild test
 ```
 
 ### 6. Performance Expectations
 - Mock providers: < 1 second per test
 - Real providers: 5+ minutes for model downloads
 - Use `.timeLimit()` on integration tests
 
 */