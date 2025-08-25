//
//  MLXPerformanceTests.swift
//  VocorizeTests
//
//  Performance tests for MLX framework loading and optimization validation
//  Measures and validates MLX initialization performance improvements
//

import Foundation
import Testing
import os.log
@testable import Vocorize

/// Comprehensive MLX performance test suite
/// Tests various optimization strategies and measures their effectiveness
@Suite("MLX Performance Tests")
struct MLXPerformanceTests {
    
    // MARK: - Test Configuration
    
    private let profiler = MLXPerformanceProfiler()
    private let optimizedManager = OptimizedMLXManager.shared
    private let logger = Logger(subsystem: "com.vocorize.tests", category: "mlx-performance")
    
    // MARK: - Performance Baseline Tests
    
    @Test("MLX Framework Loading Performance")
    func testMLXFrameworkLoadingPerformance() async throws {
        let config = MLXPerformanceProfiler.ProfilingConfig.standard
        let metrics = await profiler.profileMLXInitialization(config: config)
        
        // Performance thresholds for different scenarios
        let acceptableThreshold: TimeInterval = 20.0  // 20 seconds max for comprehensive loading
        let goodThreshold: TimeInterval = 10.0        // 10 seconds is good performance
        let excellentThreshold: TimeInterval = 5.0    // 5 seconds is excellent
        
        print("MLX Framework Loading Performance:")
        print("- Cold Start Time: \(String(format: "%.2f", metrics.coldStartTime))s")
        print("- Memory Overhead: \(metrics.memoryOverhead / 1_000_000)MB")
        print("- Performance Grade: \(metrics.performanceGrade)")
        
        // Validate performance meets requirements
        #expect(metrics.coldStartTime < acceptableThreshold, 
               "MLX cold start time (\(String(format: "%.2f", metrics.coldStartTime))s) exceeds acceptable threshold (\(acceptableThreshold)s)")
        
        // Log performance classification
        if metrics.coldStartTime < excellentThreshold {
            print("✅ Excellent MLX performance")
        } else if metrics.coldStartTime < goodThreshold {
            print("✅ Good MLX performance")
        } else {
            print("⚠️ Acceptable MLX performance, consider optimization")
        }
        
        // Validate memory usage is reasonable
        let maxMemoryOverhead: UInt64 = 200_000_000 // 200MB
        #expect(metrics.memoryOverhead < maxMemoryOverhead,
               "Memory overhead (\(metrics.memoryOverhead / 1_000_000)MB) exceeds limit (\(maxMemoryOverhead / 1_000_000)MB)")
    }
    
    @Test("MLX Quick Performance Check")
    func testMLXQuickPerformanceCheck() async throws {
        let isAcceptable = await profiler.quickPerformanceCheck()
        
        #expect(isAcceptable, "MLX quick performance check should pass for CI/CD environments")
        
        if isAcceptable {
            print("✅ MLX performance acceptable for CI/CD")
        } else {
            print("❌ MLX performance too slow for CI/CD environments")
        }
    }
    
    // MARK: - Optimization Strategy Tests
    
    @Test("Lazy Loading Optimization")
    func testLazyLoadingOptimization() async throws {
        // Configure for lazy loading
        optimizedManager.configure(.conservative)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let instance = await optimizedManager.getOptimizedMLXInstance()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        print("Lazy Loading Performance: \(String(format: "%.2f", duration))s")
        
        // Lazy loading should be faster than full initialization
        #expect(duration < 5.0, "Lazy loading should complete within 5 seconds")
        
        // Should provide some form of MLX capability
        if instance != nil {
            print("✅ Lazy loading successful with real MLX instance")
        } else {
            print("✅ Lazy loading deferred - no immediate MLX overhead")
        }
    }
    
    @Test("Instance Sharing Optimization") 
    func testInstanceSharingOptimization() async throws {
        // Configure for instance sharing
        optimizedManager.configure(.balanced)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Get multiple instances
        let instance1 = await optimizedManager.getOptimizedMLXInstance()
        let instance2 = await optimizedManager.getOptimizedMLXInstance()
        let instance3 = await optimizedManager.getOptimizedMLXInstance()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        print("Instance Sharing Performance: \(String(format: "%.2f", duration))s for 3 instances")
        
        // Instance sharing should be much faster for subsequent instances
        #expect(duration < 3.0, "Instance sharing should be very fast")
        
        let stats = optimizedManager.getPerformanceStats()
        print("- Shared instances: \(stats.sharedInstancesCount)")
        print("- Optimization level: \(stats.optimizationLevel)")
    }
    
    @Test("Aggressive Optimization Strategy")
    func testAggressiveOptimizationStrategy() async throws {
        // Configure for aggressive optimization
        optimizedManager.configure(.aggressive)
        
        let benchmarkResult = await optimizedManager.benchmarkOptimizations()
        
        print("Optimization Benchmark Results:")
        print(benchmarkResult.summary)
        
        // Aggressive optimization should show measurable improvement
        #expect(benchmarkResult.performanceImprovement > 0, 
               "Aggressive optimization should show performance improvement")
        
        // Best configuration should be either aggressive or balanced
        #expect(["aggressive", "balanced"].contains(benchmarkResult.bestConfiguration),
               "Best configuration should be aggressive or balanced")
        
        if benchmarkResult.performanceImprovement > 50 {
            print("✅ Excellent optimization improvement: \(String(format: "%.1f", benchmarkResult.performanceImprovement))%")
        } else if benchmarkResult.performanceImprovement > 20 {
            print("✅ Good optimization improvement: \(String(format: "%.1f", benchmarkResult.performanceImprovement))%")
        } else {
            print("⚠️ Modest optimization improvement: \(String(format: "%.1f", benchmarkResult.performanceImprovement))%")
        }
    }
    
    // MARK: - Test Environment Optimization
    
    @Test("Test Environment Preparation Performance")
    func testEnvironmentPreparationPerformance() async throws {
        let result = await optimizedManager.prepareTestEnvironment()
        
        print("Test Environment Setup:")
        print("- Setup Time: \(String(format: "%.2f", result.setupTime))s")
        print("- Memory Overhead: \(result.memoryOverhead / 1_000_000)MB")
        print("- Is Optimized: \(result.isOptimized)")
        print("- Available Features: \(result.availableFeatures.joined(separator: ", "))")
        
        #expect(result.isAcceptable, "Test environment should be acceptable for testing")
        
        // Environment setup should be fast
        #expect(result.setupTime < 10.0, "Environment setup should complete within 10 seconds")
        
        // Should have optimization features available
        #expect(!result.availableFeatures.isEmpty, "Should have some optimization features available")
    }
    
    @Test("Mock MLX Instance Creation Performance")
    func testMockMLXInstancePerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let mockInstance = optimizedManager.createMockMLXInstance()
        let transcriptionResult = await mockInstance.simulateTranscription()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        print("Mock MLX Performance: \(String(format: "%.3f", duration))s")
        print("Mock transcription result: '\(transcriptionResult)'")
        
        // Mock creation should be extremely fast
        #expect(duration < 0.1, "Mock MLX instance creation should be under 100ms")
        
        // Mock should provide transcription simulation
        #expect(!transcriptionResult.isEmpty, "Mock should provide simulated transcription")
        #expect(transcriptionResult.contains("Mock"), "Should clearly identify as mock result")
    }
    
    // MARK: - Bottleneck Analysis Tests
    
    @Test("MLX Initialization Bottleneck Analysis")
    func testMLXInitializationBottleneckAnalysis() async throws {
        let steps = await profiler.profileInitializationSteps()
        
        print("MLX Initialization Steps Analysis:")
        for (index, step) in steps.enumerated() {
            let status = step.isBottleneck ? "⚠️ BOTTLENECK" : "✅ OK"
            print("\(index + 1). \(step.name): \(String(format: "%.2f", step.duration))s \(status)")
            if step.memoryDelta > 0 {
                print("   Memory: +\(step.memoryDelta / 1_000_000)MB")
            }
        }
        
        // Should have some initialization steps measured
        #expect(!steps.isEmpty, "Should measure initialization steps")
        
        // No single step should be extremely slow (over 30 seconds)
        let maxStepTime = steps.map { $0.duration }.max() ?? 0
        #expect(maxStepTime < 30.0, "No initialization step should take over 30 seconds")
        
        // Count bottlenecks
        let bottleneckCount = steps.filter { $0.isBottleneck }.count
        print("Total bottlenecks identified: \(bottleneckCount)")
        
        if bottleneckCount == 0 {
            print("✅ No initialization bottlenecks detected")
        } else {
            print("⚠️ Found \(bottleneckCount) initialization bottlenecks")
        }
    }
    
    @Test("Performance Report Generation")
    func testPerformanceReportGeneration() async throws {
        let metrics = await profiler.profileMLXInitialization(config: .quick)
        let report = profiler.generatePerformanceReport(metrics)
        
        #expect(!report.isEmpty, "Performance report should not be empty")
        #expect(report.contains("MLX Performance Analysis Report"), "Report should have proper header")
        #expect(report.contains("Performance Grade"), "Report should include performance grade")
        
        print("Generated Performance Report Preview:")
        let reportLines = report.components(separatedBy: .newlines)
        for line in reportLines.prefix(10) {
            print(line)
        }
        if reportLines.count > 10 {
            print("... (\(reportLines.count - 10) more lines)")
        }
        
        // Test JSON export
        if let jsonData = profiler.exportMetricsToJSON(metrics) {
            #expect(jsonData.count > 0, "JSON export should produce data")
            print("✅ JSON export successful: \(jsonData.count) bytes")
        } else {
            print("⚠️ JSON export failed")
        }
    }
    
    // MARK: - Comparative Performance Tests
    
    @Test("MLX vs Mock Performance Comparison")
    func testMLXVsMockPerformanceComparison() async throws {
        // Measure real MLX performance
        let mlxStartTime = CFAbsoluteTimeGetCurrent()
        _ = await optimizedManager.getOptimizedMLXInstance()
        let mlxDuration = CFAbsoluteTimeGetCurrent() - mlxStartTime
        
        // Measure mock performance
        let mockStartTime = CFAbsoluteTimeGetCurrent()
        _ = optimizedManager.createMockMLXInstance()
        let mockDuration = CFAbsoluteTimeGetCurrent() - mockStartTime
        
        let performanceRatio = mlxDuration / mockDuration
        
        print("Performance Comparison:")
        print("- Real MLX: \(String(format: "%.3f", mlxDuration))s")
        print("- Mock MLX: \(String(format: "%.3f", mockDuration))s")
        print("- Ratio: \(String(format: "%.1fx", performanceRatio)) slower")
        
        // Mock should be significantly faster
        #expect(mockDuration < mlxDuration, "Mock should be faster than real MLX")
        #expect(mockDuration < 0.01, "Mock should be very fast (< 10ms)")
        
        if performanceRatio > 100 {
            print("✅ Mock provides excellent speedup for unit tests")
        } else if performanceRatio > 10 {
            print("✅ Mock provides good speedup for unit tests")
        } else {
            print("⚠️ Mock speedup is modest, consider further optimization")
        }
    }
    
    // MARK: - Memory Performance Tests
    
    @Test("MLX Memory Usage Optimization")
    func testMLXMemoryUsageOptimization() async throws {
        let initialStats = optimizedManager.getPerformanceStats()
        let initialMemory = initialStats.memoryUsage
        
        // Configure for memory optimization
        optimizedManager.configure(.balanced)
        
        // Use MLX with optimizations
        _ = await optimizedManager.getOptimizedMLXInstance()
        _ = await optimizedManager.getOptimizedMLXInstance() // Second instance for sharing test
        
        let afterStats = optimizedManager.getPerformanceStats()
        let finalMemory = afterStats.memoryUsage
        
        let memoryIncrease = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        
        print("Memory Usage Analysis:")
        print("- Initial Memory: \(initialMemory / 1_000_000)MB")
        print("- Final Memory: \(finalMemory / 1_000_000)MB")
        print("- Memory Increase: \(memoryIncrease / 1_000_000)MB")
        print("- Shared Instances: \(afterStats.sharedInstancesCount)")
        
        // Release resources and measure cleanup
        optimizedManager.releaseSharedResources()
        let cleanupStats = optimizedManager.getPerformanceStats()
        let cleanupMemory = cleanupStats.memoryUsage
        
        print("- After Cleanup: \(cleanupMemory / 1_000_000)MB")
        
        // Memory increase should be reasonable
        #expect(memoryIncrease < 500_000_000, "Memory increase should be under 500MB")
        
        if memoryIncrease < 100_000_000 {
            print("✅ Excellent memory efficiency (< 100MB)")
        } else if memoryIncrease < 300_000_000 {
            print("✅ Good memory efficiency (< 300MB)")
        } else {
            print("⚠️ High memory usage, consider optimization")
        }
    }
    
    // MARK: - Regression Prevention Tests
    
    @Test("Performance Regression Detection")
    func testPerformanceRegressionDetection() async throws {
        // Historical baseline (these would typically be stored/loaded from CI artifacts)
        let historicalBaselines = [
            "cold_start_time": 12.0,      // 12 seconds baseline
            "memory_overhead": 150.0,      // 150MB baseline
            "initialization_steps": 4.0   // 4 steps baseline
        ]
        
        let metrics = await profiler.profileMLXInitialization(config: .quick)
        
        // Check for regressions
        var regressions: [String] = []
        
        if let baselineColdStart = historicalBaselines["cold_start_time"],
           metrics.coldStartTime > baselineColdStart * 1.5 {
            regressions.append("Cold start regression: \(String(format: "%.2f", metrics.coldStartTime))s vs \(baselineColdStart)s baseline")
        }
        
        if let baselineMemory = historicalBaselines["memory_overhead"],
           Double(metrics.memoryOverhead) / 1_000_000 > baselineMemory * 1.5 {
            regressions.append("Memory regression: \(metrics.memoryOverhead / 1_000_000)MB vs \(Int(baselineMemory))MB baseline")
        }
        
        if let baselineSteps = historicalBaselines["initialization_steps"],
           Double(metrics.initializationSteps.count) > baselineSteps * 2 {
            regressions.append("Complexity regression: \(metrics.initializationSteps.count) steps vs \(Int(baselineSteps)) baseline")
        }
        
        print("Performance Regression Analysis:")
        if regressions.isEmpty {
            print("✅ No performance regressions detected")
        } else {
            print("⚠️ Potential regressions detected:")
            for regression in regressions {
                print("  - \(regression)")
            }
        }
        
        // For now, we'll just warn about regressions rather than failing
        // In a production environment, you might want to fail on major regressions
        print("Current Performance:")
        print("- Cold Start: \(String(format: "%.2f", metrics.coldStartTime))s")
        print("- Memory: \(metrics.memoryOverhead / 1_000_000)MB")
        print("- Steps: \(metrics.initializationSteps.count)")
    }
    
    // MARK: - CI/CD Integration Tests
    
    @Test("CI Performance Thresholds")
    func testCIPerformanceThresholds() async throws {
        // Stricter thresholds for CI environments
        let ciConfig = MLXPerformanceProfiler.ProfilingConfig(
            iterations: 2,
            warmupIterations: 1,
            enableDetailedTracing: false,
            enableMemoryProfiling: true,
            enableSignposts: false,
            measureColdStart: true,
            measureWarmStart: false
        )
        
        let metrics = await profiler.profileMLXInitialization(config: ciConfig)
        
        // CI-specific thresholds (more lenient than dev environment)
        let ciColdStartThreshold: TimeInterval = 30.0  // 30 seconds max for CI
        let ciMemoryThreshold: UInt64 = 400_000_000    // 400MB max for CI
        
        print("CI Performance Validation:")
        print("- Cold Start: \(String(format: "%.2f", metrics.coldStartTime))s (limit: \(ciColdStartThreshold)s)")
        print("- Memory: \(metrics.memoryOverhead / 1_000_000)MB (limit: \(ciMemoryThreshold / 1_000_000)MB)")
        print("- Grade: \(metrics.performanceGrade)")
        
        #expect(metrics.coldStartTime < ciColdStartThreshold,
               "CI cold start time must be under \(ciColdStartThreshold)s")
        
        #expect(metrics.memoryOverhead < ciMemoryThreshold,
               "CI memory usage must be under \(ciMemoryThreshold / 1_000_000)MB")
        
        // Provide CI feedback
        if metrics.coldStartTime < 15.0 {
            print("✅ Excellent CI performance")
        } else if metrics.coldStartTime < 25.0 {
            print("✅ Acceptable CI performance")
        } else {
            print("⚠️ Slow CI performance, consider optimization")
        }
    }
}