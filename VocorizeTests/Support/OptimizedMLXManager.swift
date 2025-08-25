//
//  OptimizedMLXManager.swift
//  VocorizeTests
//
//  Optimized MLX framework manager for reducing initialization overhead in tests
//  Implements lazy loading, instance sharing, and performance optimization strategies
//

import Foundation
import os.log
import Testing

#if canImport(MLX)
import MLX
#endif

#if canImport(MLXNN)
import MLXNN
#endif

/// Optimized MLX framework manager that minimizes initialization overhead
/// Implements singleton pattern with lazy loading and resource sharing
public class OptimizedMLXManager {
    
    // MARK: - Singleton Instance
    
    public static let shared = OptimizedMLXManager()
    
    // MARK: - Configuration
    
    public struct OptimizationConfig {
        let enableLazyLoading: Bool
        let enableInstanceSharing: Bool
        let enableMemoryPooling: Bool
        let enablePreWarming: Bool
        let maxSharedInstances: Int
        let warmupDelayMs: Int
        
        public static let aggressive = OptimizationConfig(
            enableLazyLoading: true,
            enableInstanceSharing: true,
            enableMemoryPooling: true,
            enablePreWarming: true,
            maxSharedInstances: 3,
            warmupDelayMs: 100
        )
        
        public static let balanced = OptimizationConfig(
            enableLazyLoading: true,
            enableInstanceSharing: true,
            enableMemoryPooling: false,
            enablePreWarming: false,
            maxSharedInstances: 2,
            warmupDelayMs: 0
        )
        
        public static let conservative = OptimizationConfig(
            enableLazyLoading: true,
            enableInstanceSharing: false,
            enableMemoryPooling: false,
            enablePreWarming: false,
            maxSharedInstances: 1,
            warmupDelayMs: 0
        )
    }
    
    // MARK: - State Management
    
    private var config = OptimizationConfig.balanced
    private var isInitialized = false
    private var isInitializing = false
    private var initializationTask: Task<Void, Never>?
    
    // Resource pools
    private var mlxInstancePool: [AnyObject] = []
    private var mlxNNInstancePool: [AnyObject] = []
    private var metalResourcePool: [String: AnyObject] = [:]
    
    // Performance tracking
    private var initializationTimes: [TimeInterval] = []
    private var memoryUsageHistory: [UInt64] = []
    
    private let logger = Logger(subsystem: "com.vocorize.tests", category: "mlx-optimization")
    private let queue = DispatchQueue(label: "mlx.optimization", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure optimization settings
    public func configure(_ newConfig: OptimizationConfig) {
        queue.sync {
            self.config = newConfig
            logger.info("MLX optimization configured: lazy=\(newConfig.enableLazyLoading), sharing=\(newConfig.enableInstanceSharing)")
        }
    }
    
    // MARK: - Optimized Initialization
    
    /// Get or create an optimized MLX instance with minimal overhead
    public func getOptimizedMLXInstance() async -> MLXInstance? {
        if config.enableInstanceSharing && !mlxInstancePool.isEmpty {
            return await reuseMLXInstance()
        }
        
        if config.enableLazyLoading && !isInitialized && !isInitializing {
            return await initializeMLXLazily()
        }
        
        return await createFreshMLXInstance()
    }
    
    /// Pre-warm MLX framework for faster subsequent access
    public func preWarmMLX() async {
        guard config.enablePreWarming && !isInitialized else { return }
        
        logger.info("Pre-warming MLX framework")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        initializationTask = Task {
            await performPreWarmInitialization()
        }
        
        await initializationTask?.value
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        initializationTimes.append(duration)
        logger.info("MLX pre-warming completed in \(String(format: "%.2f", duration))s")
    }
    
    /// Fast initialization check without full framework loading
    public func isMLXAvailableQuickly() -> Bool {
        // Quick compile-time check without runtime initialization
        #if canImport(MLX) && canImport(MLXNN)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Resource Management
    
    /// Release shared resources to free memory
    public func releaseSharedResources() {
        queue.sync {
            mlxInstancePool.removeAll()
            mlxNNInstancePool.removeAll()
            metalResourcePool.removeAll()
            
            let memoryUsage = getCurrentMemoryUsage()
            memoryUsageHistory.append(memoryUsage)
            
            logger.info("Released MLX shared resources, memory: \(memoryUsage / 1_000_000)MB")
        }
    }
    
    /// Get performance statistics for optimization analysis
    public func getPerformanceStats() -> OptimizationStats {
        return queue.sync {
            OptimizationStats(
                initializationTimes: initializationTimes,
                averageInitTime: initializationTimes.isEmpty ? 0 : initializationTimes.reduce(0, +) / Double(initializationTimes.count),
                memoryUsage: memoryUsageHistory.last ?? 0,
                sharedInstancesCount: mlxInstancePool.count + mlxNNInstancePool.count,
                isPreWarmed: isInitialized,
                optimizationLevel: getOptimizationLevel()
            )
        }
    }
    
    // MARK: - Testing Support
    
    /// Create mock MLX instance for unit tests that don't require real MLX
    public func createMockMLXInstance() -> MockMLXInstance {
        logger.info("Creating mock MLX instance for testing")
        return MockMLXInstance()
    }
    
    /// Prepare test environment with optimal MLX setup
    public func prepareTestEnvironment() async -> TestEnvironmentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        var result = TestEnvironmentResult(
            setupTime: 0,
            memoryOverhead: 0,
            isOptimized: false,
            availableFeatures: []
        )
        
        // Quick availability check
        if !isMLXAvailableQuickly() {
            result.availableFeatures.append("mock_only")
            result.setupTime = CFAbsoluteTimeGetCurrent() - startTime
            return result
        }
        
        // Optimized setup based on configuration
        if config.enablePreWarming {
            await preWarmMLX()
            result.availableFeatures.append("pre_warmed")
        }
        
        if config.enableInstanceSharing {
            result.availableFeatures.append("instance_sharing")
        }
        
        if config.enableLazyLoading {
            result.availableFeatures.append("lazy_loading")
        }
        
        result.setupTime = CFAbsoluteTimeGetCurrent() - startTime
        result.memoryOverhead = getCurrentMemoryUsage() - startMemory
        result.isOptimized = true
        
        logger.info("Test environment prepared in \(String(format: "%.2f", result.setupTime))s")
        return result
    }
    
    // MARK: - Private Implementation
    
    private func reuseMLXInstance() async -> MLXInstance? {
        return queue.sync {
            if let instance = mlxInstancePool.first as? MLXInstance {
                logger.debug("Reusing shared MLX instance")
                return instance
            }
            return nil
        }
    }
    
    private func initializeMLXLazily() async -> MLXInstance? {
        guard !isInitializing else {
            // Wait for ongoing initialization
            await initializationTask?.value
            return await reuseMLXInstance()
        }
        
        isInitializing = true
        initializationTask = Task {
            await performLazyInitialization()
        }
        
        await initializationTask?.value
        isInitializing = false
        
        return await reuseMLXInstance()
    }
    
    private func createFreshMLXInstance() async -> MLXInstance? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        #if canImport(MLX) && canImport(MLXNN)
        let instance = MLXInstance()
        
        if config.enableInstanceSharing && mlxInstancePool.count < config.maxSharedInstances {
            queue.sync {
                mlxInstancePool.append(instance)
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        initializationTimes.append(duration)
        
        logger.info("Created fresh MLX instance in \(String(format: "%.2f", duration))s")
        return instance
        #else
        logger.warning("MLX not available, cannot create instance")
        return nil
        #endif
    }
    
    private func performPreWarmInitialization() async {
        logger.info("Starting MLX pre-warm initialization")
        
        #if canImport(MLX) && canImport(MLXNN)
        // Pre-load critical components
        _ = await loadMLXCore()
        _ = await loadMLXNN()
        
        if config.enableMemoryPooling {
            await createMemoryPool()
        }
        
        isInitialized = true
        logger.info("MLX pre-warm initialization completed")
        #else
        logger.warning("MLX not available for pre-warming")
        #endif
    }
    
    private func performLazyInitialization() async {
        logger.info("Starting MLX lazy initialization")
        
        #if canImport(MLX) && canImport(MLXNN)
        // Lazy load only what's needed
        if await loadMLXCore() {
            logger.debug("MLX core loaded successfully")
        }
        
        // Add delay if configured to prevent resource contention
        if config.warmupDelayMs > 0 {
            try? await Task.sleep(nanoseconds: UInt64(config.warmupDelayMs * 1_000_000))
        }
        
        isInitialized = true
        logger.info("MLX lazy initialization completed")
        #else
        logger.warning("MLX not available for lazy initialization")
        #endif
    }
    
    private func loadMLXCore() async -> Bool {
        #if canImport(MLX)
        // Simulate MLX core loading with minimal overhead
        return true
        #else
        return false
        #endif
    }
    
    private func loadMLXNN() async -> Bool {
        #if canImport(MLXNN)
        // Simulate MLXNN loading with minimal overhead
        return true
        #else
        return false
        #endif
    }
    
    private func createMemoryPool() async {
        guard config.enableMemoryPooling else { return }
        
        logger.info("Creating MLX memory pool")
        // Memory pool creation would be implemented here for production use
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getOptimizationLevel() -> String {
        var features: [String] = []
        if config.enableLazyLoading { features.append("lazy") }
        if config.enableInstanceSharing { features.append("sharing") }
        if config.enableMemoryPooling { features.append("pooling") }
        if config.enablePreWarming { features.append("prewarming") }
        
        return features.isEmpty ? "none" : features.joined(separator: "+")
    }
}

// MARK: - Supporting Types

/// MLX instance wrapper for optimization
public class MLXInstance {
    private let id = UUID()
    
    public init() {}
    
    public var identifier: String {
        return id.uuidString
    }
}

/// Mock MLX instance for unit testing
public class MockMLXInstance: MLXInstance {
    override public init() {
        super.init()
    }
    
    public func simulateTranscription() async -> String {
        // Simulate quick transcription without MLX overhead
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return "Mock transcription result"
    }
}

/// Performance statistics for optimization analysis
public struct OptimizationStats {
    public let initializationTimes: [TimeInterval]
    public let averageInitTime: TimeInterval
    public let memoryUsage: UInt64
    public let sharedInstancesCount: Int
    public let isPreWarmed: Bool
    public let optimizationLevel: String
    
    public var performanceGrade: String {
        switch averageInitTime {
        case 0..<1.0: return "A"
        case 1.0..<3.0: return "B"
        case 3.0..<10.0: return "C"
        default: return "F"
        }
    }
}

/// Test environment preparation result
public struct TestEnvironmentResult {
    public var setupTime: TimeInterval
    public var memoryOverhead: UInt64
    public var isOptimized: Bool
    public var availableFeatures: [String]
    
    public var isAcceptable: Bool {
        return setupTime < 5.0 && memoryOverhead < 100_000_000 // < 5s and < 100MB
    }
}

// MARK: - Testing Extensions

@available(iOS 13.0, macOS 10.15, *)
extension OptimizedMLXManager {
    
    /// Benchmark the optimization effectiveness
    public func benchmarkOptimizations() async -> BenchmarkResult {
        logger.info("Starting MLX optimization benchmark")
        
        var results: [String: TimeInterval] = [:]
        
        // Benchmark without optimization
        configure(.conservative)
        let conservativeTime = await measureInitializationTime()
        results["conservative"] = conservativeTime
        
        // Benchmark with balanced optimization
        configure(.balanced)
        let balancedTime = await measureInitializationTime()
        results["balanced"] = balancedTime
        
        // Benchmark with aggressive optimization
        configure(.aggressive)
        let aggressiveTime = await measureInitializationTime()
        results["aggressive"] = aggressiveTime
        
        let improvement = (conservativeTime - aggressiveTime) / conservativeTime * 100
        
        logger.info("Optimization benchmark completed, improvement: \(String(format: "%.1f", improvement))%")
        
        return BenchmarkResult(
            results: results,
            bestConfiguration: aggressiveTime < balancedTime ? "aggressive" : "balanced",
            performanceImprovement: improvement
        )
    }
    
    private func measureInitializationTime() async -> TimeInterval {
        releaseSharedResources() // Reset state
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = await getOptimizedMLXInstance()
        return CFAbsoluteTimeGetCurrent() - startTime
    }
}

/// Benchmark result for optimization comparison
public struct BenchmarkResult {
    public let results: [String: TimeInterval]
    public let bestConfiguration: String
    public let performanceImprovement: Double
    
    public var summary: String {
        var summary = "MLX Optimization Benchmark Results:\n"
        for (config, time) in results.sorted(by: { $0.value < $1.value }) {
            summary += "- \(config.capitalized): \(String(format: "%.2f", time))s\n"
        }
        summary += "Best Configuration: \(bestConfiguration) "
        summary += "(\(String(format: "%.1f", performanceImprovement))% improvement)"
        return summary
    }
}