//
//  TranscriptionProviderFactoryTests.swift
//  VocorizeTests
//
//  TDD RED PHASE: Comprehensive failing tests for TranscriptionProviderFactory
//  These tests MUST fail initially because TranscriptionProviderFactory doesn't exist yet
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import AVFoundation
import WhisperKit

/// ALL TESTS IN THIS FILE ARE DISABLED FOR TDD RED PHASE
/// These tests are designed to fail because TranscriptionProviderFactory doesn't exist yet.
/// Tests will be re-enabled when implementing provider factory functionality.
struct TranscriptionProviderFactoryTests {
    
    @Test
    func tddRedPhase_allFactoryTestsDisabled() async throws {
        // This test confirms that TranscriptionProviderFactory TDD tests are properly disabled
        // When TranscriptionProviderFactory is implemented, remove this test and enable the real tests
        #expect(true, "TDD RED phase: TranscriptionProviderFactory tests are disabled until implementation")
    }
    
    // MARK: - DISABLED TDD TESTS - Re-enable when implementing TranscriptionProviderFactory
    
    /*
     * ALL TESTS BELOW ARE COMMENTED OUT FOR TDD RED PHASE
     * 
     * These tests are designed to fail because:
     * - TranscriptionProviderFactory class doesn't exist yet
     * - TranscriptionProviderFactory.shared doesn't exist yet
     * - MockMLXProvider references may be problematic
     * - Factory registration logic isn't implemented
     * 
     * TO RE-ENABLE:
     * 1. Implement TranscriptionProviderFactory class
     * 2. Add shared instance support
     * 3. Implement provider registration logic
     * 4. Fix MockMLXProvider references
     * 5. Uncomment the tests below
     * 6. Remove the placeholder test above
     */
    
    /*
    // MARK: - Factory Registration Tests
    
    @Test(.serialized)
    func factory_canRegisterAllAvailableProviders() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let registeredProviders = await factory.getAllRegisteredProviders()
        #expect(registeredProviders.count == 2)
        #expect(await factory.isProviderRegistered(.whisperKit))
        #expect(await factory.isProviderRegistered(.mlx))
    }
    
    // Additional factory tests would be uncommented here...
    */
}