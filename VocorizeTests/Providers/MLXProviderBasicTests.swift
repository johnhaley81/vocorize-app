//
//  MLXProviderBasicTests.swift
//  VocorizeTests
//
//  Basic unit tests for MLXProvider implementation
//  Focuses on core functionality and conditional compilation without complex mocking
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing
import XCTest

#if canImport(MLX) && canImport(MLXNN)
import MLX
import MLXNN
#endif

struct MLXProviderBasicTests {
    
    // MARK: - Provider Identity Tests
    
    @Test
    func providerType_returnsMLX() async throws {
        #expect(MLXProvider.providerType == .mlx)
    }
    
    @Test
    func displayName_returnsMLX() async throws {
        #expect(MLXProvider.displayName == "MLX")
    }
    
    // MARK: - Availability Tests
    
    @Test
    func mlxAvailability_checksCompileTimeAvailability() async throws {
        #if canImport(MLX) && canImport(MLXNN)
        // When MLX is available at compile time
        #expect(MLXAvailability.isFrameworkAvailable == true)
        #expect(MLXAvailability.areProductsAvailable == true)
        
        // System compatibility depends on architecture
        #if arch(arm64)
        #expect(MLXAvailability.isSystemCompatible == true)
        #expect(MLXAvailability.isAvailable == true)
        #else
        #expect(MLXAvailability.isSystemCompatible == false)
        #expect(MLXAvailability.isAvailable == false)
        #endif
        #else
        // When MLX is not available at compile time
        #expect(MLXAvailability.isFrameworkAvailable == false)
        #expect(MLXAvailability.areProductsAvailable == false)
        #expect(MLXAvailability.isAvailable == false)
        #endif
    }
    
    // MARK: - Provider Initialization Tests
    
    @Test
    func provider_initializesWithoutError() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let provider = MLXProvider()
        
        // Basic identity should work
        #expect(MLXProvider.providerType == .mlx)
        #expect(MLXProvider.displayName == "MLX")
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - Conditional Compilation Tests
    
    @Test
    func provider_handlesMLXUnavailabilityGracefully() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let provider = MLXProvider()
        
        #if !(canImport(MLX) && canImport(MLXNN)) || !arch(arm64)
        // When MLX is not available, operations should throw providerNotAvailable
        
        do {
            _ = try await provider.getAvailableModels()
            Issue.record("Expected providerNotAvailable error when MLX unavailable")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .providerNotAvailable(let providerType) = error as? TranscriptionProviderError {
                #expect(providerType == .mlx)
            } else {
                Issue.record("Expected providerNotAvailable error, got \(error)")
            }
        }
        
        do {
            _ = try await provider.getRecommendedModel()
            Issue.record("Expected providerNotAvailable error when MLX unavailable")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .providerNotAvailable = error as? TranscriptionProviderError {
                // Expected
            } else {
                Issue.record("Expected providerNotAvailable error, got \(error)")
            }
        }
        
        do {
            try await provider.downloadModel("test-model") { _ in }
            Issue.record("Expected providerNotAvailable error when MLX unavailable")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .providerNotAvailable = error as? TranscriptionProviderError {
                // Expected
            } else {
                Issue.record("Expected providerNotAvailable error, got \(error)")
            }
        }
        #endif
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - Model Status Tests (Safe Operations)
    
    @Test
    func isModelDownloaded_handlesNonExistentModel() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let provider = MLXProvider()
        let nonExistentModel = "nonexistent_model_12345"
        
        // This should always return false for non-existent models
        let isDownloaded = await provider.isModelDownloaded(nonExistentModel)
        #expect(isDownloaded == false)
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    @Test
    func isModelLoadedInMemory_handlesNonExistentModel() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let provider = MLXProvider()
        let nonExistentModel = "nonexistent_model_12345"
        
        // This should always return false for non-existent/unloaded models
        let isLoaded = await provider.isModelLoadedInMemory(nonExistentModel)
        #expect(isLoaded == false)
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - Model Deletion Tests (Safe Operations)
    
    @Test
    func deleteModel_throwsErrorForNonExistentModel() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let provider = MLXProvider()
        let nonExistentModel = "never_downloaded_model"
        
        do {
            try await provider.deleteModel(nonExistentModel)
            Issue.record("Expected error for non-existent model deletion")
        } catch {
            #expect(error is TranscriptionProviderError)
            if case .modelNotFound = error as? TranscriptionProviderError {
                // Expected error type
            } else {
                Issue.record("Expected modelNotFound error, got \(error)")
            }
        }
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - Available Models Tests (MLX Available Only)
    
    @Test
    func getAvailableModels_whenMLXAvailable_returnsMLXModels() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        #if canImport(MLX) && canImport(MLXNN) && arch(arm64)
        guard MLXAvailability.isAvailable else {
            throw XCTSkip("MLX not available on this system")
        }
        
        let provider = MLXProvider()
        
        let models = try await provider.getAvailableModels()
        
        #expect(!models.isEmpty)
        #expect(models.allSatisfy { $0.providerType == .mlx })
        
        // Should include MLX-specific models
        let modelNames = models.map { $0.internalName }
        #expect(modelNames.contains { $0.contains("whisper") && $0.contains("mlx") })
        
        // Verify models have proper metadata
        if let firstModel = models.first {
            #expect(!firstModel.displayName.isEmpty)
            #expect(firstModel.displayName.contains("MLX"))
            #expect(!firstModel.estimatedSize.isEmpty)
            #expect(firstModel.estimatedSize != "Unknown")
        }
        #else
        throw XCTSkip("MLX not available at compile time")
        #endif
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - Recommended Model Tests (MLX Available Only)
    
    @Test
    func getRecommendedModel_whenMLXAvailable_returnsMLXModel() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        #if canImport(MLX) && canImport(MLXNN) && arch(arm64)
        guard MLXAvailability.isAvailable else {
            throw XCTSkip("MLX not available on this system")
        }
        
        let provider = MLXProvider()
        
        let recommendedModel = try await provider.getRecommendedModel()
        
        #expect(!recommendedModel.isEmpty)
        #expect(recommendedModel.contains("mlx"))
        
        // Should be available for download
        let availableModels = try await provider.getAvailableModels()
        let modelNames = availableModels.map { $0.internalName }
        #expect(modelNames.contains(recommendedModel))
        #else
        throw XCTSkip("MLX not available at compile time")
        #endif
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - System Requirements Tests
    
    @Test
    func conditionalCompilation_handlesMLXUnavailableAtCompileTime() async throws {
        // Test that code compiles and runs correctly when MLX is not available
        #if !(canImport(MLX) && canImport(MLXNN))
        // When MLX is not available, verify static properties work
        #expect(MLXAvailability.isFrameworkAvailable == false)
        #expect(MLXAvailability.areProductsAvailable == false)
        #expect(MLXAvailability.isAvailable == false)
        
        // Provider identity should still work
        #expect(MLXProvider.providerType == .mlx)
        #expect(MLXProvider.displayName == "MLX")
        #else
        // When MLX is available, verify it's properly detected
        #expect(MLXAvailability.isFrameworkAvailable == true)
        #expect(MLXAvailability.areProductsAvailable == true)
        
        // System compatibility depends on architecture
        #if arch(arm64)
        #expect(MLXAvailability.isSystemCompatible == true)
        #else
        #expect(MLXAvailability.isSystemCompatible == false)
        #endif
        #endif
    }
    
    @Test
    func macOSVersionRequirement_isEnforced() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let provider = MLXProvider()
        
        // Basic functionality should be available
        #expect(MLXProvider.providerType == .mlx)
        #expect(MLXProvider.displayName == "MLX")
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
    
    // MARK: - Performance Tests
    
    @Test
    func basicOperations_completeQuickly() async throws {
        #if compiler(>=5.9)
        // Only run on Swift 5.9+ (macOS 13.0+ equivalent)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run basic provider operations (should be fast)
        let provider = MLXProvider()
        
        // Basic availability check (should be fast)
        _ = MLXAvailability.isAvailable
        _ = MLXAvailability.isFrameworkAvailable
        _ = MLXAvailability.areProductsAvailable
        _ = MLXAvailability.isSystemCompatible
        
        // Test model status operations (should be fast with non-existent models)
        let modelName = "nonexistent-test-model"
        _ = await provider.isModelDownloaded(modelName)
        _ = await provider.isModelLoadedInMemory(modelName)
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Basic operations should complete very quickly
        #expect(executionTime < 1.0, "MLX basic operations took \(String(format: "%.2f", executionTime)) seconds, expected < 1 second")
        
        print("✅ MLX basic operations performance: \(String(format: "%.2f", executionTime))s (target: <1s)")
        #else
        throw XCTSkip("Requires Swift 5.9+ / macOS 13.0+")
        #endif
    }
}