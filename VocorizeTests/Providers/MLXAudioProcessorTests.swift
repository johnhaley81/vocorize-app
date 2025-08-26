//
//  MLXAudioProcessorTests.swift
//  VocorizeTests
//
//  Tests for MLXAudioProcessor functionality including audio format validation,
//  mel spectrogram computation, and MLX tensor conversion capabilities.
//

import Foundation
@testable import Vocorize
import Testing
import XCTest
import AVFoundation

/// Test suite for MLXAudioProcessor functionality
struct MLXAudioProcessorTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test
    func testMLXAvailabilityCheck() async throws {
        // Test that MLXAudioProcessor correctly reports MLX availability
        let isAvailable = MLXAudioProcessor.isMLXAvailable
        
        #if canImport(MLX) && canImport(MLXNN)
        // If MLX is importable, availability should match MLXAvailability
        #expect(isAvailable == MLXAvailability.areProductsAvailable)
        #else
        // If MLX is not importable, should always be false
        #expect(isAvailable == false)
        #endif
    }
    
    @Test
    func testSupportedFormats() async throws {
        let processor = MLXAudioProcessor()
        let supportedFormats = processor.getSupportedFormats()
        
        // Verify expected audio formats are supported
        #expect(supportedFormats.contains("wav"))
        #expect(supportedFormats.contains("m4a"))
        #expect(supportedFormats.contains("mp3"))
        #expect(supportedFormats.contains("aac"))
        #expect(supportedFormats.contains("flac"))
        
        // Formats should be sorted
        #expect(supportedFormats == supportedFormats.sorted())
    }
    
    @Test
    func testAudioFormatValidation() async throws {
        let processor = MLXAudioProcessor()
        
        // Test valid formats
        let validWAV = URL(fileURLWithPath: "/path/to/audio.wav")
        let validM4A = URL(fileURLWithPath: "/path/to/audio.m4a")
        let validMP3 = URL(fileURLWithPath: "/path/to/audio.mp3")
        
        #expect(try processor.validateAudioFormat(validWAV))
        #expect(try processor.validateAudioFormat(validM4A))
        #expect(try processor.validateAudioFormat(validMP3))
        
        // Test invalid formats
        let invalidTXT = URL(fileURLWithPath: "/path/to/file.txt")
        let invalidMOV = URL(fileURLWithPath: "/path/to/video.mov")
        
        #expect(throws: MLXAudioProcessorError.self) {
            try processor.validateAudioFormat(invalidTXT)
        }
        
        #expect(throws: MLXAudioProcessorError.self) {
            try processor.validateAudioFormat(invalidMOV)
        }
    }
    
    @Test
    func testAudioConfigurationDefaults() async throws {
        let defaultConfig = MLXAudioConfig.whisperDefault
        
        // Verify Whisper-compatible defaults
        #expect(defaultConfig.sampleRate == 16000)
        #expect(defaultConfig.melFilters == 80)
        #expect(defaultConfig.frameSize == 400)
        #expect(defaultConfig.hopLength == 160)
        #expect(defaultConfig.maxDurationSeconds == 30.0)
        #expect(defaultConfig.minDurationSeconds == 0.1)
    }
    
    @Test
    func testCustomAudioConfiguration() async throws {
        let customConfig = MLXAudioConfig(
            sampleRate: 44100,
            melFilters: 128,
            frameSize: 512,
            hopLength: 256,
            maxDurationSeconds: 60.0,
            minDurationSeconds: 0.5
        )
        
        #expect(customConfig.sampleRate == 44100)
        #expect(customConfig.melFilters == 128)
        #expect(customConfig.frameSize == 512)
        #expect(customConfig.hopLength == 256)
        #expect(customConfig.maxDurationSeconds == 60.0)
        #expect(customConfig.minDurationSeconds == 0.5)
    }
    
    // MARK: - Memory Estimation Tests
    
    @Test
    func testMemoryRequirementEstimation() async throws {
        let shortAudio = 1.0 // 1 second
        let longAudio = 30.0 // 30 seconds
        
        let shortMemory = MLXAudioProcessor.estimateMemoryRequirements(
            audioDurationSeconds: shortAudio
        )
        let longMemory = MLXAudioProcessor.estimateMemoryRequirements(
            audioDurationSeconds: longAudio
        )
        
        // Longer audio should require more memory
        #expect(longMemory > shortMemory)
        
        // Memory requirements should be reasonable (not negative, not excessive)
        #expect(shortMemory > 0)
        #expect(longMemory > 0)
        #expect(shortMemory < 100_000_000) // Less than 100MB for 1 second
        #expect(longMemory < 1_000_000_000) // Less than 1GB for 30 seconds
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func testMLXAudioProcessorErrorEquality() async throws {
        let error1 = MLXAudioProcessorError.mlxNotAvailable
        let error2 = MLXAudioProcessorError.mlxNotAvailable
        let error3 = MLXAudioProcessorError.memoryAllocationFailed
        
        #expect(error1 == error2)
        #expect(error1 != error3)
        
        let formatError1 = MLXAudioProcessorError.unsupportedAudioFormat("mp4")
        let formatError2 = MLXAudioProcessorError.unsupportedAudioFormat("mp4")
        let formatError3 = MLXAudioProcessorError.unsupportedAudioFormat("avi")
        
        #expect(formatError1 == formatError2)
        #expect(formatError1 != formatError3)
        
        let sampleRateError1 = MLXAudioProcessorError.invalidSampleRate(44100, expected: 16000)
        let sampleRateError2 = MLXAudioProcessorError.invalidSampleRate(44100, expected: 16000)
        let sampleRateError3 = MLXAudioProcessorError.invalidSampleRate(48000, expected: 16000)
        
        #expect(sampleRateError1 == sampleRateError2)
        #expect(sampleRateError1 != sampleRateError3)
    }
    
    @Test
    func testMLXAudioProcessorErrorDescriptions() async throws {
        let mlxNotAvailableError = MLXAudioProcessorError.mlxNotAvailable
        #expect(mlxNotAvailableError.errorDescription?.contains("MLX framework is not available") == true)
        
        let unsupportedFormatError = MLXAudioProcessorError.unsupportedAudioFormat("xyz")
        #expect(unsupportedFormatError.errorDescription?.contains("Unsupported audio format: xyz") == true)
        
        let fileReadError = MLXAudioProcessorError.audioFileReadFailed("/path/to/file.wav")
        #expect(fileReadError.errorDescription?.contains("Failed to read audio file") == true)
        
        let conversionError = MLXAudioProcessorError.audioConversionFailed("Invalid format")
        #expect(conversionError.errorDescription?.contains("Audio conversion failed: Invalid format") == true)
        
        let memoryError = MLXAudioProcessorError.memoryAllocationFailed
        #expect(memoryError.errorDescription?.contains("Failed to allocate memory") == true)
        
        let sampleRateError = MLXAudioProcessorError.invalidSampleRate(44100, expected: 16000)
        #expect(sampleRateError.errorDescription?.contains("Invalid sample rate: 44100Hz, expected: 16000Hz") == true)
        
        let tooLongError = MLXAudioProcessorError.audioTooLong(45.0, maxSeconds: 30.0)
        #expect(tooLongError.errorDescription?.contains("Audio too long: 45.0s, maximum: 30.0s") == true)
        
        let tooShortError = MLXAudioProcessorError.audioTooShort(0.05, minSeconds: 0.1)
        #expect(tooShortError.errorDescription?.contains("Audio too short: 0.05s, minimum: 0.1s") == true)
    }
    
    // MARK: - Conditional MLX Tests
    
    @Test(.enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13))
    func testProcessorCreationWithMLXAvailability() async throws {
        // Test that processor can be created regardless of MLX availability
        let processor = MLXAudioProcessor()
        
        // Basic functionality should work
        let supportedFormats = processor.getSupportedFormats()
        #expect(!supportedFormats.isEmpty)
        
        // Configuration should work
        let config = MLXAudioConfig.whisperDefault
        let processorWithConfig = MLXAudioProcessor(config: config)
        #expect(processorWithConfig.getSupportedFormats() == supportedFormats)
    }
    
    // MARK: - Integration Test Placeholders
    
    /// Test processing would fail appropriately when MLX is not available
    @Test
    func testAudioProcessingFailsWithoutMLX() async throws {
        // Skip this test if MLX is actually available
        guard !MLXAudioProcessor.isMLXAvailable else {
            return // Skip test when MLX is available
        }
        
        let processor = MLXAudioProcessor()
        let dummyURL = URL(fileURLWithPath: "/path/to/dummy.wav")
        
        // Processing should fail with MLX not available error
        do {
            _ = try await processor.processAudioFile(dummyURL)
            Issue.record("Expected MLX not available error")
        } catch let error as MLXAudioProcessorError {
            #expect(error == .mlxNotAvailable)
        } catch {
            Issue.record("Expected MLXAudioProcessorError.mlxNotAvailable, got: \(error)")
        }
    }
    
    // NOTE: Actual audio processing tests with real files would require MLX to be available
    // and sample audio files. Those tests should be added when implementing the MLX provider.
}

// MARK: - Test Utilities

extension MLXAudioProcessorTests {
    
    /// Create a dummy audio URL for testing purposes
    private func createTestAudioURL(extension ext: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("test_audio.\(ext)")
    }
    
    /// Verify that error contains expected message
    private func verifyError<T: Error>(_ error: T, contains message: String) {
        if let localizedError = error as? LocalizedError {
            #expect(localizedError.errorDescription?.contains(message) == true)
        } else {
            Issue.record("Error does not conform to LocalizedError: \(error)")
        }
    }
}