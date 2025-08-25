//
//  MockWhisperKitProvider.swift
//  VocorizeTests
//
//  Enhanced mock implementation of WhisperKit TranscriptionProvider using fixtures
//  Provides realistic, predictable responses with comprehensive test data
//

import Foundation
import AVFoundation
import WhisperKit
@testable import Vocorize

/// Enhanced mock WhisperKit provider that uses test fixtures for realistic responses
actor MockWhisperKitProvider: TranscriptionProvider {
    
    // MARK: - Protocol Conformance
    
    static var providerType: TranscriptionProviderType { .whisperKit }
    static var displayName: String { "WhisperKit (Fixture Mock)" }
    
    // MARK: - Mock State
    
    private var downloadedModels: Set<String> = []
    private var loadedModels: Set<String> = []
    private var currentLoadedModel: String?
    private let mockPaths: MockPathsFixture
    private let expectedTranscriptions: ExpectedTranscriptionsFixture
    private let testModels: TestModelsFixture
    
    // MARK: - Configuration
    
    private var simulateNetworkDelay: Bool = false
    private var simulateErrors: Bool = false
    private var operationDelay: TimeInterval = 0.0
    
    // MARK: - Initialization
    
    init() async throws {
        self.mockPaths = try TestFixtures.loadMockPaths()
        self.expectedTranscriptions = try TestFixtures.loadExpectedTranscriptions()
        self.testModels = try TestFixtures.loadTestModels()
        self.operationDelay = testModels.testConfiguration.mockDownloadDelay
    }
    
    convenience init(preloadModels: [String]) async throws {
        try await self.init()
        self.downloadedModels = Set(preloadModels)
    }
    
    // MARK: - TranscriptionProvider Protocol Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        
        // Check model is downloaded (we don't check loaded for compatibility with existing tests)
        guard downloadedModels.contains(modelName) else {
            throw TranscriptionProviderError.modelLoadFailed(modelName, NSError(domain: "ModelNotDownloaded", code: -1))
        }
        
        let filename = audioURL.lastPathComponent
        let progress = Progress(totalUnitCount: 100)
        
        // Check for error scenarios first
        if let errorScenario = expectedTranscriptions.errorScenarios[filename] {
            switch errorScenario.error {
            case "AudioDecodingFailed":
                throw TranscriptionProviderError.transcriptionFailed(modelName, NSError(domain: "AudioDecoding", code: -1))
            case "UnsupportedAudioFormat":
                throw TranscriptionProviderError.transcriptionFailed(modelName, NSError(domain: "UnsupportedFormat", code: -2))
            case "EmptyAudioFile":
                throw TranscriptionProviderError.transcriptionFailed(modelName, NSError(domain: "EmptyAudio", code: -3))
            case "AudioTooLong":
                throw TranscriptionProviderError.transcriptionFailed(modelName, NSError(domain: "AudioTooLong", code: -4))
            default:
                throw TranscriptionProviderError.transcriptionFailed(modelName, NSError(domain: "UnknownError", code: -999))
            }
        }
        
        // Simulate transcription progress
        let progressSteps = 5
        for i in 0...progressSteps {
            if simulateNetworkDelay {
                try await Task.sleep(nanoseconds: UInt64(testModels.testConfiguration.mockTranscriptionDelay * 1_000_000_000 / Double(progressSteps)))
            }
            
            progress.completedUnitCount = Int64(i * (100 / progressSteps))
            progress.localizedDescription = "Transcribing with \(modelName)... \(i * (100 / progressSteps))%"
            
            await MainActor.run {
                progressCallback(progress)
            }
        }
        
        // Get expected transcription result
        guard let transcriptionResult = expectedTranscriptions.transcriptions[filename] else {
            // Fallback for unknown files
            if filename.contains("silence") {
                return ""
            }
            return "Mock transcription for \(filename)"
        }
        
        // Apply model-specific modifiers if available (simplified for mock)
        return transcriptionResult.text
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        if simulateErrors && modelName.contains("nonexistent") {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        // Check if model exists in our test data
        guard testModels.models.contains(where: { $0.internalName == modelName }) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        let progress = Progress(totalUnitCount: 100)
        
        // Simulate download progress
        let steps = 10
        for i in 0...steps {
            if simulateNetworkDelay {
                try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000 / Double(steps)))
            }
            
            progress.completedUnitCount = Int64(i * (100 / steps))
            progress.localizedDescription = "Downloading \(modelName)... \(i * (100 / steps))%"
            
            await MainActor.run {
                progressCallback(progress)
            }
        }
        
        // Mark as downloaded
        downloadedModels.insert(modelName)
    }
    
    func deleteModel(_ modelName: String) async throws {
        guard downloadedModels.contains(modelName) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        downloadedModels.remove(modelName)
        loadedModels.remove(modelName)
        
        if currentLoadedModel == modelName {
            currentLoadedModel = nil
        }
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        return downloadedModels.contains(modelName)
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        return testModels.models
            .filter { $0.provider == "whisperkit" }
            .map { testModel in
                ProviderModelInfo(
                    internalName: testModel.internalName,
                    displayName: testModel.displayName,
                    providerType: .whisperKit,
                    estimatedSize: testModel.storageSize,
                    isRecommended: testModel.isRecommended,
                    isDownloaded: downloadedModels.contains(testModel.internalName)
                )
            }
    }
    
    func getRecommendedModel() async throws -> String {
        return testModels.testConfiguration.defaultTestModel
    }
    
    // MARK: - Extended API (for comprehensive testing)
    
    /// Load model into memory (extended WhisperKit functionality)
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        guard downloadedModels.contains(modelName) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        if simulateNetworkDelay {
            try await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }
        
        // Unload current model if different
        if let currentModel = currentLoadedModel, currentModel != modelName {
            loadedModels.remove(currentModel)
        }
        
        loadedModels.insert(modelName)
        currentLoadedModel = modelName
        return true
    }
    
    /// Check if model is loaded in memory (extended WhisperKit functionality)
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        return loadedModels.contains(modelName)
    }
    
    /// Get model path (extended WhisperKit functionality)
    func getModelPath(_ modelName: String) async -> URL? {
        guard downloadedModels.contains(modelName),
              let pathInfo = mockPaths.modelPaths[modelName] else {
            return nil
        }
        
        return URL(fileURLWithPath: pathInfo.modelPath)
    }
    
    /// Get device capabilities (extended WhisperKit functionality)
    func getCurrentDeviceCapabilities() async -> MockDeviceCapabilities {
        return MockDeviceCapabilities(
            hasNeuralEngine: true,
            availableMemory: 8_000_000_000, // 8GB
            coreMLComputeUnits: "all",
            supportedModelSizes: ["tiny", "base", "small"]
        )
    }
    
    /// Check model compatibility (extended WhisperKit functionality)
    func isModelCompatibleWithDevice(_ modelName: String, device: MockDeviceCapabilities) async -> Bool {
        return testModels.models.contains { $0.internalName == modelName && $0.testCompatible }
    }
    
    /// Get available device memory (extended WhisperKit functionality)
    func getAvailableDeviceMemory() async -> Int64 {
        return 8_000_000_000 // 8GB for testing
    }
    
    // MARK: - Test Configuration
    
    func resetMockState() {
        downloadedModels.removeAll()
        loadedModels.removeAll()
        currentLoadedModel = nil
    }
    
    func mockDownloadedModels(_ models: [String]) {
        downloadedModels = Set(models)
    }
    
    func mockLoadedModels(_ models: [String]) {
        loadedModels = Set(models)
        currentLoadedModel = models.last
    }
    
    func setSimulateErrors(_ enabled: Bool) {
        simulateErrors = enabled
    }
    
    func setSimulateNetworkDelay(_ enabled: Bool) {
        simulateNetworkDelay = enabled
    }
    
    func setOperationDelay(_ delay: TimeInterval) {
        operationDelay = delay
    }
}

// MARK: - Mock Device Capabilities

struct MockDeviceCapabilities {
    let hasNeuralEngine: Bool
    let availableMemory: Int64
    let coreMLComputeUnits: String
    let supportedModelSizes: [String]
}

// MARK: - Convenience Factory Methods

extension MockWhisperKitProvider {
    
    /// Create mock with fast test models pre-downloaded
    static func withFastModels() async throws -> MockWhisperKitProvider {
        let fastModels = try TestFixtures.getFastTestModels()
        let modelNames = fastModels.map { $0.internalName }
        
        let provider = try await MockWhisperKitProvider(preloadModels: modelNames)
        await provider.setSimulateNetworkDelay(false)
        return provider
    }
    
    /// Create mock with recommended model ready
    static func withRecommendedModel() async throws -> MockWhisperKitProvider {
        let recommended = try TestFixtures.getRecommendedTestModel()
        let provider = try await MockWhisperKitProvider(preloadModels: [recommended.internalName])
        
        await provider.setSimulateNetworkDelay(false)
        _ = try await provider.loadModelIntoMemory(recommended.internalName)
        return provider
    }
    
    /// Create mock for error testing
    static func withErrorSimulation() async throws -> MockWhisperKitProvider {
        let provider = try await MockWhisperKitProvider()
        await provider.setSimulateErrors(true)
        return provider
    }
}