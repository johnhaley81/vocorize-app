//
//  WhisperKitProvider.swift
//  Vocorize
//
//  Adapter that makes the existing WhisperKit implementation conform to TranscriptionProvider protocol
//

import Foundation
import AVFoundation
import WhisperKit
import Dependencies

/// WhisperKit provider implementation that wraps the existing TranscriptionClientLive
/// This maintains complete backward compatibility with the existing WhisperKit implementation
actor WhisperKitProvider: TranscriptionProvider {
    
    // MARK: - Protocol Conformance
    
    static var providerType: TranscriptionProviderType { .whisperKit }
    static var displayName: String { "WhisperKit" }
    
    // MARK: - Private Properties
    
    /// The underlying WhisperKit implementation
    private let transcriptionClient: TranscriptionClient
    
    // MARK: - Initialization
    
    init(transcriptionClient: TranscriptionClient? = nil) {
        // Use injected client or default to live implementation
        self.transcriptionClient = transcriptionClient ?? TranscriptionClient.liveValue
    }
    
    // MARK: - TranscriptionProvider Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        return try await transcriptionClient.transcribe(
            audioURL,
            modelName,
            options,
            progressCallback
        )
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> Void {
        try await transcriptionClient.downloadModel(
            modelName,
            progressCallback
        )
    }
    
    func deleteModel(_ modelName: String) async throws -> Void {
        try await transcriptionClient.deleteModel(modelName)
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        return await transcriptionClient.isModelDownloaded(modelName)
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        // Get the available models from WhisperKit
        let availableModelNames = try await transcriptionClient.getAvailableModels()
        let recommendedModels = try await transcriptionClient.getRecommendedModels()
        
        // Create ProviderModelInfo objects for each model
        var providerModels: [ProviderModelInfo] = []
        
        for modelName in availableModelNames {
            // Check if this model is downloaded
            let isDownloaded = await transcriptionClient.isModelDownloaded(modelName)
            
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
    }
    
    func getRecommendedModel() async throws -> String {
        let recommendedModels = try await transcriptionClient.getRecommendedModels()
        
        // Return the default model first
        let defaultModel = recommendedModels.default
        
        // Check if the default model is available
        let availableModels = try await transcriptionClient.getAvailableModels()
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
    
    // MARK: - Private Helper Methods
    
    /// Formats a model name into a user-friendly display name
    /// - Parameter modelName: The raw model name to format
    /// - Returns: A sanitized, user-friendly display name
    private func formatDisplayName(for modelName: String) -> String {
        // Input validation: ensure the model name is safe to process
        guard !modelName.isEmpty,
              modelName.count <= 200, // Reasonable length limit
              !modelName.contains(".."), // Prevent path traversal patterns
              !modelName.contains("/"), // Prevent file system paths
              !modelName.contains("\\"), // Prevent Windows paths
              !modelName.hasPrefix("."), // Prevent hidden file patterns
              modelName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }) else {
            // Return a safe fallback for invalid input
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
