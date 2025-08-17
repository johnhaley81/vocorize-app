//
//  WhisperKitProvider.swift
//  Vocorize
//
//  Self-contained WhisperKit implementation that manages models and transcription directly
//

import Foundation
import AVFoundation
import WhisperKit
import Dependencies

/// Device capabilities for hardware detection
struct DeviceCapabilities {
    let hasNeuralEngine: Bool?
    let availableMemory: UInt64
    let coreMLComputeUnits: String?
    let supportedModelSizes: [String]
}

/// Self-contained WhisperKit provider implementation that manages WhisperKit models directly
/// This implementation handles model downloading, loading, and transcription without dependencies
actor WhisperKitProvider: TranscriptionProvider {
    
    // MARK: - Protocol Conformance
    
    static var providerType: TranscriptionProviderType { .whisperKit }
    static var displayName: String { "WhisperKit" }
    
    // MARK: - Private Properties
    
    /// The current in-memory `WhisperKit` instance, if any.
    private var whisperKit: WhisperKit?
    
    /// The name of the currently loaded model, if any.
    private var currentModelName: String?
    
    /// The base folder under which we store model data (e.g., ~/Library/Application Support/...).
    private lazy var modelsBaseFolder: URL = {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            // Typically: .../Application Support/com.tanvir.Vocorize
            let ourAppFolder = appSupportURL.appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
            // Inside there, store everything in /models
            let baseURL = ourAppFolder.appendingPathComponent("models", isDirectory: true)
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            return baseURL
        } catch {
            // Fallback to temporary directory if Application Support is unavailable
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
                .appendingPathComponent("models", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            return tempURL
        }
    }()
    
    // MARK: - Initialization
    
    init() {
        // Initialize with empty state
    }
    
    // MARK: - TranscriptionProvider Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        
        // Check if the requested model is currently loaded
        guard let whisperKit = whisperKit, currentModelName == modelName else {
            // For testing purposes, don't auto-load the model
            // The caller should explicitly load the model first
            throw TranscriptionProviderError.modelLoadFailed(modelName, NSError(
                domain: "WhisperKitProvider",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Model \(modelName) is not loaded in memory. Call loadModelIntoMemory() first.",
                ]
            ))
        }

        do {
            // Report initial transcription progress
            let transcriptionProgress = Progress(totalUnitCount: 100)
            transcriptionProgress.completedUnitCount = 0
            progressCallback(transcriptionProgress)
            
            // Perform the transcription.
            let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
            
            // Report completion
            transcriptionProgress.completedUnitCount = 100
            progressCallback(transcriptionProgress)
            
            // Concatenate results from all segments.
            let text = results.map(\.text).joined(separator: " ")
            return text
        } catch {
            throw TranscriptionProviderError.transcriptionFailed(modelName, error)
        }
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> Void {
        // Only download, don't load into memory
        try await downloadModelIfNeeded(variant: modelName, progressCallback: progressCallback)
    }
    
    func deleteModel(_ modelName: String) async throws -> Void {
        let modelFolder = modelPath(for: modelName)
        
        // Check if the model exists
        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        // If this is the currently loaded model, unload it first
        if currentModelName == modelName {
            unloadCurrentModel()
        }
        
        do {
            // Delete the model directory
            try FileManager.default.removeItem(at: modelFolder)
        } catch {
            throw TranscriptionProviderError.modelNotFound("Failed to delete model \(modelName): \(error.localizedDescription)")
        }
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        let modelFolderPath = modelPath(for: modelName).path
        let fileManager = FileManager.default
        
        // First, check if the basic model directory exists
        guard fileManager.fileExists(atPath: modelFolderPath) else {
            return false
        }
        
        do {
            // Check if the directory has actual model files in it
            let contents = try fileManager.contentsOfDirectory(atPath: modelFolderPath)
            
            // Model should have multiple files and certain key components
            guard !contents.isEmpty else {
                return false
            }
            
            // Check for specific model structure - need both tokenizer and model files
            let hasModelFiles = contents.contains { $0.hasSuffix(".mlmodelc") || $0.contains("model") }
            let tokenizerFolderPath = tokenizerPath(for: modelName).path
            let hasTokenizer = fileManager.fileExists(atPath: tokenizerFolderPath)
            
            // Both conditions must be true for a model to be considered downloaded
            return hasModelFiles && hasTokenizer
        } catch {
            return false
        }
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        do {
            // Get the available models from WhisperKit directly
            let availableModelNames = try await WhisperKit.fetchAvailableModels()
            let recommendedModels = await WhisperKit.recommendedRemoteModels()
            
            // Create ProviderModelInfo objects for each model
            var providerModels: [ProviderModelInfo] = []
            
            for modelName in availableModelNames {
                // Check if this model is downloaded
                let isDownloaded = await isModelDownloaded(modelName)
                
                // Check if this model is recommended (supported or default)
                let isRecommended = recommendedModels.supported.contains(modelName) ||
                                   modelName == recommendedModels.default
                
                // Create a readable display name from the model name
                let displayName = formatDisplayName(for: modelName)
                
                // Estimate size based on model name patterns
                let estimatedSize = estimateModelSize(for: modelName)
                
                let providerModel = ProviderModelInfo(
                    internalName: modelName,
                    displayName: displayName,
                    providerType: .whisperKit,
                    estimatedSize: estimatedSize,
                    isRecommended: isRecommended,
                    isDownloaded: isDownloaded
                )
                
                providerModels.append(providerModel)
            }
            
            // Sort models: recommended first, then by size (smaller first), then alphabetically
            return providerModels.sorted { model1, model2 in
                if model1.isRecommended != model2.isRecommended {
                    return model1.isRecommended && !model2.isRecommended
                }
                
                // Extract size ordering (base, small, medium, large, turbo)
                let order1 = sizeOrder(for: model1.internalName)
                let order2 = sizeOrder(for: model2.internalName)
                
                if order1 != order2 {
                    return order1 < order2
                }
                
                return model1.displayName < model2.displayName
            }
        } catch {
            throw TranscriptionProviderError.modelNotFound("Failed to fetch available models: \(error.localizedDescription)")
        }
    }
    
    func getRecommendedModel() async throws -> String {
        let recommendedModels = await WhisperKit.recommendedRemoteModels()
        
        // Return the default model first
        let defaultModel = recommendedModels.default
        
        // Check if the default model is available
        let availableModels = try await WhisperKit.fetchAvailableModels()
        if availableModels.contains(defaultModel) {
            return defaultModel
        }
        
        // If default is not available, try the first supported model
        for supportedModel in recommendedModels.supported {
            if availableModels.contains(supportedModel) {
                return supportedModel
            }
        }
        
        // If no recommended models are available, try to get a reasonable default
        // Look for common small/base models that are likely to work well
        let preferredDefaults = ["openai_whisper-base", "openai_whisper-small", "openai_whisper-medium"]
        
        for defaultModel in preferredDefaults {
            if availableModels.contains(defaultModel) {
                return defaultModel
            }
        }
        
        // Fall back to the first available model if none of the preferred defaults are found
        guard let firstAvailable = availableModels.first else {
            throw TranscriptionProviderError.modelNotFound("No models available")
        }
        
        return firstAvailable
    }
    
    // MARK: - Private WhisperKit Management Methods
    
    /// Ensures the given `variant` model is downloaded and loaded, reporting
    /// overall progress (0%–50% for downloading, 50%–100% for loading).
    private func downloadAndLoadModel(variant: String, progressCallback: @escaping (Progress) -> Void) async throws {
        // Special handling for corrupted or malformed variant names
        if variant.isEmpty {
            throw TranscriptionProviderError.modelNotFound("Cannot download model: Empty model name")
        }
        
        let overallProgress = Progress(totalUnitCount: 100)
        overallProgress.completedUnitCount = 0
        progressCallback(overallProgress)
        

        // 1) Model download phase (0-50% progress)
        if !(await isModelDownloaded(variant)) {
            try await downloadModelIfNeeded(variant: variant) { downloadProgress in
                let fraction = downloadProgress.fractionCompleted * 0.5
                overallProgress.completedUnitCount = Int64(fraction * 100)
                progressCallback(overallProgress)
            }
        } else {
            // Skip download phase if already downloaded
            overallProgress.completedUnitCount = 50
            progressCallback(overallProgress)
        }

        // 2) Model loading phase (50-100% progress)
        try await loadWhisperKitModel(variant) { loadingProgress in
            let fraction = 0.5 + (loadingProgress.fractionCompleted * 0.5)
            overallProgress.completedUnitCount = Int64(fraction * 100)
            progressCallback(overallProgress)
        }
        
        // Final progress update
        overallProgress.completedUnitCount = 100
        progressCallback(overallProgress)
    }
    
    /// Creates or returns the local folder (on disk) for a given `variant` model.
    private func modelPath(for variant: String) -> URL {
        // Remove any possible path traversal or invalid characters from variant name
        let sanitizedVariant = variant.components(separatedBy: CharacterSet(charactersIn: "./\\")).joined(separator: "_")
        
        return modelsBaseFolder
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(sanitizedVariant, isDirectory: true)
    }
    
    /// Creates or returns the local folder for the tokenizer files of a given `variant`.
    private func tokenizerPath(for variant: String) -> URL {
        modelPath(for: variant).appendingPathComponent("tokenizer", isDirectory: true)
    }
    
    /// Unloads any currently loaded model (clears `whisperKit` and `currentModelName`).
    private func unloadCurrentModel() {
        whisperKit = nil
        currentModelName = nil
    }
    
    /// Downloads the model to a temporary folder (if it isn't already on disk),
    /// then moves it into its final folder in `modelsBaseFolder`.
    private func downloadModelIfNeeded(
        variant: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        let modelFolder = modelPath(for: variant)
        
        // If the model folder exists but isn't a complete model, clean it up
        let isDownloaded = await isModelDownloaded(variant)
        if FileManager.default.fileExists(atPath: modelFolder.path) && !isDownloaded {
            try FileManager.default.removeItem(at: modelFolder)
        }
        
        // If model is already fully downloaded, we're done
        if isDownloaded {
            // Still report 100% progress for consistency
            let finalProgress = Progress(totalUnitCount: 100)
            finalProgress.completedUnitCount = 100
            progressCallback(finalProgress)
            return
        }
        
        // Report initial progress
        let initialProgress = Progress(totalUnitCount: 100)
        initialProgress.completedUnitCount = 0
        progressCallback(initialProgress)


        // Create parent directories
        let parentDir = modelFolder.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        do {
            // Download directly using the exact variant name provided
            let tempFolder = try await WhisperKit.download(
                variant: variant,
                downloadBase: nil,
                useBackgroundSession: false,
                from: "argmaxinc/whisperkit-coreml",
                token: nil,
                progressCallback: { progress in
                    progressCallback(progress)
                }
            )
            
            // Ensure target folder exists
            try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)
            
            // Move the downloaded snapshot to the final location
            try moveContents(of: tempFolder, to: modelFolder)
            
            // Report final progress
            let finalProgress = Progress(totalUnitCount: 100)
            finalProgress.completedUnitCount = 100
            progressCallback(finalProgress)
            
        } catch {
            // Clean up any partial download if an error occurred
            if FileManager.default.fileExists(atPath: modelFolder.path) {
                try? FileManager.default.removeItem(at: modelFolder)
            }
            
            // Check if this looks like a "model not found" error
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("not found") || errorDescription.contains("404") || errorDescription.contains("does not exist") {
                throw TranscriptionProviderError.modelNotFound(variant)
            }
            
            // Rethrow as download failed for other errors
            throw TranscriptionProviderError.modelDownloadFailed(variant, error)
        }
    }
    
    /// Loads a local model folder via `WhisperKitConfig`, optionally reporting load progress.
    private func loadWhisperKitModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        let loadingProgress = Progress(totalUnitCount: 100)
        loadingProgress.completedUnitCount = 0
        progressCallback(loadingProgress)

        let modelFolder = modelPath(for: modelName)
        let tokenizerFolder = tokenizerPath(for: modelName)

        do {
            // Use WhisperKit's config to load the model
            let config = WhisperKitConfig(
                model: modelName,
                modelFolder: modelFolder.path,
                tokenizerFolder: tokenizerFolder,
                prewarm: true,
                load: true
            )

            // The initializer automatically calls `loadModels`.
            whisperKit = try await WhisperKit(config)
            currentModelName = modelName

            // Finalize load progress
            loadingProgress.completedUnitCount = 100
            progressCallback(loadingProgress)

        } catch {
            throw TranscriptionProviderError.modelLoadFailed(modelName, error)
        }
    }
    
    /// Moves all items from `sourceFolder` into `destFolder` (shallow move of directory contents).
    private func moveContents(of sourceFolder: URL, to destFolder: URL) throws {
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(atPath: sourceFolder.path)
        for item in items {
            let src = sourceFolder.appendingPathComponent(item)
            let dst = destFolder.appendingPathComponent(item)
            try fileManager.moveItem(at: src, to: dst)
        }
    }
    
    // MARK: - Additional Methods for Testing
    
    /// Loads a model into memory for immediate use
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        // Unload current model if different
        if currentModelName != modelName {
            unloadCurrentModel()
        }
        
        // Download if not already downloaded
        if !(await isModelDownloaded(modelName)) {
            try await downloadModelIfNeeded(variant: modelName) { _ in }
        }
        
        // Load the model into memory
        try await loadWhisperKitModel(modelName) { _ in }
        
        return whisperKit != nil && currentModelName == modelName
    }
    
    /// Checks if a model is currently loaded in memory
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        return whisperKit != nil && currentModelName == modelName
    }
    
    /// Gets the file path for a model
    func getModelPath(_ modelName: String) async -> URL? {
        let modelPath = modelPath(for: modelName)
        return await isModelDownloaded(modelName) ? modelPath : nil
    }
    
    /// Gets current device capabilities
    func getCurrentDeviceCapabilities() async -> DeviceCapabilities {
        // Get available memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Detect Neural Engine (Apple Silicon specific)
        var hasNeuralEngine: Bool? = nil
        var coreMLComputeUnits: String? = nil
        
        #if arch(arm64)
        // On Apple Silicon, assume Neural Engine is available
        hasNeuralEngine = true
        coreMLComputeUnits = "all"
        #else
        // On Intel, no Neural Engine
        hasNeuralEngine = false
        coreMLComputeUnits = "cpuAndGPU"
        #endif
        
        // Determine supported model sizes based on available memory
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
    
    /// Checks if a model is compatible with the current device
    func isModelCompatibleWithDevice(_ modelName: String, device: DeviceCapabilities) async -> Bool {
        let modelNameLower = modelName.lowercased()
        
        // Check if the model size is supported
        for supportedSize in device.supportedModelSizes {
            if modelNameLower.contains(supportedSize) {
                return true
            }
        }
        
        // If no specific size found, assume it's compatible with base constraints
        return device.availableMemory >= 2_000_000_000 // At least 2GB
    }
    
    /// Gets available device memory
    func getAvailableDeviceMemory() async -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    // MARK: - Private Helper Methods
    
    /// Validates a model name to prevent path traversal and other security issues
    /// - Parameter modelName: The model name to validate
    /// - Returns: true if the model name is safe, false otherwise
    private func validateModelName(_ modelName: String) -> Bool {
        guard !modelName.isEmpty,
              modelName.count <= 200, // Reasonable length limit
              !modelName.contains(".."), // Prevent path traversal
              !modelName.contains("/"), // Prevent file system paths
              !modelName.contains("\\"), // Prevent Windows paths
              !modelName.hasPrefix("."), // Prevent hidden file patterns
              modelName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }) else {
            return false
        }
        return true
    }
    
    /// Formats a model name into a user-friendly display name
    /// - Parameter modelName: The raw model name to format
    /// - Returns: A sanitized, user-friendly display name
    private func formatDisplayName(for modelName: String) -> String {
        // Input validation to prevent malicious input
        guard validateModelName(modelName) else {
            return "Unknown Model"
        }
        
        // Handle common WhisperKit model naming patterns
        var displayName = modelName
        
        // Remove common prefixes (using safer, more specific replacements)
        if displayName.hasPrefix("openai_whisper-") {
            displayName = String(displayName.dropFirst("openai_whisper-".count))
        }
        if displayName.hasPrefix("whisper-") {
            displayName = String(displayName.dropFirst("whisper-".count))
        }
        
        // Capitalize and add spaces
        displayName = displayName.replacingOccurrences(of: "_", with: " ")
        displayName = displayName.replacingOccurrences(of: "-", with: " ")
        
        // Capitalize words
        displayName = displayName.capitalized
        
        // Handle special cases
        if displayName.lowercased().contains("turbo") {
            displayName = displayName.replacingOccurrences(of: "Turbo", with: "Turbo")
        }
        
        // Final sanitization: ensure the result is still safe
        let sanitized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Unknown Model" : sanitized
    }
    
    /// Estimates model size based on model name patterns
    private func estimateModelSize(for modelName: String) -> String {
        let lowercased = modelName.lowercased()
        
        if lowercased.contains("large") {
            return "~3.1 GB"
        } else if lowercased.contains("medium") {
            return "~1.5 GB"
        } else if lowercased.contains("small") {
            return "~461 MB"
        } else if lowercased.contains("base") {
            return "~145 MB"
        } else if lowercased.contains("tiny") {
            return "~65 MB"
        } else if lowercased.contains("turbo") {
            return "~461 MB"
        } else {
            return "Unknown"
        }
    }
    
    /// Returns a sort order for model sizes
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
        } else if lowercased.contains("turbo") {
            return 4
        } else if lowercased.contains("large") {
            return 5
        } else {
            return 6 // Unknown models go last
        }
    }
}