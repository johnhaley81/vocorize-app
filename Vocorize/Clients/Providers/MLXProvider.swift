//
//  MLXProvider.swift
//  Vocorize
//
//  MLX-based transcription provider implementation
//  Provides MLX-accelerated Whisper transcription with conditional compilation support
//

import Foundation
import AVFoundation
import Dependencies
import WhisperKit

#if canImport(MLX) && canImport(MLXNN)
import MLX
import MLXNN
#endif

/// MLX-based transcription provider that leverages Apple Silicon's unified memory architecture
/// This implementation provides hardware-accelerated transcription using the MLX framework
@available(macOS 13.0, *)
actor MLXProvider: TranscriptionProvider {
    
    // MARK: - Protocol Conformance
    
    static var providerType: TranscriptionProviderType { .mlx }
    static var displayName: String { "MLX" }
    
    // MARK: - Private Properties
    
    #if canImport(MLX) && canImport(MLXNN)
    /// The current loaded MLX model instance
    private var mlxModel: Any?
    
    /// The name of the currently loaded model
    private var currentModelName: String?
    
    /// MLX-specific configuration options
    private var mlxConfig: [String: Any] = [:]
    
    /// Hugging Face client for model downloads
    private lazy var huggingFaceClient = HuggingFaceClient()
    #endif
    
    /// Base folder for storing MLX models
    private lazy var modelsBaseFolder: URL = {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let ourAppFolder = appSupportURL.appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
            let baseURL = ourAppFolder.appendingPathComponent("mlx-models", isDirectory: true)
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            return baseURL
        } catch {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
                .appendingPathComponent("mlx-models", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            return tempURL
        }
    }()
    
    // MARK: - Initialization
    
    init() {
        #if canImport(MLX) && canImport(MLXNN)
        // Initialize MLX-specific configuration
        mlxConfig = [
            "device": "gpu",
            "dtype": "float16",
            "batch_size": 1
        ]
        #endif
    }
    
    // MARK: - TranscriptionProvider Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        
        #if canImport(MLX) && canImport(MLXNN)
        // Check if MLX is available on this system
        guard MLXAvailability.isAvailable else {
            throw TranscriptionProviderError.providerNotAvailable(.mlx)
        }
        
        // Ensure the model is loaded in memory
        guard mlxModel != nil, currentModelName == modelName else {
            throw TranscriptionProviderError.modelLoadFailed(modelName, NSError(
                domain: "MLXProvider",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Model \(modelName) is not loaded in memory. Call loadModelIntoMemory() first."
                ]
            ))
        }
        
        do {
            // Report initial progress
            let transcriptionProgress = Progress(totalUnitCount: 100)
            transcriptionProgress.completedUnitCount = 0
            progressCallback(transcriptionProgress)
            
            // Preprocess audio for MLX (placeholder implementation)
            transcriptionProgress.completedUnitCount = 20
            progressCallback(transcriptionProgress)
            
            let preprocessedAudio = try await preprocessAudioForMLX(audioURL: audioURL)
            
            // Perform MLX transcription (placeholder implementation)
            transcriptionProgress.completedUnitCount = 60
            progressCallback(transcriptionProgress)
            
            let transcriptionResult = try await performMLXTranscription(
                audio: preprocessedAudio,
                options: options
            )
            
            // Post-process results
            transcriptionProgress.completedUnitCount = 90
            progressCallback(transcriptionProgress)
            
            let finalText = postprocessTranscriptionResult(transcriptionResult)
            
            // Report completion
            transcriptionProgress.completedUnitCount = 100
            progressCallback(transcriptionProgress)
            
            return finalText
            
        } catch {
            throw TranscriptionProviderError.transcriptionFailed(modelName, error)
        }
        #else
        // MLX not available - throw appropriate error
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> Void {
        
        #if canImport(MLX) && canImport(MLXNN)
        guard MLXAvailability.isAvailable else {
            throw TranscriptionProviderError.providerNotAvailable(.mlx)
        }
        
        // Check if model is already downloaded
        if await isModelDownloaded(modelName) {
            let progress = Progress(totalUnitCount: 100)
            progress.completedUnitCount = 100
            progressCallback(progress)
            return
        }
        
        do {
            // Report initial progress
            let downloadProgress = Progress(totalUnitCount: 100)
            downloadProgress.completedUnitCount = 0
            progressCallback(downloadProgress)
            
            // Download model from appropriate source (placeholder implementation)
            try await downloadMLXModel(modelName: modelName) { progress in
                progressCallback(progress)
            }
            
        } catch {
            throw TranscriptionProviderError.modelDownloadFailed(modelName, error)
        }
        #else
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }
    
    func deleteModel(_ modelName: String) async throws -> Void {
        let modelFolder = modelPath(for: modelName)
        
        // Check if model exists
        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        #if canImport(MLX) && canImport(MLXNN)
        // Unload if currently loaded
        if currentModelName == modelName {
            unloadCurrentModel()
        }
        #endif
        
        do {
            // Delete model directory
            try FileManager.default.removeItem(at: modelFolder)
        } catch {
            throw TranscriptionProviderError.modelNotFound("Failed to delete model \(modelName): \(error.localizedDescription)")
        }
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        let modelFolderPath = modelPath(for: modelName).path
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: modelFolderPath) else {
            return false
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: modelFolderPath)
            
            // Check for MLX-specific model files
            let hasModelFiles = contents.contains { filename in
                filename.contains("model") || filename.hasSuffix(".npz") || filename.hasSuffix(".safetensors")
            }
            
            let hasConfigFile = contents.contains { filename in
                filename.contains("config") || filename.hasSuffix(".json")
            }
            
            return hasModelFiles && hasConfigFile
            
        } catch {
            return false
        }
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        #if canImport(MLX) && canImport(MLXNN)
        guard MLXAvailability.isAvailable else {
            throw TranscriptionProviderError.providerNotAvailable(.mlx)
        }
        
        // MLX-compatible Whisper models from Hugging Face
        let mlxModelNames = [
            "whisper-tiny-mlx",
            "whisper-base-mlx",
            "whisper-small-mlx",
            "whisper-medium-mlx",
            "whisper-large-v3-turbo"
        ]
        
        var providerModels: [ProviderModelInfo] = []
        
        for modelName in mlxModelNames {
            let isDownloaded = await isModelDownloaded(modelName)
            let isRecommended = modelName.contains("base") || modelName.contains("small")
            let displayName = formatDisplayName(for: modelName)
            let estimatedSize = estimateModelSize(for: modelName)
            
            let providerModel = ProviderModelInfo(
                internalName: modelName,
                displayName: displayName,
                providerType: .mlx,
                estimatedSize: estimatedSize,
                isRecommended: isRecommended,
                isDownloaded: isDownloaded
            )
            
            providerModels.append(providerModel)
        }
        
        // Sort by recommended first, then by size
        return providerModels.sorted { model1, model2 in
            if model1.isRecommended != model2.isRecommended {
                return model1.isRecommended && !model2.isRecommended
            }
            
            let order1 = sizeOrder(for: model1.internalName)
            let order2 = sizeOrder(for: model2.internalName)
            
            if order1 != order2 {
                return order1 < order2
            }
            
            return model1.displayName < model2.displayName
        }
        #else
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }
    
    func getRecommendedModel() async throws -> String {
        #if canImport(MLX) && canImport(MLXNN)
        guard MLXAvailability.isAvailable else {
            throw TranscriptionProviderError.providerNotAvailable(.mlx)
        }
        
        // Get device capabilities to recommend appropriate model
        let deviceCapabilities = await getCurrentDeviceCapabilities()
        
        // Recommend model based on available memory
        let memoryGB = deviceCapabilities.availableMemory / (1024 * 1024 * 1024)
        
        if memoryGB >= 16 {
            return "whisper-medium-mlx"
        } else if memoryGB >= 8 {
            return "whisper-small-mlx"
        } else {
            return "whisper-base-mlx"
        }
        #else
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }
    
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        #if canImport(MLX) && canImport(MLXNN)
        guard MLXAvailability.isAvailable else {
            throw TranscriptionProviderError.providerNotAvailable(.mlx)
        }
        
        // Unload current model if different
        if currentModelName != modelName {
            unloadCurrentModel()
        }
        
        // Check if model is already loaded
        if mlxModel != nil && currentModelName == modelName {
            return true
        }
        
        // Ensure model is downloaded
        guard await isModelDownloaded(modelName) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        do {
            // Load MLX model (placeholder implementation)
            let loadedModel = try await loadMLXModel(modelName: modelName)
            
            mlxModel = loadedModel
            currentModelName = modelName
            
            return mlxModel != nil
            
        } catch {
            throw TranscriptionProviderError.modelLoadFailed(modelName, error)
        }
        #else
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }
    
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        #if canImport(MLX) && canImport(MLXNN)
        return mlxModel != nil && currentModelName == modelName
        #else
        return false
        #endif
    }
    
    // MARK: - Private MLX-Specific Methods
    
    #if canImport(MLX) && canImport(MLXNN)
    
    /// Preprocesses audio file for MLX processing
    private func preprocessAudioForMLX(audioURL: URL) async throws -> [Float] {
        // Placeholder implementation - would implement actual audio preprocessing
        // This would involve:
        // 1. Loading audio file using AVAudioFile
        // 2. Converting to appropriate sample rate (16kHz for Whisper)
        // 3. Converting to mono if needed
        // 4. Normalizing audio levels
        // 5. Converting to Float array format expected by MLX
        
        // For now, return empty array as placeholder
        return []
    }
    
    /// Performs MLX-accelerated transcription
    private func performMLXTranscription(
        audio: [Float],
        options: DecodingOptions
    ) async throws -> [String] {
        // Placeholder implementation - would implement actual MLX transcription
        // This would involve:
        // 1. Converting audio to MLX arrays
        // 2. Running forward pass through loaded model
        // 3. Applying beam search or greedy decoding
        // 4. Converting token IDs back to text
        
        // For now, return placeholder text
        return ["MLX transcription placeholder"]
    }
    
    /// Downloads MLX model from Hugging Face Hub
    private func downloadMLXModel(
        modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        // Map model name to Hugging Face repository ID
        let repoId = mapModelNameToRepoId(modelName)
        
        // Get local model path
        let modelFolder = modelPath(for: modelName)
        
        do {
            // Use HuggingFaceClient to download the model
            try await huggingFaceClient.downloadModel(
                repoId: repoId,
                localPath: modelFolder
            ) { downloadProgress in
                // Convert HuggingFaceClient.DownloadProgress to Foundation.Progress
                let progress = Progress.from(downloadProgress: downloadProgress)
                progressCallback(progress)
            }
            
            // Validate downloaded model
            _ = try await huggingFaceClient.validateModelIntegrity(localPath: modelFolder)
            
        } catch {
            // Clean up partial download on failure
            try? FileManager.default.removeItem(at: modelFolder)
            throw error
        }
    }
    
    /// Loads MLX model from disk
    private func loadMLXModel(modelName: String) async throws -> Any {
        // Placeholder implementation - would implement actual model loading
        // This would involve:
        // 1. Reading model configuration
        // 2. Loading model weights using MLX
        // 3. Initializing tokenizer
        // 4. Preparing model for inference
        
        return "placeholder-model-\(modelName)"
    }
    
    /// Unloads current MLX model from memory
    private func unloadCurrentModel() {
        mlxModel = nil
        currentModelName = nil
    }
    
    #endif
    
    // MARK: - Private Helper Methods
    
    /// Gets path for a specific model
    private func modelPath(for modelName: String) -> URL {
        let sanitizedModelName = modelName.components(separatedBy: CharacterSet(charactersIn: "./\\")).joined(separator: "_")
        return modelsBaseFolder.appendingPathComponent(sanitizedModelName, isDirectory: true)
    }
    
    /// Post-processes transcription results
    private func postprocessTranscriptionResult(_ results: [String]) -> String {
        return results.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Gets current device capabilities for MLX
    private func getCurrentDeviceCapabilities() async -> DeviceCapabilities {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        #if arch(arm64)
        let hasNeuralEngine = true
        let coreMLComputeUnits = "all"
        #else
        let hasNeuralEngine = false
        let coreMLComputeUnits = "cpuOnly"
        #endif
        
        var supportedModelSizes: [String] = ["tiny", "base"]
        let memoryGB = physicalMemory / (1024 * 1024 * 1024)
        
        if memoryGB >= 4 {
            supportedModelSizes.append("small")
        }
        if memoryGB >= 8 {
            supportedModelSizes.append("medium")
        }
        if memoryGB >= 16 {
            supportedModelSizes.append("large")
        }
        
        return DeviceCapabilities(
            hasNeuralEngine: hasNeuralEngine,
            availableMemory: physicalMemory,
            coreMLComputeUnits: coreMLComputeUnits,
            supportedModelSizes: supportedModelSizes
        )
    }
    
    /// Formats model name for display
    private func formatDisplayName(for modelName: String) -> String {
        var displayName = modelName
        
        // Remove MLX suffix
        displayName = displayName.replacingOccurrences(of: "-mlx", with: "")
        
        // Remove whisper prefix
        if displayName.hasPrefix("whisper-") {
            displayName = String(displayName.dropFirst("whisper-".count))
        }
        
        // Capitalize and format
        displayName = displayName.replacingOccurrences(of: "-", with: " ")
        displayName = displayName.capitalized
        
        // Add MLX indicator
        displayName = "\(displayName) (MLX)"
        
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Estimates model size
    private func estimateModelSize(for modelName: String) -> String {
        let lowercased = modelName.lowercased()
        
        if lowercased.contains("large") {
            return "~1.5 GB"  // MLX models are generally smaller than CoreML
        } else if lowercased.contains("medium") {
            return "~750 MB"
        } else if lowercased.contains("small") {
            return "~230 MB"
        } else if lowercased.contains("base") {
            return "~75 MB"
        } else if lowercased.contains("tiny") {
            return "~35 MB"
        } else {
            return "Unknown"
        }
    }
    
    /// Returns sort order for model sizes
    private func sizeOrder(for modelName: String) -> Int {
        let lowercased = modelName.lowercased()
        
        if lowercased.contains("tiny") {
            return 0
        } else if lowercased.contains("base") {
            return 1
        } else if lowercased.contains("small") {
            return 2
        } else if lowercased.contains("medium") {
            return 3
        } else if lowercased.contains("large") || lowercased.contains("turbo") {
            return 4
        } else {
            return 5
        }
    }
    
    /// Maps internal model names to Hugging Face repository IDs
    private func mapModelNameToRepoId(_ modelName: String) -> String {
        // If the model name already contains the repository path, use it directly
        if modelName.contains("/") {
            return modelName
        }
        
        // Otherwise, map simple names to full repository paths
        switch modelName {
        case "whisper-tiny-mlx":
            return "mlx-community/whisper-tiny-mlx"
        case "whisper-base-mlx":
            return "mlx-community/whisper-base-mlx"
        case "whisper-small-mlx":
            return "mlx-community/whisper-small-mlx"
        case "whisper-medium-mlx":
            return "mlx-community/whisper-medium-mlx"
        case "whisper-large-v3-turbo":
            return "mlx-community/whisper-large-v3-turbo"
        default:
            // If it looks like an MLX model name, try to map it
            if modelName.hasPrefix("mlx-community/") {
                return modelName
            }
            
            // Default to base model if unknown
            return "mlx-community/whisper-base-mlx"
        }
    }
}