//
//  WhisperKitProviderTests.swift
//  VocorizeTests
//
//  Fast unit tests for WhisperKitProvider using MockWhisperKitProvider
//  These tests run in <5 seconds total using test fixtures and mock data
//  For integration testing with real WhisperKit, use separate integration test files
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import AVFoundation
import WhisperKit

struct WhisperKitProviderTests {
    
    // MARK: - Test Setup
    
    /// Creates a fast mock provider for unit testing
    private func createMockProvider() async throws -> MockWhisperKitProvider {
        return try await MockWhisperKitProvider.withFastModels()
    }
    
    /// Creates a mock provider with recommended model pre-loaded
    private func createReadyMockProvider() async throws -> MockWhisperKitProvider {
        return try await MockWhisperKitProvider.withRecommendedModel()
    }
    
    /// Creates a mock provider configured for error testing
    private func createErrorMockProvider() async throws -> MockWhisperKitProvider {
        return try await MockWhisperKitProvider.withErrorSimulation()
    }
    
    // MARK: - Provider Identity Tests
    
    @Test
    func providerType_returnsWhisperKit() async throws {
        let provider = try await createMockProvider()
        #expect(MockWhisperKitProvider.providerType == .whisperKit)
    }
    
    @Test
    func displayName_returnsWhisperKit() async throws {
        let provider = try await createMockProvider()
        #expect(MockWhisperKitProvider.displayName.contains("WhisperKit"))
    }
    
    // MARK: - Model Download Tests
    
    @Test
    func downloadModel_downloadsModelWithProgress() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-base"
        var progressUpdates: [Progress] = []
        
        try await provider.downloadModel(modelName) { progress in
            progressUpdates.append(progress)
        }
        
        // Verify progress was reported during download
        #expect(!progressUpdates.isEmpty)
        #expect(progressUpdates.first?.totalUnitCount == 100)
        #expect(progressUpdates.last?.completedUnitCount == 100)
        
        // Verify model was downloaded
        let isDownloaded = await provider.isModelDownloaded(modelName)
        #expect(isDownloaded == true)
    }
    
    @Test
    func downloadModel_progressCallbackReceivesAccurateUpdates() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-tiny"
        var progressUpdates: [Double] = []
        
        try await provider.downloadModel(modelName) { progress in
            let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            progressUpdates.append(percentage)
        }
        
        // Verify progress went from 0 to 1.0
        #expect(progressUpdates.first == 0.0)
        #expect(progressUpdates.last == 1.0)
        #expect(progressUpdates.count > 5) // Should have multiple updates
        
        // Verify progress is monotonically increasing
        for i in 1..<progressUpdates.count {
            #expect(progressUpdates[i] >= progressUpdates[i-1])
        }
    }
    
    @Test
    func downloadModel_throwsErrorForInvalidModel() async throws {
        let provider = try await createMockProvider()
        let invalidModelName = "nonexistent_model_12345"
        
        do {
            try await provider.downloadModel(invalidModelName) { _ in }
            Issue.record("Expected error for invalid model, but download succeeded")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .modelNotFound(let model) = error as? TranscriptionProviderError {
                #expect(model == invalidModelName)
            }
        }
    }
    
    // MARK: - Model Loading Tests
    
    @Test
    func loadModel_loadsModelIntoMemory() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-base"
        
        // First ensure model is downloaded
        try await provider.downloadModel(modelName) { _ in }
        
        // Load model into memory
        let wasLoaded = try await provider.loadModelIntoMemory(modelName)
        #expect(wasLoaded == true)
        
        // Verify model is loaded and ready for transcription
        let isLoaded = await provider.isModelLoadedInMemory(modelName)
        #expect(isLoaded == true)
    }
    
    @Test
    func loadModel_unloadsCurrentModelWhenLoadingNew() async throws {
        let provider = try await createMockProvider()
        let firstModel = "openai_whisper-tiny"
        let secondModel = "openai_whisper-base"
        
        // Download both models
        try await provider.downloadModel(firstModel) { _ in }
        try await provider.downloadModel(secondModel) { _ in }
        
        // Load first model
        _ = try await provider.loadModelIntoMemory(firstModel)
        #expect(await provider.isModelLoadedInMemory(firstModel) == true)
        
        // Loading second model should unload first
        _ = try await provider.loadModelIntoMemory(secondModel)
        #expect(await provider.isModelLoadedInMemory(secondModel) == true)
        #expect(await provider.isModelLoadedInMemory(firstModel) == false)
    }
    
    // MARK: - Transcription Tests
    
    @Test
    func transcribe_usesLoadedModelForTranscription() async throws {
        let provider = try await createReadyMockProvider()
        let modelName = "openai_whisper-base"
        
        // Prepare test audio file
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        let options = DecodingOptions()
        var transcriptionProgress: [Progress] = []
        
        let result = try await provider.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            options: options,
            progressCallback: { progress in
                transcriptionProgress.append(progress)
            }
        )
        
        #expect(!result.isEmpty)
        #expect(!transcriptionProgress.isEmpty)
        #expect(transcriptionProgress.last?.isFinished == true)
    }
    
    @Test
    func transcribe_throwsErrorWhenModelNotDownloaded() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-base"
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        let options = DecodingOptions()
        
        do {
            _ = try await provider.transcribe(
                audioURL: audioURL,
                modelName: modelName,
                options: options,
                progressCallback: { _ in }
            )
            Issue.record("Expected error for undownloaded model, but transcription succeeded")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .modelLoadFailed = error as? TranscriptionProviderError {
                // Expected error type
            } else {
                Issue.record("Expected modelLoadFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - Model Deletion Tests
    
    @Test
    func deleteModel_removesModelFromDiskAndMemory() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-tiny"
        
        // Download and load model
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        // Verify model exists
        #expect(await provider.isModelDownloaded(modelName) == true)
        #expect(await provider.isModelLoadedInMemory(modelName) == true)
        
        try await provider.deleteModel(modelName)
        
        // Verify model is completely removed
        #expect(await provider.isModelDownloaded(modelName) == false)
        #expect(await provider.isModelLoadedInMemory(modelName) == false)
    }
    
    @Test
    func deleteModel_throwsErrorForNonExistentModel() async throws {
        let provider = try await createMockProvider()
        let nonExistentModel = "never_downloaded_model"
        
        do {
            try await provider.deleteModel(nonExistentModel)
            Issue.record("Expected error for non-existent model deletion")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .modelNotFound = error as? TranscriptionProviderError {
                // Expected error type
            }
        }
    }
    
    // MARK: - Model Status Tests
    
    @Test
    func isModelDownloaded_checksModelDirectory() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-base"
        
        // Initially should not be downloaded
        let initialStatus = await provider.isModelDownloaded(modelName)
        #expect(initialStatus == false)
        
        // After download should be true
        try await provider.downloadModel(modelName) { _ in }
        
        let finalStatus = await provider.isModelDownloaded(modelName)
        #expect(finalStatus == true)
        
        // Should provide model path information
        let modelPath = await provider.getModelPath(modelName)
        #expect(modelPath != nil)
    }
    
    @Test
    func isModelLoadedInMemory_checksMemoryStatus() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-tiny"
        
        // Initially not loaded
        let initialStatus = await provider.isModelLoadedInMemory(modelName)
        #expect(initialStatus == false)
        
        // Download and load
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        let loadedStatus = await provider.isModelLoadedInMemory(modelName)
        #expect(loadedStatus == true)
    }
    
    // MARK: - Available Models Tests
    
    @Test
    func getAvailableModels_returnsWhisperKitModels() async throws {
        let provider = try await createMockProvider()
        
        let models = try await provider.getAvailableModels()
        
        #expect(!models.isEmpty)
        #expect(models.allSatisfy { $0.providerType == .whisperKit })
        
        // Should include common WhisperKit models
        let modelNames = models.map { $0.internalName }
        #expect(modelNames.contains { $0.contains("whisper-tiny") })
        #expect(modelNames.contains { $0.contains("whisper-base") })
        #expect(modelNames.contains { $0.contains("whisper-small") })
        
        // Verify models have proper metadata
        #expect(models.first != nil)
        
        if let firstModel = models.first {
            #expect(!firstModel.displayName.isEmpty)
            #expect(!firstModel.estimatedSize.isEmpty)
            #expect(firstModel.estimatedSize != "Unknown")
        }
    }
    
    @Test
    func getAvailableModels_includesRecommendedModelInfo() async throws {
        let provider = try await createMockProvider()
        
        let models = try await provider.getAvailableModels()
        
        // Should have at least one recommended model
        let recommendedModels = models.filter { $0.isRecommended }
        #expect(!recommendedModels.isEmpty)
        
        // Recommended models should be suitable for current hardware
        let currentDevice = await provider.getCurrentDeviceCapabilities()
        for recommended in recommendedModels {
            let isCompatible = await provider.isModelCompatibleWithDevice(recommended.internalName, device: currentDevice)
            #expect(isCompatible == true)
        }
    }
    
    // MARK: - Model Recommendation Tests
    
    @Test
    func getRecommendedModel_selectsOptimalModel() async throws {
        let provider = try await createMockProvider()
        
        let recommendedModel = try await provider.getRecommendedModel()
        
        #expect(!recommendedModel.isEmpty)
        
        // Should be available for download
        let availableModels = try await provider.getAvailableModels()
        let modelNames = availableModels.map { $0.internalName }
        #expect(modelNames.contains(recommendedModel))
        
        // Should be marked as recommended
        let modelInfo = availableModels.first { $0.internalName == recommendedModel }
        #expect(modelInfo?.isRecommended == true)
        
        // Should be compatible with current device
        let deviceCapabilities = await provider.getCurrentDeviceCapabilities()
        let isCompatible = await provider.isModelCompatibleWithDevice(recommendedModel, device: deviceCapabilities)
        #expect(isCompatible == true)
    }
    
    @Test
    func getRecommendedModel_prefersBalancedPerformanceAndAccuracy() async throws {
        let provider = try await createMockProvider()
        
        let recommended = try await provider.getRecommendedModel()
        
        // For most devices, should prefer base or small models for balance
        let lowercased = recommended.lowercased()
        let isReasonableChoice = lowercased.contains("base") || 
                                lowercased.contains("small") || 
                                lowercased.contains("tiny")
        #expect(isReasonableChoice == true)
        
        // Should not recommend large models on constrained devices
        let deviceMemory = await provider.getAvailableDeviceMemory()
        if deviceMemory < 8_000_000_000 { // Less than 8GB
            #expect(!lowercased.contains("large"))
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func errorHandling_mapsErrorsToProviderErrors() async throws {
        let provider = try await createErrorMockProvider()
        
        do {
            let invalidAudioURL = URL(fileURLWithPath: "/nonexistent/audio/file.wav")
            _ = try await provider.transcribe(
                audioURL: invalidAudioURL,
                modelName: "openai_whisper-base",
                options: DecodingOptions(),
                progressCallback: { _ in }
            )
            Issue.record("Expected transcription error for invalid audio file")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .transcriptionFailed(_, let underlyingError) = error as? TranscriptionProviderError {
                // Should wrap the original error
                #expect(underlyingError.localizedDescription.contains("file") || 
                       underlyingError.localizedDescription.contains("audio"))
            }
        }
    }
    
    // MARK: - Model Path Management Tests
    
    @Test
    func getModelPath_returnsModelDirectory() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-base"
        
        // First download the model
        try await provider.downloadModel(modelName) { _ in }
        
        let modelPath = await provider.getModelPath(modelName)
        
        #expect(modelPath != nil)
        
        // Only check these if modelPath exists
        if let modelPath = modelPath {
            #expect(modelPath.path.contains("WhisperKit"))
            #expect(modelPath.path.contains(modelName))
            #expect(modelPath.isFileURL)
        }
    }
    
    @Test
    func getModelPath_returnsNilForNonExistentModel() async throws {
        let provider = try await createMockProvider()
        let nonExistentModel = "fantasy_model_xyz"
        
        let modelPath = await provider.getModelPath(nonExistentModel)
        #expect(modelPath == nil)
    }
    
    // MARK: - Progress Callback Tests
    
    @Test
    func progressCallbacks_reportAccurateDownloadProgress() async throws {
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-tiny"
        var progressValues: [Double] = []
        var progressDescriptions: [String] = []
        
        try await provider.downloadModel(modelName) { progress in
            let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            progressValues.append(percentage)
            progressDescriptions.append(progress.localizedDescription)
        }
        
        // Should have detailed progress reporting
        #expect(progressValues.count >= 5) // Multiple progress updates
        #expect(progressValues.first == 0.0)
        #expect(progressValues.last == 1.0)
        
        // Should have meaningful progress descriptions
        #expect(progressDescriptions.contains { $0.lowercased().contains("download") })
        #expect(progressDescriptions.contains { $0.lowercased().contains("model") })
    }
    
    @Test
    func progressCallbacks_reportTranscriptionProgress() async throws {
        let provider = try await createReadyMockProvider()
        let modelName = "openai_whisper-base"
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        var progressValues: [Double] = []
        var progressDescriptions: [String] = []
        
        _ = try await provider.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            options: DecodingOptions(),
            progressCallback: { progress in
                let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                progressValues.append(percentage)
                progressDescriptions.append(progress.localizedDescription)
            }
        )
        
        // Should report transcription-specific progress
        #expect(!progressValues.isEmpty)
        #expect(progressDescriptions.contains { $0.lowercased().contains("transcrib") })
    }
    
    // MARK: - Hardware Capability Tests
    
    @Test
    func getCurrentDeviceCapabilities_detectsHardwareFeatures() async throws {
        let provider = try await createMockProvider()
        
        let capabilities = await provider.getCurrentDeviceCapabilities()
        
        #expect(capabilities.hasNeuralEngine != nil)
        #expect(capabilities.availableMemory > 0)
        #expect(capabilities.coreMLComputeUnits != nil)
        #expect(!capabilities.supportedModelSizes.isEmpty)
    }
    
    @Test
    func isModelCompatibleWithDevice_checksHardwareRequirements() async throws {
        let provider = try await createMockProvider()
        let largeModel = "openai_whisper-large-v3"
        let tinyModel = "openai_whisper-tiny"
        
        let capabilities = await provider.getCurrentDeviceCapabilities()
        
        let largeCompatible = await provider.isModelCompatibleWithDevice(largeModel, device: capabilities)
        let tinyCompatible = await provider.isModelCompatibleWithDevice(tinyModel, device: capabilities)
        
        // Tiny model should always be compatible
        #expect(tinyCompatible == true)
        
        // Large model compatibility depends on available memory
        if capabilities.availableMemory < 4_000_000_000 { // Less than 4GB
            #expect(largeCompatible == false)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test
    func testSuite_completesWithinPerformanceTarget() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run a representative subset of operations
        let provider = try await createMockProvider()
        let modelName = "openai_whisper-tiny"
        
        // Model operations
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        _ = await provider.isModelDownloaded(modelName)
        _ = await provider.isModelLoadedInMemory(modelName)
        
        // Quick transcription
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        _ = try await provider.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Unit tests should complete much faster than 5 seconds
        #expect(executionTime < 5.0, "Test suite took \(executionTime) seconds, expected < 5 seconds")
        
        print("✅ Unit test performance: \(String(format: "%.2f", executionTime))s (target: <5s)")
    }
    
    // MARK: - Helper Methods
    
    private func createTestAudioFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test_audio.wav")
        
        // Create a minimal WAV file for testing
        let sampleRate: Double = 16000
        let duration: Double = 1.0
        let sampleCount = Int(sampleRate * duration)
        
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: audioURL, settings: audioFormat.settings)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(sampleCount))!
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        
        // Fill with silence (zeros)
        for i in 0..<sampleCount {
            buffer.floatChannelData![0][i] = 0.0
        }
        
        try audioFile.write(from: buffer)
        return audioURL
    }
}