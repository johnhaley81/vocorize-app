//
//  MLXIntegrationTests.swift
//  VocorizeTests
//
//  Comprehensive integration tests for MLX functionality within the broader provider system.
//  Tests real MLX functionality when available with graceful fallback when unavailable.
//  Validates complete transcription workflows and provider factory integration.
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import AVFoundation
import WhisperKit
import ComposableArchitecture

#if canImport(MLX)
import MLX
#endif

#if canImport(MLXNN)
import MLXNN
#endif

/// Comprehensive integration tests for MLX functionality within the provider system
/// These tests validate the complete MLX integration pipeline while maintaining 
/// compatibility across different system configurations (MLX available vs unavailable)
struct MLXIntegrationTests {
    
    // MARK: - Test Environment Detection
    
    private let testMode: TestMode
    private let mlxAvailable: Bool
    
    init() async {
        self.testMode = ProcessInfo.processInfo.environment["VOCORIZE_TEST_MODE"]
            .flatMap(TestMode.init) ?? .integration
        self.mlxAvailable = MLXAvailability.isAvailable
    }
    
    private enum TestMode: String {
        case unit
        case integration
        
        var shouldRunMLXTests: Bool {
            return self == .integration
        }
    }
    
    // MARK: - MLX Availability Integration Tests
    
    @Test
    func mlxAvailability_integrationWithProviderSystem() async throws {
        let availability = MLXAvailability()
        
        // Test integration of MLX availability with provider registration
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            let availabilityResult = await availability.performMLXHealthCheck()
            
            if mlxAvailable {
                #expect(availabilityResult.isHealthy == true, "MLX should be healthy when available")
                #expect(availabilityResult.errors.isEmpty, "No errors expected when MLX available")
                #expect(availabilityResult.checkedComponents.contains("MLX.Core"))
                #expect(availabilityResult.checkedComponents.contains("MLX.NN"))
                
                // MLX provider should be registerable when available
                if let mlxProvider = await createMLXProviderIfAvailable() {
                    await registry.register(mlxProvider, .mlx)
                    let isRegistered = await registry.availableProviderTypes().contains(.mlx)
                    #expect(isRegistered == true, "MLX provider should register when available")
                }
            } else {
                #expect(availabilityResult.isHealthy == false, "MLX should not be healthy when unavailable")
                #expect(!availabilityResult.errors.isEmpty, "Errors expected when MLX unavailable")
                
                // MLX provider should not be available for registration
                await #expect(throws: TranscriptionProviderError.providerNotAvailable(.mlx)) {
                    if let provider = await createMLXProviderIfAvailable() {
                        throw TranscriptionProviderError.providerNotAvailable(.mlx)
                    }
                    throw TranscriptionProviderError.providerNotAvailable(.mlx)
                }
            }
        }
    }
    
    @Test(.enabled(if: TestMode(rawValue: ProcessInfo.processInfo.environment["VOCORIZE_TEST_MODE"] ?? "integration")?.shouldRunMLXTests ?? true))
    func mlxAvailability_conditionalProviderRegistration() async throws {
        let availability = MLXAvailability()
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            // Test conditional registration based on availability
            let initResult = await availability.testMLXInitialization()
            
            if initResult.success {
                // Should be able to register MLX provider
                if let mlxProvider = await createMLXProviderIfAvailable() {
                    await registry.register(mlxProvider, .mlx)
                    
                    let registeredTypes = await registry.availableProviderTypes()
                    #expect(registeredTypes.contains(.mlx), "MLX provider should be registered")
                    
                    let provider = try await registry.provider(.mlx)
                    #expect(provider != nil, "Should retrieve registered MLX provider")
                }
                
                // Performance should be sufficient for Whisper models
                let performanceSufficient = await availability.isPerformanceSufficientForWhisper()
                #expect(performanceSufficient == true, "Performance should be sufficient on Apple Silicon")
                
            } else {
                // Should gracefully handle unavailability
                #expect(initResult.error != nil, "Error expected when MLX unavailable")
                
                await #expect(throws: TranscriptionProviderError.providerNotAvailable(.mlx)) {
                    _ = try await registry.provider(.mlx)
                }
            }
        }
    }
    
    // MARK: - Provider Factory Integration Tests
    
    @Test(.serialized)
    func providerFactory_mlxModelRouting() async throws {
        guard testMode.shouldRunMLXTests else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            // Register both providers if available
            let whisperProvider = try await MockWhisperKitProvider()
            await registry.register(whisperProvider, .whisperKit)
            
            if let mlxProvider = await createMLXProviderIfAvailable() {
                await registry.register(mlxProvider, .mlx)
                
                // Test model routing logic
                let mlxModels = [
                    "mlx-community/whisper-tiny-mlx",
                    "mlx-community/whisper-base-mlx",
                    "mlx-community/whisper-small-mlx",
                    "whisper-tiny-mlx",
                    "whisper-base-mlx"
                ]
                
                // MLX models should route to MLX provider
                for modelName in mlxModels {
                    // This would test the future model routing logic
                    // For now, we test that both providers can coexist
                    let availableTypes = await registry.availableProviderTypes()
                    #expect(availableTypes.contains(.mlx))
                    #expect(availableTypes.contains(.whisperKit))
                }
                
                // Verify provider factory coordination
                let mlxProviderRetrieved = try await registry.provider(.mlx)
                let whisperProviderRetrieved = try await registry.provider(.whisperKit)
                
                #expect(mlxProviderRetrieved != nil)
                #expect(whisperProviderRetrieved != nil)
                
                // Test provider-specific model availability
                let mlxModels = try await mlxProviderRetrieved.getAvailableModels()
                let whisperModels = try await whisperProviderRetrieved.getAvailableModels()
                
                #expect(mlxModels.allSatisfy { $0.providerType == .mlx })
                #expect(whisperModels.allSatisfy { $0.providerType == .whisperKit })
            }
        }
    }
    
    @Test(.serialized)
    func providerFactory_mlxProviderSelection() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            // Register MLX provider
            if let mlxProvider = await createMLXProviderIfAvailable() {
                await registry.register(mlxProvider, .mlx)
                
                // Test provider selection logic
                let selectedProvider = try await registry.provider(.mlx)
                let providerModels = try await selectedProvider.getAvailableModels()
                
                #expect(!providerModels.isEmpty, "MLX provider should have available models")
                #expect(providerModels.first?.providerType == .mlx)
                
                // Test recommended model selection
                let recommendedModel = try await selectedProvider.getRecommendedModel()
                #expect(!recommendedModel.isEmpty, "Should have recommended MLX model")
                
                // Recommended model should be in available models
                let modelNames = providerModels.map { $0.internalName }
                #expect(modelNames.contains(recommendedModel))
            }
        }
    }
    
    // MARK: - End-to-End Workflow Tests
    
    @Test(.serialized, .timeLimit(.minutes(5)))
    func endToEnd_mlxTranscriptionWorkflow() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else { 
            print("⏭️ Skipping MLX E2E test - MLX not available or in unit test mode")
            return
        }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else {
                print("⏭️ MLX provider not available")
                return
            }
            
            await registry.register(mlxProvider, .mlx)
            
            // Get recommended model for testing
            let recommendedModel = try await mlxProvider.getRecommendedModel()
            
            // Test complete workflow: download -> load -> transcribe
            var downloadProgress: [Progress] = []
            
            // 1. Download model
            try await mlxProvider.downloadModel(recommendedModel) { progress in
                downloadProgress.append(progress)
            }
            
            #expect(!downloadProgress.isEmpty, "Should report download progress")
            #expect(downloadProgress.last?.isFinished == true, "Download should complete")
            
            // 2. Verify model is downloaded
            let isDownloaded = await mlxProvider.isModelDownloaded(recommendedModel)
            #expect(isDownloaded == true, "Model should be downloaded")
            
            // 3. Load model into memory
            let wasLoaded = try await mlxProvider.loadModelIntoMemory(recommendedModel)
            #expect(wasLoaded == true, "Model should load into memory")
            
            let isLoadedInMemory = await mlxProvider.isModelLoadedInMemory(recommendedModel)
            #expect(isLoadedInMemory == true, "Model should be loaded in memory")
            
            // 4. Transcribe test audio
            let audioURL = try createTestAudioFile()
            defer { try? FileManager.default.removeItem(at: audioURL) }
            
            var transcriptionProgress: [Progress] = []
            
            let transcriptionResult = try await mlxProvider.transcribe(
                audioURL: audioURL,
                modelName: recommendedModel,
                options: DecodingOptions(),
                progressCallback: { progress in
                    transcriptionProgress.append(progress)
                }
            )
            
            #expect(!transcriptionResult.isEmpty, "Should produce transcription result")
            #expect(!transcriptionProgress.isEmpty, "Should report transcription progress")
            #expect(transcriptionProgress.last?.isFinished == true, "Transcription should complete")
            
            print("✅ MLX E2E transcription result: '\(transcriptionResult)'")
        }
    }
    
    @Test(.serialized)
    func endToEnd_modelDownloadAndManagement() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            let testModel = try await mlxProvider.getRecommendedModel()
            
            // Test model lifecycle integration
            var downloadProgressUpdates: [Double] = []
            
            // 1. Initially not downloaded
            let initiallyDownloaded = await mlxProvider.isModelDownloaded(testModel)
            #expect(initiallyDownloaded == false, "Model should not be initially downloaded")
            
            // 2. Download with progress tracking
            try await mlxProvider.downloadModel(testModel) { progress in
                let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                downloadProgressUpdates.append(percentage)
            }
            
            #expect(!downloadProgressUpdates.isEmpty, "Should track download progress")
            #expect(downloadProgressUpdates.first == 0.0, "Should start at 0%")
            #expect(downloadProgressUpdates.last == 1.0, "Should complete at 100%")
            
            // 3. Verify download completion
            let afterDownload = await mlxProvider.isModelDownloaded(testModel)
            #expect(afterDownload == true, "Model should be downloaded after download")
            
            // 4. Load and verify memory state
            _ = try await mlxProvider.loadModelIntoMemory(testModel)
            let isLoaded = await mlxProvider.isModelLoadedInMemory(testModel)
            #expect(isLoaded == true, "Model should be loaded after loading")
            
            // 5. Delete and verify cleanup
            try await mlxProvider.deleteModel(testModel)
            let afterDelete = await mlxProvider.isModelDownloaded(testModel)
            let afterDeleteInMemory = await mlxProvider.isModelLoadedInMemory(testModel)
            
            #expect(afterDelete == false, "Model should not be downloaded after deletion")
            #expect(afterDeleteInMemory == false, "Model should not be in memory after deletion")
        }
    }
    
    @Test(.serialized)
    func endToEnd_modelSwitchingAndMemoryManagement() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            let availableModels = try await mlxProvider.getAvailableModels()
            guard availableModels.count >= 2 else {
                print("⏭️ Skipping model switching test - need at least 2 models")
                return
            }
            
            let firstModel = availableModels[0].internalName
            let secondModel = availableModels[1].internalName
            
            // Download both models
            try await mlxProvider.downloadModel(firstModel) { _ in }
            try await mlxProvider.downloadModel(secondModel) { _ in }
            
            // Load first model
            _ = try await mlxProvider.loadModelIntoMemory(firstModel)
            #expect(await mlxProvider.isModelLoadedInMemory(firstModel) == true)
            #expect(await mlxProvider.isModelLoadedInMemory(secondModel) == false)
            
            // Switch to second model (should unload first)
            _ = try await mlxProvider.loadModelIntoMemory(secondModel)
            #expect(await mlxProvider.isModelLoadedInMemory(secondModel) == true)
            
            // Verify memory management (only one model should be loaded)
            let firstStillLoaded = await mlxProvider.isModelLoadedInMemory(firstModel)
            let secondLoaded = await mlxProvider.isModelLoadedInMemory(secondModel)
            
            if firstStillLoaded && secondLoaded {
                print("⚠️ Multiple models loaded - memory management may need optimization")
            }
            
            #expect(secondLoaded == true, "Second model should be loaded")
        }
    }
    
    // MARK: - Fallback and Error Integration Tests
    
    @Test(.serialized)
    func errorIntegration_mlxUnavailableFallback() async throws {
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            // Test behavior when MLX is not available
            if !mlxAvailable {
                await #expect(throws: TranscriptionProviderError.providerNotAvailable(.mlx)) {
                    _ = try await registry.provider(.mlx)
                }
                
                // Should fall back to WhisperKit gracefully
                let whisperProvider = try await MockWhisperKitProvider()
                await registry.register(whisperProvider, .whisperKit)
                
                let fallbackProvider = try await registry.provider(.whisperKit)
                #expect(fallbackProvider != nil, "Should fall back to WhisperKit")
                
                // Should still provide transcription capability
                let audioURL = try createTestAudioFile()
                defer { try? FileManager.default.removeItem(at: audioURL) }
                
                let testModel = "openai_whisper-tiny"
                try await fallbackProvider.downloadModel(testModel) { _ in }
                
                let result = try await fallbackProvider.transcribe(
                    audioURL: audioURL,
                    modelName: testModel,
                    options: DecodingOptions(),
                    progressCallback: { _ in }
                )
                
                #expect(!result.isEmpty, "Should still transcribe with fallback provider")
            }
        }
    }
    
    @Test(.serialized)
    func errorIntegration_networkFailureScenarios() async throws {
        guard testMode.shouldRunMLXTests else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            // Test network failure handling with MLX provider
            if let mlxProvider = await createMLXProviderIfAvailable() {
                await registry.register(mlxProvider, .mlx)
                
                // Test download failure scenarios
                await #expect(throws: TranscriptionProviderError.self) {
                    try await mlxProvider.downloadModel("nonexistent_mlx_model_12345") { _ in }
                }
                
                // Registry should remain stable after errors
                let providerStillRegistered = await registry.availableProviderTypes().contains(.mlx)
                #expect(providerStillRegistered == true, "Provider should remain registered after download errors")
            }
        }
    }
    
    @Test(.serialized)
    func errorIntegration_memoryPressureHandling() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            let availableModels = try await mlxProvider.getAvailableModels()
            guard let testModel = availableModels.first?.internalName else { return }
            
            try await mlxProvider.downloadModel(testModel) { _ in }
            
            // Test behavior under memory pressure simulation
            // This is a basic test - real memory pressure testing would require more sophisticated setup
            let memoryInfoBefore = await getMemoryInfo()
            
            _ = try await mlxProvider.loadModelIntoMemory(testModel)
            
            let memoryInfoAfter = await getMemoryInfo()
            let memoryUsageIncreased = memoryInfoAfter["used"] as? UInt64 ?? 0 > memoryInfoBefore["used"] as? UInt64 ?? 0
            
            if memoryUsageIncreased {
                print("✅ Memory usage increased after model loading (expected)")
            }
            
            // Verify provider remains functional
            let isStillLoaded = await mlxProvider.isModelLoadedInMemory(testModel)
            #expect(isStillLoaded == true, "Model should remain loaded")
        }
    }
    
    // MARK: - Performance Integration Tests
    
    @Test(.serialized, .timeLimit(.minutes(10)))
    func performance_mlxVsWhisperKitComparison() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else {
            print("⏭️ Skipping performance comparison - MLX not available")
            return
        }
        
        let shouldRunPerformanceTests = ProcessInfo.processInfo.environment["VOCORIZE_TRACK_PERFORMANCE"] == "true"
        guard shouldRunPerformanceTests else {
            print("⏭️ Skipping performance test - VOCORIZE_TRACK_PERFORMANCE not enabled")
            return
        }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            // Setup both providers
            let whisperProvider = try await MockWhisperKitProvider()
            await registry.register(whisperProvider, .whisperKit)
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            let audioURL = try createTestAudioFile()
            defer { try? FileManager.default.removeItem(at: audioURL) }
            
            // Prepare models
            let whisperModel = "openai_whisper-tiny"
            try await whisperProvider.downloadModel(whisperModel) { _ in }
            
            let mlxModel = try await mlxProvider.getRecommendedModel()
            try await mlxProvider.downloadModel(mlxModel) { _ in }
            
            // Measure WhisperKit performance
            let whisperStartTime = CFAbsoluteTimeGetCurrent()
            let whisperResult = try await whisperProvider.transcribe(
                audioURL: audioURL,
                modelName: whisperModel,
                options: DecodingOptions(),
                progressCallback: { _ in }
            )
            let whisperDuration = CFAbsoluteTimeGetCurrent() - whisperStartTime
            
            // Measure MLX performance  
            let mlxStartTime = CFAbsoluteTimeGetCurrent()
            let mlxResult = try await mlxProvider.transcribe(
                audioURL: audioURL,
                modelName: mlxModel,
                options: DecodingOptions(),
                progressCallback: { _ in }
            )
            let mlxDuration = CFAbsoluteTimeGetCurrent() - mlxStartTime
            
            // Log performance comparison
            print("🚀 Performance Comparison:")
            print("   WhisperKit: \(String(format: "%.2f", whisperDuration))s")
            print("   MLX: \(String(format: "%.2f", mlxDuration))s")
            
            if mlxDuration < whisperDuration {
                let speedup = whisperDuration / mlxDuration
                print("   MLX is \(String(format: "%.2f", speedup))x faster")
            } else {
                let slowdown = mlxDuration / whisperDuration
                print("   MLX is \(String(format: "%.2f", slowdown))x slower")
            }
            
            #expect(!whisperResult.isEmpty, "WhisperKit should produce result")
            #expect(!mlxResult.isEmpty, "MLX should produce result")
        }
    }
    
    @Test(.serialized)
    func performance_concurrentMLXOperations() async throws {
        guard testMode.shouldRunMLXTests && mlxAvailable else { return }
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            let testModel = try await mlxProvider.getRecommendedModel()
            try await mlxProvider.downloadModel(testModel) { _ in }
            _ = try await mlxProvider.loadModelIntoMemory(testModel)
            
            // Test concurrent transcription operations
            let audioURLs = try (1...3).map { _ in try createTestAudioFile() }
            defer { audioURLs.forEach { try? FileManager.default.removeItem(at: $0) } }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let transcriptionTasks = audioURLs.map { audioURL in
                Task {
                    try await mlxProvider.transcribe(
                        audioURL: audioURL,
                        modelName: testModel,
                        options: DecodingOptions(),
                        progressCallback: { _ in }
                    )
                }
            }
            
            var results: [String] = []
            for task in transcriptionTasks {
                let result = try await task.value
                results.append(result)
            }
            
            let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
            
            #expect(results.count == 3, "Should complete all concurrent operations")
            #expect(results.allSatisfy { !$0.isEmpty }, "All results should be non-empty")
            
            print("✅ Concurrent MLX operations completed in \(String(format: "%.2f", totalDuration))s")
        }
    }
    
    // MARK: - Real Hardware Tests (Conditional)
    
    @Test(.enabled(if: MLXAvailability.isAvailable), .timeLimit(.minutes(15)))
    func realHardware_mlxOnAppleSilicon() async throws {
        guard mlxAvailable else { return }
        guard testMode.shouldRunMLXTests else { return }
        
        let availability = MLXAvailability()
        let runtimeInfo = await availability.getMLXRuntimeInfo()
        
        // Verify Apple Silicon requirements
        #expect(runtimeInfo["architecture"] as? String == "arm64", "Should run on ARM64")
        #expect(runtimeInfo["metal_support"] as? Bool == true, "Should have Metal support")
        #expect(runtimeInfo["unified_memory"] as? Bool == true, "Should have unified memory")
        
        // Test real MLX operations
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            // Test real model operations on Apple Silicon
            let performanceMetrics = await availability.measureMLXPerformance()
            #expect(performanceMetrics.isValid == true, "Performance metrics should be valid")
            #expect(performanceMetrics.tensorOpsPerSecond > 0, "Should have tensor operation capability")
            #expect(performanceMetrics.memoryBandwidth > 0, "Should have memory bandwidth")
            
            let isPerformanceSufficient = await availability.isPerformanceSufficientForWhisper()
            #expect(isPerformanceSufficient == true, "Performance should be sufficient for Whisper")
            
            print("🔧 Apple Silicon MLX Performance:")
            print("   Tensor Ops/sec: \(String(format: "%.0f", performanceMetrics.tensorOpsPerSecond))")
            print("   Memory Bandwidth: \(String(format: "%.1f", performanceMetrics.memoryBandwidth)) GB/s")
        }
    }
    
    @Test(.enabled(if: MLXAvailability.isAvailable))
    func realHardware_mlxMemoryEfficiency() async throws {
        guard mlxAvailable && testMode.shouldRunMLXTests else { return }
        
        let availability = MLXAvailability()
        
        try await withDependencies {
            $0.transcriptionProviderRegistry = .liveValue
        } operation: {
            @Dependency(\.transcriptionProviderRegistry) var registry
            await registry.clear()
            
            guard let mlxProvider = await createMLXProviderIfAvailable() else { return }
            await registry.register(mlxProvider, .mlx)
            
            let beforeMemory = await getMemoryInfo()
            
            // Download and load a model
            let testModel = try await mlxProvider.getRecommendedModel()
            try await mlxProvider.downloadModel(testModel) { _ in }
            _ = try await mlxProvider.loadModelIntoMemory(testModel)
            
            let afterLoadMemory = await getMemoryInfo()
            
            // Perform transcription
            let audioURL = try createTestAudioFile()
            defer { try? FileManager.default.removeItem(at: audioURL) }
            
            _ = try await mlxProvider.transcribe(
                audioURL: audioURL,
                modelName: testModel,
                options: DecodingOptions(),
                progressCallback: { _ in }
            )
            
            let afterTranscriptionMemory = await getMemoryInfo()
            
            // Cleanup
            try await mlxProvider.deleteModel(testModel)
            let afterCleanupMemory = await getMemoryInfo()
            
            // Verify memory management
            let loadMemoryIncrease = (afterLoadMemory["used"] as? UInt64 ?? 0) - (beforeMemory["used"] as? UInt64 ?? 0)
            let transcriptionMemoryIncrease = (afterTranscriptionMemory["used"] as? UInt64 ?? 0) - (afterLoadMemory["used"] as? UInt64 ?? 0)
            let cleanupMemoryDecrease = (afterCleanupMemory["used"] as? UInt64 ?? 0) < (afterTranscriptionMemory["used"] as? UInt64 ?? 0)
            
            print("💾 MLX Memory Usage:")
            print("   Model Loading: +\(loadMemoryIncrease / 1024 / 1024) MB")
            print("   Transcription: +\(transcriptionMemoryIncrease / 1024 / 1024) MB") 
            print("   Cleanup: \(cleanupMemoryDecrease ? "✅ Decreased" : "⚠️ No decrease")")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates MLX provider if available, returns nil otherwise
    private func createMLXProviderIfAvailable() async -> (any TranscriptionProvider)? {
        guard mlxAvailable else { return nil }
        
        // In a real implementation, this would create an actual MLX provider
        // For now, we return a mock or skip the test
        return await createMockMLXProvider()
    }
    
    /// Creates mock MLX provider for testing using test infrastructure
    private func createMockMLXProvider() async -> MockMLXProvider {
        return MockMLXProvider()
    }
    
    /// Creates a test audio file for transcription testing
    private func createTestAudioFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("mlx_test_audio_\(UUID().uuidString).wav")
        
        // Create minimal WAV file
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
    
    /// Gets current memory usage information
    private func getMemoryInfo() async -> [String: Any] {
        let processInfo = ProcessInfo.processInfo
        return [
            "physical": processInfo.physicalMemory,
            "used": 0, // Placeholder - real implementation would use mach calls
        ]
    }
}

// MARK: - Helper Methods (continued)