//
//  TranscriptionProviderRegistry.swift
//  Vocorize
//
//  Created for Phase 1.1 - TranscriptionProvider Protocol
//

import Foundation
import Dependencies
import DependenciesMacros

/// Global actor that manages the registry of available transcription providers
@globalActor
public actor TranscriptionProviderRegistry {
    public static let shared = TranscriptionProviderRegistry()
    
    /// Dictionary storing registered providers by their type
    private var providers: [TranscriptionProviderType: any TranscriptionProvider] = [:]
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Registers a transcription provider for the given type
    /// - Parameters:
    ///   - provider: The provider instance to register
    ///   - type: The provider type to register it under
    public func register<Provider: TranscriptionProvider>(
        _ provider: Provider,
        for type: TranscriptionProviderType
    ) {
        providers[type] = provider
    }
    
    /// Retrieves a registered provider for the specified type
    /// - Parameter type: The provider type to retrieve
    /// - Returns: The registered provider, or nil if not found
    /// - Throws: TranscriptionProviderError.providerNotAvailable if provider is not registered
    public func provider(for type: TranscriptionProviderType) throws -> any TranscriptionProvider {
        guard let provider = providers[type] else {
            throw TranscriptionProviderError.providerNotAvailable(type)
        }
        return provider
    }
    
    /// Returns a list of all registered provider types
    /// - Returns: Array of registered TranscriptionProviderType values
    public func availableProviderTypes() -> [TranscriptionProviderType] {
        return Array(providers.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Checks if a provider is available for the specified type
    /// - Parameter type: The provider type to check
    /// - Returns: true if a provider is registered for this type, false otherwise
    public func isProviderAvailable(_ type: TranscriptionProviderType) -> Bool {
        return providers[type] != nil
    }
    
    /// Removes a provider from the registry
    /// - Parameter type: The provider type to unregister
    public func unregister(_ type: TranscriptionProviderType) {
        providers.removeValue(forKey: type)
    }
    
    /// Removes all registered providers from the registry
    public func clear() {
        providers.removeAll()
    }
    
    /// Returns the number of registered providers
    public var count: Int {
        return providers.count
    }
}

// MARK: - Dependency Integration

/// Client wrapper for the TranscriptionProviderRegistry to integrate with TCA's dependency system
@DependencyClient
public struct TranscriptionProviderRegistryClient {
    /// Registers a provider for the given type
    public var register: @Sendable (any TranscriptionProvider, TranscriptionProviderType) async -> Void
    
    /// Retrieves a provider for the specified type
    public var provider: @Sendable (TranscriptionProviderType) async throws -> any TranscriptionProvider
    
    /// Returns all available provider types
    public var availableProviderTypes: @Sendable () async -> [TranscriptionProviderType] = { [] }
    
    /// Checks if a provider is available
    public var isProviderAvailable: @Sendable (TranscriptionProviderType) async -> Bool = { _ in false }
    
    /// Unregisters a provider
    public var unregister: @Sendable (TranscriptionProviderType) async -> Void
    
    /// Clears all providers
    public var clear: @Sendable () async -> Void
    
    /// Returns the count of registered providers
    public var count: @Sendable () async -> Int = { 0 }
}

extension TranscriptionProviderRegistryClient: DependencyKey {
    public static var liveValue: Self {
        return Self(
            register: { provider, type in
                await TranscriptionProviderRegistry.shared.register(provider, for: type)
            },
            provider: { type in
                try await TranscriptionProviderRegistry.shared.provider(for: type)
            },
            availableProviderTypes: {
                await TranscriptionProviderRegistry.shared.availableProviderTypes()
            },
            isProviderAvailable: { type in
                await TranscriptionProviderRegistry.shared.isProviderAvailable(type)
            },
            unregister: { type in
                await TranscriptionProviderRegistry.shared.unregister(type)
            },
            clear: {
                await TranscriptionProviderRegistry.shared.clear()
            },
            count: {
                await TranscriptionProviderRegistry.shared.count
            }
        )
    }
    
    public static var testValue: Self {
        return Self(
            register: { _, _ in },
            provider: { _ in throw TranscriptionProviderError.providerNotAvailable(.whisperKit) },
            availableProviderTypes: { [] },
            isProviderAvailable: { _ in false },
            unregister: { _ in },
            clear: { },
            count: { 0 }
        )
    }
}

extension DependencyValues {
    public var transcriptionProviderRegistry: TranscriptionProviderRegistryClient {
        get { self[TranscriptionProviderRegistryClient.self] }
        set { self[TranscriptionProviderRegistryClient.self] = newValue }
    }
}
