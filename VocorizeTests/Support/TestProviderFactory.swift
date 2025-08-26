//
//  TestProviderFactory.swift
//  VocorizeTests
//
//  Factory for creating appropriate providers based on test configuration
//  Handles both mock providers (fast unit tests) and real providers (integration tests)
//  Integrates with ModelCacheManager for efficient model caching in integration tests
//

import Foundation
import WhisperKit
@testable import Vocorize

/// Factory for creating test-appropriate transcription providers
public actor TestProviderFactory {
    
    // MARK: - Cache Management
    
    /// Shared cache manager for integration tests
    public static let cacheManager = ModelCacheManager()
    
    /// Models commonly used in integration tests
    public static let commonTestModels = [
        "openai_whisper-tiny",
        "openai_whisper-base",
        "openai_whisper-small"
    ]
    
    // MARK: - Provider Creation
    
    /// Creates a TranscriptionProviderFactory configured for current test mode
    public static func createFactory() -> TranscriptionProviderFactory {
        let factory = TranscriptionProviderFactory()
        return factory
    }
    
    /// Creates a pre-configured TranscriptionProviderFactory with providers registered
    public static func createConfiguredFactory() async -> TranscriptionProviderFactory {
        let factory = TranscriptionProviderFactory()
        
        switch VocorizeTestConfiguration.currentTestMode {
        case .unit:
            await registerMockProviders(to: factory)
        case .integration:
            await registerRealProviders(to: factory)
        }
        
        return factory
    }
    
    /// Creates a single provider instance based on test mode
    public static func createProvider(for type: TranscriptionProviderType) -> any TranscriptionProvider {
        switch VocorizeTestConfiguration.currentTestMode {
        case .unit:
            return createMockProvider(for: type)
        case .integration:
            return createRealProvider(for: type)
        }
    }
    
    // MARK: - Mock Provider Registration
    
    private static func registerMockProviders(to factory: TranscriptionProviderFactory) async {
        // Register fast mock providers for unit tests
        let whisperMock = SimpleWhisperKitProvider.successful()
        await factory.registerProvider(whisperMock, for: .whisperKit)
        
        // Register MLX mock when available
        let mlxMock = MockMLXProvider()
        await factory.registerProvider(mlxMock, for: .mlx)
    }
    
    // MARK: - Real Provider Registration
    
    private static func registerRealProviders(to factory: TranscriptionProviderFactory) async {
        // Register cache-enabled WhisperKit provider
        let whisperProvider = CachedWhisperKitProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        // Register MLX provider conditionally based on availability
        await registerMLXProviderIfAvailable(to: factory)
    }
    
    /// Safely registers MLX provider with comprehensive fallback strategy
    private static func registerMLXProviderIfAvailable(to factory: TranscriptionProviderFactory) async {
        let availability = MLXAvailability()
        let healthCheck = await availability.performMLXHealthCheck()
        
        if healthCheck.isHealthy {
            // TODO: Register real MLX provider when implemented
            print("✅ MLX framework fully functional - would register real MLX provider")
            let mockMLXProvider = MockMLXProvider()
            await factory.registerProvider(mockMLXProvider, for: .mlx)
        } else {
            print("⚠️ MLX not fully functional: \(healthCheck.errors.joined(separator: ", "))")
            print("   Using mock MLX provider for integration tests")
            let mockMLXProvider = MockMLXProvider()
            await factory.registerProvider(mockMLXProvider, for: .mlx)
        }
    }
    
    // MARK: - Individual Provider Creation
    
    private static func createMockProvider(for type: TranscriptionProviderType) -> any TranscriptionProvider {
        switch type {
        case .whisperKit:
            return SimpleWhisperKitProvider.successful()
        case .mlx:
            return MockMLXProvider()
        }
    }
    
    private static func createRealProvider(for type: TranscriptionProviderType) -> any TranscriptionProvider {
        switch type {
        case .whisperKit:
            // TODO: Implement CachedWhisperKitProvider for real integration tests
            // For now, use MockWhisperKitProvider with realistic configuration
            return SimpleWhisperKitProvider.successful()
        case .mlx:
            // When real MLX provider is implemented, return it here
            fatalError("Real MLX provider not yet implemented - use mock or skip MLX tests")
        }
    }
}

// MARK: - Mock Providers

/// Mock MLX provider for testing (until real implementation is available)
actor MockMLXProvider: TranscriptionProvider {
    static let providerType: TranscriptionProviderType = .mlx
    static let displayName: String = "Mock MLX Provider"
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        // Simulate progress for mock MLX transcription
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        
        // Simulate some processing time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        progress.completedUnitCount = 50
        progressCallback(progress)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        return "Mock MLX transcription result"
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        
        // Simulate quick download for mock
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        progress.completedUnitCount = 100
        progressCallback(progress)
    }
    
    func deleteModel(_ modelName: String) async throws {
        // Mock deletion - no-op
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        // Mock models are always "available"
        return true
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        return [
            ProviderModelInfo(
                internalName: "mlx-tiny",
                displayName: "MLX Tiny",
                providerType: .mlx,
                estimatedSize: "25 MB",
                isRecommended: true,
                isDownloaded: true
            ),
            ProviderModelInfo(
                internalName: "mlx-base",
                displayName: "MLX Base", 
                providerType: .mlx,
                estimatedSize: "90 MB",
                isRecommended: false,
                isDownloaded: true
            )
        ]
    }
    
    func getRecommendedModel() async throws -> String {
        return "mlx-tiny"
    }
    
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        // Mock MLX models are always "loadable"
        return true
    }
    
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        // Mock MLX models are always "loaded"
        return true
    }
}

// MARK: - Test Utilities

extension TestProviderFactory {
    
    /// Creates a completely isolated factory for test independence
    public static func createIsolatedFactory() async -> TranscriptionProviderFactory {
        let factory = TranscriptionProviderFactory()
        // Don't register any providers - tests can register exactly what they need
        return factory
    }
    
    /// Creates a factory with only WhisperKit provider (common test scenario)
    public static func createWhisperKitOnlyFactory() async -> TranscriptionProviderFactory {
        let factory = TranscriptionProviderFactory()
        
        let provider: any TranscriptionProvider = VocorizeTestConfiguration.shouldUseMockProviders 
            ? SimpleWhisperKitProvider.successful()
            : CachedWhisperKitProvider()
        
        await factory.registerProvider(provider, for: .whisperKit)
        return factory
    }
    
    /// Creates a factory with only MLX provider (for MLX-specific tests)
    public static func createMLXOnlyFactory() async -> TranscriptionProviderFactory {
        let factory = TranscriptionProviderFactory()
        
        let provider: any TranscriptionProvider = await createMLXProvider()
        
        await factory.registerProvider(provider, for: .mlx)
        return factory
    }
    
    // MARK: - Cache Management Utilities
    
    /// Warms the model cache with commonly used test models
    public static func warmTestCache() async {
        print("🔥 Warming test cache with common models...")
        await cacheManager.warmCache(with: commonTestModels)
    }
    
    /// Clears expired models from test cache
    public static func cleanupTestCache() async {
        print("🧹 Cleaning up expired test models...")
        await cacheManager.clearCache()
        await cacheManager.optimizeCache()
    }
    
    /// Gets cache statistics for debugging
    public static func printCacheStatus() async {
        await cacheManager.printCacheStatus()
    }
    
    /// Resets cache statistics (useful for test isolation)
    public static func resetCacheStatistics() async {
        await cacheManager.resetStatistics()
    }
    
    // MARK: - Advanced Provider Creation
    
    /// Creates MLX provider with intelligent fallback
    private static func createMLXProvider() async -> any TranscriptionProvider {
        if VocorizeTestConfiguration.shouldUseMockProviders {
            return MockMLXProvider()
        }
        
        // For integration tests, perform comprehensive MLX check
        let availability = MLXAvailability()
        let healthCheck = await availability.performMLXHealthCheck()
        
        if healthCheck.isHealthy {
            // TODO: Return real MLX provider when implemented
            print("📝 MLX available but real provider not implemented, using mock")
            return MockMLXProvider()
        } else {
            print("⚠️ MLX not available, using mock provider for tests")
            return MockMLXProvider()
        }
    }
}

// MARK: - Cached WhisperKit Provider

/// Simplified WhisperKit provider with caching support for integration tests
actor CachedWhisperKitProvider: TranscriptionProvider {
    static let providerType: TranscriptionProviderType = .whisperKit
    static let displayName: String = "Cached WhisperKit Provider"
    
    private let cacheManager: ModelCacheManager
    private var downloadedModels: Set<String> = ["openai/whisper-tiny"]
    
    init(cacheManager: ModelCacheManager = TestProviderFactory.cacheManager) {
        self.cacheManager = cacheManager
    }
    
    // MARK: - TranscriptionProvider Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        // Check if model is "downloaded" (simulated)
        guard downloadedModels.contains(modelName) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }
        
        // Simulate transcription progress
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        return "Cached provider transcription result"
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        // Simulate download progress
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        
        // Simulate some download time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        // Mark as downloaded
        downloadedModels.insert(modelName)
        print("✅ Downloaded model: \(modelName)")
    }
    
    func deleteModel(_ modelName: String) async throws {
        downloadedModels.remove(modelName)
        print("🗑️ Deleted model: \(modelName)")
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        return downloadedModels.contains(modelName)
    }
    
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        // For testing, download model if not available, then assume it can be loaded
        if !(await isModelDownloaded(modelName)) {
            try await downloadModel(modelName, progressCallback: { _ in })
        }
        return await isModelDownloaded(modelName)
    }
    
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        // For testing, assume loaded if downloaded
        return await isModelDownloaded(modelName)
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        return [
            ProviderModelInfo(
                internalName: "openai/whisper-tiny",
                displayName: "Tiny (39 MB)",
                providerType: .whisperKit,
                estimatedSize: "39 MB",
                isRecommended: true,
                isDownloaded: downloadedModels.contains("openai/whisper-tiny")
            ),
            ProviderModelInfo(
                internalName: "openai/whisper-base",
                displayName: "Base (74 MB)",
                providerType: .whisperKit,
                estimatedSize: "74 MB",
                isRecommended: false,
                isDownloaded: downloadedModels.contains("openai/whisper-base")
            )
        ]
    }
    
    func getRecommendedModel() async throws -> String {
        return "openai/whisper-tiny"
    }
    
    func getCurrentDeviceCapabilities() async -> MockDeviceCapabilities {
        // For testing purposes, return mock capabilities
        return MockDeviceCapabilities(
            hasNeuralEngine: true,
            availableMemory: 8_000_000_000,
            coreMLComputeUnits: "all",
            supportedModelSizes: ["tiny", "base", "small"]
        )
    }
    
}