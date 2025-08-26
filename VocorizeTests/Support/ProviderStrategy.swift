//
//  ProviderStrategy.swift
//  VocorizeTests
//
//  Provider strategy pattern for clean separation of mock and real provider creation
//  Eliminates complex conditional logic in factory methods
//

import Foundation
@testable import Vocorize

/// Strategy for creating transcription providers based on test context
public protocol ProviderStrategy {
    /// Creates a WhisperKit provider appropriate for this strategy
    func createWhisperKitProvider() async -> any TranscriptionProvider
    
    /// Creates an MLX provider appropriate for this strategy
    func createMLXProvider() async -> any TranscriptionProvider
    
    /// Validates that this strategy can create all required providers
    func validateCapability() async -> ProviderStrategyValidation
}

/// Result of provider strategy validation
public struct ProviderStrategyValidation {
    let isValid: Bool
    let warnings: [String]
    let errors: [String]
    
    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
}

// MARK: - Mock Provider Strategy

/// Strategy for creating fast mock providers for unit tests
public actor MockProviderStrategy: ProviderStrategy {
    
    public init() {}
    
    public func createWhisperKitProvider() async -> any TranscriptionProvider {
        return SimpleWhisperKitProvider.successful()
    }
    
    public func createMLXProvider() async -> any TranscriptionProvider {
        return MockMLXProvider()
    }
    
    public func validateCapability() async -> ProviderStrategyValidation {
        return ProviderStrategyValidation(
            isValid: true,
            warnings: [],
            errors: []
        )
    }
}

// MARK: - Integration Provider Strategy

/// Strategy for creating real or cache-enabled providers for integration tests
public actor IntegrationProviderStrategy: ProviderStrategy {
    
    private let cacheManager: ModelCacheManager
    
    public init(cacheManager: ModelCacheManager = TestProviderFactory.cacheManager) {
        self.cacheManager = cacheManager
    }
    
    public func createWhisperKitProvider() async -> any TranscriptionProvider {
        return CachedWhisperKitProvider(cacheManager: cacheManager)
    }
    
    public func createMLXProvider() async -> any TranscriptionProvider {
        let availability = MLXAvailability()
        let healthCheck = await availability.performMLXHealthCheck()
        
        if healthCheck.isHealthy {
            // TODO: Return real MLX provider when implemented
            print("📝 MLX available but real provider not implemented, using mock")
            return MockMLXProvider()
        } else {
            print("⚠️ MLX not available, using mock provider for integration tests")
            return MockMLXProvider()
        }
    }
    
    public func validateCapability() async -> ProviderStrategyValidation {
        var warnings: [String] = []
        var errors: [String] = []
        
        // Check MLX availability
        let availability = MLXAvailability()
        let healthCheck = await availability.performMLXHealthCheck()
        
        if !healthCheck.isHealthy {
            warnings.append("MLX not fully functional: \(healthCheck.errors.joined(separator: ", "))")
        }
        
        // Check cache availability
        let cacheStats = await cacheManager.getStatistics()
        if cacheStats.availableSpace < 1_000_000_000 { // 1GB
            warnings.append("Low disk space for model cache: \(cacheStats.availableSpace) bytes")
        }
        
        return ProviderStrategyValidation(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }
}

// MARK: - Adaptive Provider Strategy

/// Strategy that adapts based on runtime conditions
public actor AdaptiveProviderStrategy: ProviderStrategy {
    
    private let mockStrategy: MockProviderStrategy
    private let integrationStrategy: IntegrationProviderStrategy
    
    public init() {
        self.mockStrategy = MockProviderStrategy()
        self.integrationStrategy = IntegrationProviderStrategy()
    }
    
    public func createWhisperKitProvider() async -> any TranscriptionProvider {
        // Always prefer cached provider for better integration test coverage
        let validation = await integrationStrategy.validateCapability()
        if !validation.hasErrors {
            return await integrationStrategy.createWhisperKitProvider()
        } else {
            return await mockStrategy.createWhisperKitProvider()
        }
    }
    
    public func createMLXProvider() async -> any TranscriptionProvider {
        // Check MLX availability and fall back gracefully
        let availability = MLXAvailability()
        if await availability.canImportMLX() {
            return await integrationStrategy.createMLXProvider()
        } else {
            return await mockStrategy.createMLXProvider()
        }
    }
    
    public func validateCapability() async -> ProviderStrategyValidation {
        let integrationValidation = await integrationStrategy.validateCapability()
        let mockValidation = await mockStrategy.validateCapability()
        
        return ProviderStrategyValidation(
            isValid: integrationValidation.isValid || mockValidation.isValid,
            warnings: integrationValidation.warnings + mockValidation.warnings,
            errors: integrationValidation.errors + mockValidation.errors
        )
    }
}

// MARK: - Factory Extension

extension TestProviderFactory {
    
    /// Creates a factory using the specified provider strategy
    public static func createFactory(using strategy: ProviderStrategy) async -> TranscriptionProviderFactory {
        let factory = TranscriptionProviderFactory()
        
        // Register providers using strategy
        let whisperProvider = await strategy.createWhisperKitProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        let mlxProvider = await strategy.createMLXProvider()
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        return factory
    }
    
    /// Creates a factory with automatic strategy selection based on test mode
    public static func createFactoryWithAdaptiveStrategy() async -> TranscriptionProviderFactory {
        let strategy: ProviderStrategy = switch VocorizeTestConfiguration.currentTestMode {
        case .unit:
            MockProviderStrategy()
        case .integration:
            AdaptiveProviderStrategy()
        }
        
        return await createFactory(using: strategy)
    }
}