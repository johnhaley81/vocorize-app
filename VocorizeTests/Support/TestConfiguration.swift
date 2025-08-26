//
//  TestConfiguration.swift
//  VocorizeTests
//
//  Test configuration system for switching between mock and real providers
//  Provides clean separation between unit tests (mock) and integration tests (real)
//

import Foundation

/// Test environment detection and configuration
public enum VocorizeTestConfiguration {
    
    // MARK: - Test Environment Detection
    
    /// Determines the current test mode based on environment variables and test context
    public static var currentTestMode: TestMode {
        // Check explicit override first
        if let override = _testModeOverride {
            return override
        }
        
        // Check environment variable (allows override)
        if let envMode = ProcessInfo.processInfo.environment["VOCORIZE_TEST_MODE"] {
            switch envMode.lowercased() {
            case "integration", "real":
                return .integration
            case "unit", "mock":
                return .unit
            default:
                break
            }
        }
        
        // Auto-detect based on test class or method names
        if isIntegrationTestContext() {
            return .integration
        }
        
        // Default to unit tests for fast execution
        return .unit
    }
    
    // Static storage for test mode override
    private static var _testModeOverride: TestMode?
    
    /// Explicitly sets test mode for specific test contexts
    public static func setTestMode(_ mode: TestMode) {
        _testModeOverride = mode
    }
    
    /// Resets test mode to auto-detection
    public static func resetTestMode() {
        _testModeOverride = nil
    }
    
    // MARK: - Configuration Properties
    
    /// Whether to use real providers (slower but complete testing)
    public static var shouldUseRealProviders: Bool {
        currentTestMode == .integration
    }
    
    /// Whether to use mock providers (faster unit testing)
    public static var shouldUseMockProviders: Bool {
        currentTestMode == .unit
    }
    
    /// Expected test execution time hint for tooling
    public static var expectedExecutionTime: ExecutionTime {
        switch currentTestMode {
        case .unit:
            return .fast
        case .integration:
            return .slow
        }
    }
    
    // MARK: - Private Helpers
    
    private static func isIntegrationTestContext() -> Bool {
        // Check if we're running from integration test files or with integration-specific patterns
        let callStack = Thread.callStackSymbols
        
        for frame in callStack {
            // Look for integration test classes or methods
            if frame.contains("Integration") || 
               frame.contains("SystemTest") || 
               frame.contains("EndToEnd") ||
               frame.contains("RealProvider") {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Supporting Types

/// Test execution modes
public enum TestMode: String, CaseIterable {
    /// Unit tests with mocked dependencies - fast execution
    case unit = "unit"
    
    /// Integration tests with real dependencies - slower but comprehensive
    case integration = "integration"
    
    public var description: String {
        switch self {
        case .unit:
            return "Unit Tests (Mock Providers)"
        case .integration:
            return "Integration Tests (Real Providers)"
        }
    }
}

/// Expected execution time categories for test planning
public enum ExecutionTime {
    /// Fast tests (< 1 second) - suitable for frequent runs during development
    case fast
    
    /// Slow tests (> 5 seconds) - suitable for CI/CD and comprehensive validation
    case slow
    
    public var description: String {
        switch self {
        case .fast:
            return "Fast (< 1s) - Mock providers"
        case .slow:
            return "Slow (> 5s) - Real providers with model downloads"
        }
    }
}

// MARK: - Test Configuration Extensions

extension VocorizeTestConfiguration {
    
    /// Prints current test configuration for debugging
    public static func printConfiguration() {
        let mode = currentTestMode
        let time = expectedExecutionTime
        
        print("🧪 Test Configuration:")
        print("   Mode: \(mode.description)")
        print("   Expected Time: \(time.description)")
        print("   Real Providers: \(shouldUseRealProviders)")
        print("   Mock Providers: \(shouldUseMockProviders)")
    }
    
    /// Validates test environment is properly configured
    public static func validateConfiguration() -> Bool {
        // Ensure we have a valid test mode
        guard TestMode.allCases.contains(currentTestMode) else {
            print("⚠️ Invalid test mode detected")
            return false
        }
        
        // Ensure mutually exclusive provider selection
        guard shouldUseRealProviders != shouldUseMockProviders else {
            print("⚠️ Test configuration conflict: both real and mock providers selected")
            return false
        }
        
        return true
    }
}