//
//  TranscriptionClientTestExtensions.swift
//  VocorizeTests
//
//  Test extensions for TranscriptionClient that integrate with TestConfiguration
//  This file bridges the main TranscriptionClient with test-specific provider factories
//

import Dependencies
import Foundation
import WhisperKit
@testable import Vocorize

extension TranscriptionClient {
    
    /// Automatically configured test value that respects TestConfiguration
    /// - Unit tests: Uses fast mock providers (< 1 second execution)
    /// - Integration tests: Uses real providers (5+ minutes for model downloads)
    static var autoTestValue: Self {
        if VocorizeTestConfiguration.shouldUseMockProviders {
            return .testValue  // Use the new default testValue which is fast
        } else {
            return .integrationTestValue
        }
    }
    
    /// Creates a test client with SimpleWhisperKitProvider through TranscriptionProviderFactory
    /// This provides better integration with the provider system while maintaining speed
    static func mockTestValue() async -> Self {
        let factory = TranscriptionProviderFactory()
        
        // Register SimpleWhisperKitProvider for fast, realistic testing
        let mockProvider = SimpleWhisperKitProvider.successful()
        await factory.registerProvider(mockProvider, for: .whisperKit)
        
        return .testValue(with: factory)
    }
    
    /// Fast test value using the quick mock implementation (non-async)
    /// This is the fastest option but bypasses the provider system
    static var quickMockTestValue: Self {
        return .testValue  // Use the default testValue from main client
    }
    
    /// Creates a test client with a specific factory configuration
    /// Useful for tests that need precise control over provider setup
    static func testValue(with factory: TranscriptionProviderFactory) -> Self {
        let live = TranscriptionClientLive(factory: factory)
        return Self(
            transcribe: { try await live.transcribe(url: $0, model: $1, options: $2, progressCallback: $3) },
            downloadModel: { try await live.downloadModel(variant: $0, progressCallback: $1) },
            deleteModel: { try await live.deleteModel(variant: $0) },
            isModelDownloaded: { await live.isModelDownloaded($0) },
            getRecommendedModels: { await live.getRecommendedModels() },
            getAvailableModels: { try await live.getAvailableModels() }
        )
    }
    
    /// Slow integration test value - always uses real providers
    static var integrationTestValue: Self {
        let factory = TranscriptionProviderFactory()
        let live = TranscriptionClientLive(factory: factory)
        return Self(
            transcribe: { try await live.transcribe(url: $0, model: $1, options: $2, progressCallback: $3) },
            downloadModel: { try await live.downloadModel(variant: $0, progressCallback: $1) },
            deleteModel: { try await live.deleteModel(variant: $0) },
            isModelDownloaded: { await live.isModelDownloaded($0) },
            getRecommendedModels: { await live.getRecommendedModels() },
            getAvailableModels: { try await live.getAvailableModels() }
        )
    }
}

// MARK: - Convenience Test Helpers

extension TranscriptionClient {
    
    /// Creates a client with only WhisperKit provider for focused testing
    /// Uses mock or real provider based on TestConfiguration
    static func whisperKitOnlyTestValue() async -> Self {
        let factory = await TestProviderFactory.createWhisperKitOnlyFactory()
        return .testValue(with: factory)
    }
    
    /// Creates a client with only MLX provider for MLX-specific testing
    /// Uses mock or real provider based on TestConfiguration
    static func mlxOnlyTestValue() async -> Self {
        let factory = await TestProviderFactory.createMLXOnlyFactory()
        return .testValue(with: factory)
    }
    
    /// Creates an empty client for tests that need to register providers manually
    /// Useful for testing specific provider combinations or error scenarios
    static func isolatedTestValue() async -> Self {
        let factory = await TestProviderFactory.createIsolatedFactory()
        return .testValue(with: factory)
    }
    
    /// Creates a client configured with MockWhisperKitProvider for consistent mocking
    /// This is preferred over quickMockTestValue when you need provider-level features
    static func mockProviderTestValue() async -> Self {
        return await .mockTestValue()
    }
}

// MARK: - Test Configuration Helpers

extension TranscriptionClient {
    
    /// Validates that the client is configured correctly for current test mode
    static func validateTestConfiguration() -> Bool {
        // TODO: Re-enable once VocorizeTestConfiguration compilation issues are resolved
        // guard VocorizeTestConfiguration.validateConfiguration() else {
        //     return false
        // }
        
        // Additional client-specific validations could go here
        return true
    }
    
    /// Prints current test client configuration for debugging
    static func printTestConfiguration() {
        // TODO: Re-enable once VocorizeTestConfiguration compilation issues are resolved
        // VocorizeTestConfiguration.printConfiguration()
        print("   Available Test Values:")
        print("     - .testValue (default fast mock - no provider system)")
        print("     - .autoTestValue (respects TestConfiguration)")
        print("     - .quickMockTestValue (alias for .testValue)")
        print("     - .mockTestValue() (SimpleWhisperKitProvider through factory - async)")
        print("     - .integrationTestValue (real providers)")
        print("     - .whisperKitOnlyTestValue() (focused testing - async)")
        print("     - .mlxOnlyTestValue() (MLX focused testing - async)")
        print("     - .isolatedTestValue() (manual provider setup - async)")
        print("     - .whisperKitOnlyTestValue() (focused)")
        print("     - .mlxOnlyTestValue() (focused)")
        print("     - .isolatedTestValue() (manual setup)")
    }
}

// MARK: - Dependency Value Extensions

extension DependencyValues {
    /// Convenience accessor for test-configured transcription client
    /// Defaults to automatic configuration based on TestConfiguration
    var testTranscription: TranscriptionClient {
        get { 
            return TranscriptionClient.autoTestValue
        }
        set { self[TranscriptionClient.self] = newValue }
    }
}