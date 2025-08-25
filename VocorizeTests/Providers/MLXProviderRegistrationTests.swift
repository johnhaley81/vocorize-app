//
//  MLXProviderRegistrationTests.swift
//  VocorizeTests
//
//  TDD RED PHASE: Comprehensive failing tests for MLX provider registration
//  These tests MUST fail initially because MLXProvider class doesn't exist yet
//  and provider factory routing logic needs to be updated.
//

import Foundation
@testable import Vocorize
import Testing

/// ALL TESTS IN THIS FILE ARE DISABLED FOR TDD RED PHASE
/// These tests are designed to fail because MLXProvider and related functionality don't exist yet.
/// Tests will be re-enabled when implementing MLX provider functionality.
struct MLXProviderRegistrationTests {
    
    @Test
    func tddRedPhase_allMLXTestsDisabled() async throws {
        // This test confirms that MLX TDD tests are properly disabled
        // When MLXProvider is implemented, remove this test and enable the real tests
        #expect(true, "TDD RED phase: MLX tests are disabled until implementation")
    }
    
    // MARK: - DISABLED TDD TESTS - Re-enable when implementing MLXProvider
    
    /*
     * ALL TESTS BELOW ARE COMMENTED OUT FOR TDD RED PHASE
     * 
     * These tests are designed to fail because:
     * - MLXProvider class doesn't exist yet
     * - TranscriptionProviderFactory.shared doesn't exist yet
     * - .mlx provider type may not be implemented
     * - MLX-specific functionality hasn't been built
     * 
     * TO RE-ENABLE:
     * 1. Implement MLXProvider class
     * 2. Add MLX support to TranscriptionProviderFactory
     * 3. Implement MLX provider registration logic
     * 4. Uncomment the tests below
     * 5. Remove the placeholder test above
     */
    
    /*
    // MARK: - MLX Provider Creation Tests
    
    @Test
    func testMLXProviderCanBeRegistered() async throws {
        let provider = MLXProvider()
        
        #expect(MLXProvider.providerType == .mlx, "MLXProvider should have .mlx provider type")
        #expect(MLXProvider.displayName == "MLX", "MLXProvider should have 'MLX' display name")
        #expect(provider != nil, "Should be able to create MLXProvider instance")
        
        let isTranscriptionProvider = provider is any TranscriptionProvider
        #expect(isTranscriptionProvider == true, "MLXProvider should conform to TranscriptionProvider")
        
        let isActor = provider is Actor
        #expect(isActor == true, "MLXProvider should be an Actor")
    }
    
    @Test
    func testMLXProviderInitialization() async throws {
        let provider = MLXProvider()
        
        let initResult = await provider.initialize()
        #expect(initResult.success == true, "MLXProvider should initialize successfully")
        #expect(initResult.error == nil, "MLXProvider initialization should have no errors")
        
        let hasMLXAccess = await provider.hasMLXFrameworkAccess()
        #expect(hasMLXAccess == true, "MLXProvider should have access to MLX frameworks")
        
        let availableDevices = await provider.getAvailableDevices()
        #expect(!availableDevices.isEmpty, "Should detect available compute devices")
    }
    
    // MARK: - Provider Factory Registration Tests
    
    @Test(.serialized)
    func testMLXModelRoutingLogic() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let mlxModelPatterns = [
            "mlx-community/whisper-tiny-mlx",
            "mlx-community/whisper-base-mlx", 
            "mlx-community/whisper-small-mlx",
            "whisper-tiny-mlx",
            "whisper-base-mlx"
        ]
        
        for modelName in mlxModelPatterns {
            let detectedType = await factory.getProviderTypeForModel(modelName)
            #expect(detectedType == .mlx, "Model '\(modelName)' should be detected as MLX provider type")
        }
    }
    
    @Test(.serialized)
    func testMLXProviderFactoryIntegration() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let mlxProvider = MLXProvider()
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let isRegistered = await factory.isProviderRegistered(.mlx)
        #expect(isRegistered == true, "MLX provider should be registered")
        
        let provider = try await factory.getProviderForModel("mlx-community/whisper-tiny-mlx")
        let isMLXProvider = type(of: provider) == MLXProvider.self
        #expect(isMLXProvider == true, "Should return MLXProvider for MLX model")
    }
    
    // Additional tests would be uncommented here...
    */
}

/// MockMLXProvider declaration removed to avoid duplicate declarations.
/// This is expected for TDD RED phase - the real MLXProvider doesn't exist yet.
/// When implementing MLXProvider, use the MockMLXProvider from TranscriptionClientProviderTests.swift
/// or create a shared mock in a common test utilities file.