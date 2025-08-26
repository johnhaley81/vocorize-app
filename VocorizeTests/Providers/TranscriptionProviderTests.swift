//
//  TranscriptionProviderTests.swift
//  VocorizeTests
//
//  Test suite for TranscriptionProvider protocol system
//  Following TDD principles - tests verify expected behavior
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import AVFoundation
import WhisperKit

struct TranscriptionProviderTests {
    
    // MARK: - TranscriptionProviderType Tests
    
    @Test
    func providerType_containsExpectedValues() {
        let allCases = TranscriptionProviderType.allCases
        
        #expect(allCases.contains(.whisperKit))
        #expect(allCases.contains(.mlx))
        #expect(allCases.count == 2)
    }
    
    @Test
    func providerType_rawValues() {
        #expect(TranscriptionProviderType.whisperKit.rawValue == "whisperkit")
        #expect(TranscriptionProviderType.mlx.rawValue == "mlx")
    }
    
    @Test
    func providerType_displayNames() {
        #expect(TranscriptionProviderType.whisperKit.displayName == "WhisperKit (Core ML)")
        #expect(TranscriptionProviderType.mlx.displayName == "MLX")
    }
    
    @Test
    func providerType_codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding/decoding whisperKit
        let whisperKitData = try encoder.encode(TranscriptionProviderType.whisperKit)
        let decodedWhisperKit = try decoder.decode(TranscriptionProviderType.self, from: whisperKitData)
        #expect(decodedWhisperKit == .whisperKit)
        
        // Test encoding/decoding mlx
        let mlxData = try encoder.encode(TranscriptionProviderType.mlx)
        let decodedMlx = try decoder.decode(TranscriptionProviderType.self, from: mlxData)
        #expect(decodedMlx == .mlx)
    }
    
    // MARK: - ProviderModelInfo Tests
    
    @Test
    func providerModelInfo_initialization() {
        let modelInfo = ProviderModelInfo(
            internalName: "tiny",
            displayName: "Tiny (English)",
            providerType: .whisperKit,
            estimatedSize: "39 MB",
            isRecommended: true,
            isDownloaded: false
        )
        
        #expect(modelInfo.internalName == "tiny")
        #expect(modelInfo.displayName == "Tiny (English)")
        #expect(modelInfo.providerType == .whisperKit)
        #expect(modelInfo.estimatedSize == "39 MB")
        #expect(modelInfo.isRecommended == true)
        #expect(modelInfo.isDownloaded == false)
    }
    
    @Test
    func providerModelInfo_idGeneration() {
        let whisperKitModel = ProviderModelInfo(
            internalName: "base",
            displayName: "Base",
            providerType: .whisperKit,
            estimatedSize: "145 MB"
        )
        
        let mlxModel = ProviderModelInfo(
            internalName: "small",
            displayName: "Small",
            providerType: .mlx,
            estimatedSize: "244 MB"
        )
        
        #expect(whisperKitModel.id == "whisperkit:base")
        #expect(mlxModel.id == "mlx:small")
    }
    
    @Test
    func providerModelInfo_defaultValues() {
        let modelInfo = ProviderModelInfo(
            internalName: "medium",
            displayName: "Medium",
            providerType: .whisperKit,
            estimatedSize: "769 MB"
        )
        
        #expect(modelInfo.isRecommended == false)
        #expect(modelInfo.isDownloaded == false)
    }
    
    @Test
    func providerModelInfo_equatable() {
        let model1 = ProviderModelInfo(
            internalName: "tiny",
            displayName: "Tiny",
            providerType: .whisperKit,
            estimatedSize: "39 MB",
            isRecommended: true,
            isDownloaded: true
        )
        
        let model2 = ProviderModelInfo(
            internalName: "tiny",
            displayName: "Tiny",
            providerType: .whisperKit,
            estimatedSize: "39 MB",
            isRecommended: true,
            isDownloaded: true
        )
        
        let model3 = ProviderModelInfo(
            internalName: "base",
            displayName: "Base",
            providerType: .whisperKit,
            estimatedSize: "145 MB"
        )
        
        #expect(model1 == model2)
        #expect(model1 != model3)
    }
    
    @Test
    func providerModelInfo_identifiable() {
        let model = ProviderModelInfo(
            internalName: "large",
            displayName: "Large",
            providerType: .mlx,
            estimatedSize: "1.55 GB"
        )
        
        // Test that id property exists and can be used for Identifiable
        let identifier = model.id
        #expect(identifier == "mlx:large")
    }
    
    @Test
    func providerModelInfo_codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let originalModel = ProviderModelInfo(
            internalName: "base",
            displayName: "Base Model",
            providerType: .whisperKit,
            estimatedSize: "145 MB",
            isRecommended: true,
            isDownloaded: false
        )
        
        let encodedData = try encoder.encode(originalModel)
        let decodedModel = try decoder.decode(ProviderModelInfo.self, from: encodedData)
        
        #expect(decodedModel == originalModel)
        #expect(decodedModel.id == originalModel.id)
    }
    
    // MARK: - TranscriptionProviderRegistry Tests
    
    @Test(.serialized)
    func registry_initialState() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear() // Ensure clean state
        
        let count = await registry.count
        let availableTypes = await registry.availableProviderTypes()
        
        #expect(count == 0)
        #expect(availableTypes.isEmpty)
    }
    
    @Test(.serialized)
    func registry_registerProvider() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        let mockProvider = MockTranscriptionProvider()
        await registry.register(mockProvider, for: .whisperKit)
        
        let count = await registry.count
        let isAvailable = await registry.isProviderAvailable(.whisperKit)
        let availableTypes = await registry.availableProviderTypes()
        
        #expect(count == 1)
        #expect(isAvailable == true)
        #expect(availableTypes.contains(.whisperKit))
    }
    
    @Test(.serialized)
    func registry_retrieveProvider() async throws {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        let mockProvider = MockTranscriptionProvider()
        await registry.register(mockProvider, for: .whisperKit)
        
        let retrievedProvider = try await registry.provider(for: .whisperKit)
        
        // Test that we can retrieve the provider
        #expect(retrievedProvider != nil)
        #expect(type(of: retrievedProvider) == MockTranscriptionProvider.self)
    }
    
    @Test(.serialized)
    func registry_providerNotFound() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        await #expect(throws: TranscriptionProviderError.providerNotAvailable(.mlx)) {
            try await registry.provider(for: .mlx)
        }
    }
    
    @Test(.serialized)
    func registry_multipleProviders() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        // let mlxProvider = MockMLXProvider() // Commented out for TDD RED phase
        
        await registry.register(whisperProvider, for: .whisperKit)
        // await registry.register(mlxProvider, for: .mlx) // Commented out for TDD RED phase
        
        let count = await registry.count
        let availableTypes = await registry.availableProviderTypes()
        let whisperAvailable = await registry.isProviderAvailable(.whisperKit)
        // let mlxAvailable = await registry.isProviderAvailable(.mlx) // Commented out for TDD RED phase
        
        #expect(count == 1) // Only WhisperKit provider registered for TDD RED phase
        #expect(availableTypes.contains(.whisperKit))
        // #expect(availableTypes.contains(.mlx)) // Commented out for TDD RED phase
        #expect(whisperAvailable == true)
        // #expect(mlxAvailable == true) // Commented out for TDD RED phase
    }
    
    @Test(.serialized)
    func registry_unregisterProvider() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        let mockProvider = MockTranscriptionProvider()
        await registry.register(mockProvider, for: .whisperKit)
        
        // Verify it's registered
        let initialCount = await registry.count
        #expect(initialCount == 1)
        
        // Unregister
        await registry.unregister(.whisperKit)
        
        let finalCount = await registry.count
        let isAvailable = await registry.isProviderAvailable(.whisperKit)
        
        #expect(finalCount == 0)
        #expect(isAvailable == false)
    }
    
    @Test(.serialized)
    func registry_clearAllProviders() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        // Register multiple providers
        await registry.register(MockTranscriptionProvider(), for: .whisperKit)
        // await registry.register(MockMLXProvider(), for: .mlx) // Commented out for TDD RED phase
        
        let initialCount = await registry.count
        #expect(initialCount == 1) // Only WhisperKit provider for TDD RED phase
        
        // Clear all
        await registry.clear()
        
        let finalCount = await registry.count
        let availableTypes = await registry.availableProviderTypes()
        
        #expect(finalCount == 0)
        #expect(availableTypes.isEmpty)
    }
    
    @Test(.serialized)
    func registry_availableProviderTypesSorted() async {
        let registry = TranscriptionProviderRegistry.shared
        await registry.clear()
        
        // Register in reverse alphabetical order
        await registry.register(MockTranscriptionProvider(), for: .whisperKit)
        // await registry.register(MockMLXProvider(), for: .mlx) // Commented out for TDD RED phase
        
        let availableTypes = await registry.availableProviderTypes()
        
        // Should be sorted by rawValue: only "whisperkit" available in TDD RED phase
        #expect(availableTypes == [.whisperKit]) // Only WhisperKit for TDD RED phase
    }
    
    // MARK: - TranscriptionProviderRegistryClient Tests
    
    @Test
    func registryClient_testValue() async throws {
        await withDependencies {
            $0.transcriptionProviderRegistry = .testValue
        } operation: {
            let client = TranscriptionProviderRegistryClient.testValue
            
            // Test default test values
            let count = await client.count()
            let availableTypes = await client.availableProviderTypes()
            let isAvailable = await client.isProviderAvailable(.whisperKit)
            
            #expect(count == 0)
            #expect(availableTypes.isEmpty)
            #expect(isAvailable == false)
            
            // Test that provider throws expected error
            await #expect(throws: TranscriptionProviderError.providerNotAvailable(.whisperKit)) {
                try await client.provider(.whisperKit)
            }
        }
    }
    
    // MARK: - TranscriptionProviderError Tests
    
    @Test
    func providerError_modelNotFound() {
        let error = TranscriptionProviderError.modelNotFound("tiny")
        let description = error.errorDescription
        
        #expect(description == "Model 'tiny' not found")
    }
    
    @Test
    func providerError_modelDownloadFailed() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let error = TranscriptionProviderError.modelDownloadFailed("base", underlyingError)
        let description = error.errorDescription
        
        #expect(description == "Failed to download model 'base': Network error")
    }
    
    @Test
    func providerError_transcriptionFailed() {
        let underlyingError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio format error"])
        let error = TranscriptionProviderError.transcriptionFailed("medium", underlyingError)
        let description = error.errorDescription
        
        #expect(description == "Transcription failed with model 'medium': Audio format error")
    }
    
    @Test
    func providerError_modelLoadFailed() {
        let underlyingError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Insufficient memory"])
        let error = TranscriptionProviderError.modelLoadFailed("large", underlyingError)
        let description = error.errorDescription
        
        #expect(description == "Failed to load model 'large': Insufficient memory")
    }
    
    @Test
    func providerError_unsupportedModelFormat() {
        let error = TranscriptionProviderError.unsupportedModelFormat("custom-model")
        let description = error.errorDescription
        
        #expect(description == "Unsupported model format for 'custom-model'")
    }
    
    @Test
    func providerError_providerNotAvailable() {
        let error = TranscriptionProviderError.providerNotAvailable(.mlx)
        let description = error.errorDescription
        
        #expect(description == "Provider 'MLX' is not available")
    }
    
    // MARK: - Protocol Compliance Tests
    
    @Test
    func mockProvider_conformsToProtocol() {
        let provider = MockTranscriptionProvider()
        
        // Test static properties
        #expect(MockTranscriptionProvider.providerType == .whisperKit)
        #expect(MockTranscriptionProvider.displayName == "Mock WhisperKit Provider")
        
        // Test that provider is an actor
        #expect(provider is any Actor)
    }
    
    @Test
    func mockProvider_hasRequiredMethods() async throws {
        let provider = MockTranscriptionProvider()
        
        // Test that all protocol methods exist and can be called
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")
        let options = DecodingOptions()
        let progress = Progress()
        
        // These should not throw compilation errors (methods exist)
        let transcription = try await provider.transcribe(
            audioURL: audioURL,
            modelName: "tiny",
            options: options,
            progressCallback: { _ in }
        )
        
        try await provider.downloadModel("tiny") { _ in }
        try await provider.deleteModel("tiny")
        let isDownloaded = await provider.isModelDownloaded("tiny")
        let models = try await provider.getAvailableModels()
        let recommended = try await provider.getRecommendedModel()
        
        // Verify mock behavior
        #expect(transcription == "Mock transcription result")
        #expect(isDownloaded == false)
        #expect(models.count == 2)
        #expect(recommended == "tiny")
    }
}

// MARK: - Mock Implementations for Testing

/// Mock TranscriptionProvider implementation for testing
actor MockTranscriptionProvider: TranscriptionProvider {
    static let providerType: TranscriptionProviderType = .whisperKit
    static let displayName: String = "Mock WhisperKit Provider"
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        // Simulate progress
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        progress.completedUnitCount = 50
        progressCallback(progress)
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        return "Mock transcription result"
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        progress.completedUnitCount = 100
        progressCallback(progress)
    }
    
    func deleteModel(_ modelName: String) async throws {
        // Mock deletion - no-op
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        return false
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        return [
            ProviderModelInfo(
                internalName: "tiny",
                displayName: "Tiny",
                providerType: .whisperKit,
                estimatedSize: "39 MB",
                isRecommended: true
            ),
            ProviderModelInfo(
                internalName: "base",
                displayName: "Base",
                providerType: .whisperKit,
                estimatedSize: "145 MB"
            )
        ]
    }
    
    func getRecommendedModel() async throws -> String {
        return "tiny"
    }
    
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        // Mock always succeeds
        return true
    }
    
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        // Mock always loaded
        return true
    }
}

/// MockMLXProvider declaration removed to avoid duplicate declarations.
/// This is expected for TDD RED phase - tests should use the MockMLXProvider 
/// from TranscriptionClientProviderTests.swift or create a shared mock utilities file.