//
//  WhisperKitProviderTests.swift
//  VocorizeTests
//
//  RED PHASE: Comprehensive failing tests for WhisperKitProvider
//  These tests MUST fail initially because the current WhisperKitProvider
//  only wraps TranscriptionClient. These tests verify it will work as
//  a self-contained implementation using WhisperKit APIs directly.
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import AVFoundation
import WhisperKit

struct WhisperKitProviderTests {
    
    // MARK: - Provider Identity Tests
    
    @Test
    func providerType_returnsWhisperKit() {
        #expect(WhisperKitProvider.providerType == .whisperKit)
    }
    
    @Test
    func displayName_returnsWhisperKit() {
        #expect(WhisperKitProvider.displayName == "WhisperKit")
    }
    
    // MARK: - Model Download Tests (MUST FAIL - provider doesn't implement direct WhisperKit download)
    
    @Test
    func downloadModel_downloadsModelDirectlyFromHuggingFace() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        var progressUpdates: [Progress] = []
        
        // This MUST fail because current provider wraps TranscriptionClient
        // The new implementation should download directly via WhisperKit.download(...)
        try await provider.downloadModel(modelName) { progress in
            progressUpdates.append(progress)
        }
        
        // Verify progress was reported during direct download
        #expect(!progressUpdates.isEmpty)
        #expect(progressUpdates.first?.totalUnitCount == 100)
        #expect(progressUpdates.last?.completedUnitCount == 100)
        
        // Verify model was downloaded to correct WhisperKit path
        let isDownloaded = await provider.isModelDownloaded(modelName)
        #expect(isDownloaded == true)
    }
    
    @Test
    func downloadModel_progressCallbackReceivesAccurateUpdates() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-tiny"
        var progressUpdates: [Double] = []
        
        // This MUST fail - current implementation doesn't provide real WhisperKit progress
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
        let provider = WhisperKitProvider()
        let invalidModelName = "nonexistent_model_12345"
        
        // This MUST fail - current implementation doesn't validate against WhisperKit models
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
    
    // MARK: - Model Loading Tests (MUST FAIL - provider doesn't manage WhisperKit instances)
    
    @Test
    func loadModel_loadsModelIntoMemoryDirectly() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        
        // First ensure model is downloaded
        try await provider.downloadModel(modelName) { _ in }
        
        // This MUST fail - current provider doesn't expose model loading
        // New implementation should load model into WhisperKit instance
        let wasLoaded = try await provider.loadModelIntoMemory(modelName)
        #expect(wasLoaded == true)
        
        // Verify model is loaded and ready for transcription
        let isLoaded = await provider.isModelLoadedInMemory(modelName)
        #expect(isLoaded == true)
    }
    
    @Test
    func loadModel_unloadsCurrentModelWhenLoadingNew() async throws {
        let provider = WhisperKitProvider()
        let firstModel = "openai_whisper-tiny"
        let secondModel = "openai_whisper-base"
        
        // Download both models
        try await provider.downloadModel(firstModel) { _ in }
        try await provider.downloadModel(secondModel) { _ in }
        
        // Load first model
        _ = try await provider.loadModelIntoMemory(firstModel)
        #expect(await provider.isModelLoadedInMemory(firstModel) == true)
        
        // This MUST fail - current provider doesn't manage memory
        // Loading second model should unload first
        _ = try await provider.loadModelIntoMemory(secondModel)
        #expect(await provider.isModelLoadedInMemory(secondModel) == true)
        #expect(await provider.isModelLoadedInMemory(firstModel) == false)
    }
    
    // MARK: - Transcription Tests (MUST FAIL - provider doesn't use loaded WhisperKit instances)
    
    @Test
    func transcribe_usesLoadedWhisperKitInstanceDirectly() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        
        // Prepare test audio file
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        // Ensure model is downloaded and loaded
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        let options = DecodingOptions()
        var transcriptionProgress: [Progress] = []
        
        // This MUST fail - current provider uses TranscriptionClient, not direct WhisperKit
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
    func transcribe_throwsErrorWhenModelNotLoaded() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        let options = DecodingOptions()
        
        // This MUST fail - current provider doesn't check if model is loaded in memory
        do {
            _ = try await provider.transcribe(
                audioURL: audioURL,
                modelName: modelName,
                options: options,
                progressCallback: { _ in }
            )
            Issue.record("Expected error for unloaded model, but transcription succeeded")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .modelLoadFailed = error as? TranscriptionProviderError {
                // Expected error type
            } else {
                Issue.record("Expected modelLoadFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - Model Deletion Tests (MUST FAIL - provider doesn't manage WhisperKit model files)
    
    @Test
    func deleteModel_removesModelFromDiskAndMemory() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-tiny"
        
        // Download and load model
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        // Verify model exists
        #expect(await provider.isModelDownloaded(modelName) == true)
        #expect(await provider.isModelLoadedInMemory(modelName) == true)
        
        // This MUST fail - current provider doesn't manage WhisperKit model storage
        try await provider.deleteModel(modelName)
        
        // Verify model is completely removed
        #expect(await provider.isModelDownloaded(modelName) == false)
        #expect(await provider.isModelLoadedInMemory(modelName) == false)
    }
    
    @Test
    func deleteModel_throwsErrorForNonExistentModel() async throws {
        let provider = WhisperKitProvider()
        let nonExistentModel = "never_downloaded_model"
        
        // This MUST fail - current provider doesn't validate model existence
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
    
    // MARK: - Model Status Tests (MUST FAIL - provider doesn't check WhisperKit model paths)
    
    @Test
    func isModelDownloaded_checksWhisperKitModelDirectory() async {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        
        // Initially should not be downloaded
        let initialStatus = await provider.isModelDownloaded(modelName)
        #expect(initialStatus == false)
        
        // After download should be true
        try? await provider.downloadModel(modelName) { _ in }
        
        // This MUST fail - current provider uses TranscriptionClient check, not WhisperKit paths
        let finalStatus = await provider.isModelDownloaded(modelName)
        #expect(finalStatus == true)
        
        // Should check actual WhisperKit model directory structure
        let modelPath = await provider.getModelPath(modelName)
        #expect(modelPath != nil)
        #expect(FileManager.default.fileExists(atPath: modelPath!.path))
    }
    
    @Test
    func isModelLoadedInMemory_checksWhisperKitInstance() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-tiny"
        
        // Initially not loaded
        let initialStatus = await provider.isModelLoadedInMemory(modelName)
        #expect(initialStatus == false)
        
        // Download and load
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        // This MUST fail - current provider doesn't expose memory status
        let loadedStatus = await provider.isModelLoadedInMemory(modelName)
        #expect(loadedStatus == true)
    }
    
    // MARK: - Available Models Tests (MUST FAIL - provider doesn't query WhisperKit directly)
    
    @Test
    func getAvailableModels_queriesWhisperKitDirectly() async throws {
        let provider = WhisperKitProvider()
        
        // This MUST fail - current provider uses TranscriptionClient, not WhisperKit.availableModels
        let models = try await provider.getAvailableModels()
        
        #expect(!models.isEmpty)
        #expect(models.allSatisfy { $0.providerType == .whisperKit })
        
        // Should include common WhisperKit models
        let modelNames = models.map { $0.internalName }
        #expect(modelNames.contains { $0.contains("whisper-tiny") })
        #expect(modelNames.contains { $0.contains("whisper-base") })
        #expect(modelNames.contains { $0.contains("whisper-small") })
        
        // Verify models have proper metadata
        let firstModel = models.first!
        #expect(!firstModel.displayName.isEmpty)
        #expect(!firstModel.estimatedSize.isEmpty)
        #expect(firstModel.estimatedSize != "Unknown")
    }
    
    @Test
    func getAvailableModels_includesRecommendedModelInfo() async throws {
        let provider = WhisperKitProvider()
        
        // This MUST fail - current implementation doesn't use WhisperKit recommendation logic
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
    
    // MARK: - Model Recommendation Tests (MUST FAIL - provider doesn't use WhisperKit hardware detection)
    
    @Test
    func getRecommendedModel_selectsOptimalModelForCurrentHardware() async throws {
        let provider = WhisperKitProvider()
        
        // This MUST fail - current provider uses TranscriptionClient logic, not WhisperKit hardware detection
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
    func getRecommendedModel_prefersBaseDrivenByPerformanceAndAccuracy() async throws {
        let provider = WhisperKitProvider()
        
        // This MUST fail - current provider doesn't implement WhisperKit performance heuristics
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
    
    // MARK: - Error Handling Tests (MUST FAIL - provider doesn't implement WhisperKit error mapping)
    
    @Test
    func errorHandling_mapsWhisperKitErrorsToProviderErrors() async throws {
        let provider = WhisperKitProvider()
        
        // This MUST fail - current provider doesn't map WhisperKit-specific errors
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
                // Should wrap the original WhisperKit error
                #expect(underlyingError.localizedDescription.contains("file") || 
                       underlyingError.localizedDescription.contains("audio"))
            }
        }
    }
    
    // MARK: - Model Path Management Tests (MUST FAIL - provider doesn't expose WhisperKit paths)
    
    @Test
    func getModelPath_returnsWhisperKitModelDirectory() async {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        
        // This MUST fail - current provider doesn't expose model paths
        let modelPath = await provider.getModelPath(modelName)
        
        #expect(modelPath != nil)
        #expect(modelPath!.path.contains("WhisperKit"))
        #expect(modelPath!.path.contains(modelName))
        #expect(modelPath!.isFileURL)
    }
    
    @Test
    func getModelPath_returnsNilForNonExistentModel() async {
        let provider = WhisperKitProvider()
        let nonExistentModel = "fantasy_model_xyz"
        
        // This MUST fail - current provider doesn't validate model existence
        let modelPath = await provider.getModelPath(nonExistentModel)
        #expect(modelPath == nil)
    }
    
    // MARK: - Progress Callback Tests (MUST FAIL - provider doesn't implement native WhisperKit progress)
    
    @Test
    func progressCallbacks_reportAccurateDownloadProgress() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-tiny"
        var progressValues: [Double] = []
        var progressDescriptions: [String] = []
        
        // This MUST fail - current provider doesn't provide granular WhisperKit progress
        try await provider.downloadModel(modelName) { progress in
            let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            progressValues.append(percentage)
            progressDescriptions.append(progress.localizedDescription)
        }
        
        // Should have detailed progress reporting
        #expect(progressValues.count >= 10) // Multiple progress updates
        #expect(progressValues.first == 0.0)
        #expect(progressValues.last == 1.0)
        
        // Should have meaningful progress descriptions
        #expect(progressDescriptions.contains { $0.lowercased().contains("download") })
        #expect(progressDescriptions.contains { $0.lowercased().contains("model") })
    }
    
    @Test
    func progressCallbacks_reportTranscriptionProgress() async throws {
        let provider = WhisperKitProvider()
        let modelName = "openai_whisper-base"
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        // Setup model
        try await provider.downloadModel(modelName) { _ in }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        var progressValues: [Double] = []
        var progressDescriptions: [String] = []
        
        // This MUST fail - current provider doesn't expose WhisperKit transcription progress
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
    
    // MARK: - Hardware Capability Tests (MUST FAIL - provider doesn't implement hardware detection)
    
    @Test
    func getCurrentDeviceCapabilities_detectsHardwareFeatures() async {
        let provider = WhisperKitProvider()
        
        // This MUST fail - current provider doesn't expose hardware detection
        let capabilities = await provider.getCurrentDeviceCapabilities()
        
        #expect(capabilities.hasNeuralEngine != nil)
        #expect(capabilities.availableMemory > 0)
        #expect(capabilities.coreMLComputeUnits != nil)
        #expect(!capabilities.supportedModelSizes.isEmpty)
    }
    
    @Test
    func isModelCompatibleWithDevice_checksHardwareRequirements() async {
        let provider = WhisperKitProvider()
        let largeModel = "openai_whisper-large-v3"
        let tinyModel = "openai_whisper-tiny"
        
        let capabilities = await provider.getCurrentDeviceCapabilities()
        
        // This MUST fail - current provider doesn't implement compatibility checking
        let largeCompatible = await provider.isModelCompatibleWithDevice(largeModel, device: capabilities)
        let tinyCompatible = await provider.isModelCompatibleWithDevice(tinyModel, device: capabilities)
        
        // Tiny model should always be compatible
        #expect(tinyCompatible == true)
        
        // Large model compatibility depends on available memory
        if capabilities.availableMemory < 4_000_000_000 { // Less than 4GB
            #expect(largeCompatible == false)
        }
    }
    
    // MARK: - Helper Methods (These will also fail as they don't exist)
    
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

// MARK: - Additional Types That Need To Exist

// DeviceCapabilities struct is now defined in WhisperKitProvider.swift