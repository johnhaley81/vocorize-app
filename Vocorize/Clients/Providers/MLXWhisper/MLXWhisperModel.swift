//
//  MLXWhisperModel.swift
//  Vocorize
//
//  MLX Whisper model implementation using MLX Swift framework
//

import Foundation

#if canImport(MLX)
import MLX
import MLXNN

// MARK: - Multi-Head Attention

/// Multi-head attention layer for Whisper
public class MLXMultiHeadAttention: Module {
    let numHeads: Int
    let headDim: Int
    let scale: Float

    @ModuleInfo var query: Linear
    @ModuleInfo var key: Linear
    @ModuleInfo var value: Linear
    @ModuleInfo var out: Linear

    public init(modelDim: Int, numHeads: Int) {
        self.numHeads = numHeads
        self.headDim = modelDim / numHeads
        self.scale = Float(1.0 / sqrt(Double(headDim)))

        self._query = ModuleInfo(wrappedValue: Linear(modelDim, modelDim))
        self._key = ModuleInfo(wrappedValue: Linear(modelDim, modelDim, bias: false))
        self._value = ModuleInfo(wrappedValue: Linear(modelDim, modelDim))
        self._out = ModuleInfo(wrappedValue: Linear(modelDim, modelDim))
    }

    public func callAsFunction(
        _ x: MLXArray,
        xa: MLXArray? = nil,
        mask: MLXArray? = nil,
        kvCache: (MLXArray, MLXArray)? = nil
    ) -> (MLXArray, (MLXArray, MLXArray)) {
        let batchSize = x.shape[0]
        let seqLen = x.shape[1]

        // Query from x
        var q = query(x)

        // Key and value from xa (cross-attention) or x (self-attention)
        let source = xa ?? x
        var k: MLXArray
        var v: MLXArray

        if let cache = kvCache {
            k = cache.0
            v = cache.1
        } else {
            k = key(source)
            v = value(source)
        }

        // Reshape for multi-head attention
        q = q.reshaped([batchSize, seqLen, numHeads, headDim]).transposed(0, 2, 1, 3)
        let sourceLen = k.shape[1]
        k = k.reshaped([batchSize, sourceLen, numHeads, headDim]).transposed(0, 2, 1, 3)
        v = v.reshaped([batchSize, sourceLen, numHeads, headDim]).transposed(0, 2, 1, 3)

        // Scaled dot-product attention
        var scores = MLX.matmul(q, k.transposed(0, 1, 3, 2)) * scale

        if let mask = mask {
            scores = scores + mask
        }

        let weights = softmax(scores, axis: -1)
        var output = MLX.matmul(weights, v)

        // Reshape back
        output = output.transposed(0, 2, 1, 3).reshaped([batchSize, seqLen, numHeads * headDim])
        output = out(output)

        // Return output and updated cache
        let newCache = (key(source), value(source))
        return (output, newCache)
    }
}

// MARK: - Encoder Layer

/// Single encoder layer for Whisper
public class MLXEncoderLayer: Module {
    @ModuleInfo var selfAttn: MLXMultiHeadAttention
    @ModuleInfo var selfAttnLayerNorm: LayerNorm
    @ModuleInfo var mlp1: Linear
    @ModuleInfo var mlp2: Linear
    @ModuleInfo var mlpLayerNorm: LayerNorm

    public init(config: MLXWhisperConfig) {
        self._selfAttn = ModuleInfo(wrappedValue: MLXMultiHeadAttention(
            modelDim: config.modelDim,
            numHeads: config.encoderAttentionHeads
        ))
        self._selfAttnLayerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
        self._mlp1 = ModuleInfo(wrappedValue: Linear(config.modelDim, config.ffnDim))
        self._mlp2 = ModuleInfo(wrappedValue: Linear(config.ffnDim, config.modelDim))
        self._mlpLayerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
    }

    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Self attention with residual
        let attnOutput = selfAttn(selfAttnLayerNorm(x)).0
        var hidden = x + attnOutput

        // MLP with residual
        let mlpInput = mlpLayerNorm(hidden)
        let mlpOutput = mlp2(gelu(mlp1(mlpInput)))
        hidden = hidden + mlpOutput

        return hidden
    }
}

// MARK: - Decoder Layer

/// Single decoder layer for Whisper
public class MLXDecoderLayer: Module {
    @ModuleInfo var selfAttn: MLXMultiHeadAttention
    @ModuleInfo var selfAttnLayerNorm: LayerNorm
    @ModuleInfo var crossAttn: MLXMultiHeadAttention
    @ModuleInfo var crossAttnLayerNorm: LayerNorm
    @ModuleInfo var mlp1: Linear
    @ModuleInfo var mlp2: Linear
    @ModuleInfo var mlpLayerNorm: LayerNorm

    public init(config: MLXWhisperConfig) {
        self._selfAttn = ModuleInfo(wrappedValue: MLXMultiHeadAttention(
            modelDim: config.modelDim,
            numHeads: config.decoderAttentionHeads
        ))
        self._selfAttnLayerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
        self._crossAttn = ModuleInfo(wrappedValue: MLXMultiHeadAttention(
            modelDim: config.modelDim,
            numHeads: config.decoderAttentionHeads
        ))
        self._crossAttnLayerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
        self._mlp1 = ModuleInfo(wrappedValue: Linear(config.modelDim, config.ffnDim))
        self._mlp2 = ModuleInfo(wrappedValue: Linear(config.ffnDim, config.modelDim))
        self._mlpLayerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
    }

    public func callAsFunction(
        _ x: MLXArray,
        xa: MLXArray,
        mask: MLXArray? = nil,
        selfAttnCache: (MLXArray, MLXArray)? = nil,
        crossAttnCache: (MLXArray, MLXArray)? = nil
    ) -> (MLXArray, (MLXArray, MLXArray), (MLXArray, MLXArray)) {
        // Self attention with causal mask
        let (selfAttnOut, newSelfCache) = selfAttn(
            selfAttnLayerNorm(x),
            mask: mask,
            kvCache: selfAttnCache
        )
        var hidden = x + selfAttnOut

        // Cross attention with encoder output
        let (crossAttnOut, newCrossCache) = crossAttn(
            crossAttnLayerNorm(hidden),
            xa: xa,
            kvCache: crossAttnCache
        )
        hidden = hidden + crossAttnOut

        // MLP with residual
        let mlpInput = mlpLayerNorm(hidden)
        let mlpOutput = mlp2(gelu(mlp1(mlpInput)))
        hidden = hidden + mlpOutput

        return (hidden, newSelfCache, newCrossCache)
    }
}

// MARK: - Audio Encoder

/// Whisper audio encoder
public class MLXWhisperEncoder: Module {
    let config: MLXWhisperConfig

    @ModuleInfo var conv1: Conv1d
    @ModuleInfo var conv2: Conv1d
    @ModuleInfo var positionalEmbedding: MLXArray
    @ModuleInfo var layers: [MLXEncoderLayer]
    @ModuleInfo var layerNorm: LayerNorm

    public init(config: MLXWhisperConfig) {
        self.config = config

        // Convolutional frontend
        self._conv1 = ModuleInfo(wrappedValue: Conv1d(
            inputChannels: config.numMels,
            outputChannels: config.modelDim,
            kernelSize: 3,
            padding: 1
        ))
        self._conv2 = ModuleInfo(wrappedValue: Conv1d(
            inputChannels: config.modelDim,
            outputChannels: config.modelDim,
            kernelSize: 3,
            stride: 2,
            padding: 1
        ))

        // Positional embeddings (sinusoidal)
        self._positionalEmbedding = ModuleInfo(wrappedValue: MLXWhisperEncoder.createPositionalEmbedding(
            maxLen: config.maxAudioCtx,
            dim: config.modelDim
        ))

        // Encoder layers
        self._layers = ModuleInfo(wrappedValue: (0..<config.numEncoderLayers).map { _ in
            MLXEncoderLayer(config: config)
        })

        self._layerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
    }

    private static func createPositionalEmbedding(maxLen: Int, dim: Int) -> MLXArray {
        // Create sinusoidal positional embeddings
        var embedding = [[Float]](repeating: [Float](repeating: 0, count: dim), count: maxLen)

        for pos in 0..<maxLen {
            for i in stride(from: 0, to: dim, by: 2) {
                let angle = Float(pos) / pow(10000.0, Float(i) / Float(dim))
                embedding[pos][i] = sin(angle)
                if i + 1 < dim {
                    embedding[pos][i + 1] = cos(angle)
                }
            }
        }

        return MLXArray(embedding.flatMap { $0 }).reshaped([1, maxLen, dim])
    }

    public func callAsFunction(_ melSpectrogram: MLXArray) -> MLXArray {
        // Input: [batch, numMels, frames]
        // Apply convolutional frontend
        var x = gelu(conv1(melSpectrogram))
        x = gelu(conv2(x))

        // Transpose to [batch, frames, modelDim]
        x = x.transposed(0, 2, 1)

        // Add positional embeddings
        let seqLen = x.shape[1]
        let posEmb = positionalEmbedding[0..., ..<seqLen, 0...]
        x = x + posEmb

        // Apply encoder layers
        for layer in layers {
            x = layer(x)
        }

        // Final layer norm
        x = layerNorm(x)

        return x
    }
}

// MARK: - Text Decoder

/// Whisper text decoder
public class MLXWhisperDecoder: Module {
    let config: MLXWhisperConfig

    @ModuleInfo var tokenEmbedding: Embedding
    @ModuleInfo var positionalEmbedding: MLXArray
    @ModuleInfo var layers: [MLXDecoderLayer]
    @ModuleInfo var layerNorm: LayerNorm

    public init(config: MLXWhisperConfig) {
        self.config = config

        self._tokenEmbedding = ModuleInfo(wrappedValue: Embedding(
            embeddingCount: config.vocabSize,
            dimensions: config.modelDim
        ))

        // Learned positional embeddings for decoder
        self._positionalEmbedding = ModuleInfo(wrappedValue: MLXArray.zeros([1, config.maxTextCtx, config.modelDim]))

        // Decoder layers
        self._layers = ModuleInfo(wrappedValue: (0..<config.numDecoderLayers).map { _ in
            MLXDecoderLayer(config: config)
        })

        self._layerNorm = ModuleInfo(wrappedValue: LayerNorm(dimensions: config.modelDim))
    }

    /// Creates causal attention mask
    private func createCausalMask(seqLen: Int) -> MLXArray {
        // Create lower triangular mask
        var mask = [[Float]](repeating: [Float](repeating: Float.negativeInfinity, count: seqLen), count: seqLen)
        for i in 0..<seqLen {
            for j in 0...i {
                mask[i][j] = 0
            }
        }
        return MLXArray(mask.flatMap { $0 }).reshaped([1, 1, seqLen, seqLen])
    }

    public func callAsFunction(
        _ tokens: MLXArray,
        encoderOutput: MLXArray,
        cache: [((MLXArray, MLXArray), (MLXArray, MLXArray))]? = nil
    ) -> (MLXArray, [((MLXArray, MLXArray), (MLXArray, MLXArray))]) {
        let seqLen = tokens.shape[1]

        // Token embeddings + positional embeddings
        var x = tokenEmbedding(tokens)
        let posEmb = positionalEmbedding[0..., ..<seqLen, 0...]
        x = x + posEmb

        // Create causal mask for self-attention
        let mask = createCausalMask(seqLen: seqLen)

        // Apply decoder layers
        var newCache: [((MLXArray, MLXArray), (MLXArray, MLXArray))] = []
        for (i, layer) in layers.enumerated() {
            let layerCache = cache?[i]
            let (output, selfCache, crossCache) = layer(
                x,
                xa: encoderOutput,
                mask: mask,
                selfAttnCache: layerCache?.0,
                crossAttnCache: layerCache?.1
            )
            x = output
            newCache.append((selfCache, crossCache))
        }

        // Final layer norm
        x = layerNorm(x)

        return (x, newCache)
    }

    /// Project decoder output to vocabulary logits
    public func projectToVocab(_ x: MLXArray) -> MLXArray {
        // Use token embedding weights for output projection (weight tying)
        return MLX.matmul(x, tokenEmbedding.weight.T)
    }
}

// MARK: - Full Whisper Model

/// Complete MLX Whisper model
public class MLXWhisperModel: Module {
    public let config: MLXWhisperConfig

    @ModuleInfo var encoder: MLXWhisperEncoder
    @ModuleInfo var decoder: MLXWhisperDecoder

    public init(config: MLXWhisperConfig) {
        self.config = config
        self._encoder = ModuleInfo(wrappedValue: MLXWhisperEncoder(config: config))
        self._decoder = ModuleInfo(wrappedValue: MLXWhisperDecoder(config: config))
    }

    /// Encode audio to hidden representations
    public func encode(_ melSpectrogram: MLXArray) -> MLXArray {
        return encoder(melSpectrogram)
    }

    /// Decode tokens given encoder output
    public func decode(
        _ tokens: MLXArray,
        encoderOutput: MLXArray,
        cache: [((MLXArray, MLXArray), (MLXArray, MLXArray))]? = nil
    ) -> (MLXArray, [((MLXArray, MLXArray), (MLXArray, MLXArray))]) {
        let (hidden, newCache) = decoder(tokens, encoderOutput: encoderOutput, cache: cache)
        let logits = decoder.projectToVocab(hidden)
        return (logits, newCache)
    }

    /// Full forward pass
    public func callAsFunction(_ melSpectrogram: MLXArray, tokens: MLXArray) -> MLXArray {
        let encoderOutput = encode(melSpectrogram)
        let (logits, _) = decode(tokens, encoderOutput: encoderOutput)
        return logits
    }
}

#else
// Stub implementation when MLX is not available
public class MLXWhisperModel {
    public let config: MLXWhisperConfig

    public init(config: MLXWhisperConfig) {
        self.config = config
    }
}
#endif
