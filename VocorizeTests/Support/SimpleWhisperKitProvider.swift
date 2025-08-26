//
//  SimpleWhisperKitProvider.swift
//  VocorizeTests
//
//  Simple, fast mock implementation of TranscriptionProvider for unit testing
//  Provides instant responses without fixture dependencies
//

import Foundation
import AVFoundation
import WhisperKit
@testable import Vocorize

/// Ultra-fast, simple mock TranscriptionProvider that returns instant responses
/// Designed as a simple alternative to the fixture-based MockWhisperKitProvider
actor SimpleWhisperKitProvider: TranscriptionProvider {
    
    // MARK: - Protocol Conformance
    
    static var providerType: TranscriptionProviderType { .whisperKit }
    static var displayName: String { "SimpleWhisperKit (Unit Test)" }
    
    // MARK: - Mock State
    
    private var downloadedModels: Set<String> = ["openai/whisper-tiny", "openai/whisper-base"]
    private var transcriptionResult: String = "Mock transcription result"
    private var shouldFailTranscription = false
    private var shouldFailDownload = false
    
    // MARK: - Initialization
    
    init() {
        // Instant initialization - no dependencies, no I/O
    }
    
    // MARK: - TranscriptionProvider Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        
        // Simulate progress instantly
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        // Check for configured failures
        if shouldFailTranscription {
            throw TranscriptionProviderError.transcriptionFailed(
                modelName, 
                NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock transcription failure"])
            )
        }
        
        // Return instant result
        return transcriptionResult
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> Void {
        
        // Simulate progress instantly
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        // Check for configured failures
        if shouldFailDownload {
            throw TranscriptionProviderError.modelDownloadFailed(
                modelName, 
                NSError(domain: "MockError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Mock download failure"])
            )
        }
        
        // Add to downloaded models
        downloadedModels.insert(modelName)
    }
    
    func deleteModel(_ modelName: String) async throws -> Void {
        // Instant completion
        downloadedModels.remove(modelName)
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        // Instant response
        return downloadedModels.contains(modelName)
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        // Instant response with static test data
        return [
            ProviderModelInfo(
                internalName: "openai/whisper-tiny",
                displayName: "Tiny (39 MB)",
                providerType: .whisperKit,
                estimatedSize: "39 MB",
                isRecommended: true,
                isDownloaded: downloadedModels.contains("openai/whisper-tiny")
            ),
            ProviderModelInfo(
                internalName: "openai/whisper-base",
                displayName: "Base (74 MB)",
                providerType: .whisperKit,
                estimatedSize: "74 MB",
                isRecommended: false,
                isDownloaded: downloadedModels.contains("openai/whisper-base")
            ),
            ProviderModelInfo(
                internalName: "openai/whisper-small",
                displayName: "Small (244 MB)",
                providerType: .whisperKit,
                estimatedSize: "244 MB",
                isRecommended: false,
                isDownloaded: downloadedModels.contains("openai/whisper-small")
            )
        ]
    }
    
    func getRecommendedModel() async throws -> String {
        // Instant response
        return "openai/whisper-tiny"
    }
    
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        // For testing, assume model can be loaded if downloaded
        if !(await isModelDownloaded(modelName)) {
            try await downloadModel(modelName, progressCallback: { _ in })
        }
        return true
    }
    
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        // For testing, assume loaded if downloaded
        return await isModelDownloaded(modelName)
    }
    
    // MARK: - Test Configuration Methods
    
    /// Configure the mock to return specific transcription text
    func setTranscriptionResult(_ text: String) {
        transcriptionResult = text
    }
    
    /// Configure the mock to simulate transcription failures
    func setShouldFailTranscription(_ shouldFail: Bool) {
        shouldFailTranscription = shouldFail
    }
    
    /// Configure the mock to simulate download failures
    func setShouldFailDownload(_ shouldFail: Bool) {
        shouldFailDownload = shouldFail
    }
    
    /// Add a model to the downloaded set (for testing model availability)
    func addDownloadedModel(_ modelName: String) {
        downloadedModels.insert(modelName)
    }
    
    /// Remove a model from the downloaded set
    func removeDownloadedModel(_ modelName: String) {
        downloadedModels.remove(modelName)
    }
    
    /// Reset mock to clean state for independent tests
    func reset() {
        downloadedModels = ["openai/whisper-tiny", "openai/whisper-base"]
        transcriptionResult = "Mock transcription result"
        shouldFailTranscription = false
        shouldFailDownload = false
    }
    
    // MARK: - Factory Methods for Common Test Scenarios
    
    /// Create mock configured for successful operations (default)
    static func successful() -> SimpleWhisperKitProvider {
        return SimpleWhisperKitProvider()
    }
    
    /// Create mock configured to fail transcription
    static func failingTranscription() -> SimpleWhisperKitProvider {
        let mock = SimpleWhisperKitProvider()
        Task {
            await mock.setShouldFailTranscription(true)
        }
        return mock
    }
    
    /// Create mock configured to fail downloads
    static func failingDownload() -> SimpleWhisperKitProvider {
        let mock = SimpleWhisperKitProvider()
        Task {
            await mock.setShouldFailDownload(true)
        }
        return mock
    }
    
    /// Create mock with no models downloaded
    static func withNoModels() -> SimpleWhisperKitProvider {
        let mock = SimpleWhisperKitProvider()
        Task {
            await mock.reset()
            for model in await mock.downloadedModels {
                await mock.removeDownloadedModel(model)
            }
        }
        return mock
    }
    
    /// Create mock with specific transcription result
    static func withResult(_ text: String) -> SimpleWhisperKitProvider {
        let mock = SimpleWhisperKitProvider()
        Task {
            await mock.setTranscriptionResult(text)
        }
        return mock
    }
}