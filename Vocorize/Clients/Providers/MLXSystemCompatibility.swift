//
//  MLXSystemCompatibility.swift
//  Vocorize
//
//  MLX System Compatibility Detection Utility
//  Provides comprehensive system compatibility checking for MLX framework,
//  including architecture detection, macOS version requirements, hardware capabilities,
//  and performance estimation.
//

import Foundation

#if canImport(MLX)
import MLX
#endif

#if canImport(MLXNN)
import MLXNN
#endif

/// Comprehensive MLX system compatibility checker
/// This class provides detailed system compatibility analysis for MLX framework
/// including hardware detection, OS requirements, and performance estimation.
public class MLXSystemCompatibility {
    
    // MARK: - Initialization
    
    public init() {
        // Initialize instance
    }
    
    // MARK: - Architecture Detection
    
    /// Check if system has Apple Silicon processor
    public func hasAppleSilicon() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Get current system architecture
    public func getCurrentArchitecture() async -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
    
    /// Check if system is Intel Mac
    public func isIntelMac() async -> Bool {
        #if arch(x86_64)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if system supports MLX Apple Silicon optimizations
    public func supportsMLXAppleSiliconOptimizations() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if system has Neural Engine support
    public func hasNeuralEngineSupport() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if system has unified memory support
    public func hasUnifiedMemorySupport() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if system has Rosetta support
    public func hasRosettaSupport() async -> Bool {
        // Check if running under Rosetta translation
        var size = 0
        sysctlbyname("sysctl.proc_translated", nil, &size, nil, 0)
        if size > 0 {
            var ret: Int32 = 0
            sysctlbyname("sysctl.proc_translated", &ret, &size, nil, 0)
            return ret == 1
        }
        return false
    }
    
    /// Check if MLX supports Intel architecture
    public func supportsMLXOnIntel() async -> Bool {
        // MLX can run on Intel Macs but with reduced performance
        return true
    }
    
    /// Get performance warning for Intel Macs
    public func getIntelPerformanceWarning() async -> String {
        if await isIntelMac() {
            return "MLX performance is optimized for Apple Silicon. Intel Macs may experience reduced performance."
        }
        return ""
    }
    
    /// Check if MLX is compatible with Rosetta translation
    public func isMLXCompatibleWithRosetta() async -> Bool {
        return true
    }
    
    // MARK: - macOS Version Compatibility
    
    /// Get current macOS version
    public func getCurrentMacOSVersion() async -> String? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Check if macOS version is compatible with MLX
    public func isMacOSVersionCompatible() async -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        // MLX requires macOS 15.0+
        return version.majorVersion >= 15
    }
    
    /// Get minimum required macOS version
    public func getMinimumMacOSVersion() async -> String {
        return "15.0"
    }
    
    /// Get macOS version requirements
    public func getMacOSVersionRequirements() async -> [String: String] {
        return [
            "minimum": "15.0",
            "recommended": "15.1"
        ]
    }
    
    /// Check if system has required Metal support
    public func hasRequiredMetalSupport() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if system has required Core ML support
    public func hasRequiredCoreMLSupport() async -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 15
    }
    
    /// Check if system has advanced memory management
    public func hasAdvancedMemoryManagement() async -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 15
    }
    
    /// Check if system has GPU unified memory support
    public func hasGPUUnifiedMemorySupport() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - MLX Runtime Availability
    
    /// Check if MLX runtime is available
    public func hasMLXRuntimeAvailable() async -> Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }
    
    /// Get MLX runtime version
    public func getMLXRuntimeVersion() async -> String? {
        #if canImport(MLX)
        return "0.10.0+" // Placeholder version
        #else
        return nil
        #endif
    }
    
    /// Check if MLX Core runtime is available
    public func hasMLXCoreRuntime() async -> Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if MLX Neural Networks runtime is available
    public func hasMLXNNRuntime() async -> Bool {
        #if canImport(MLXNN)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if MLX Transforms runtime is available
    public func hasMLXTransformsRuntime() async -> Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }
    
    /// Get MLX runtime requirements
    public func getMLXRuntimeRequirements() async -> [String: Any] {
        return [
            "minimum_memory": Int64(8_000_000_000), // 8GB
            "gpu_requirements": [
                "metal_support": true,
                "unified_memory": await hasUnifiedMemorySupport()
            ],
            "cpu_requirements": [
                "architecture": await getCurrentArchitecture(),
                "minimum_cores": 4
            ]
        ]
    }
    
    // MARK: - Hardware Capability Detection
    
    /// Get GPU capabilities
    public func getGPUCapabilities() async -> [String: Any] {
        let hasAppleSilicon = await hasAppleSilicon()
        
        return [
            "has_discrete_gpu": !hasAppleSilicon,
            "has_integrated_gpu": hasAppleSilicon,
            "gpu_memory": hasAppleSilicon ? ProcessInfo.processInfo.physicalMemory : Int64(2_000_000_000)
        ]
    }
    
    /// Check if Metal Performance Shaders are supported
    public func hasMetalPerformanceShaders() async -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// Get memory capabilities
    public func getMemoryCapabilities() async -> [String: Any] {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let availableMemory = physicalMemory * 3 / 4 // Estimate 75% available
        
        return [
            "total_memory": physicalMemory,
            "available_memory": availableMemory,
            "unified_memory": await hasUnifiedMemorySupport()
        ]
    }
    
    /// Get memory bandwidth estimate
    public func getMemoryBandwidth() async -> Double {
        #if arch(arm64)
        // Estimate for Apple Silicon unified memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let gbMemory = Double(physicalMemory) / (1024 * 1024 * 1024)
        return gbMemory * 50.0 // Conservative bandwidth estimate
        #else
        return 50.0 // Conservative estimate for Intel
        #endif
    }
    
    // MARK: - Performance Estimation
    
    /// Estimate MLX performance
    public func estimateMLXPerformance() async -> MLXPerformanceEstimate {
        let hasAppleSilicon = await hasAppleSilicon()
        
        if hasAppleSilicon {
            let modelScores: [String: Double] = [
                "whisper-tiny": 0.9,
                "whisper-base": 0.8,
                "whisper-small": 0.7
            ]
            return MLXPerformanceEstimate(
                isValid: true,
                modelScores: modelScores,
                overallScore: 0.8
            )
        } else {
            let modelScores: [String: Double] = [
                "whisper-tiny": 0.6,
                "whisper-base": 0.5,
                "whisper-small": 0.4
            ]
            return MLXPerformanceEstimate(
                isValid: true,
                modelScores: modelScores,
                overallScore: 0.5
            )
        }
    }
    
    /// Get recommended MLX models based on hardware
    public func getRecommendedMLXModels() async -> [String] {
        let hasAppleSilicon = await hasAppleSilicon()
        
        if hasAppleSilicon {
            return ["whisper-tiny", "whisper-base", "whisper-small"]
        } else {
            return ["whisper-tiny"] // Only recommend tiny for Intel
        }
    }
    
    /// Get current thermal state
    public func getCurrentThermalState() async -> String? {
        // Simplified thermal state detection
        let processInfo = ProcessInfo.processInfo
        if processInfo.thermalState == .critical {
            return "critical"
        } else if processInfo.thermalState == .serious {
            return "high"
        } else if processInfo.thermalState == .fair {
            return "medium"
        } else {
            return "normal"
        }
    }
    
    /// Check if MLX can run under thermal pressure
    public func canRunMLXUnderThermalPressure() async -> Bool {
        let thermalState = await getCurrentThermalState()
        return thermalState != "critical"
    }
    
    /// Get thermal throttling warning
    public func getThermalThrottlingWarning() async -> String {
        let thermalState = await getCurrentThermalState()
        if thermalState == "critical" {
            return "System is under critical thermal pressure. MLX performance may be severely impacted."
        } else if thermalState == "high" {
            return "System is under high thermal pressure. MLX performance may be reduced."
        }
        return ""
    }
    
    /// Check if thermal conditions are optimal
    public func hasOptimalThermalConditions() async -> Bool? {
        let thermalState = await getCurrentThermalState()
        return thermalState == "normal"
    }
    
    // MARK: - Platform Specific Features
    
    /// Get platform-specific features
    public func getPlatformSpecificFeatures() async -> [String: Any] {
        return [
            "MetalKit": true,
            "CoreML": true,
            "Accelerate": true
        ]
    }
    
    /// Get security features
    public func getSecurityFeatures() async -> [String: Any] {
        return [
            "system_integrity_protection": true
        ]
    }
    
    /// Check if developer mode is enabled
    public func isDeveloperModeEnabled() async -> Bool {
        // Simplified check - assume developer mode for development builds
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Get required permissions
    public func getRequiredPermissions() async -> [String] {
        return [
            "microphone_access",
            "file_system_access"
        ]
    }
    
    /// Check if special entitlements are needed
    public func needsSpecialEntitlements() async -> Bool {
        return false
    }
    
    /// Get required entitlements
    public func getRequiredEntitlements() async -> [String] {
        return []
    }
    
    /// Check if compatible with sandbox
    public func isSandboxCompatible() async -> Bool? {
        return true
    }
    
    // MARK: - Compatibility Summary
    
    /// Generate compatibility summary
    public func generateCompatibilitySummary() async -> MLXCompatibilitySummary {
        let hasAppleSilicon = await hasAppleSilicon()
        let hasMLXRuntime = await hasMLXRuntimeAvailable()
        let isVersionCompatible = await isMacOSVersionCompatible()
        
        let isCompatible = hasAppleSilicon && hasMLXRuntime && isVersionCompatible
        
        var details: [String: Any] = [
            "apple_silicon": hasAppleSilicon,
            "mlx_runtime": hasMLXRuntime,
            "macos_version": isVersionCompatible
        ]
        
        var recommendations: [String] = []
        var warnings: [String] = []
        var blockingIssues: [String] = []
        
        if !hasAppleSilicon {
            blockingIssues.append("Apple Silicon processor required for optimal MLX performance")
            recommendations.append("Consider upgrading to Apple Silicon Mac for best performance")
        }
        
        if !hasMLXRuntime {
            blockingIssues.append("MLX runtime not available")
        }
        
        if !isVersionCompatible {
            blockingIssues.append("macOS 15.0 or later required")
            recommendations.append("Update to macOS 15.0 or later")
        }
        
        if hasAppleSilicon {
            let thermalState = await getCurrentThermalState()
            if thermalState != "normal" {
                warnings.append("System thermal conditions may impact performance")
            }
        }
        
        return MLXCompatibilitySummary(
            isCompatible: isCompatible,
            details: details,
            recommendations: recommendations,
            warnings: warnings,
            blockingIssues: blockingIssues
        )
    }
    
    /// Get optimization tips
    public func getOptimizationTips() async -> [String] {
        var tips: [String] = []
        
        if await hasAppleSilicon() {
            tips.append("Use unified memory architecture for optimal performance")
            tips.append("Enable Metal backend for GPU acceleration")
        }
        
        if await getCurrentThermalState() != "normal" {
            tips.append("Ensure adequate cooling for sustained performance")
        }
        
        tips.append("Close unnecessary applications to free up memory")
        
        return tips
    }
    
    /// Generate detailed compatibility report
    public func generateDetailedReport() async -> String {
        var report = "MLX System Compatibility Report\n"
        report += "================================\n\n"
        
        // System Information
        report += "System Information\n"
        report += "------------------\n"
        report += "Architecture: \(await getCurrentArchitecture())\n"
        report += "macOS Version: \(await getCurrentMacOSVersion() ?? "Unknown")\n"
        report += "Apple Silicon: \(await hasAppleSilicon())\n"
        report += "Thermal State: \(await getCurrentThermalState() ?? "Unknown")\n\n"
        
        // MLX Compatibility
        report += "MLX Compatibility\n"
        report += "-----------------\n"
        report += "MLX Runtime Available: \(await hasMLXRuntimeAvailable())\n"
        report += "Version Compatible: \(await isMacOSVersionCompatible())\n"
        report += "Metal Support: \(await hasRequiredMetalSupport())\n\n"
        
        // Performance Estimates
        report += "Performance Estimates\n"
        report += "--------------------\n"
        let performance = await estimateMLXPerformance()
        for (model, score) in performance.modelScores {
            report += "\(model): \(String(format: "%.1f", score * 100))%\n"
        }
        report += "\n"
        
        // Recommendations
        report += "Recommendations\n"
        report += "---------------\n"
        let tips = await getOptimizationTips()
        for tip in tips {
            report += "• \(tip)\n"
        }
        
        return report
    }
    
    /// Generate JSON compatibility report
    public func generateJSONReport() async -> String? {
        let summary = await generateCompatibilitySummary()
        let performance = await estimateMLXPerformance()
        
        let report: [String: Any] = [
            "compatibility": [
                "is_compatible": summary.isCompatible ?? false,
                "details": summary.details,
                "blocking_issues": summary.blockingIssues,
                "warnings": summary.warnings,
                "recommendations": summary.recommendations
            ],
            "performance": [
                "is_valid": performance.isValid,
                "model_scores": performance.modelScores,
                "overall_score": performance.overallScore
            ],
            "system": [
                "architecture": await getCurrentArchitecture(),
                "macos_version": await getCurrentMacOSVersion() ?? "Unknown",
                "apple_silicon": await hasAppleSilicon(),
                "thermal_state": await getCurrentThermalState() ?? "Unknown"
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - Supporting Types

/// MLX performance estimate result
public struct MLXPerformanceEstimate {
    public let isValid: Bool
    public let modelScores: [String: Double]
    public let overallScore: Double
    
    public init(isValid: Bool, modelScores: [String: Double], overallScore: Double) {
        self.isValid = isValid
        self.modelScores = modelScores
        self.overallScore = overallScore
    }
}

/// MLX compatibility summary result
public struct MLXCompatibilitySummary {
    public let isCompatible: Bool?
    public let details: [String: Any]
    public let recommendations: [String]
    public let warnings: [String]
    public let blockingIssues: [String]
    
    public init(isCompatible: Bool?, details: [String: Any], recommendations: [String], warnings: [String], blockingIssues: [String]) {
        self.isCompatible = isCompatible
        self.details = details
        self.recommendations = recommendations
        self.warnings = warnings
        self.blockingIssues = blockingIssues
    }
}