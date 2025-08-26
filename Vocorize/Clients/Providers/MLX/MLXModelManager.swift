//
//  MLXModelManager.swift
//  Vocorize
//
//  Thread-safe MLX model management actor
//  Handles loading, unloading, caching, and lifecycle management of MLX models
//

import Foundation
import os.log

#if canImport(MLX) && canImport(MLXNN)
import MLX
import MLXNN
#endif

/// Thread-safe actor for managing MLX model lifecycle and memory
/// Only one model can be loaded at a time to optimize memory usage
@available(macOS 13.0, *)
public actor MLXModelManager {
    
    // MARK: - Types
    
    /// Model loading state
    public enum ModelState {
        case notLoaded
        case loading(progress: Double)
        case loaded(model: String)
        case error(Error)
    }
    
    /// Memory usage information
    public struct MemoryUsage {
        public let totalMemory: UInt64
        public let usedMemory: UInt64
        public let availableMemory: UInt64
        public let modelMemory: UInt64
        
        public var memoryPressure: Double {
            guard totalMemory > 0 else { return 0.0 }
            return Double(usedMemory) / Double(totalMemory)
        }
    }
    
    /// Model loading error types
    public enum ModelError: LocalizedError, Equatable {
        case modelNotFound(String)
        case loadingInProgress(String)
        case memoryPressure(Double)
        case invalidModelFormat(String)
        case frameworkNotAvailable
        case loadTimeout(String)
        case modelCorrupted(String)
        
        public var errorDescription: String? {
            switch self {
            case .modelNotFound(let name):
                return "MLX model '\(name)' not found or not downloaded"
            case .loadingInProgress(let name):
                return "MLX model '\(name)' is currently being loaded"
            case .memoryPressure(let pressure):
                return "Insufficient memory to load MLX model (pressure: \(Int(pressure * 100))%)"
            case .invalidModelFormat(let name):
                return "MLX model '\(name)' has invalid or unsupported format"
            case .frameworkNotAvailable:
                return "MLX framework is not available on this system"
            case .loadTimeout(let name):
                return "Loading MLX model '\(name)' timed out"
            case .modelCorrupted(let name):
                return "MLX model '\(name)' appears to be corrupted"
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// Logger for debugging and monitoring
    private let logger = Logger(subsystem: "com.tanvir.Vocorize", category: "MLXModelManager")
    
    /// Current model state
    private var currentState: ModelState = .notLoaded
    
    /// Loaded model reference (MLX-specific types)
    #if canImport(MLX) && canImport(MLXNN)
    private var loadedModel: Any?
    #endif
    
    /// Currently loaded model name
    private var loadedModelName: String?
    
    /// Model loading task for cancellation
    private var loadingTask: Task<Void, Error>?
    
    /// Memory cache for model metadata
    private var modelCache: [String: Any] = [:]
    
    /// Maximum memory pressure threshold (80%)
    private let maxMemoryPressure: Double = 0.8
    
    /// Model loading timeout (5 minutes)
    private let loadingTimeout: TimeInterval = 300.0
    
    // MARK: - Initialization
    
    public init() {
        logger.info("MLXModelManager initialized")
    }
    
    deinit {
        loadingTask?.cancel()
        logger.info("MLXModelManager deinitialized")
    }
    
    // MARK: - Public Model Management
    
    /// Loads a model into memory with progress reporting
    /// - Parameters:
    ///   - modelName: Name of the model to load
    ///   - progressCallback: Callback for loading progress (0.0 to 1.0)
    /// - Returns: True if successfully loaded, false otherwise
    /// - Throws: ModelError if loading fails
    public func loadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void = { _ in }
    ) async throws -> Bool {
        logger.info("Loading MLX model: \(modelName)")
        
        // Check MLX framework availability
        guard MLXAvailability.areProductsAvailable else {
            logger.error("MLX framework not available")
            currentState = .error(ModelError.frameworkNotAvailable)
            throw ModelError.frameworkNotAvailable
        }
        
        // Check if model is already loading
        if case .loading = currentState {
            logger.warning("Model loading already in progress")
            throw ModelError.loadingInProgress(modelName)
        }
        
        // Check if same model is already loaded
        if case .loaded(let loadedName) = currentState, loadedName == modelName {
            logger.info("Model \(modelName) already loaded")
            return true
        }
        
        // Check memory pressure before loading
        let memoryUsage = await getMemoryUsage()
        if memoryUsage.memoryPressure > maxMemoryPressure {
            logger.error("High memory pressure: \(memoryUsage.memoryPressure)")
            throw ModelError.memoryPressure(memoryUsage.memoryPressure)
        }
        
        // Unload current model if different
        if case .loaded(let currentModel) = currentState, currentModel != modelName {
            logger.info("Unloading current model: \(currentModel)")
            try await unloadModel(currentModel)
        }
        
        // Update state to loading
        currentState = .loading(progress: 0.0)
        
        // Create loading task with timeout
        loadingTask = Task { [self] in
            try await withTimeout(loadingTimeout) { [self] in
                try await performModelLoading(modelName, progressCallback: progressCallback)
            }
        }
        
        do {
            try await loadingTask?.value
            currentState = .loaded(model: modelName)
            loadedModelName = modelName
            logger.info("Successfully loaded MLX model: \(modelName)")
            return true
        } catch {
            currentState = .error(error)
            loadedModelName = nil
            logger.error("Failed to load MLX model \(modelName): \(error)")
            throw error
        }
    }
    
    /// Unloads a specific model from memory
    /// - Parameter modelName: Name of the model to unload
    /// - Throws: ModelError if unloading fails
    public func unloadModel(_ modelName: String) async throws {
        logger.info("Unloading MLX model: \(modelName)")
        
        // Cancel any ongoing loading
        loadingTask?.cancel()
        loadingTask = nil
        
        // Check if this model is currently loaded
        guard let currentlyLoaded = loadedModelName, currentlyLoaded == modelName else {
            logger.info("Model \(modelName) is not currently loaded")
            return
        }
        
        #if canImport(MLX) && canImport(MLXNN)
        // Clear model reference
        loadedModel = nil
        
        // Force memory cleanup
        MLX.eval([])
        #endif
        
        // Update state
        currentState = .notLoaded
        loadedModelName = nil
        
        // Clear model from cache
        modelCache.removeValue(forKey: modelName)
        
        logger.info("Successfully unloaded MLX model: \(modelName)")
    }
    
    /// Checks if a specific model is currently loaded in memory
    /// - Parameter modelName: Name of the model to check
    /// - Returns: True if model is loaded, false otherwise
    public func isModelLoaded(_ modelName: String) async -> Bool {
        if case .loaded(let loadedName) = currentState, loadedName == modelName {
            return true
        }
        return false
    }
    
    /// Gets the name of the currently loaded model
    /// - Returns: Model name if loaded, nil otherwise
    public func getCurrentModel() async -> String? {
        if case .loaded(let modelName) = currentState {
            return modelName
        }
        return loadedModelName
    }
    
    /// Gets the current model loading state
    /// - Returns: Current ModelState
    public func getModelState() async -> ModelState {
        return currentState
    }
    
    /// Clears all cached model data and memory
    public func clearMemoryCache() async {
        logger.info("Clearing MLX model memory cache")
        
        // Cancel any loading tasks
        loadingTask?.cancel()
        loadingTask = nil
        
        #if canImport(MLX) && canImport(MLXNN)
        // Clear loaded model
        loadedModel = nil
        
        // Force MLX memory cleanup
        MLX.eval([])
        #endif
        
        // Clear cache and state
        modelCache.removeAll()
        currentState = .notLoaded
        loadedModelName = nil
        
        logger.info("MLX model memory cache cleared")
    }
    
    /// Gets current memory usage information
    /// - Returns: MemoryUsage struct with detailed memory information
    public func getMemoryUsage() async -> MemoryUsage {
        let memoryInfo = getSystemMemoryInfo()
        let modelMemory = getModelMemoryUsage()
        
        return MemoryUsage(
            totalMemory: memoryInfo.totalMemory,
            usedMemory: memoryInfo.usedMemory,
            availableMemory: memoryInfo.availableMemory,
            modelMemory: modelMemory
        )
    }
    
    // MARK: - Private Implementation
    
    /// Performs the actual model loading with conditional compilation
    private func performModelLoading(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws {
        
        #if canImport(MLX) && canImport(MLXNN)
        
        // Create progress tracker
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 0
        progressCallback(progress)
        
        // Simulate model loading phases
        // Phase 1: Model file validation (0-20%)
        try await validateModelFiles(modelName)
        progress.completedUnitCount = 20
        progressCallback(progress)
        
        // Phase 2: Memory allocation (20-40%)
        try await allocateModelMemory(modelName)
        progress.completedUnitCount = 40
        progressCallback(progress)
        
        // Phase 3: Model loading (40-80%)
        try await loadModelFromDisk(modelName) { loadingProgress in
            let totalProgress = 40 + (loadingProgress * 40)
            progress.completedUnitCount = Int64(totalProgress)
            progressCallback(progress)
        }
        
        // Phase 4: Model initialization (80-100%)
        try await initializeModel(modelName)
        progress.completedUnitCount = 100
        progressCallback(progress)
        
        #else
        
        // Framework not available, throw error
        throw ModelError.frameworkNotAvailable
        
        #endif
    }
    
    #if canImport(MLX) && canImport(MLXNN)
    
    /// Validates model files exist and are readable
    private func validateModelFiles(_ modelName: String) async throws {
        logger.debug("Validating model files for: \(modelName)")
        
        // Check if model exists in expected location
        let modelPath = getModelPath(for: modelName)
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelNotFound(modelName)
        }
        
        // Additional validation can be added here
        // Check file size, format, integrity, etc.
    }
    
    /// Allocates memory for model loading
    private func allocateModelMemory(_ modelName: String) async throws {
        logger.debug("Allocating memory for model: \(modelName)")
        
        let memoryUsage = await getMemoryUsage()
        if memoryUsage.memoryPressure > maxMemoryPressure {
            throw ModelError.memoryPressure(memoryUsage.memoryPressure)
        }
        
        // Pre-allocate memory if needed
        // This is a placeholder for actual MLX memory allocation
    }
    
    /// Loads model from disk using MLX APIs
    private func loadModelFromDisk(
        _ modelName: String,
        progressCallback: @escaping (Double) -> Void
    ) async throws {
        logger.debug("Loading model from disk: \(modelName)")
        
        // Simulate incremental loading with progress updates
        for i in 0..<10 {
            try Task.checkCancellation()
            
            // Simulate loading work
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            let progress = Double(i + 1) / 10.0
            progressCallback(progress)
        }
        
        // Store reference to loaded model
        // This would be the actual MLX model loading code
        loadedModel = modelName // Placeholder
    }
    
    /// Initializes the loaded model
    private func initializeModel(_ modelName: String) async throws {
        logger.debug("Initializing model: \(modelName)")
        
        // Perform model initialization
        // Warm up, validate, etc.
        
        // Cache model metadata
        modelCache[modelName] = [
            "loadedAt": Date(),
            "memoryUsage": getModelMemoryUsage()
        ]
    }
    
    #endif
    
    /// Gets the file path for a model
    private func getModelPath(for modelName: String) -> URL {
        // Use similar path structure as WhisperKitProvider
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsURL = appSupportURL
            .appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("mlx", isDirectory: true)
        
        return modelsURL.appendingPathComponent(modelName, isDirectory: true)
    }
    
    /// Gets system memory information
    private func getSystemMemoryInfo() -> (totalMemory: UInt64, usedMemory: UInt64, availableMemory: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = UInt64(info.resident_size)
            // Estimate total memory (this is simplified)
            let totalMemory = UInt64(ProcessInfo.processInfo.physicalMemory)
            let availableMemory = totalMemory - usedMemory
            
            return (totalMemory, usedMemory, availableMemory)
        }
        
        // Fallback values
        let totalMemory = UInt64(ProcessInfo.processInfo.physicalMemory)
        return (totalMemory, 0, totalMemory)
    }
    
    /// Gets model-specific memory usage
    private func getModelMemoryUsage() -> UInt64 {
        #if canImport(MLX) && canImport(MLXNN)
        if loadedModel != nil {
            // This would calculate actual model memory usage
            // For now, return estimated value
            return 1_000_000_000 // 1GB estimate
        }
        #endif
        return 0
    }
}

// MARK: - Timeout Utility

extension MLXModelManager {
    
    /// Executes a task with timeout
    private func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask { [self] in
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ModelError.loadTimeout(await loadedModelName ?? "unknown")
            }
            
            // Return the first completed result
            let result = try await group.next()!
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
}

// MARK: - MLXAvailability Integration

extension MLXModelManager {
    
    /// Checks if MLX is available and compatible
    public static func isMLXAvailable() -> Bool {
        return MLXAvailability.areProductsAvailable && MLXAvailability.isVersionCompatible
    }
    
    /// Gets MLX system compatibility info
    public static func getSystemCompatibility() -> (available: Bool, reason: String) {
        if !MLXAvailability.isFrameworkAvailable {
            return (false, "MLX framework not available")
        }
        
        if !MLXAvailability.areProductsAvailable {
            return (false, "MLX products (MLX/MLXNN) not available")
        }
        
        if !MLXAvailability.isVersionCompatible {
            return (false, "MLX version not compatible")
        }
        
        return (true, "MLX is available and compatible")
    }
}