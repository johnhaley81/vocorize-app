//
//  MLXProviderRegistrationTests.swift
//  VocorizeTests
//
//  Tests for MLX provider registration and basic functionality
//

import Foundation
@testable import Vocorize
import Testing

/// Tests for MLXProvider registration and protocol conformance
struct MLXProviderRegistrationTests {

    // MARK: - MLX Provider Creation Tests

    @Test
    func testMLXProviderProtocolConformance() async throws {
        let provider = MLXProvider()

        #expect(MLXProvider.providerType == .mlx, "MLXProvider should have .mlx provider type")
        #expect(MLXProvider.displayName == "MLX Whisper", "MLXProvider should have 'MLX Whisper' display name")

        // Verify actor conformance
        let providerAny: any TranscriptionProvider = provider
        #expect(type(of: providerAny).providerType == .mlx)
    }

    @Test
    func testMLXProviderTypeEnumeration() async throws {
        #expect(TranscriptionProviderType.mlx.rawValue == "mlx")
        #expect(TranscriptionProviderType.mlx.displayName == "MLX")

        // Verify all cases
        let allCases = TranscriptionProviderType.allCases
        #expect(allCases.contains(.mlx))
        #expect(allCases.contains(.whisperKit))
    }

    // MARK: - Provider Factory Registration Tests

    @Test(.serialized)
    func testMLXModelRoutingLogic() async throws {
        let factory = TranscriptionProviderFactory()

        // Test MLX model pattern detection
        let mlxModelPatterns = [
            "mlx-community/whisper-tiny",
            "mlx-community/whisper-base",
            "mlx-community/whisper-small",
            "mlx-community/whisper-large-v3-turbo",
            "mlx-whisper-tiny",
            "whisper-base-mlx"
        ]

        for modelName in mlxModelPatterns {
            let detectedType = await factory.getProviderTypeForModel(modelName)
            #expect(detectedType == .mlx, "Model '\(modelName)' should be detected as MLX provider type")
        }
    }

    @Test(.serialized)
    func testWhisperKitModelRoutingLogic() async throws {
        let factory = TranscriptionProviderFactory()

        // Test WhisperKit model pattern detection
        let whisperKitPatterns = [
            "openai_whisper-tiny",
            "openai_whisper-base",
            "whisper-large-v3"
        ]

        for modelName in whisperKitPatterns {
            let detectedType = await factory.getProviderTypeForModel(modelName)
            #expect(detectedType == .whisperKit, "Model '\(modelName)' should be detected as WhisperKit provider type")
        }
    }

    @Test(.serialized)
    func testMLXProviderFactoryIntegration() async throws {
        let factory = TranscriptionProviderFactory()
        await factory.clear()

        let mlxProvider = MLXProvider()
        await factory.registerProvider(mlxProvider, for: .mlx)

        let isRegistered = await factory.isProviderRegistered(.mlx)
        #expect(isRegistered == true, "MLX provider should be registered")

        let provider = try await factory.getProviderForModel("mlx-community/whisper-tiny")
        #expect(type(of: provider).providerType == .mlx, "Should return MLXProvider for MLX model")
    }

    @Test(.serialized)
    func testBothProvidersCanBeRegistered() async throws {
        let factory = TranscriptionProviderFactory()
        await factory.clear()

        let whisperKitProvider = WhisperKitProvider()
        let mlxProvider = MLXProvider()

        await factory.registerProvider(whisperKitProvider, for: .whisperKit)
        await factory.registerProvider(mlxProvider, for: .mlx)

        let registeredCount = await factory.getRegisteredProviderCount()
        #expect(registeredCount == 2, "Both providers should be registered")

        let isWhisperKitRegistered = await factory.isProviderRegistered(.whisperKit)
        let isMLXRegistered = await factory.isProviderRegistered(.mlx)

        #expect(isWhisperKitRegistered == true)
        #expect(isMLXRegistered == true)
    }

    // MARK: - MLX Provider Available Models Tests

    @Test
    func testMLXProviderAvailableModels() async throws {
        let provider = MLXProvider()

        let availableModels = try await provider.getAvailableModels()

        #expect(!availableModels.isEmpty, "MLX provider should return available models")

        // Check that all returned models are MLX type
        for model in availableModels {
            #expect(model.providerType == .mlx, "All models should be MLX type")
        }

        // Check for expected model names
        let modelNames = availableModels.map { $0.internalName }
        #expect(modelNames.contains("mlx-community/whisper-large-v3-turbo"), "Should include large v3 turbo")
    }

    @Test
    func testMLXProviderRecommendedModel() async throws {
        let provider = MLXProvider()

        let recommendedModel = try await provider.getRecommendedModel()

        #expect(recommendedModel == "mlx-community/whisper-large-v3-turbo", "Recommended model should be large v3 turbo")
    }

    // MARK: - Model Download Status Tests

    @Test
    func testMLXProviderModelNotDownloaded() async throws {
        let provider = MLXProvider()

        // A model that definitely won't be downloaded
        let isDownloaded = await provider.isModelDownloaded("mlx-community/nonexistent-model")

        #expect(isDownloaded == false, "Nonexistent model should not be marked as downloaded")
    }

    // MARK: - MLX Availability Integration Tests

    @Test
    func testMLXAvailabilityCheck() async throws {
        // These tests verify the MLX availability infrastructure works
        let isFrameworkAvailable = MLXAvailability.isFrameworkAvailable
        let areProductsAvailable = MLXAvailability.areProductsAvailable
        let isSystemCompatible = MLXAvailability.isSystemCompatible

        // Log availability status
        print("MLX Framework Available: \(isFrameworkAvailable)")
        print("MLX Products Available: \(areProductsAvailable)")
        print("System Compatible: \(isSystemCompatible)")

        // The overall availability should match individual checks
        let overallAvailable = MLXAvailability.isAvailable
        let expectedAvailable = isFrameworkAvailable && areProductsAvailable && isSystemCompatible

        #expect(overallAvailable == expectedAvailable, "Overall availability should match individual checks")
    }

    @Test
    func testMLXCompatibilityInfo() async throws {
        let compatInfo = MLXAvailability.compatibilityInfo

        #expect(compatInfo["framework_available"] != nil)
        #expect(compatInfo["products_available"] != nil)
        #expect(compatInfo["system_compatible"] != nil)
        #expect(compatInfo["architecture"] != nil)
    }
}

// MARK: - MLX Whisper Config Tests

struct MLXWhisperConfigTests {

    @Test
    func testDefaultConfigValues() async throws {
        let config = MLXWhisperConfig()

        #expect(config.numEncoderLayers == 12)
        #expect(config.numDecoderLayers == 12)
        #expect(config.modelDim == 768)
        #expect(config.vocabSize == 51865)
        #expect(config.numMels == 128)
    }

    @Test
    func testLargeV3TurboConfig() async throws {
        let config = MLXWhisperConfig.largev3turbo

        #expect(config.numEncoderLayers == 32)
        #expect(config.numDecoderLayers == 4)  // Turbo has fewer decoder layers
        #expect(config.modelDim == 1280)
        #expect(config.numAttentionHeads == 20)
    }

    @Test
    func testTinyConfig() async throws {
        let config = MLXWhisperConfig.tiny

        #expect(config.numEncoderLayers == 4)
        #expect(config.numDecoderLayers == 4)
        #expect(config.modelDim == 384)
        #expect(config.numAttentionHeads == 6)
    }

    @Test
    func testConfigJsonDecoding() async throws {
        let jsonString = """
        {
            "encoder_layers": 6,
            "decoder_layers": 6,
            "d_model": 512,
            "vocab_size": 51865
        }
        """

        let data = jsonString.data(using: .utf8)!
        let config = try JSONDecoder().decode(MLXWhisperConfig.self, from: data)

        #expect(config.numEncoderLayers == 6)
        #expect(config.numDecoderLayers == 6)
        #expect(config.modelDim == 512)
    }
}

// MARK: - MLX Decoding Options Tests

struct MLXDecodingOptionsTests {

    @Test
    func testDefaultOptions() async throws {
        let options = MLXDecodingOptions.default

        #expect(options.language == nil)
        #expect(options.translate == false)
        #expect(options.withTimestamps == false)
        #expect(options.temperature == 0.0)
        #expect(options.beamSize == 1)
    }

    @Test
    func testCustomOptions() async throws {
        let options = MLXDecodingOptions(
            language: "en",
            translate: true,
            withTimestamps: true,
            temperature: 0.5,
            beamSize: 5
        )

        #expect(options.language == "en")
        #expect(options.translate == true)
        #expect(options.withTimestamps == true)
        #expect(options.temperature == 0.5)
        #expect(options.beamSize == 5)
    }
}

// MARK: - MLX Audio Processor Tests

struct MLXAudioProcessorTests {

    @Test
    func testAudioProcessorInitialization() async throws {
        let processor = MLXAudioProcessor()

        // Verify constants
        #expect(MLXAudioProcessor.sampleRate == 16000.0)
        #expect(MLXAudioProcessor.nFFT == 400)
        #expect(MLXAudioProcessor.hopLength == 160)
        #expect(MLXAudioProcessor.nMels == 128)
    }

    @Test
    func testAudioProcessorConstants() async throws {
        #expect(MLXWhisperAudioConstants.sampleRate == 16000)
        #expect(MLXWhisperAudioConstants.nFFT == 400)
        #expect(MLXWhisperAudioConstants.hopLength == 160)
        #expect(MLXWhisperAudioConstants.chunkLength == 30)
        #expect(MLXWhisperAudioConstants.nSamplesPerChunk == 480000)
    }
}

// MARK: - MLX Tokenizer Tests

struct MLXWhisperTokenizerTests {

    @Test
    func testTokenizerInitialization() async throws {
        let config = MLXWhisperConfig()
        let tokenizer = MLXWhisperTokenizer(config: config)

        #expect(tokenizer.eotToken == config.eotToken)
        #expect(tokenizer.sotToken == config.sotToken)
        #expect(tokenizer.transcribeToken == config.transcribeToken)
    }

    @Test
    func testLanguageTokenMapping() async throws {
        let config = MLXWhisperConfig()
        let tokenizer = MLXWhisperTokenizer(config: config)

        // Test common language codes
        let englishToken = tokenizer.languageToken(for: "en")
        let spanishToken = tokenizer.languageToken(for: "es")
        let frenchToken = tokenizer.languageToken(for: "fr")

        #expect(englishToken != nil, "English should have a token")
        #expect(spanishToken != nil, "Spanish should have a token")
        #expect(frenchToken != nil, "French should have a token")

        // Tokens should be different
        #expect(englishToken != spanishToken)
        #expect(spanishToken != frenchToken)
    }

    @Test
    func testInitialTokensGeneration() async throws {
        let config = MLXWhisperConfig()
        let tokenizer = MLXWhisperTokenizer(config: config)

        let tokens = tokenizer.getInitialTokens(language: "en", task: "transcribe")

        #expect(!tokens.isEmpty, "Should generate initial tokens")
        #expect(tokens.first == tokenizer.sotToken, "First token should be SOT")
        #expect(tokens.contains(tokenizer.transcribeToken), "Should contain transcribe token")
    }

    @Test
    func testTranslateTaskTokens() async throws {
        let config = MLXWhisperConfig()
        let tokenizer = MLXWhisperTokenizer(config: config)

        let tokens = tokenizer.getInitialTokens(language: "es", task: "translate")

        #expect(tokens.contains(tokenizer.translateToken), "Should contain translate token for translate task")
        #expect(!tokens.contains(tokenizer.transcribeToken), "Should not contain transcribe token for translate task")
    }
}
