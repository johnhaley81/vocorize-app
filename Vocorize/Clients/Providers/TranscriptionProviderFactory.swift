//
//  TranscriptionProviderFactory.swift
//  Vocorize
//
//  Factory for managing and routing model names to appropriate transcription providers
//  Thread-safe actor implementation with singleton pattern
//

import Foundation

/// Factory responsible for managing transcription providers and routing model names to the correct provider
public actor TranscriptionProviderFactory {
    
    // MARK: - Properties
    
    /// Registry of providers by type
    private var providers: [TranscriptionProviderType: any TranscriptionProvider] = [:]
    
    // MARK: - Initialization
    
    public init() {
        // Public initializer for dependency injection
    }
    
    // MARK: - Provider Registration
    
    /// Registers a provider for a specific type
    /// - Parameters:
    ///   - provider: The provider to register
    ///   - type: The provider type
    public func registerProvider(_ provider: any TranscriptionProvider, for type: TranscriptionProviderType) {
        providers[type] = provider
    }
    
    /// Unregisters a provider for a specific type
    /// - Parameter type: The provider type to unregister
    public func unregisterProvider(_ type: TranscriptionProviderType) {
        providers.removeValue(forKey: type)
    }
    
    /// Clears all registered providers
    public func clear() {
        providers.removeAll()
    }
    
    // MARK: - Provider Lookup
    
    /// Gets the appropriate provider for a model name
    /// - Parameter modelName: The model name to route
    /// - Returns: The provider that can handle this model
    /// - Throws: TranscriptionProviderFactoryError if model is not supported or provider not registered
    public func getProviderForModel(_ modelName: String) async throws -> any TranscriptionProvider {
        guard let providerType = await getProviderTypeForModel(modelName) else {
            throw TranscriptionProviderFactoryError.modelNotSupported(modelName)
        }
        
        guard let provider = providers[providerType] else {
            throw TranscriptionProviderFactoryError.providerNotRegistered(providerType)
        }
        
        return provider
    }
    
    /// Determines which provider type should handle a model name
    /// - Parameter modelName: The model name to analyze
    /// - Returns: The provider type that should handle this model, or nil if not supported
    public func getProviderTypeForModel(_ modelName: String) async -> TranscriptionProviderType? {
        let lowercaseModel = modelName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return nil for empty or whitespace-only strings
        if lowercaseModel.isEmpty {
            return nil
        }
        
        // MLX patterns (check these first as they're more specific)
        if lowercaseModel.hasPrefix("mlx-") || 
           lowercaseModel.hasPrefix("mlx-community/") ||
           lowercaseModel.hasSuffix("-mlx") ||
           lowercaseModel.contains("-mlx-") {
            return .mlx
        }
        
        // WhisperKit patterns
        if lowercaseModel.hasPrefix("openai_whisper-") ||
           lowercaseModel.hasPrefix("whisper-") {
            return .whisperKit
        }
        
        // Return nil for unrecognized patterns
        return nil
    }
    
    // MARK: - State Inspection
    
    /// Checks if a provider is registered for the given type
    /// - Parameter type: The provider type to check
    /// - Returns: true if provider is registered
    public func isProviderRegistered(_ type: TranscriptionProviderType) async -> Bool {
        return providers[type] != nil
    }
    
    /// Gets the number of registered providers
    /// - Returns: Count of registered providers
    public func getRegisteredProviderCount() async -> Int {
        return providers.count
    }
    
    /// Gets all registered provider types
    /// - Returns: Array of provider types, sorted for consistency
    public func getAllRegisteredProviderTypes() async -> [TranscriptionProviderType] {
        return Array(providers.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Gets all registered providers
    /// - Returns: Array of all registered providers
    public func getAllRegisteredProviders() async -> [any TranscriptionProvider] {
        return Array(providers.values)
    }
}