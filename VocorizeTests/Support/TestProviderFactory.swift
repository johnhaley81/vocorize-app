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
        if MLXAvailability.isAvailable {
            // When MLX provider is implemented, register it here
            print("✅ MLX framework available - would register real MLX provider")
        } else {
            print("⚠️ MLX not available - skipping MLX provider registration")
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
            return CachedWhisperKitProvider()
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
                isRecommended: true
            ),
            ProviderModelInfo(
                internalName: "mlx-base",
                displayName: "MLX Base", 
                providerType: .mlx,
                estimatedSize: "90 MB"
            )
        ]
    }
    
    func getRecommendedModel() async throws -> String {
        return "mlx-tiny"
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
        
        let provider: any TranscriptionProvider = VocorizeTestConfiguration.shouldUseMockProviders 
            ? MockMLXProvider()
            : {
                // For integration tests, check MLX availability
                if MLXAvailability.isAvailable {
                    fatalError("Real MLX provider not yet implemented")
                } else {
                    // Fall back to mock even in integration mode if MLX unavailable
                    return MockMLXProvider()
                }
            }()
        
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
}

// MARK: - Cached WhisperKit Provider

/// WhisperKit provider with integrated model caching for faster integration tests
actor CachedWhisperKitProvider: TranscriptionProvider {
    static let providerType: TranscriptionProviderType = .whisperKit
    static let displayName: String = "Cached WhisperKit Provider"
    
    private let underlyingProvider: WhisperKitProvider
    private let cacheManager: ModelCacheManager
    
    init(cacheManager: ModelCacheManager = TestProviderFactory.cacheManager) {
        self.underlyingProvider = WhisperKitProvider()
        self.cacheManager = cacheManager
    }
    
    // MARK: - TranscriptionProvider Implementation
    
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        // Ensure model is available (from cache or download)
        try await ensureModelAvailable(modelName, progressCallback: progressCallback)
        
        // Delegate to underlying provider for transcription
        return try await underlyingProvider.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            options: options,
            progressCallback: progressCallback
        )
    }
    
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        // Check cache first
        if let cachedModelURL = await cacheManager.getCachedModel(modelName) {
            print("🎯 Using cached model: \(modelName)")
            
            // Simulate progress for consistency
            let progress = Progress(totalUnitCount: 100)
            progressCallback(progress)
            progress.completedUnitCount = 100
            progressCallback(progress)
            return
        }
        
        // Download and cache the model
        print("⬇️ Downloading and caching model: \(modelName)")
        
        // Download using underlying provider
        try await underlyingProvider.downloadModel(modelName, progressCallback: progressCallback)
        
        // Cache the downloaded model for future use
        if let modelPath = await getModelPath(modelName) {
            try await cacheManager.cacheModel(modelName, from: modelPath)
        }
    }
    
    func deleteModel(_ modelName: String) async throws {
        // Remove from cache and underlying provider
        try await cacheManager.removeCachedModel(modelName)
        try await underlyingProvider.deleteModel(modelName)
    }
    
    func isModelDownloaded(_ modelName: String) async -> Bool {
        // Check cache first, then underlying provider
        if await cacheManager.getCachedModel(modelName) != nil {
            return true
        }
        return await underlyingProvider.isModelDownloaded(modelName)
    }
    
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        // Ensure model is available from cache or download
        try await ensureModelAvailable(modelName, progressCallback: { _ in })
        return try await underlyingProvider.loadModelIntoMemory(modelName)
    }
    
    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        return await underlyingProvider.isModelLoadedInMemory(modelName)
    }
    
    func getAvailableModels() async throws -> [ProviderModelInfo] {
        return try await underlyingProvider.getAvailableModels()
    }
    
    func getRecommendedModel() async throws -> String {
        return try await underlyingProvider.getRecommendedModel()
    }
    
    func getCurrentDeviceCapabilities() async -> DeviceCapabilities {
        return await underlyingProvider.getCurrentDeviceCapabilities()
    }
    
    // MARK: - Private Helpers
    
    private func ensureModelAvailable(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        // Check if model is already available locally or in cache
        if await underlyingProvider.isModelDownloaded(modelName) {
            return // Model already available locally
        }
        
        if let cachedModelURL = await cacheManager.getCachedModel(modelName) {
            print("🎯 Restoring model from cache: \(modelName)")
            // Copy cached model to expected location
            try await restoreModelFromCache(modelName, cachedURL: cachedModelURL)
            return
        }
        
        // Model not available - download and cache it
        try await downloadModel(modelName, progressCallback: progressCallback)
    }
    
    private func restoreModelFromCache(_ modelName: String, cachedURL: URL) async throws {
        // Get the expected model location for the underlying provider
        guard let expectedPath = await getModelPath(modelName) else {
            throw CacheError.modelNotFound(modelName)
        }
        
        // Copy from cache to expected location
        let fileManager = FileManager.default
        
        // Remove existing if present
        if fileManager.fileExists(atPath: expectedPath.path) {
            try fileManager.removeItem(at: expectedPath)
        }
        
        // Create parent directory if needed
        try fileManager.createDirectory(
            at: expectedPath.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Copy cached model to expected location
        try fileManager.copyItem(at: cachedURL, to: expectedPath)
        
        print("✅ Restored \(modelName) from cache to \(expectedPath.path)")
    }
    
    private func getModelPath(_ modelName: String) async -> URL? {
        // This would need to be implemented based on WhisperKit's model storage strategy
        // For now, return a mock path that follows WhisperKit conventions
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let whisperKitModelsPath = homeDirectory
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
            .appendingPathComponent(modelName.replacingOccurrences(of: "/", with: "_"))
        
        return whisperKitModelsPath
    }
}