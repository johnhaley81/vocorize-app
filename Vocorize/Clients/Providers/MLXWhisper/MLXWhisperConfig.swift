//
//  MLXWhisperConfig.swift
//  Vocorize
//
//  Configuration structures for MLX Whisper models
//

import Foundation

/// Configuration for MLX Whisper model architecture
public struct MLXWhisperConfig: Codable {
    /// Number of audio encoder layers
    public let numEncoderLayers: Int

    /// Number of text decoder layers
    public let numDecoderLayers: Int

    /// Number of attention heads
    public let numAttentionHeads: Int

    /// Model dimension (hidden size)
    public let modelDim: Int

    /// Feed-forward dimension (intermediate size)
    public let ffnDim: Int

    /// Vocabulary size
    public let vocabSize: Int

    /// Maximum audio context length (in frames)
    public let maxAudioCtx: Int

    /// Maximum text context length (tokens)
    public let maxTextCtx: Int

    /// Number of mel frequency bins
    public let numMels: Int

    /// Encoder attention heads (may differ from decoder)
    public let encoderAttentionHeads: Int

    /// Decoder attention heads
    public let decoderAttentionHeads: Int

    // Special token IDs
    public let eotToken: Int
    public let sotToken: Int
    public let translateToken: Int
    public let transcribeToken: Int
    public let noSpeechToken: Int
    public let noTimestampsToken: Int
    public let langTokenOffset: Int

    enum CodingKeys: String, CodingKey {
        case numEncoderLayers = "encoder_layers"
        case numDecoderLayers = "decoder_layers"
        case numAttentionHeads = "num_attention_heads"
        case modelDim = "d_model"
        case ffnDim = "encoder_ffn_dim"
        case vocabSize = "vocab_size"
        case maxAudioCtx = "max_source_positions"
        case maxTextCtx = "max_target_positions"
        case numMels = "num_mel_bins"
        case encoderAttentionHeads = "encoder_attention_heads"
        case decoderAttentionHeads = "decoder_attention_heads"
        case eotToken = "eos_token_id"
        case sotToken = "decoder_start_token_id"
        case translateToken = "translate_token_id"
        case transcribeToken = "transcribe_token_id"
        case noSpeechToken = "no_speech_token_id"
        case noTimestampsToken = "no_timestamps_token_id"
        case langTokenOffset = "lang_token_offset"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.numEncoderLayers = try container.decodeIfPresent(Int.self, forKey: .numEncoderLayers) ?? 12
        self.numDecoderLayers = try container.decodeIfPresent(Int.self, forKey: .numDecoderLayers) ?? 12
        self.numAttentionHeads = try container.decodeIfPresent(Int.self, forKey: .numAttentionHeads) ?? 12
        self.modelDim = try container.decodeIfPresent(Int.self, forKey: .modelDim) ?? 768
        self.ffnDim = try container.decodeIfPresent(Int.self, forKey: .ffnDim) ?? 3072
        self.vocabSize = try container.decodeIfPresent(Int.self, forKey: .vocabSize) ?? 51865
        self.maxAudioCtx = try container.decodeIfPresent(Int.self, forKey: .maxAudioCtx) ?? 1500
        self.maxTextCtx = try container.decodeIfPresent(Int.self, forKey: .maxTextCtx) ?? 448
        self.numMels = try container.decodeIfPresent(Int.self, forKey: .numMels) ?? 128
        self.encoderAttentionHeads = try container.decodeIfPresent(Int.self, forKey: .encoderAttentionHeads) ?? 12
        self.decoderAttentionHeads = try container.decodeIfPresent(Int.self, forKey: .decoderAttentionHeads) ?? 12

        // Special tokens - using Whisper defaults
        self.eotToken = try container.decodeIfPresent(Int.self, forKey: .eotToken) ?? 50257
        self.sotToken = try container.decodeIfPresent(Int.self, forKey: .sotToken) ?? 50258
        self.translateToken = try container.decodeIfPresent(Int.self, forKey: .translateToken) ?? 50358
        self.transcribeToken = try container.decodeIfPresent(Int.self, forKey: .transcribeToken) ?? 50359
        self.noSpeechToken = try container.decodeIfPresent(Int.self, forKey: .noSpeechToken) ?? 50362
        self.noTimestampsToken = try container.decodeIfPresent(Int.self, forKey: .noTimestampsToken) ?? 50363
        self.langTokenOffset = try container.decodeIfPresent(Int.self, forKey: .langTokenOffset) ?? 50259
    }

    public init(
        numEncoderLayers: Int = 12,
        numDecoderLayers: Int = 12,
        numAttentionHeads: Int = 12,
        modelDim: Int = 768,
        ffnDim: Int = 3072,
        vocabSize: Int = 51865,
        maxAudioCtx: Int = 1500,
        maxTextCtx: Int = 448,
        numMels: Int = 128,
        encoderAttentionHeads: Int = 12,
        decoderAttentionHeads: Int = 12,
        eotToken: Int = 50257,
        sotToken: Int = 50258,
        translateToken: Int = 50358,
        transcribeToken: Int = 50359,
        noSpeechToken: Int = 50362,
        noTimestampsToken: Int = 50363,
        langTokenOffset: Int = 50259
    ) {
        self.numEncoderLayers = numEncoderLayers
        self.numDecoderLayers = numDecoderLayers
        self.numAttentionHeads = numAttentionHeads
        self.modelDim = modelDim
        self.ffnDim = ffnDim
        self.vocabSize = vocabSize
        self.maxAudioCtx = maxAudioCtx
        self.maxTextCtx = maxTextCtx
        self.numMels = numMels
        self.encoderAttentionHeads = encoderAttentionHeads
        self.decoderAttentionHeads = decoderAttentionHeads
        self.eotToken = eotToken
        self.sotToken = sotToken
        self.translateToken = translateToken
        self.transcribeToken = transcribeToken
        self.noSpeechToken = noSpeechToken
        self.noTimestampsToken = noTimestampsToken
        self.langTokenOffset = langTokenOffset
    }

    /// Configuration for Whisper Large V3 Turbo
    public static var largev3turbo: MLXWhisperConfig {
        MLXWhisperConfig(
            numEncoderLayers: 32,
            numDecoderLayers: 4,
            numAttentionHeads: 20,
            modelDim: 1280,
            ffnDim: 5120,
            vocabSize: 51866,
            maxAudioCtx: 1500,
            maxTextCtx: 448,
            numMels: 128,
            encoderAttentionHeads: 20,
            decoderAttentionHeads: 20
        )
    }

    /// Configuration for Whisper Large V3
    public static var largev3: MLXWhisperConfig {
        MLXWhisperConfig(
            numEncoderLayers: 32,
            numDecoderLayers: 32,
            numAttentionHeads: 20,
            modelDim: 1280,
            ffnDim: 5120,
            vocabSize: 51866,
            maxAudioCtx: 1500,
            maxTextCtx: 448,
            numMels: 128,
            encoderAttentionHeads: 20,
            decoderAttentionHeads: 20
        )
    }

    /// Configuration for Whisper Medium
    public static var medium: MLXWhisperConfig {
        MLXWhisperConfig(
            numEncoderLayers: 24,
            numDecoderLayers: 24,
            numAttentionHeads: 16,
            modelDim: 1024,
            ffnDim: 4096,
            vocabSize: 51865,
            maxAudioCtx: 1500,
            maxTextCtx: 448,
            numMels: 128,
            encoderAttentionHeads: 16,
            decoderAttentionHeads: 16
        )
    }

    /// Configuration for Whisper Small
    public static var small: MLXWhisperConfig {
        MLXWhisperConfig(
            numEncoderLayers: 12,
            numDecoderLayers: 12,
            numAttentionHeads: 12,
            modelDim: 768,
            ffnDim: 3072,
            vocabSize: 51865,
            maxAudioCtx: 1500,
            maxTextCtx: 448,
            numMels: 128,
            encoderAttentionHeads: 12,
            decoderAttentionHeads: 12
        )
    }

    /// Configuration for Whisper Base
    public static var base: MLXWhisperConfig {
        MLXWhisperConfig(
            numEncoderLayers: 6,
            numDecoderLayers: 6,
            numAttentionHeads: 8,
            modelDim: 512,
            ffnDim: 2048,
            vocabSize: 51865,
            maxAudioCtx: 1500,
            maxTextCtx: 448,
            numMels: 128,
            encoderAttentionHeads: 8,
            decoderAttentionHeads: 8
        )
    }

    /// Configuration for Whisper Tiny
    public static var tiny: MLXWhisperConfig {
        MLXWhisperConfig(
            numEncoderLayers: 4,
            numDecoderLayers: 4,
            numAttentionHeads: 6,
            modelDim: 384,
            ffnDim: 1536,
            vocabSize: 51865,
            maxAudioCtx: 1500,
            maxTextCtx: 448,
            numMels: 128,
            encoderAttentionHeads: 6,
            decoderAttentionHeads: 6
        )
    }
}

/// Decoding options for MLX Whisper transcription
public struct MLXDecodingOptions {
    /// Language code for transcription (e.g., "en", "es", "fr")
    public var language: String?

    /// Whether to perform translation to English
    public var translate: Bool

    /// Whether to include timestamps in output
    public var withTimestamps: Bool

    /// Temperature for sampling (0 = greedy)
    public var temperature: Float

    /// Beam size for beam search (1 = greedy)
    public var beamSize: Int

    /// Maximum number of tokens to generate
    public var maxTokens: Int

    /// Suppress blank tokens
    public var suppressBlank: Bool

    /// Suppress specific token IDs
    public var suppressTokens: [Int]?

    public init(
        language: String? = nil,
        translate: Bool = false,
        withTimestamps: Bool = false,
        temperature: Float = 0.0,
        beamSize: Int = 1,
        maxTokens: Int = 224,
        suppressBlank: Bool = true,
        suppressTokens: [Int]? = nil
    ) {
        self.language = language
        self.translate = translate
        self.withTimestamps = withTimestamps
        self.temperature = temperature
        self.beamSize = beamSize
        self.maxTokens = maxTokens
        self.suppressBlank = suppressBlank
        self.suppressTokens = suppressTokens
    }

    /// Default transcription options
    public static var `default`: MLXDecodingOptions {
        MLXDecodingOptions()
    }
}

/// Audio processing constants for Whisper
public enum MLXWhisperAudioConstants {
    public static let sampleRate: Int = 16000
    public static let nFFT: Int = 400
    public static let hopLength: Int = 160
    public static let chunkLength: Int = 30  // seconds
    public static let nSamplesPerChunk: Int = sampleRate * chunkLength
    public static let nFrames: Int = nSamplesPerChunk / hopLength  // 3000 frames for 30s
}
