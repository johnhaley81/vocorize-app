//
//  MLXModel.swift
//  Vocorize
//
//  MLX-based Whisper model structure for defining and managing MLX models
//  Provides configuration, initialization, and lifecycle management for MLX Whisper models
//

import Foundation
import os.log

#if canImport(MLX) && canImport(MLXNN)
import MLX
import MLXNN
#endif

// MARK: - MLX Model Configuration

/// Configuration parameters for MLX Whisper models
/// Defines the architecture and parameters needed for model initialization
@available(macOS 13.0, *)
public struct MLXModelConfig: Codable, Equatable, Sendable {
    
    // MARK: - Core Model Parameters
    
    /// Model name identifier
    public let modelName: String
    
    /// Model variant (tiny, base, small, medium, large, etc.)
    public let modelVariant: String
    
    /// Vocabulary size for the tokenizer
    public let vocabSize: Int
    
    /// Number of mel-spectrogram bins
    public let nMels: Int
    
    /// Maximum context length for the model
    public let nCtx: Int
    
    /// Number of attention heads in the model
    public let nHead: Int
    
    /// Model dimension size
    public let nState: Int
    
    /// Number of layers in the model
    public let nLayer: Int
    
    /// Maximum number of text tokens
    public let nTextCtx: Int
    
    /// Maximum number of audio tokens
    public let nAudioCtx: Int
    
    // MARK: - Model Metadata
    
    /// Whether the model is multilingual
    public let isMultilingual: Bool
    
    /// Whether the model includes timestamps
    public let hasTimestamps: Bool
    
    /// Language codes supported by the model
    public let supportedLanguages: [String]
    
    /// Model file format version
    public let formatVersion: String
    
    /// Expected model file size in bytes
    public let expectedSize: UInt64
    
    /// Model creation date
    public let createdAt: Date?
    
    // MARK: - Performance Configuration
    
    /// Preferred batch size for inference
    public let preferredBatchSize: Int
    
    /// Memory requirements in bytes
    public let memoryRequirement: UInt64
    
    /// Whether the model supports streaming
    public let supportsStreaming: Bool
    
    /// Maximum sequence length for efficient processing
    public let maxSequenceLength: Int
    
    // MARK: - Initialization
    
    public init(
        modelName: String,
        modelVariant: String,
        vocabSize: Int = 51865,
        nMels: Int = 80,
        nCtx: Int = 1500,
        nHead: Int = 8,
        nState: Int = 512,
        nLayer: Int = 6,
        nTextCtx: Int = 448,
        nAudioCtx: Int = 1500,
        isMultilingual: Bool = true,
        hasTimestamps: Bool = true,
        supportedLanguages: [String] = ["en"],
        formatVersion: String = "1.0",
        expectedSize: UInt64 = 0,
        createdAt: Date? = nil,
        preferredBatchSize: Int = 1,
        memoryRequirement: UInt64 = 1_000_000_000, // 1GB default
        supportsStreaming: Bool = false,
        maxSequenceLength: Int = 1024
    ) {
        self.modelName = modelName
        self.modelVariant = modelVariant
        self.vocabSize = vocabSize
        self.nMels = nMels
        self.nCtx = nCtx
        self.nHead = nHead
        self.nState = nState
        self.nLayer = nLayer
        self.nTextCtx = nTextCtx
        self.nAudioCtx = nAudioCtx
        self.isMultilingual = isMultilingual
        self.hasTimestamps = hasTimestamps
        self.supportedLanguages = supportedLanguages
        self.formatVersion = formatVersion
        self.expectedSize = expectedSize
        self.createdAt = createdAt
        self.preferredBatchSize = preferredBatchSize
        self.memoryRequirement = memoryRequirement
        self.supportsStreaming = supportsStreaming
        self.maxSequenceLength = maxSequenceLength
    }
    
    // MARK: - Factory Methods
    
    /// Creates a configuration for a tiny model
    public static func tiny(modelName: String) -> MLXModelConfig {
        return MLXModelConfig(
            modelName: modelName,
            modelVariant: "tiny",
            nHead: 6,
            nState: 384,
            nLayer: 4,
            supportedLanguages: ["en"],
            memoryRequirement: 200_000_000 // 200MB
        )
    }
    
    /// Creates a configuration for a base model
    public static func base(modelName: String) -> MLXModelConfig {
        return MLXModelConfig(
            modelName: modelName,
            modelVariant: "base",
            nHead: 8,
            nState: 512,
            nLayer: 6,
            memoryRequirement: 500_000_000 // 500MB
        )
    }
    
    /// Creates a configuration for a small model
    public static func small(modelName: String) -> MLXModelConfig {
        return MLXModelConfig(
            modelName: modelName,
            modelVariant: "small",
            nHead: 12,
            nState: 768,
            nLayer: 12,
            memoryRequirement: 1_000_000_000 // 1GB
        )
    }
    
    /// Creates a configuration for a medium model
    public static func medium(modelName: String) -> MLXModelConfig {
        return MLXModelConfig(
            modelName: modelName,
            modelVariant: "medium",
            nHead: 16,
            nState: 1024,
            nLayer: 24,
            memoryRequirement: 2_000_000_000 // 2GB
        )
    }
    
    /// Creates a configuration for a large model
    public static func large(modelName: String) -> MLXModelConfig {
        return MLXModelConfig(
            modelName: modelName,
            modelVariant: "large",
            nHead: 20,
            nState: 1280,
            nLayer: 32,
            memoryRequirement: 3_000_000_000 // 3GB
        )
    }
}

// MARK: - MLX Model Structure

/// Main MLX model container for Whisper-based speech recognition
/// Manages the lifecycle, configuration, and inference operations of MLX models
@available(macOS 13.0, *)
public final class MLXModel: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Model loading state
    public enum LoadingState: Equatable, Sendable {
        case notLoaded
        case loading(progress: Double)
        case loaded
        case error(String)
        
        public var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
    }
    
    /// Model validation result
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let issues: [String]
        public let warnings: [String]
        
        public init(isValid: Bool, issues: [String] = [], warnings: [String] = []) {
            self.isValid = isValid
            self.issues = issues
            self.warnings = warnings
        }
    }
    
    /// Model metadata containing runtime information
    public struct ModelMetadata: Sendable {
        public let loadedAt: Date
        public let memoryUsage: UInt64
        public let inferenceCount: UInt64
        public let lastInferenceAt: Date?
        public let averageInferenceTime: TimeInterval
        
        public init(
            loadedAt: Date = Date(),
            memoryUsage: UInt64 = 0,
            inferenceCount: UInt64 = 0,
            lastInferenceAt: Date? = nil,
            averageInferenceTime: TimeInterval = 0
        ) {
            self.loadedAt = loadedAt
            self.memoryUsage = memoryUsage
            self.inferenceCount = inferenceCount
            self.lastInferenceAt = lastInferenceAt
            self.averageInferenceTime = averageInferenceTime
        }
    }
    
    // MARK: - Properties
    
    /// Model configuration
    public let config: MLXModelConfig
    
    /// Current loading state
    private var _loadingState: LoadingState = .notLoaded
    private let stateQueue = DispatchQueue(label: "MLXModel.state", attributes: .concurrent)
    
    /// Model file path
    public let modelPath: URL
    
    /// Logger for debugging and monitoring
    private let logger = Logger(subsystem: "com.tanvir.Vocorize", category: "MLXModel")
    
    /// Model metadata
    private var _metadata: ModelMetadata?
    
    #if canImport(MLX) && canImport(MLXNN)
    /// Loaded MLX model components (conditional compilation)
    private var mlxModel: Any?
    private var tokenizer: Any?
    private var featureExtractor: Any?
    #endif
    
    /// Model validation cache
    private var validationResult: ValidationResult?
    
    // MARK: - Initialization
    
    /// Initializes an MLX model with configuration and file path
    /// - Parameters:
    ///   - config: Model configuration parameters
    ///   - modelPath: Path to the model files on disk
    public init(config: MLXModelConfig, modelPath: URL) {
        self.config = config
        self.modelPath = modelPath
        
        logger.info("MLXModel initialized: \(self.config.modelName) at \(self.modelPath.path)")
    }
    
    /// Convenience initializer from model name and path
    /// - Parameters:
    ///   - modelName: Name of the model
    ///   - modelPath: Path to the model files
    ///   - variant: Model size variant (tiny, base, small, medium, large)
    public convenience init(modelName: String, modelPath: URL, variant: String = "base") {
        let config: MLXModelConfig
        
        switch variant.lowercased() {
        case "tiny":
            config = .tiny(modelName: modelName)
        case "small":
            config = .small(modelName: modelName)
        case "medium":
            config = .medium(modelName: modelName)
        case "large":
            config = .large(modelName: modelName)
        default:
            config = .base(modelName: modelName)
        }
        
        self.init(config: config, modelPath: modelPath)
    }
    
    deinit {
        unloadModel()
        logger.info("MLXModel deinitialized: \(self.config.modelName)")
    }
    
    // MARK: - Public Model Management
    
    /// Current loading state (thread-safe)
    public var loadingState: LoadingState {
        return stateQueue.sync { _loadingState }
    }
    
    /// Model metadata (thread-safe)
    public var metadata: ModelMetadata? {
        return stateQueue.sync { _metadata }
    }
    
    /// Loads the model from disk with progress reporting
    /// - Parameter progressCallback: Callback for loading progress (0.0 to 1.0)
    /// - Throws: Error if loading fails
    public func loadModel(progressCallback: @escaping (Double) -> Void = { _ in }) async throws {
        logger.info("Loading MLX model: \(self.config.modelName)")
        
        // Check MLX framework availability
        guard MLXAvailability.areProductsAvailable else {
            let error = "MLX framework not available"
            updateState(.error(error))
            throw ModelError.frameworkNotAvailable
        }
        
        // Check if already loaded
        if loadingState.isLoaded {
            logger.info("Model \(self.config.modelName) already loaded")
            return
        }
        
        // Validate model files before loading
        try await validateModelFiles()
        
        updateState(.loading(progress: 0.0))
        
        do {
            try await performModelLoading(progressCallback: progressCallback)
            
            // Update metadata
            updateMetadata(ModelMetadata(loadedAt: Date()))
            updateState(.loaded)
            
            logger.info("Successfully loaded MLX model: \(self.config.modelName)")
            
        } catch {
            let errorMessage = "Failed to load model: \(error.localizedDescription)"
            updateState(.error(errorMessage))
            logger.error("Failed to load MLX model \(self.config.modelName): \(error)")
            throw error
        }
    }
    
    /// Unloads the model from memory
    public func unloadModel() {
        logger.info("Unloading MLX model: \(self.config.modelName)")
        
        #if canImport(MLX) && canImport(MLXNN)
        // Clear MLX model references
        mlxModel = nil
        tokenizer = nil
        featureExtractor = nil
        
        // Force memory cleanup
        MLX.eval([])
        #endif
        
        // Update state and clear metadata
        updateState(.notLoaded)
        updateMetadata(nil)
        
        logger.info("Successfully unloaded MLX model: \(self.config.modelName)")
    }
    
    /// Validates model integrity and compatibility
    /// - Returns: ValidationResult with any issues found
    public func validateModel() async -> ValidationResult {
        // Return cached result if available
        if let cached = validationResult {
            return cached
        }
        
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check file existence
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            issues.append("Model file not found at: \(modelPath.path)")
            let result = ValidationResult(isValid: false, issues: issues, warnings: warnings)
            validationResult = result
            return result
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
            if let fileSize = attributes[.size] as? UInt64 {
                if config.expectedSize > 0 && abs(Int64(fileSize) - Int64(config.expectedSize)) > Int64(config.expectedSize) / 10 {
                    warnings.append("File size (\(fileSize)) differs significantly from expected (\(config.expectedSize))")
                }
            }
        } catch {
            warnings.append("Could not verify file size: \(error.localizedDescription)")
        }
        
        // Check MLX availability
        if !MLXAvailability.areProductsAvailable {
            issues.append("MLX framework not available on this system")
        }
        
        // Check memory requirements
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        if config.memoryRequirement > availableMemory {
            warnings.append("Model memory requirement (\(config.memoryRequirement)) exceeds available memory (\(availableMemory))")
        }
        
        let result = ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
        validationResult = result
        return result
    }
    
    /// Gets model information for display
    public var modelInfo: [String: Any] {
        return [
            "name": self.config.modelName,
            "variant": self.config.modelVariant,
            "multilingual": self.config.isMultilingual,
            "vocab_size": self.config.vocabSize,
            "model_dim": self.config.nState,
            "layers": self.config.nLayer,
            "heads": self.config.nHead,
            "memory_requirement": self.config.memoryRequirement,
            "path": self.modelPath.path,
            "loaded": self.loadingState.isLoaded,
            "supported_languages": self.config.supportedLanguages
        ]
    }
    
    // MARK: - Private Implementation
    
    /// Updates loading state in a thread-safe manner
    private func updateState(_ newState: LoadingState) {
        stateQueue.async(flags: .barrier) {
            self._loadingState = newState
        }
    }
    
    /// Updates metadata in a thread-safe manner
    private func updateMetadata(_ newMetadata: ModelMetadata?) {
        stateQueue.async(flags: .barrier) {
            self._metadata = newMetadata
        }
    }
    
    /// Validates model files exist and are accessible
    private func validateModelFiles() async throws {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelNotFound(self.config.modelName)
        }
        
        guard FileManager.default.isReadableFile(atPath: modelPath.path) else {
            throw ModelError.modelNotAccessible(self.config.modelName)
        }
    }
    
    /// Performs the actual model loading with conditional compilation
    private func performModelLoading(progressCallback: @escaping (Double) -> Void) async throws {
        
        #if canImport(MLX) && canImport(MLXNN)
        
        // Phase 1: Initialize tokenizer (0-25%)
        progressCallback(0.0)
        try await initializeTokenizer()
        progressCallback(0.25)
        
        // Phase 2: Load feature extractor (25-50%)
        try await loadFeatureExtractor()
        progressCallback(0.50)
        
        // Phase 3: Load main model (50-90%)
        try await loadMainModel { modelProgress in
            let totalProgress = 0.50 + (modelProgress * 0.40)
            progressCallback(totalProgress)
        }
        
        // Phase 4: Model validation and warmup (90-100%)
        try await warmupModel()
        progressCallback(1.0)
        
        #else
        
        throw ModelError.frameworkNotAvailable
        
        #endif
    }
    
    #if canImport(MLX) && canImport(MLXNN)
    
    /// Initializes the tokenizer component
    private func initializeTokenizer() async throws {
        logger.debug("Initializing tokenizer for: \(self.config.modelName)")
        
        // Initialize tokenizer based on model configuration
        // This would load the actual MLX tokenizer
        tokenizer = self.config.modelName // Placeholder
    }
    
    /// Loads the feature extractor component
    private func loadFeatureExtractor() async throws {
        logger.debug("Loading feature extractor for: \(self.config.modelName)")
        
        // Load MLX feature extractor
        // This would initialize the actual MLX feature extraction components
        featureExtractor = self.config.modelName // Placeholder
    }
    
    /// Loads the main MLX model
    private func loadMainModel(progressCallback: @escaping (Double) -> Void) async throws {
        logger.debug("Loading main MLX model: \(self.config.modelName)")
        
        // Simulate progressive loading
        for i in 0..<10 {
            try Task.checkCancellation()
            
            // Simulate loading work
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
            
            let progress = Double(i + 1) / 10.0
            progressCallback(progress)
        }
        
        // Store reference to loaded model
        mlxModel = self.config.modelName // Placeholder for actual MLX model
    }
    
    /// Performs model warmup and validation
    private func warmupModel() async throws {
        logger.debug("Warming up MLX model: \(self.config.modelName)")
        
        // Perform model warmup operations
        // Run a small inference to ensure model is properly loaded
        
        // This would include actual MLX warmup operations
    }
    
    #endif
}

// MARK: - Model Error Types

/// Errors specific to MLX model operations
public enum ModelError: LocalizedError, Equatable {
    case modelNotFound(String)
    case modelNotAccessible(String)
    case invalidModelFormat(String)
    case frameworkNotAvailable
    case loadingFailed(String, String)
    case validationFailed(String)
    case memoryInsufficient(UInt64)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "MLX model '\(name)' not found"
        case .modelNotAccessible(let name):
            return "MLX model '\(name)' is not accessible"
        case .invalidModelFormat(let name):
            return "MLX model '\(name)' has invalid format"
        case .frameworkNotAvailable:
            return "MLX framework is not available on this system"
        case .loadingFailed(let name, let reason):
            return "Failed to load MLX model '\(name)': \(reason)"
        case .validationFailed(let reason):
            return "Model validation failed: \(reason)"
        case .memoryInsufficient(let required):
            return "Insufficient memory for model (requires \(required) bytes)"
        }
    }
    
    public static func == (lhs: ModelError, rhs: ModelError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotFound(let l), .modelNotFound(let r)),
             (.modelNotAccessible(let l), .modelNotAccessible(let r)),
             (.invalidModelFormat(let l), .invalidModelFormat(let r)),
             (.validationFailed(let l), .validationFailed(let r)):
            return l == r
        case (.loadingFailed(let l1, let l2), .loadingFailed(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.memoryInsufficient(let l), .memoryInsufficient(let r)):
            return l == r
        case (.frameworkNotAvailable, .frameworkNotAvailable):
            return true
        default:
            return false
        }
    }
}

// MARK: - Model Factory

/// Factory for creating MLX models with standard configurations
@available(macOS 13.0, *)
public struct MLXModelFactory {
    
    /// Creates an MLX model from a HuggingFace model identifier
    /// - Parameters:
    ///   - huggingFaceId: HuggingFace model identifier (e.g., "mlx-community/whisper-large-v3-turbo")
    ///   - modelPath: Local path where the model is stored
    /// - Returns: Configured MLXModel instance
    public static func createModel(from huggingFaceId: String, at modelPath: URL) -> MLXModel {
        let modelName = extractModelName(from: huggingFaceId)
        let variant = extractVariant(from: huggingFaceId)
        
        return MLXModel(modelName: modelName, modelPath: modelPath, variant: variant)
    }
    
    /// Creates an MLX model with custom configuration
    /// - Parameters:
    ///   - config: Custom model configuration
    ///   - modelPath: Local path where the model is stored
    /// - Returns: Configured MLXModel instance
    public static func createModel(with config: MLXModelConfig, at modelPath: URL) -> MLXModel {
        return MLXModel(config: config, modelPath: modelPath)
    }
    
    // MARK: - Private Helpers
    
    private static func extractModelName(from huggingFaceId: String) -> String {
        let components = huggingFaceId.components(separatedBy: "/")
        return components.last ?? huggingFaceId
    }
    
    private static func extractVariant(from huggingFaceId: String) -> String {
        let modelName = extractModelName(from: huggingFaceId)
        
        if modelName.contains("large") { return "large" }
        if modelName.contains("medium") { return "medium" }
        if modelName.contains("small") { return "small" }
        if modelName.contains("tiny") { return "tiny" }
        
        return "base"
    }
}