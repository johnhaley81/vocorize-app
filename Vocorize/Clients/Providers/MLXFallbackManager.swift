//
//  MLXFallbackManager.swift
//  Vocorize
//
//  Comprehensive MLX fallback management system
//  Handles graceful degradation when MLX is unavailable or malfunctioning
//

import Foundation

#if canImport(MLX)
import MLX
#endif

#if canImport(MLXNN)
import MLXNN
#endif

/// Manages fallback strategies when MLX is unavailable or degraded
public actor MLXFallbackManager {
    
    // MARK: - Fallback State
    
    private var fallbackMode: MLXFallbackMode = .unknown
    private var fallbackReason: String?
    private var lastHealthCheck: Date?
    
    // MARK: - Health Check Cache
    
    private static let healthCheckCacheTimeout: TimeInterval = 300 // 5 minutes
    private var cachedHealthResult: MLXAvailabilityResult?
    private var healthCheckTimestamp: Date?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Determines the appropriate MLX fallback mode
    public func determineFallbackMode() async -> MLXFallbackMode {
        // Use cached result if recent
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < Self.healthCheckCacheTimeout,
           fallbackMode != .unknown {
            return fallbackMode
        }
        
        // Perform comprehensive health check
        let healthResult = await performComprehensiveHealthCheck()
        fallbackMode = await analyzeFallbackNeeds(from: healthResult)
        fallbackReason = healthResult.errors.first
        lastHealthCheck = Date()
        
        return fallbackMode
    }
    
    /// Gets the reason for current fallback mode
    public func getFallbackReason() -> String? {
        return fallbackReason
    }
    
    /// Checks if MLX should be attempted based on current fallback mode
    public func shouldAttemptMLX() async -> Bool {
        let mode = await determineFallbackMode()
        switch mode {
        case .fullyAvailable, .partiallyAvailable:
            return true
        case .unavailable, .disabled, .unknown:
            return false
        }
    }
    
    /// Gets recommended provider type based on fallback analysis
    public func getRecommendedProviderType() async -> TranscriptionProviderType {
        let mode = await determineFallbackMode()
        switch mode {
        case .fullyAvailable, .partiallyAvailable:
            return .mlx
        case .unavailable, .disabled, .unknown:
            return .whisperKit
        }
    }
    
    // MARK: - Health Check Implementation
    
    private func performComprehensiveHealthCheck() async -> MLXAvailabilityResult {
        // Return cached result if recent
        if let cached = cachedHealthResult,
           let timestamp = healthCheckTimestamp,
           Date().timeIntervalSince(timestamp) < Self.healthCheckCacheTimeout {
            return cached
        }
        
        let availability = MLXAvailability()
        let result = await availability.performMLXHealthCheck()
        
        // Cache the result
        cachedHealthResult = result
        healthCheckTimestamp = Date()
        
        return result
    }
    
    private func analyzeFallbackNeeds(from healthResult: MLXAvailabilityResult) async -> MLXFallbackMode {
        // Check if MLX is completely unavailable
        if !healthResult.checkedComponents.contains("MLX.Core") {
            return .unavailable
        }
        
        // Check for critical errors
        let criticalErrors = healthResult.errors.filter { error in
            error.contains("not available") || 
            error.contains("initialization failed") ||
            error.contains("compilation error")
        }
        
        if !criticalErrors.isEmpty {
            return .unavailable
        }
        
        // Check for partial availability
        if healthResult.checkedComponents.count < 3 { // Expect Core, NN, Transforms
            return .partiallyAvailable
        }
        
        // Check if explicitly disabled
        if ProcessInfo.processInfo.environment["VOCORIZE_DISABLE_MLX"] == "true" {
            return .disabled
        }
        
        // All checks passed - check if we have no errors and all expected components
        if healthResult.errors.isEmpty && healthResult.checkedComponents.count >= 3 {
            return .fullyAvailable
        } else {
            return .partiallyAvailable
        }
    }
    
    // MARK: - Fallback Strategy Implementation
    
    /// Creates appropriate transcription provider based on fallback mode
    public func createTranscriptionProvider() async -> any TranscriptionProvider {
        let mode = await determineFallbackMode()
        
        switch mode {
        case .fullyAvailable:
            // TODO: Return real MLX provider when implemented
            print("📝 MLX fully available but provider not implemented, using WhisperKit")
            return await createWhisperKitFallback()
            
        case .partiallyAvailable:
            print("⚠️ MLX partially available, using WhisperKit fallback")
            return await createWhisperKitFallback()
            
        case .unavailable:
            print("❌ MLX unavailable, using WhisperKit fallback")
            return await createWhisperKitFallback()
            
        case .disabled:
            print("🚫 MLX disabled via configuration, using WhisperKit fallback")
            return await createWhisperKitFallback()
            
        case .unknown:
            print("❓ MLX status unknown, using safe WhisperKit fallback")
            return await createWhisperKitFallback()
        }
    }
    
    private func createWhisperKitFallback() async -> any TranscriptionProvider {
        // In production, return real WhisperKit provider
        // For tests, return appropriate mock
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // We're in a test environment
            // Return mock provider for tests
            fatalError("SimpleWhisperKitProvider not available in main target - use WhisperKitProvider")
        }
        #endif
        
        // TODO: Return real WhisperKit provider when available
        // For now, indicate that fallback is needed
        fatalError("WhisperKit fallback provider not yet implemented - use TranscriptionProviderFactory instead")
    }
    
    // MARK: - Monitoring and Diagnostics
    
    /// Provides detailed diagnostic information about MLX fallback status
    public func getDiagnosticInfo() async -> MLXFallbackDiagnostic {
        let mode = await determineFallbackMode()
        let healthResult = await performComprehensiveHealthCheck()
        
        return MLXFallbackDiagnostic(
            fallbackMode: mode,
            reason: fallbackReason,
            healthCheckTimestamp: lastHealthCheck,
            availableComponents: healthResult.checkedComponents,
            errors: healthResult.errors,
            isMLXImportable: await MLXAvailability().canImportMLX(),
            systemSupportsMLX: await MLXAvailability().hasMLXRuntimeRequirements(),
            recommendedAction: getRecommendedAction(for: mode)
        )
    }
    
    private func getRecommendedAction(for mode: MLXFallbackMode) -> String {
        switch mode {
        case .fullyAvailable:
            return "MLX is ready for use when real provider is implemented"
        case .partiallyAvailable:
            return "Consider using MLX for specific tasks, fallback to WhisperKit for others"
        case .unavailable:
            return "Use WhisperKit exclusively until MLX issues are resolved"
        case .disabled:
            return "Enable MLX in configuration if desired"
        case .unknown:
            return "Investigate MLX integration and run diagnostic tests"
        }
    }
    
    /// Resets cached health check results (useful for testing)
    public func resetHealthCheckCache() {
        cachedHealthResult = nil
        healthCheckTimestamp = nil
        fallbackMode = .unknown
        lastHealthCheck = nil
    }
}

// MARK: - Supporting Types

/// MLX fallback modes
public enum MLXFallbackMode: String, CaseIterable {
    case fullyAvailable = "fully_available"
    case partiallyAvailable = "partially_available"
    case unavailable = "unavailable"
    case disabled = "disabled"
    case unknown = "unknown"
    
    public var description: String {
        switch self {
        case .fullyAvailable:
            return "MLX is fully available and functional"
        case .partiallyAvailable:
            return "MLX is available but some components may be missing"
        case .unavailable:
            return "MLX is not available on this system"
        case .disabled:
            return "MLX is disabled via configuration"
        case .unknown:
            return "MLX availability status is unknown"
        }
    }
}

/// Diagnostic information about MLX fallback status
public struct MLXFallbackDiagnostic {
    let fallbackMode: MLXFallbackMode
    let reason: String?
    let healthCheckTimestamp: Date?
    let availableComponents: [String]
    let errors: [String]
    let isMLXImportable: Bool
    let systemSupportsMLX: Bool
    let recommendedAction: String
    
    public var summary: String {
        return """
        MLX Fallback Status: \(fallbackMode.description)
        Reason: \(reason ?? "None")
        Last Check: \(healthCheckTimestamp?.formatted() ?? "Never")
        Components: \(availableComponents.joined(separator: ", "))
        Importable: \(isMLXImportable)
        System Support: \(systemSupportsMLX)
        Action: \(recommendedAction)
        """
    }
}