//
//  ExampleUsage.swift
//  VocorizeTests
//
//  Example usage of test fixtures for WhisperKit testing
//  Shows how to use fixtures for fast, predictable testing
//

import Foundation
import Testing
import WhisperKit
@testable import Vocorize

/// Example test cases showing fixture usage
struct FixtureUsageExamples {
    
    // MARK: - Basic Fixture Loading
    
    @Test
    func loadTestModels_example() throws {
        let models = try TestFixtures.loadTestModels()
        
        #expect(models.models.count >= 6)
        #expect(models.version == "1.0")
        #expect(!models.testConfiguration.fastTestModels.isEmpty)
        
        // Get specific model
        let baseModel = try TestFixtures.getTestModel(internalName: "openai_whisper-base")
        #expect(baseModel.isRecommended == true)
        #expect(baseModel.testCompatible == true)
    }
    
    @Test
    func loadExpectedTranscriptions_example() throws {
        let transcriptions = try TestFixtures.loadExpectedTranscriptions()
        
        #expect(!transcriptions.transcriptions.isEmpty)
        
        // Get expected result for specific audio
        let helloResult = try TestFixtures.getExpectedTranscription(audioFileName: "hello_world.wav")
        #expect(helloResult.text == "Hello world, this is a test.")
        #expect(helloResult.confidence > 0.9)
        #expect(helloResult.language == "en")
        #expect(helloResult.segments.count == 2)
    }
    
    @Test
    func loadMockPaths_example() throws {
        let paths = try TestFixtures.loadMockPaths()
        
        #expect(!paths.modelPaths.isEmpty)
        #expect(paths.testConfiguration.mockFileSystem == true)
        
        // Get path for specific model
        let basePath = try TestFixtures.getMockPath(modelName: "openai_whisper-base")
        #expect(basePath.modelPath.contains("WhisperKit/Models"))
        #expect(basePath.exists == false) // Initially not downloaded
    }
    
    // MARK: - Mock Provider Usage
    
    @Test
    func mockProvider_basicUsage() async throws {
        // Ensure test audio exists
        try TestFixtures.ensureTestAudioFilesExist()
        
        // Create and configure mock provider
        let provider = try await MockWhisperKitProvider()
        await provider.setSimulateNetworkDelay(false) // Instant operations
        await provider.setOperationDelay(0.001) // Minimal delay
        
        // Test model availability
        let availableModels = try await provider.getAvailableModels()
        #expect(availableModels.count >= 3)
        
        let whisperKitModels = availableModels.filter { $0.providerType == .whisperKit }
        #expect(!whisperKitModels.isEmpty)
    }
    
    @Test
    func mockProvider_downloadAndLoad() async throws {
        let provider = try await MockWhisperKitProvider()
        await provider.setSimulateNetworkDelay(false)
        
        let modelName = "openai_whisper-base"
        
        // Initially not downloaded
        let initialStatus = await provider.isModelDownloaded(modelName)
        #expect(initialStatus == false)
        
        // Download model
        var progressUpdates: [Progress] = []
        try await provider.downloadModel(modelName) { progress in
            progressUpdates.append(progress)
        }
        
        // Verify download completed
        #expect(!progressUpdates.isEmpty)
        #expect(progressUpdates.last?.completedUnitCount == 100)
        
        let downloadedStatus = await provider.isModelDownloaded(modelName)
        #expect(downloadedStatus == true)
        
        // Load into memory (extended functionality)
        let loadResult = try await provider.loadModelIntoMemory(modelName)
        #expect(loadResult == true)
        
        let loadedStatus = await provider.isModelLoadedInMemory(modelName)
        #expect(loadedStatus == true)
    }
    
    @Test
    func mockProvider_transcription() async throws {
        try TestFixtures.ensureTestAudioFilesExist()
        
        let provider = try await MockWhisperKitProvider(preloadModels: ["openai_whisper-base"])
        await provider.setSimulateNetworkDelay(false)
        
        let audioURL = TestFixtures.getTestAudioURL(filename: "hello_world.wav")
        #expect(TestFixtures.testAudioFileExists(filename: "hello_world.wav"))
        
        var transcriptionProgress: [Progress] = []
        let result = try await provider.transcribe(
            audioURL: audioURL,
            modelName: "openai_whisper-base",
            options: DecodingOptions(),
            progressCallback: { progress in
                transcriptionProgress.append(progress)
            }
        )
        
        #expect(result == "Hello world, this is a test.")
        #expect(!transcriptionProgress.isEmpty)
        #expect(transcriptionProgress.last?.completedUnitCount == 100)
    }
    
    @Test
    func mockProvider_silenceHandling() async throws {
        try TestFixtures.ensureTestAudioFilesExist()
        
        let provider = try await MockWhisperKitProvider(preloadModels: ["openai_whisper-tiny"])
        await provider.setSimulateNetworkDelay(false)
        
        let silenceURL = TestFixtures.getTestAudioURL(filename: "silence.wav")
        let result = try await provider.transcribe(
            audioURL: silenceURL,
            modelName: "openai_whisper-tiny",
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        
        #expect(result.isEmpty) // Silence should return empty string
    }
    
    @Test
    func mockProvider_errorScenarios() async throws {
        try TestFixtures.ensureTestAudioFilesExist()
        
        let provider = try await MockWhisperKitProvider(preloadModels: ["openai_whisper-base"])
        await provider.setSimulateNetworkDelay(false)
        
        // Test corrupted audio
        let corruptedURL = TestFixtures.getTestAudioURL(filename: "corrupted_audio.wav")
        
        do {
            _ = try await provider.transcribe(
                audioURL: corruptedURL,
                modelName: "openai_whisper-base",
                options: DecodingOptions(),
                progressCallback: { _ in }
            )
            Issue.record("Expected error for corrupted audio file")
        } catch {
            #expect(error is TranscriptionProviderError)
        }
    }
    
    // MARK: - Hardware Simulation
    
    @Test
    func mockProvider_hardwareDetection() async throws {
        let provider = try await MockWhisperKitProvider()
        
        let capabilities = await provider.getCurrentDeviceCapabilities()
        #expect(capabilities.hasNeuralEngine == true)
        #expect(capabilities.availableMemory > 0)
        
        // Test model compatibility
        let tinyCompatible = await provider.isModelCompatibleWithDevice("openai_whisper-tiny", device: capabilities)
        #expect(tinyCompatible == true)
        
        let largeCompatible = await provider.isModelCompatibleWithDevice("openai_whisper-large-v3", device: capabilities)
        // Large model might not be test compatible
        #expect(largeCompatible == false)
    }
    
    @Test
    func mockProvider_recommendedModel() async throws {
        let provider = try await MockWhisperKitProvider()
        
        let recommended = try await provider.getRecommendedModel()
        #expect(recommended == "openai_whisper-base")
        
        // Verify it's actually marked as recommended
        let testModel = try TestFixtures.getTestModel(internalName: recommended)
        #expect(testModel.isRecommended == true)
    }
    
    // MARK: - Model Management Tests
    
    @Test
    func mockProvider_modelDeletion() async throws {
        let provider = try await MockWhisperKitProvider()
        let modelName = "openai_whisper-tiny"
        
        // Download first
        try await provider.downloadModel(modelName) { _ in }
        #expect(await provider.isModelDownloaded(modelName) == true)
        
        // Delete
        try await provider.deleteModel(modelName)
        #expect(await provider.isModelDownloaded(modelName) == false)
        #expect(await provider.isModelLoadedInMemory(modelName) == false)
    }
    
    @Test
    func mockProvider_pathRetrieval() async throws {
        let provider = try await MockWhisperKitProvider()
        let modelName = "openai_whisper-base"
        
        // No path when not downloaded
        let noPath = await provider.getModelPath(modelName)
        #expect(noPath == nil)
        
        // Path available after download
        try await provider.downloadModel(modelName) { _ in }
        let downloadedPath = await provider.getModelPath(modelName)
        #expect(downloadedPath != nil)
        #expect(downloadedPath?.path.contains(modelName) == true)
    }
    
    // MARK: - Fast Test Model Selection
    
    @Test
    func fastTestModels_selection() throws {
        let fastModels = try TestFixtures.getFastTestModels()
        
        // Should include tiny and base models
        let modelNames = fastModels.map { $0.internalName }
        #expect(modelNames.contains("openai_whisper-tiny"))
        #expect(modelNames.contains("openai_whisper-base"))
        
        // All fast models should be test compatible
        #expect(fastModels.allSatisfy { $0.testCompatible })
        
        // Should be suitable for quick testing (small sizes)
        #expect(fastModels.allSatisfy { model in
            let sizeValue = Int(model.storageSize.replacingOccurrences(of: "MB", with: "")) ?? 0
            return sizeValue < 600 // Less than 600MB
        })
    }
    
    @Test
    func testCompatibleModels_filtering() throws {
        let compatibleModels = try TestFixtures.getTestCompatibleModels()
        
        #expect(!compatibleModels.isEmpty)
        #expect(compatibleModels.allSatisfy { $0.testCompatible })
        
        // Should include at least tiny, base, and small models
        let names = compatibleModels.map { $0.internalName }
        #expect(names.contains("openai_whisper-tiny"))
        #expect(names.contains("openai_whisper-base"))
        #expect(names.contains("openai_whisper-small"))
    }
    
    // MARK: - Provider Model Info Conversion
    
    @Test
    func providerModelInfo_conversion() throws {
        let allModels = try TestFixtures.getAllProviderModelInfo()
        
        #expect(!allModels.isEmpty)
        #expect(allModels.allSatisfy { !$0.displayName.isEmpty })
        #expect(allModels.allSatisfy { !$0.internalName.isEmpty })
        #expect(allModels.allSatisfy { !$0.estimatedSize.isEmpty })
        
        // Get WhisperKit models specifically
        let whisperKitModels = try TestFixtures.getProviderModelInfo(for: .whisperKit)
        #expect(!whisperKitModels.isEmpty)
        #expect(whisperKitModels.allSatisfy { $0.providerType == .whisperKit })
    }
    
    // MARK: - Audio File Management
    
    @Test
    func audioFileGeneration_onDemand() throws {
        // Clean up any existing files first
        let audioDir = TestFixtures.getTestAudioURL(filename: "").deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: audioDir.path) {
            try FileManager.default.removeItem(at: audioDir)
        }
        
        // Generate files on demand
        try TestFixtures.ensureTestAudioFilesExist()
        
        // Verify files exist
        let requiredFiles = [
            "silence.wav",
            "hello_world.wav",
            "quick_brown_fox.wav",
            "numbers_123.wav",
            "multilingual_sample.wav",
            "noisy_audio.wav",
            "long_sentence.wav"
        ]
        
        for filename in requiredFiles {
            #expect(TestFixtures.testAudioFileExists(filename: filename))
        }
    }
    
    // MARK: - Error Handling
    
    @Test
    func fixtureErrors_handling() throws {
        // Test missing model error
        do {
            _ = try TestFixtures.getTestModel(internalName: "nonexistent_model")
            Issue.record("Expected error for missing model")
        } catch TestFixtureError.modelNotFound(let name) {
            #expect(name == "nonexistent_model")
        }
        
        // Test missing transcription error
        do {
            _ = try TestFixtures.getExpectedTranscription(audioFileName: "nonexistent_audio.wav")
            Issue.record("Expected error for missing transcription")
        } catch TestFixtureError.transcriptionNotFound(let filename) {
            #expect(filename == "nonexistent_audio.wav")
        }
        
        // Test missing path error
        do {
            _ = try TestFixtures.getMockPath(modelName: "nonexistent_model")
            Issue.record("Expected error for missing path")
        } catch TestFixtureError.pathNotFound(let modelName) {
            #expect(modelName == "nonexistent_model")
        }
    }
    
    // MARK: - Factory Method Tests
    
    @Test
    func mockProvider_factoryMethods() async throws {
        // Test fast models factory
        let fastProvider = try await MockWhisperKitProvider.withFastModels()
        let fastModels = try await fastProvider.getAvailableModels()
        let downloadedCount = fastModels.filter { $0.isDownloaded }.count
        #expect(downloadedCount >= 2) // Should have fast models pre-downloaded
        
        // Test recommended model factory
        let recommendedProvider = try await MockWhisperKitProvider.withRecommendedModel()
        let recommendedModel = try await recommendedProvider.getRecommendedModel()
        let isDownloaded = await recommendedProvider.isModelDownloaded(recommendedModel)
        let isLoaded = await recommendedProvider.isModelLoadedInMemory(recommendedModel)
        #expect(isDownloaded == true)
        #expect(isLoaded == true)
        
        // Test error simulation factory
        let errorProvider = try await MockWhisperKitProvider.withErrorSimulation()
        // This would be used for testing error scenarios
        let models = try await errorProvider.getAvailableModels()
        #expect(!models.isEmpty) // Should still return models, errors are context-dependent
    }
}