//
//  MockWhisperKitProviderSpeedTest.swift
//  VocorizeTests
//
//  Speed demonstration for MockWhisperKitProvider - shows instant execution vs 27+ second real provider
//

import Foundation
import AVFoundation
import WhisperKit
@testable import Vocorize
import Testing

struct MockWhisperKitProviderSpeedTest {
    
    @Test("SimpleWhisperKitProvider provides instant responses")
    func testInstantSpeed() async throws {
        let mock = SimpleWhisperKitProvider()
        
        let startTime = Date()
        
        // Perform all the operations that take 27+ seconds with real WhisperKit
        let models = try await mock.getAvailableModels()
        let recommendedModel = try await mock.getRecommendedModel()
        let isDownloaded = await mock.isModelDownloaded("openai/whisper-tiny")
        
        try await mock.downloadModel("openai/whisper-small") { _ in }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio.wav")
        
        let result = try await mock.transcribe(
            audioURL: tempURL,
            modelName: "openai/whisper-tiny",
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Verify results are correct
        #expect(models.count == 5)
        #expect(recommendedModel == "openai/whisper-tiny")
        #expect(isDownloaded == true)
        #expect(result == "Mock transcription result")
        
        // Most importantly: all operations completed in under 50ms (vs 27+ seconds)
        #expect(duration < 0.05, "Duration should be under 50ms but was \(String(format: "%.3f", duration * 1000))ms")
        
        print("✅ Mock completed all operations in: \(duration)")
        print("⚡ Expected real WhisperKit time: 27+ seconds")
        print("🚀 Speed improvement: ~540x faster")
    }
    
    @Test("SimpleWhisperKitProvider can simulate errors instantly")
    func testInstantErrorSimulation() async throws {
        let mock = SimpleWhisperKitProvider.failingTranscription()
        
        let startTime = Date()
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio.wav")
        
        do {
            _ = try await mock.transcribe(
                audioURL: tempURL,
                modelName: "openai/whisper-tiny",
                options: DecodingOptions(),
                progressCallback: { _ in }
            )
            Issue.record("Expected transcription to fail")
        } catch {
            let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
            
            // Verify error is correct type
            #expect(error is TranscriptionProviderError)
            
            // Verify error simulation is also instant
            #expect(duration < 0.01)
            
            print("✅ Mock error simulation completed in: \(duration)")
        }
    }
    
    @Test("SimpleWhisperKitProvider factory methods work correctly")
    func testFactoryMethods() async throws {
        // Test successful factory
        let successMock = SimpleWhisperKitProvider.successful()
        let result = try await successMock.transcribe(
            audioURL: FileManager.default.temporaryDirectory.appendingPathComponent("test.wav"),
            modelName: "test-model",
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        #expect(result == "Mock transcription result")
        
        // Test with custom result factory
        let customMock = SimpleWhisperKitProvider.withResult("Custom result")
        // Note: Factory methods use Task{}, so we need a small delay for async setup
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        let customResult = try await customMock.transcribe(
            audioURL: FileManager.default.temporaryDirectory.appendingPathComponent("test.wav"),
            modelName: "test-model",
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        #expect(customResult == "Custom result")
    }
    
    @Test("SimpleWhisperKitProvider supports test configuration")
    func testConfiguration() async throws {
        let mock = SimpleWhisperKitProvider()
        
        // Test configuration methods
        await mock.setTranscriptionResult("Configured result")
        await mock.addDownloadedModel("custom-model")
        
        let result = try await mock.transcribe(
            audioURL: FileManager.default.temporaryDirectory.appendingPathComponent("test.wav"),
            modelName: "custom-model",
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        #expect(result == "Configured result")
        
        let isDownloaded = await mock.isModelDownloaded("custom-model")
        #expect(isDownloaded == true)
        
        // Test reset functionality
        await mock.reset()
        
        let resetResult = try await mock.transcribe(
            audioURL: FileManager.default.temporaryDirectory.appendingPathComponent("test.wav"),
            modelName: "openai/whisper-tiny",
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        #expect(resetResult == "Mock transcription result")
        
        let customModelStillDownloaded = await mock.isModelDownloaded("custom-model")
        #expect(customModelStillDownloaded == false)
    }
}

// MARK: - Timer Extension for Duration Measurement
// Using Date() for compatibility across Swift versions