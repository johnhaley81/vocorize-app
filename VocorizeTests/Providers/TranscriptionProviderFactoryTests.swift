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

struct TranscriptionProviderFactoryTests {
    
    // MARK: - Factory Registration Tests
    
    @Test(.serialized)
    func factory_canRegisterAllAvailableProviders() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let registeredTypes = await factory.getAllRegisteredProviderTypes()
        let registeredCount = await factory.getRegisteredProviderCount()
        
        #expect(registeredCount == 2)
        #expect(registeredTypes.contains(.whisperKit))
        #expect(registeredTypes.contains(.mlx))
        #expect(registeredTypes.count == 2)
    }
    
    @Test(.serialized)
    func factory_canDetermineCorrectProviderForModelName() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        // Test WhisperKit model names
        let whisperModelProvider = try await factory.getProviderForModel("openai_whisper-tiny")
        let whisperBaseProvider = try await factory.getProviderForModel("openai_whisper-base")
        let whisperLargeProvider = try await factory.getProviderForModel("openai_whisper-large-v3-v20240930")
        
        #expect(type(of: whisperModelProvider) == MockTranscriptionProvider.self)
        #expect(type(of: whisperBaseProvider) == MockTranscriptionProvider.self)
        #expect(type(of: whisperLargeProvider) == MockTranscriptionProvider.self)
    }
    
    @Test(.serialized)
    func factory_returnsWhisperKitProviderForWhisperKitModels() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        let whisperKitModels = [
            "openai_whisper-tiny",
            "openai_whisper-base", 
            "openai_whisper-small",
            "openai_whisper-medium",
            "openai_whisper-large-v3-v20240930",
            "openai_whisper-large-v2",
            "whisper-tiny.en",
            "whisper-base.en"
        ]
        
        for modelName in whisperKitModels {
            let provider = try await factory.getProviderForModel(modelName)
            #expect(type(of: provider) == MockTranscriptionProvider.self)
            
            let providerType = await factory.getProviderTypeForModel(modelName)
            #expect(providerType == .whisperKit)
        }
    }
    
    @Test(.serialized)
    func factory_returnsMLXProviderForMLXModels() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let mlxProvider = MockMLXProvider()
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let mlxModels = [
            "mlx-community/whisper-tiny-mlx",
            "mlx-community/whisper-base-mlx",
            "mlx-community/whisper-small-mlx",
            "mlx-community/whisper-medium-mlx", 
            "mlx-community/whisper-large-v3-mlx",
            "mlx-whisper-tiny",
            "mlx-whisper-base"
        ]
        
        for modelName in mlxModels {
            let provider = try await factory.getProviderForModel(modelName)
            #expect(type(of: provider) == MockMLXProvider.self)
            
            let providerType = await factory.getProviderTypeForModel(modelName)
            #expect(providerType == .mlx)
        }
    }
    
    @Test(.serialized)
    func factory_handlesUnknownModelNamesGracefully() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        let unknownModelNames = [
            "unknown-model",
            "custom-transcription-model",
            "invalid_model_name",
            "",
            "   ",
            "some-random-model-v2"
        ]
        
        for modelName in unknownModelNames {
            await #expect(throws: TranscriptionProviderFactoryError.modelNotSupported(modelName)) {
                try await factory.getProviderForModel(modelName)
            }
            
            let providerType = await factory.getProviderTypeForModel(modelName)
            #expect(providerType == nil)
        }
    }
    
    @Test(.serialized)
    func factory_canProvideListOfAllRegisteredProviders() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        // Initially empty
        let initialProviders = await factory.getAllRegisteredProviders()
        #expect(initialProviders.isEmpty)
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let allProviders = await factory.getAllRegisteredProviders()
        let providerTypes = await factory.getAllRegisteredProviderTypes()
        
        #expect(allProviders.count == 2)
        #expect(providerTypes.count == 2)
        #expect(providerTypes.contains(.whisperKit))
        #expect(providerTypes.contains(.mlx))
        
        // Should be sorted by provider type for consistency
        #expect(providerTypes == [.mlx, .whisperKit])
    }
    
    // MARK: - Singleton Pattern Tests
    
    @Test
    func factory_singletonSharedInstanceWorksCorrectly() {
        let factory1 = TranscriptionProviderFactory.shared
        let factory2 = TranscriptionProviderFactory.shared
        
        // Should be the same instance
        #expect(factory1 === factory2)
    }
    
    @Test(.serialized)
    func factory_sharedInstanceMaintainsStateAcrossAccesses() async {
        let factory1 = TranscriptionProviderFactory.shared
        await factory1.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        await factory1.registerProvider(whisperProvider, for: .whisperKit)
        
        let factory2 = TranscriptionProviderFactory.shared
        let count = await factory2.getRegisteredProviderCount()
        let isRegistered = await factory2.isProviderRegistered(.whisperKit)
        
        #expect(count == 1)
        #expect(isRegistered == true)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test(.serialized)
    func factory_providerRegistrationIsThreadSafe() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        // Simulate concurrent registration from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let provider = MockTranscriptionProvider()
                    await factory.registerProvider(provider, for: .whisperKit)
                }
            }
            
            for i in 0..<10 {
                group.addTask {
                    let provider = MockMLXProvider()
                    await factory.registerProvider(provider, for: .mlx)
                }
            }
        }
        
        let finalCount = await factory.getRegisteredProviderCount()
        let registeredTypes = await factory.getAllRegisteredProviderTypes()
        
        // Should have both types registered despite concurrent access
        #expect(finalCount == 2)
        #expect(registeredTypes.contains(.whisperKit))
        #expect(registeredTypes.contains(.mlx))
    }
    
    @Test(.serialized)
    func factory_concurrentModelLookupIsThreadSafe() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        // Simulate concurrent model lookups
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    do {
                        let provider = try await factory.getProviderForModel("openai_whisper-tiny")
                        let isWhisperKit = type(of: provider) == MockTranscriptionProvider.self
                        #expect(isWhisperKit)
                    } catch {
                        #expect(Bool(false), "Unexpected error: \(error)")
                    }
                }
                
                group.addTask {
                    do {
                        let provider = try await factory.getProviderForModel("mlx-community/whisper-base-mlx")
                        let isMLX = type(of: provider) == MockMLXProvider.self
                        #expect(isMLX)
                    } catch {
                        #expect(Bool(false), "Unexpected error: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Provider Unregistration Tests
    
    @Test(.serialized)
    func factory_canUnregisterProviders() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let initialCount = await factory.getRegisteredProviderCount()
        #expect(initialCount == 2)
        
        await factory.unregisterProvider(.whisperKit)
        
        let finalCount = await factory.getRegisteredProviderCount()
        let isWhisperKitRegistered = await factory.isProviderRegistered(.whisperKit)
        let isMLXRegistered = await factory.isProviderRegistered(.mlx)
        
        #expect(finalCount == 1)
        #expect(isWhisperKitRegistered == false)
        #expect(isMLXRegistered == true)
    }
    
    @Test(.serialized)
    func factory_unregisteringNonExistentProviderDoesNothing() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        // Try to unregister when nothing is registered
        await factory.unregisterProvider(.whisperKit)
        
        let count = await factory.getRegisteredProviderCount()
        #expect(count == 0)
        
        // Register one provider and try to unregister a different one
        let whisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        await factory.unregisterProvider(.mlx)
        
        let finalCount = await factory.getRegisteredProviderCount()
        let isWhisperKitRegistered = await factory.isProviderRegistered(.whisperKit)
        
        #expect(finalCount == 1)
        #expect(isWhisperKitRegistered == true)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test(.serialized)
    func factory_providesCorrectProviderForEdgeCases() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        // Edge case model names that should work
        let edgeCaseModels = [
            ("openai_whisper-tiny.en", TranscriptionProviderType.whisperKit),
            ("openai_whisper-base.en", TranscriptionProviderType.whisperKit),
            ("mlx-community/whisper-large-v3-mlx-q4", TranscriptionProviderType.mlx),
            ("whisper-small", TranscriptionProviderType.whisperKit),
            ("mlx-whisper-medium", TranscriptionProviderType.mlx)
        ]
        
        for (modelName, expectedType) in edgeCaseModels {
            let provider = try await factory.getProviderForModel(modelName)
            let actualType = await factory.getProviderTypeForModel(modelName)
            
            #expect(actualType == expectedType)
            
            switch expectedType {
            case .whisperKit:
                #expect(type(of: provider) == MockTranscriptionProvider.self)
            case .mlx:
                #expect(type(of: provider) == MockMLXProvider.self)
            }
        }
    }
    
    @Test(.serialized)
    func factory_throwsWhenProviderNotRegisteredForModel() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        // Only register WhisperKit provider
        let whisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        // Try to get MLX provider for MLX model
        await #expect(throws: TranscriptionProviderFactoryError.providerNotRegistered(.mlx)) {
            try await factory.getProviderForModel("mlx-community/whisper-tiny-mlx")
        }
    }
    
    @Test(.serialized)
    func factory_handlesModelNameCaseInsensitivity() async throws {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        let caseVariations = [
            "openai_whisper-tiny",
            "OPENAI_WHISPER-TINY",
            "OpenAI_Whisper-Tiny",
            "openai_WHISPER-tiny"
        ]
        
        for modelName in caseVariations {
            let provider = try await factory.getProviderForModel(modelName)
            let providerType = await factory.getProviderTypeForModel(modelName)
            
            #expect(type(of: provider) == MockTranscriptionProvider.self)
            #expect(providerType == .whisperKit)
        }
    }
    
    @Test(.serialized)
    func factory_canClearAllRegisteredProviders() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperProvider = MockTranscriptionProvider()
        let mlxProvider = MockMLXProvider()
        
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        let initialCount = await factory.getRegisteredProviderCount()
        #expect(initialCount == 2)
        
        await factory.clear()
        
        let finalCount = await factory.getRegisteredProviderCount()
        let registeredTypes = await factory.getAllRegisteredProviderTypes()
        
        #expect(finalCount == 0)
        #expect(registeredTypes.isEmpty)
    }
    
    @Test(.serialized)
    func factory_canOverrideExistingProviderRegistration() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let firstWhisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(firstWhisperProvider, for: .whisperKit)
        
        let count1 = await factory.getRegisteredProviderCount()
        #expect(count1 == 1)
        
        // Register a different provider for the same type
        let secondWhisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(secondWhisperProvider, for: .whisperKit)
        
        let count2 = await factory.getRegisteredProviderCount()
        #expect(count2 == 1) // Should still be 1, just overridden
        
        let isRegistered = await factory.isProviderRegistered(.whisperKit)
        #expect(isRegistered == true)
    }
    
    // MARK: - Model Pattern Matching Tests
    
    @Test(.serialized)
    func factory_correctlyIdentifiesWhisperKitPatterns() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let whisperKitPatterns = [
            "openai_whisper-tiny",
            "openai_whisper-base",
            "openai_whisper-small",
            "openai_whisper-medium", 
            "openai_whisper-large",
            "openai_whisper-large-v2",
            "openai_whisper-large-v3",
            "openai_whisper-large-v3-v20240930",
            "whisper-tiny",
            "whisper-base",
            "whisper-small.en",
            "whisper-medium.en",
            "whisper-large-v2.en"
        ]
        
        for pattern in whisperKitPatterns {
            let detectedType = await factory.getProviderTypeForModel(pattern)
            #expect(detectedType == .whisperKit, "Pattern '\(pattern)' should be detected as WhisperKit")
        }
    }
    
    @Test(.serialized)
    func factory_correctlyIdentifiesMLXPatterns() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        let mlxPatterns = [
            "mlx-community/whisper-tiny-mlx",
            "mlx-community/whisper-base-mlx",
            "mlx-community/whisper-small-mlx",
            "mlx-community/whisper-medium-mlx",
            "mlx-community/whisper-large-mlx",
            "mlx-community/whisper-large-v2-mlx",
            "mlx-community/whisper-large-v3-mlx",
            "mlx-whisper-tiny",
            "mlx-whisper-base",
            "mlx-whisper-small",
            "whisper-tiny-mlx",
            "whisper-base-mlx"
        ]
        
        for pattern in mlxPatterns {
            let detectedType = await factory.getProviderTypeForModel(pattern)
            #expect(detectedType == .mlx, "Pattern '\(pattern)' should be detected as MLX")
        }
    }
    
    // MARK: - Factory State Inspection Tests
    
    @Test(.serialized)
    func factory_providesAccurateStateInspection() async {
        let factory = TranscriptionProviderFactory.shared
        await factory.clear()
        
        // Initial state
        #expect(await factory.getRegisteredProviderCount() == 0)
        #expect(await factory.getAllRegisteredProviderTypes().isEmpty)
        #expect(await factory.isProviderRegistered(.whisperKit) == false)
        #expect(await factory.isProviderRegistered(.mlx) == false)
        
        // After registering WhisperKit
        let whisperProvider = MockTranscriptionProvider()
        await factory.registerProvider(whisperProvider, for: .whisperKit)
        
        #expect(await factory.getRegisteredProviderCount() == 1)
        #expect(await factory.getAllRegisteredProviderTypes() == [.whisperKit])
        #expect(await factory.isProviderRegistered(.whisperKit) == true)
        #expect(await factory.isProviderRegistered(.mlx) == false)
        
        // After registering MLX
        let mlxProvider = MockMLXProvider()
        await factory.registerProvider(mlxProvider, for: .mlx)
        
        #expect(await factory.getRegisteredProviderCount() == 2)
        #expect(await factory.getAllRegisteredProviderTypes().count == 2)
        #expect(await factory.isProviderRegistered(.whisperKit) == true)
        #expect(await factory.isProviderRegistered(.mlx) == true)
    }
}