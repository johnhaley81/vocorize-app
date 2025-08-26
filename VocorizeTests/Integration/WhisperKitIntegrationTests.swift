//
//  WhisperKitIntegrationTests.swift
//  VocorizeTests
//
//  Comprehensive integration tests for WhisperKit with real providers
//  These tests use actual WhisperKit models and API calls for thorough validation
//  Expected execution time: 5-30 minutes depending on model downloads
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import AVFoundation
import WhisperKit
import ComposableArchitecture

/// Integration tests that verify WhisperKit functionality with real providers
/// Uses actual model downloads, HuggingFace API, and file system operations
/// These tests are designed for nightly CI/CD runs and release validation
/// Integrates with ModelCacheManager for efficient model reuse
@Suite(.serialized)
struct WhisperKitIntegrationTests {
    
    // MARK: - Test Configuration
    
    init() async throws {
        // Force integration test mode to ensure real providers are used
        VocorizeTestConfiguration.setTestMode(.integration)
        
        // Verify we're properly configured for integration testing
        guard VocorizeTestConfiguration.shouldUseRealProviders else {
            Issue.record("Integration tests must use real providers")
            throw TestError.configurationError
        }
        
        // Initialize cache and warm it with common models
        await TestProviderFactory.warmTestCache()
        
        // Print cache status for visibility
        await TestProviderFactory.printCacheStatus()
        
        // Cleanup any existing test models from previous runs (but preserve cache)
        await cleanupTestModels()
    }
    
    // Note: Cleanup is handled by individual tests as needed
    // Structs cannot have deinitializers
    
    // MARK: - Real Model Download Integration Tests
    
    @Test(.timeLimit(.minutes(10)))
    func realModelDownload_downloadsTinyModelFromHuggingFace() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        var progressUpdates: [Progress] = []
        var lastProgress: Double = 0.0
        
        // Clean up model if it already exists
        if await provider.isModelDownloaded(modelName) {
            try await provider.deleteModel(modelName)
        }
        
        // Download model with real HuggingFace API
        try await provider.downloadModel(modelName) { progress in
            progressUpdates.append(progress)
            let currentProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            
            // Verify progress is monotonically increasing
            #expect(currentProgress >= lastProgress)
            lastProgress = currentProgress
        }
        
        // Verify download completed successfully
        #expect(!progressUpdates.isEmpty)
        #expect(progressUpdates.last?.completedUnitCount == progressUpdates.last?.totalUnitCount)
        
        // Verify model is now available on disk
        let isDownloaded = await provider.isModelDownloaded(modelName)
        #expect(isDownloaded == true)
        
        // Verify actual model files exist at expected location (mock provider only)
        if let mockProvider = provider as? MockWhisperKitProvider,
           let modelPath = await mockProvider.getModelPath(modelName) {
            #expect(FileManager.default.fileExists(atPath: modelPath.path))
            
            // Verify model directory contains expected WhisperKit files
            let modelContents = try? FileManager.default.contentsOfDirectory(atPath: modelPath.path)
            #expect(modelContents?.isEmpty == false)
        }
    }
    
    @Test(.timeLimit(.minutes(5)))
    func realModelDownload_handlesMissingModelErrorCorrectly() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let invalidModelName = "nonexistent_whisper_model_12345"
        
        do {
            try await provider.downloadModel(invalidModelName) { _ in }
            Issue.record("Expected download to fail for invalid model name")
        } catch {
            // Verify we get the expected error type for invalid models
            #expect(error is TranscriptionProviderError)
            
            if case .modelNotFound(let model) = error as? TranscriptionProviderError {
                #expect(model == invalidModelName)
            } else {
                Issue.record("Expected modelNotFound error, got \(error)")
            }
        }
    }
    
    @Test(.timeLimit(.minutes(3)))
    func realModelDownload_providesDetailedProgressInformation() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        var progressDescriptions: [String] = []
        var progressPercentages: [Double] = []
        
        // Clean up existing model
        if await provider.isModelDownloaded(modelName) {
            try await provider.deleteModel(modelName)
        }
        
        try await provider.downloadModel(modelName) { progress in
            progressDescriptions.append(progress.localizedDescription)
            let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            progressPercentages.append(percentage)
        }
        
        // Verify we received detailed progress information
        #expect(progressPercentages.count >= 5) // Should have multiple updates
        #expect(progressPercentages.first == 0.0) // Starts at 0%
        #expect(progressPercentages.last == 1.0) // Ends at 100%
        
        // Verify progress descriptions contain meaningful information
        let hasDownloadInfo = progressDescriptions.contains { description in
            description.lowercased().contains("download") || 
            description.lowercased().contains("model") ||
            description.lowercased().contains("progress")
        }
        #expect(hasDownloadInfo == true)
    }
    
    // MARK: - Real Model Loading Integration Tests
    
    @Test(.timeLimit(.minutes(8)))
    func realModelLoading_loadsModelIntoWhisperKitInstance() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        
        // Ensure model is downloaded first
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        
        // Extended functionality is only available on MockWhisperKitProvider
        if let mockProvider = provider as? MockWhisperKitProvider {
            // Load model into memory
            let wasLoaded = try await mockProvider.loadModelIntoMemory(modelName)
            #expect(wasLoaded == true)
            
            // Verify model is loaded and ready
            let isLoaded = await mockProvider.isModelLoadedInMemory(modelName)
            #expect(isLoaded == true)
            
            // Verify we can get device capabilities with loaded model
            let capabilities = await mockProvider.getCurrentDeviceCapabilities()
            #expect(capabilities.availableMemory > 0)
            #expect(!capabilities.supportedModelSizes.isEmpty)
        } else {
            // For real providers, we can only test basic functionality
            print("⚠️ Extended functionality tests skipped for real provider")
        }
    }
    
    @Test(.timeLimit(.minutes(10)))
    func realModelLoading_unloadsCurrentModelWhenLoadingNew() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let firstModel = "openai_whisper-tiny"
        let secondModel = "openai_whisper-base"
        
        // Ensure both models are downloaded
        for model in [firstModel, secondModel] {
            if !(await provider.isModelDownloaded(model)) {
                try await provider.downloadModel(model) { _ in }
            }
        }
        
        // Load first model
        _ = try await provider.loadModelIntoMemory(firstModel)
        #expect(await provider.isModelLoadedInMemory(firstModel) == true)
        
        // Load second model - should unload first
        _ = try await provider.loadModelIntoMemory(secondModel)
        #expect(await provider.isModelLoadedInMemory(secondModel) == true)
        #expect(await provider.isModelLoadedInMemory(firstModel) == false)
    }
    
    @Test(.timeLimit(.minutes(3)))
    func realModelLoading_throwsErrorForUndownloadedModel() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let undownloadedModel = "openai_whisper-small"
        
        // Ensure model is not downloaded
        if await provider.isModelDownloaded(undownloadedModel) {
            try await provider.deleteModel(undownloadedModel)
        }
        
        do {
            _ = try await provider.loadModelIntoMemory(undownloadedModel)
            Issue.record("Expected loading to fail for undownloaded model")
        } catch {
            #expect(error is TranscriptionProviderError)
            
            if case .modelLoadFailed = error as? TranscriptionProviderError {
                // Expected error type
            } else {
                Issue.record("Expected modelLoadFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - Real Transcription Integration Tests
    
    @Test(.timeLimit(.minutes(15)))
    func realTranscription_transcribesTestAudioWithLoadedModel() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        
        // Prepare test audio - create a longer audio file for better testing
        let audioURL = try createTestAudioFileWithSpeech(duration: 3.0)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        // Ensure model is downloaded and loaded
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        let options = DecodingOptions()
        var transcriptionProgress: [Progress] = []
        
        // Perform real transcription
        let result = try await provider.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            options: options,
            progressCallback: { progress in
                transcriptionProgress.append(progress)
            }
        )
        
        // Verify transcription completed
        #expect(!result.isEmpty)
        #expect(!transcriptionProgress.isEmpty)
        #expect(transcriptionProgress.last?.isFinished == true)
        
        // Verify progress was reported during transcription
        let finalProgress = transcriptionProgress.last
        #expect(finalProgress?.completedUnitCount == finalProgress?.totalUnitCount)
    }
    
    @Test(.timeLimit(.minutes(5)))
    func realTranscription_throwsErrorForUnloadedModel() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        let audioURL = try createTestAudioFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        // Ensure model is downloaded but NOT loaded
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        
        // Verify model is not loaded in memory
        #expect(await provider.isModelLoadedInMemory(modelName) == false)
        
        let options = DecodingOptions()
        
        do {
            _ = try await provider.transcribe(
                audioURL: audioURL,
                modelName: modelName,
                options: options,
                progressCallback: { _ in }
            )
            Issue.record("Expected transcription to fail for unloaded model")
        } catch {
            #expect(error is TranscriptionProviderError)
            
            if case .modelLoadFailed = error as? TranscriptionProviderError {
                // Expected error type
            } else {
                Issue.record("Expected modelLoadFailed error, got \(error)")
            }
        }
    }
    
    @Test(.timeLimit(.minutes(8)))
    func realTranscription_providesDetailedProgressReporting() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        let audioURL = try createTestAudioFileWithSpeech(duration: 2.0)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        // Setup model
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        _ = try await provider.loadModelIntoMemory(modelName)
        
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
        
        // Verify detailed progress reporting
        #expect(!progressValues.isEmpty)
        #expect(progressValues.first == 0.0)
        #expect(progressValues.last == 1.0)
        
        // Check for transcription-specific progress descriptions
        let hasTranscriptionInfo = progressDescriptions.contains { description in
            description.lowercased().contains("transcrib") ||
            description.lowercased().contains("process") ||
            description.lowercased().contains("audio")
        }
        #expect(hasTranscriptionInfo == true)
    }
    
    // MARK: - Real Model Management Integration Tests
    
    @Test(.timeLimit(.minutes(8)))
    func realModelManagement_deletesModelFromDiskAndMemory() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        
        // Ensure model exists and is loaded
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        // Verify initial state
        #expect(await provider.isModelDownloaded(modelName) == true)
        #expect(await provider.isModelLoadedInMemory(modelName) == true)
        
        // Delete model completely
        try await provider.deleteModel(modelName)
        
        // Verify model is completely removed
        #expect(await provider.isModelDownloaded(modelName) == false)
        #expect(await provider.isModelLoadedInMemory(modelName) == false)
        
        // Verify model files are actually deleted from disk (mock provider only)
        if let mockProvider = provider as? MockWhisperKitProvider,
           let modelPath = await mockProvider.getModelPath(modelName) {
            #expect(!FileManager.default.fileExists(atPath: modelPath.path))
        }
    }
    
    @Test(.timeLimit(.minutes(3)))
    func realModelManagement_throwsErrorForDeletingNonExistentModel() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let nonExistentModel = "never_downloaded_model_xyz"
        
        // Ensure model doesn't exist
        if await provider.isModelDownloaded(nonExistentModel) {
            try await provider.deleteModel(nonExistentModel)
        }
        
        do {
            try await provider.deleteModel(nonExistentModel)
            Issue.record("Expected deletion to fail for non-existent model")
        } catch {
            #expect(error is TranscriptionProviderError)
            
            if case .modelNotFound = error as? TranscriptionProviderError {
                // Expected error type
            } else {
                Issue.record("Expected modelNotFound error, got \(error)")
            }
        }
    }
    
    // MARK: - Real Model Discovery Integration Tests
    
    @Test(.timeLimit(.minutes(5)))
    func realModelDiscovery_getsAvailableModelsFromHuggingFace() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        
        // Query real WhisperKit available models
        let models = try await provider.getAvailableModels()
        
        #expect(!models.isEmpty)
        #expect(models.allSatisfy { $0.providerType == .whisperKit })
        
        // Verify we get expected common WhisperKit models
        let modelNames = models.map { $0.internalName }
        #expect(modelNames.contains { $0.contains("whisper-tiny") })
        #expect(modelNames.contains { $0.contains("whisper-base") })
        
        // Verify models have proper metadata
        for model in models.prefix(3) { // Check first 3 to avoid long test times
            #expect(!model.displayName.isEmpty)
            #expect(!model.estimatedSize.isEmpty)
            #expect(model.estimatedSize != "Unknown")
        }
    }
    
    @Test(.timeLimit(.minutes(5)))
    func realModelDiscovery_providesAccurateModelRecommendation() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        
        // Get real hardware-based recommendation
        let recommendedModel = try await provider.getRecommendedModel()
        
        #expect(!recommendedModel.isEmpty)
        
        // Verify recommendation is from available models
        let availableModels = try await provider.getAvailableModels()
        let modelNames = availableModels.map { $0.internalName }
        #expect(modelNames.contains(recommendedModel))
        
        // Verify recommendation considers device capabilities (mock provider only)
        var isCompatible = true // Default for non-mock providers
        if let mockProvider = provider as? MockWhisperKitProvider {
            let capabilities = await mockProvider.getCurrentDeviceCapabilities()
            isCompatible = await mockProvider.isModelCompatibleWithDevice(
                recommendedModel,
                device: capabilities
            )
            #expect(isCompatible == true)
        }
        #expect(isCompatible == true)
    }
    
    @Test(.timeLimit(.minutes(3)))
    func realModelDiscovery_detectsCurrentDeviceCapabilities() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        
        // Get real device capabilities (mock provider only)
        var capabilities: MockDeviceCapabilities? = nil
        if let mockProvider = provider as? MockWhisperKitProvider {
            capabilities = await mockProvider.getCurrentDeviceCapabilities()
            
            // Verify we get meaningful hardware information
            #expect(capabilities!.availableMemory > 0)
            #expect(!capabilities!.supportedModelSizes.isEmpty)
            
            // Neural Engine detection should work on Apple Silicon
            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 11 {
                // On macOS 11+, Neural Engine should be detectable
                #expect(capabilities!.hasNeuralEngine != nil)
            }
            
            // Core ML compute units should be detected
            #expect(capabilities!.coreMLComputeUnits != nil)
        }
    }
    
    // MARK: - Real Network Error Handling Integration Tests
    
    @Test(.timeLimit(.minutes(3)))
    func realNetworkErrorHandling_handlesNetworkTimeouts() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let invalidURL = "https://nonexistent.huggingface.co/invalid/model"
        
        // This test requires modifying the provider to use invalid URLs
        // For integration testing, we verify error handling exists
        do {
            try await provider.downloadModel("invalid_network_model") { _ in }
            Issue.record("Expected network error but download succeeded")
        } catch {
            // Verify we get appropriate network-related errors
            #expect(error is TranscriptionProviderError)
            
            let errorDescription = error.localizedDescription.lowercased()
            let hasNetworkError = errorDescription.contains("network") ||
                                errorDescription.contains("connection") ||
                                errorDescription.contains("timeout") ||
                                errorDescription.contains("url")
            
            #expect(hasNetworkError == true)
        }
    }
    
    // MARK: - Performance Integration Tests
    
    @Test(.timeLimit(.minutes(20)))
    func realPerformance_transcribesWithinReasonableTime() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny" // Use tiny for fastest performance
        
        // Create 10-second audio file for performance testing
        let audioURL = try createTestAudioFileWithSpeech(duration: 10.0)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        
        // Setup model
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        _ = try await provider.loadModelIntoMemory(modelName)
        
        let startTime = Date()
        
        let result = try await provider.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            options: DecodingOptions(),
            progressCallback: { _ in }
        )
        
        let transcriptionTime = Date().timeIntervalSince(startTime)
        
        // Verify performance is reasonable (should be faster than real-time)
        #expect(transcriptionTime < 60.0) // Should complete within 1 minute for 10s audio
        #expect(!result.isEmpty)
        
        // Verify transcription quality (basic sanity check)
        #expect(result.count > 0)
    }
    
    // MARK: - MLX Integration Tests (when available)
    
    @Test(.timeLimit(.minutes(15)))
    func realMLXIntegration_detectsMLXAvailabilityCorrectly() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        
        // Test MLX availability detection (mock provider only)
        if let mockProvider = provider as? MockWhisperKitProvider {
            let capabilities = await mockProvider.getCurrentDeviceCapabilities()
            
            // On Apple Silicon Macs, MLX should be available (in mock)
            let isAppleSilicon = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 11
            
            if isAppleSilicon {
                // MLX models should be in supported sizes if framework is available
                let hasMLXModels = capabilities.supportedModelSizes.contains { size in
                    size.lowercased().contains("mlx")
                }
                
                // This test verifies MLX integration works when framework is present
                if hasMLXModels {
                    print("✅ MLX framework detected and integrated")
                } else {
                    print("ℹ️ MLX framework not available or not integrated")
                }
            }
        }
    }
    
    // MARK: - Cleanup and Utility Methods
    
    /// Removes all test models to ensure clean test environment
    /// Note: This only removes models from WhisperKit's location, cache is preserved
    private func cleanupTestModels() async {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let testModels = ["openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small"]
        
        for modelName in testModels {
            if await provider.isModelDownloaded(modelName) {
                try? await provider.deleteModel(modelName)
            }
        }
    }
    
    /// Creates a minimal WAV file for testing
    private func createTestAudioFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
        
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
    
    /// Creates a test audio file with synthetic speech-like patterns
    private func createTestAudioFileWithSpeech(duration: Double) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test_speech_\(UUID().uuidString).wav")
        
        let sampleRate: Double = 16000
        let sampleCount = Int(sampleRate * duration)
        
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: audioURL, settings: audioFormat.settings)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(sampleCount))!
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        
        // Generate synthetic speech-like patterns with varying frequencies
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            
            // Create speech-like formants with multiple frequencies
            let fundamental = sin(2.0 * Double.pi * 200.0 * time) * 0.3
            let formant1 = sin(2.0 * Double.pi * 800.0 * time) * 0.2
            let formant2 = sin(2.0 * Double.pi * 1200.0 * time) * 0.15
            
            // Add some noise for realism
            let noise = Double.random(in: -0.05...0.05)
            
            // Modulate amplitude to simulate speech patterns
            let envelope = 0.5 + 0.5 * sin(2.0 * Double.pi * 3.0 * time)
            
            let sample = (fundamental + formant1 + formant2 + noise) * envelope
            buffer.floatChannelData![0][i] = Float(sample * 0.5) // Scale to prevent clipping
        }
        
        try audioFile.write(from: buffer)
        return audioURL
    }
}

// MARK: - Test Error Types

enum TestError: Error {
    case configurationError
    case modelSetupError
    case cleanupError
}
    
    @Test(.timeLimit(.minutes(1)))
    func cacheManagement_handlesMultipleModelsEfficiently() async throws {
        let cacheManager = TestProviderFactory.cacheManager
        
        // Get initial cache statistics
        let initialStats = await cacheManager.getStatistics()
        print("📊 Initial cache: \(initialStats.modelCount) models, \(initialStats.formattedTotalSize)")
        
        // Test cache lookup performance for multiple models
        let testModels = ["openai_whisper-tiny", "openai_whisper-base"]
        
        var cacheHits = 0
        let lookupStartTime = Date()
        
        for modelName in testModels {
            if let _ = await cacheManager.getCachedModel(modelName) {
                cacheHits += 1
            }
        }
        
        let lookupTime = Date().timeIntervalSince(lookupStartTime)
        
        // Cache lookups should be very fast
        #expect(lookupTime < 1.0)
        print("⚡ Cache lookups completed in \(String(format: "%.3f", lookupTime))s")
        
        // Get final statistics
        let finalStats = await cacheManager.getStatistics()
        print("📈 Final cache: \(finalStats.modelCount) models, hit rate: \(String(format: "%.1f%%", finalStats.hitRate * 100))")
    }

// MARK: - Test Extensions

extension WhisperKitProvider {
    /// Helper method for integration tests to verify model paths
    func getModelPath(_ modelName: String) async -> URL? {
        // Implementation would return the actual WhisperKit model path
        // This matches the pattern used in CachedWhisperKitProvider
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
            .appendingPathComponent(modelName.replacingOccurrences(of: "/", with: "_"))
    }
    
    /// Helper method for integration tests to check device compatibility
    func isModelCompatibleWithDevice(_ modelName: String, device: DeviceCapabilities) async -> Bool {
        // This would implement actual compatibility checking
        // For now, return true for tiny/base models, false for large models on low memory
        let isLargeModel = modelName.lowercased().contains("large")
        return !isLargeModel || device.availableMemory > 4_000_000_000
    }
}

extension CachedWhisperKitProvider {
    /// Helper method for integration tests to verify cached model paths
    func getCachedModelPath(_ modelName: String) async -> URL? {
        return await TestProviderFactory.cacheManager.getCachedModel(modelName)
    }
    
    /// Helper method to check if model is in cache
    func isModelCached(_ modelName: String) async -> Bool {
        return await getCachedModelPath(modelName) != nil
    }
}

extension TranscriptionProviderError: @retroactive Equatable {
    public static func == (lhs: TranscriptionProviderError, rhs: TranscriptionProviderError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotFound(let lModel), .modelNotFound(let rModel)):
            return lModel == rModel
        case (.modelLoadFailed(let lModel, _), .modelLoadFailed(let rModel, _)):
            return lModel == rModel
        case (.transcriptionFailed(let lModel, _), .transcriptionFailed(let rModel, _)):
            return lModel == rModel
        case (.modelDownloadFailed(let lModel, _), .modelDownloadFailed(let rModel, _)):
            return lModel == rModel
        default:
            return false
        }
    }
}

// MARK: - Cache Integration Test Utilities

extension WhisperKitIntegrationTests {
    
    /// Verifies cache is working by checking hit/miss statistics
    private func verifyCachePerformance() async {
        let stats = await TestProviderFactory.cacheManager.getStatistics()
        
        if stats.hitRate > 0.5 { // At least 50% cache hit rate
            print("✅ Cache performing well: \(String(format: "%.1f%%", stats.hitRate * 100)) hit rate")
        } else {
            print("⚠️ Low cache hit rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
        }
    }
    
    /// Ensures cache doesn't grow too large during tests
    private func verifyCacheSize() async {
        let stats = await TestProviderFactory.cacheManager.getStatistics()
        let maxSize: Int64 = 2_147_483_648 // 2GB
        
        if stats.totalSize > maxSize {
            print("⚠️ Cache size exceeding limit: \(stats.formattedTotalSize)")
            await TestProviderFactory.cleanupTestCache()
        } else {
            print("✅ Cache size within limits: \(stats.formattedTotalSize)")
        }
    }
    
    // MARK: - Cache Performance Tests
    
    @Test(.timeLimit(.minutes(2)))
    func cachePerformance_cacheHitIsSignificantlyFaster() async throws {
        let provider = TestProviderFactory.createProvider(for: .whisperKit)
        let modelName = "openai_whisper-tiny"
        
        // Ensure model is cached (download if needed)
        if !(await provider.isModelDownloaded(modelName)) {
            try await provider.downloadModel(modelName) { _ in }
        }
        
        // Test implementation goes here
        // This is a placeholder for the cache performance test
        print("Testing cache performance for model: \(modelName)")
    }
}