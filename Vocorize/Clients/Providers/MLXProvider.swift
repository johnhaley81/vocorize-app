//
//  MLXProvider.swift
//  Vocorize
//
//  MLX-based transcription provider implementing TranscriptionProvider protocol
//

import Foundation
import AVFoundation
import WhisperKit

#if canImport(MLX)
import MLX
import MLXNN
#endif

/// MLX-based transcription provider for Whisper models
/// Downloads and runs Whisper models using Apple's MLX framework
actor MLXProvider: TranscriptionProvider {

    // MARK: - Protocol Conformance

    static var providerType: TranscriptionProviderType { .mlx }
    static var displayName: String { "MLX Whisper" }

    // MARK: - Private Properties

    #if canImport(MLX)
    /// Current loaded Whisper model
    private var model: MLXWhisperModel?
    #endif

    /// Tokenizer for the current model
    private var tokenizer: MLXWhisperTokenizer?

    /// Audio processor for mel spectrogram computation
    private let audioProcessor: MLXAudioProcessor

    /// Configuration for the current model
    private var currentConfig: MLXWhisperConfig?

    /// Name of the currently loaded model
    private var currentModelName: String?

    /// Base folder for model storage
    private lazy var modelsBaseFolder: URL = {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let ourAppFolder = appSupportURL.appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
            let baseURL = ourAppFolder.appendingPathComponent("mlx-models", isDirectory: true)
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            return baseURL
        } catch {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
                .appendingPathComponent("mlx-models", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            return tempURL
        }
    }()

    // MARK: - Initialization

    init() {
        self.audioProcessor = MLXAudioProcessor()
    }

    // MARK: - TranscriptionProvider Implementation

    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String {
        #if canImport(MLX)
        // Ensure model is loaded
        guard let model = model, currentModelName == modelName else {
            throw TranscriptionProviderError.modelLoadFailed(modelName, NSError(
                domain: "MLXProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Model \(modelName) is not loaded. Call loadModelIntoMemory() first."]
            ))
        }

        guard let tokenizer = tokenizer, let config = currentConfig else {
            throw TranscriptionProviderError.modelLoadFailed(modelName, NSError(
                domain: "MLXProvider",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Tokenizer not initialized"]
            ))
        }

        // Report initial progress
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 0
        progressCallback(progress)

        // Process audio to mel spectrogram
        progress.completedUnitCount = 10
        progressCallback(progress)

        let melSpectrogram = try audioProcessor.processAudioFileToMLX(at: audioURL)

        progress.completedUnitCount = 20
        progressCallback(progress)

        // Encode audio
        let encoderOutput = model.encode(melSpectrogram)

        progress.completedUnitCount = 40
        progressCallback(progress)

        // Get initial decoder tokens
        let language = options.language
        let initialTokens = tokenizer.getInitialTokens(language: language, task: "transcribe")
        var tokens = initialTokens

        // Greedy decoding
        let maxTokens = 224
        var cache: [((MLXArray, MLXArray), (MLXArray, MLXArray))]? = nil

        for step in 0..<maxTokens {
            // Convert tokens to MLXArray
            let tokenArray = MLXArray(tokens.map { Int32($0) }).reshaped([1, tokens.count])

            // Get logits from decoder
            let (logits, newCache) = model.decode(tokenArray, encoderOutput: encoderOutput, cache: cache)
            cache = newCache

            // Get next token (greedy)
            let lastLogits = logits[0..., -1, 0...]
            let nextToken = Int(MLX.argMax(lastLogits, axis: -1).item(Int32.self))

            // Check for end of transcription
            if nextToken == config.eotToken {
                break
            }

            tokens.append(nextToken)

            // Update progress
            let progressFraction = 40 + Int64(Double(step) / Double(maxTokens) * 55)
            progress.completedUnitCount = min(progressFraction, 95)
            progressCallback(progress)
        }

        // Decode tokens to text
        let outputTokens = Array(tokens.dropFirst(initialTokens.count))
        let transcribedText = tokenizer.decodeWithoutSpecialTokens(outputTokens)

        progress.completedUnitCount = 100
        progressCallback(progress)

        return transcribedText
        #else
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }

    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        // Validate model name
        guard !modelName.isEmpty else {
            throw TranscriptionProviderError.modelNotFound("Empty model name")
        }

        let modelFolder = modelPath(for: modelName)

        // Check if already downloaded
        if await isModelDownloaded(modelName) {
            let progress = Progress(totalUnitCount: 100)
            progress.completedUnitCount = 100
            progressCallback(progress)
            return
        }

        // Report initial progress
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 0
        progressCallback(progress)

        // Create model directory
        try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)

        // Download from Hugging Face
        try await downloadFromHuggingFace(modelName: modelName, to: modelFolder) { downloadProgress in
            progress.completedUnitCount = Int64(downloadProgress * 100)
            progressCallback(progress)
        }

        progress.completedUnitCount = 100
        progressCallback(progress)
    }

    func deleteModel(_ modelName: String) async throws {
        let modelFolder = modelPath(for: modelName)

        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            throw TranscriptionProviderError.modelNotFound(modelName)
        }

        // Unload if currently loaded
        if currentModelName == modelName {
            unloadCurrentModel()
        }

        try FileManager.default.removeItem(at: modelFolder)
    }

    func isModelDownloaded(_ modelName: String) async -> Bool {
        let modelFolder = modelPath(for: modelName)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: modelFolder.path) else {
            return false
        }

        // Check for required model files
        let requiredFiles = ["config.json", "model.safetensors"]
        for file in requiredFiles {
            let filePath = modelFolder.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath.path) {
                // Also check for weights.npz (alternative format)
                if file == "model.safetensors" {
                    let altPath = modelFolder.appendingPathComponent("weights.npz")
                    if !fileManager.fileExists(atPath: altPath.path) {
                        return false
                    }
                } else {
                    return false
                }
            }
        }

        return true
    }

    func getAvailableModels() async throws -> [ProviderModelInfo] {
        // Return curated list of MLX Whisper models from mlx-community
        let models: [ProviderModelInfo] = [
            ProviderModelInfo(
                internalName: "mlx-community/whisper-tiny",
                displayName: "Whisper Tiny (MLX)",
                providerType: .mlx,
                estimatedSize: "~75 MB",
                isRecommended: false,
                isDownloaded: await isModelDownloaded("mlx-community/whisper-tiny")
            ),
            ProviderModelInfo(
                internalName: "mlx-community/whisper-base",
                displayName: "Whisper Base (MLX)",
                providerType: .mlx,
                estimatedSize: "~145 MB",
                isRecommended: false,
                isDownloaded: await isModelDownloaded("mlx-community/whisper-base")
            ),
            ProviderModelInfo(
                internalName: "mlx-community/whisper-small",
                displayName: "Whisper Small (MLX)",
                providerType: .mlx,
                estimatedSize: "~460 MB",
                isRecommended: false,
                isDownloaded: await isModelDownloaded("mlx-community/whisper-small")
            ),
            ProviderModelInfo(
                internalName: "mlx-community/whisper-medium",
                displayName: "Whisper Medium (MLX)",
                providerType: .mlx,
                estimatedSize: "~1.5 GB",
                isRecommended: false,
                isDownloaded: await isModelDownloaded("mlx-community/whisper-medium")
            ),
            ProviderModelInfo(
                internalName: "mlx-community/whisper-large-v3-turbo",
                displayName: "Whisper Large V3 Turbo (MLX)",
                providerType: .mlx,
                estimatedSize: "~1.2 GB",
                isRecommended: true,
                isDownloaded: await isModelDownloaded("mlx-community/whisper-large-v3-turbo")
            ),
            ProviderModelInfo(
                internalName: "mlx-community/whisper-large-v3-mlx",
                displayName: "Whisper Large V3 (MLX)",
                providerType: .mlx,
                estimatedSize: "~3.1 GB",
                isRecommended: false,
                isDownloaded: await isModelDownloaded("mlx-community/whisper-large-v3-mlx")
            )
        ]

        return models
    }

    func getRecommendedModel() async throws -> String {
        // Recommend turbo model for best balance of speed and quality
        return "mlx-community/whisper-large-v3-turbo"
    }

    func loadModelIntoMemory(_ modelName: String) async throws -> Bool {
        #if canImport(MLX)
        // Check if model is downloaded
        if !(await isModelDownloaded(modelName)) {
            try await downloadModel(modelName) { _ in }
        }

        // Unload current model if different
        if currentModelName != modelName {
            unloadCurrentModel()
        }

        let modelFolder = modelPath(for: modelName)

        // Load configuration
        let config = try loadConfiguration(from: modelFolder, modelName: modelName)
        currentConfig = config

        // Initialize tokenizer
        let newTokenizer = MLXWhisperTokenizer(config: config)
        try newTokenizer.load(from: modelFolder)
        tokenizer = newTokenizer

        // Initialize model
        let newModel = MLXWhisperModel(config: config)

        // Load weights
        try loadWeights(for: newModel, from: modelFolder)

        model = newModel
        currentModelName = modelName

        return true
        #else
        throw TranscriptionProviderError.providerNotAvailable(.mlx)
        #endif
    }

    func isModelLoadedInMemory(_ modelName: String) async -> Bool {
        #if canImport(MLX)
        return model != nil && currentModelName == modelName
        #else
        return false
        #endif
    }

    // MARK: - Private Methods

    /// Get path for model storage
    private func modelPath(for modelName: String) -> URL {
        // Sanitize model name for filesystem
        let sanitizedName = modelName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")

        return modelsBaseFolder.appendingPathComponent(sanitizedName, isDirectory: true)
    }

    /// Unload current model
    private func unloadCurrentModel() {
        #if canImport(MLX)
        model = nil
        #endif
        tokenizer = nil
        currentConfig = nil
        currentModelName = nil
    }

    /// Load model configuration
    private func loadConfiguration(from folder: URL, modelName: String) throws -> MLXWhisperConfig {
        let configURL = folder.appendingPathComponent("config.json")

        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(MLXWhisperConfig.self, from: data)
        }

        // Fall back to predefined configs based on model name
        let nameLower = modelName.lowercased()

        if nameLower.contains("large-v3-turbo") {
            return .largev3turbo
        } else if nameLower.contains("large-v3") || nameLower.contains("large") {
            return .largev3
        } else if nameLower.contains("medium") {
            return .medium
        } else if nameLower.contains("small") {
            return .small
        } else if nameLower.contains("base") {
            return .base
        } else if nameLower.contains("tiny") {
            return .tiny
        }

        // Default to small config
        return .small
    }

    #if canImport(MLX)
    /// Load model weights from safetensors or npz file
    private func loadWeights(for model: MLXWhisperModel, from folder: URL) throws {
        let safetensorsPath = folder.appendingPathComponent("model.safetensors")
        let npzPath = folder.appendingPathComponent("weights.npz")

        if FileManager.default.fileExists(atPath: safetensorsPath.path) {
            // Load from safetensors
            let weights = try MLX.loadArrays(url: safetensorsPath)
            try model.update(parameters: mapWeights(weights), verify: .noUnusedKeys)
        } else if FileManager.default.fileExists(atPath: npzPath.path) {
            // Load from npz
            let weights = try MLX.loadArrays(url: npzPath)
            try model.update(parameters: mapWeights(weights), verify: .noUnusedKeys)
        } else {
            throw TranscriptionProviderError.modelLoadFailed(
                currentModelName ?? "unknown",
                NSError(domain: "MLXProvider", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "No weights file found (model.safetensors or weights.npz)"
                ])
            )
        }
    }

    /// Map weight names from HuggingFace format to our model structure
    private func mapWeights(_ weights: [String: MLXArray]) -> [String: MLXArray] {
        var mapped: [String: MLXArray] = [:]

        for (key, value) in weights {
            // Convert HuggingFace naming to our naming convention
            var newKey = key

            // Handle encoder layers
            newKey = newKey.replacingOccurrences(of: "model.encoder.", with: "encoder.")
            newKey = newKey.replacingOccurrences(of: "encoder.layers.", with: "encoder.layers.")

            // Handle decoder layers
            newKey = newKey.replacingOccurrences(of: "model.decoder.", with: "decoder.")
            newKey = newKey.replacingOccurrences(of: "decoder.layers.", with: "decoder.layers.")

            // Handle attention projections
            newKey = newKey.replacingOccurrences(of: "self_attn.q_proj", with: "selfAttn.query")
            newKey = newKey.replacingOccurrences(of: "self_attn.k_proj", with: "selfAttn.key")
            newKey = newKey.replacingOccurrences(of: "self_attn.v_proj", with: "selfAttn.value")
            newKey = newKey.replacingOccurrences(of: "self_attn.out_proj", with: "selfAttn.out")

            newKey = newKey.replacingOccurrences(of: "encoder_attn.q_proj", with: "crossAttn.query")
            newKey = newKey.replacingOccurrences(of: "encoder_attn.k_proj", with: "crossAttn.key")
            newKey = newKey.replacingOccurrences(of: "encoder_attn.v_proj", with: "crossAttn.value")
            newKey = newKey.replacingOccurrences(of: "encoder_attn.out_proj", with: "crossAttn.out")

            // Handle layer norms
            newKey = newKey.replacingOccurrences(of: "self_attn_layer_norm", with: "selfAttnLayerNorm")
            newKey = newKey.replacingOccurrences(of: "encoder_attn_layer_norm", with: "crossAttnLayerNorm")
            newKey = newKey.replacingOccurrences(of: "final_layer_norm", with: "mlpLayerNorm")

            // Handle MLP
            newKey = newKey.replacingOccurrences(of: "fc1", with: "mlp1")
            newKey = newKey.replacingOccurrences(of: "fc2", with: "mlp2")

            // Handle embeddings
            newKey = newKey.replacingOccurrences(of: "embed_tokens", with: "tokenEmbedding")
            newKey = newKey.replacingOccurrences(of: "embed_positions", with: "positionalEmbedding")

            // Handle convolutions
            newKey = newKey.replacingOccurrences(of: "conv1", with: "conv1")
            newKey = newKey.replacingOccurrences(of: "conv2", with: "conv2")

            mapped[newKey] = value
        }

        return mapped
    }
    #endif

    /// Download model from Hugging Face
    private func downloadFromHuggingFace(
        modelName: String,
        to folder: URL,
        progressCallback: @escaping (Double) -> Void
    ) async throws {
        // Construct Hugging Face URL
        let repoName = modelName.hasPrefix("mlx-community/") ? modelName : "mlx-community/\(modelName)"
        let baseURL = "https://huggingface.co/\(repoName)/resolve/main"

        // Files to download
        let filesToDownload = [
            "config.json",
            "tokenizer.json",
            "vocab.json",
            "merges.txt",
            "model.safetensors"
        ]

        let totalFiles = filesToDownload.count
        var downloadedFiles = 0

        for fileName in filesToDownload {
            let fileURL = URL(string: "\(baseURL)/\(fileName)")!
            let destinationURL = folder.appendingPathComponent(fileName)

            do {
                try await downloadFile(from: fileURL, to: destinationURL)
                downloadedFiles += 1
                progressCallback(Double(downloadedFiles) / Double(totalFiles))
            } catch {
                // Some files are optional (merges.txt, vocab.json)
                let requiredFiles = ["config.json", "model.safetensors"]
                if requiredFiles.contains(fileName) {
                    // Try alternative weight format
                    if fileName == "model.safetensors" {
                        let altURL = URL(string: "\(baseURL)/weights.npz")!
                        let altDestination = folder.appendingPathComponent("weights.npz")
                        do {
                            try await downloadFile(from: altURL, to: altDestination)
                            downloadedFiles += 1
                            progressCallback(Double(downloadedFiles) / Double(totalFiles))
                        } catch {
                            throw TranscriptionProviderError.modelDownloadFailed(modelName, error)
                        }
                    } else {
                        throw TranscriptionProviderError.modelDownloadFailed(modelName, error)
                    }
                }
            }
        }
    }

    /// Download a single file
    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "MLXProvider",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to download \(url.lastPathComponent)"]
            )
        }

        try data.write(to: destination)
    }
}
