//
//  TestFixtures.swift
//  VocorizeTests
//
//  Centralized fixture loading and management for test data
//  Provides convenient access to all test fixtures with error handling
//

import Foundation
@testable import Vocorize

/// Central fixture loader for test data
struct TestFixtures {
    
    // MARK: - Fixture Loading
    
    /// Load test models fixture data
    static func loadTestModels() throws -> TestModelsFixture {
        let url = getFixtureURL(filename: "TestModels.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TestModelsFixture.self, from: data)
    }
    
    /// Load expected transcriptions fixture data
    static func loadExpectedTranscriptions() throws -> ExpectedTranscriptionsFixture {
        let url = getFixtureURL(filename: "ExpectedTranscriptions.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ExpectedTranscriptionsFixture.self, from: data)
    }
    
    /// Load mock paths fixture data
    static func loadMockPaths() throws -> MockPathsFixture {
        let url = getFixtureURL(filename: "MockPaths.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MockPathsFixture.self, from: data)
    }
    
    // MARK: - Convenience Methods
    
    /// Get a specific model by internal name
    static func getTestModel(internalName: String) throws -> TestModelInfo {
        let models = try loadTestModels()
        guard let model = models.models.first(where: { $0.internalName == internalName }) else {
            throw TestFixtureError.modelNotFound(internalName)
        }
        return model
    }
    
    /// Get expected transcription for audio file
    static func getExpectedTranscription(audioFileName: String) throws -> TranscriptionResult {
        let transcriptions = try loadExpectedTranscriptions()
        guard let result = transcriptions.transcriptions[audioFileName] else {
            throw TestFixtureError.transcriptionNotFound(audioFileName)
        }
        return result
    }
    
    /// Get all fast test models (suitable for quick testing)
    static func getFastTestModels() throws -> [TestModelInfo] {
        let fixture = try loadTestModels()
        let fastModelNames = fixture.testConfiguration.fastTestModels
        return fixture.models.filter { fastModelNames.contains($0.internalName) }
    }
    
    /// Get all test compatible models
    static func getTestCompatibleModels() throws -> [TestModelInfo] {
        let fixture = try loadTestModels()
        return fixture.models.filter { $0.testCompatible }
    }
    
    /// Get recommended test model
    static func getRecommendedTestModel() throws -> TestModelInfo {
        let models = try loadTestModels()
        let recommendedName = models.testConfiguration.defaultTestModel
        return try getTestModel(internalName: recommendedName)
    }
    
    /// Get mock path for model
    static func getMockPath(modelName: String) throws -> ModelPathInfo {
        let paths = try loadMockPaths()
        guard let pathInfo = paths.modelPaths[modelName] else {
            throw TestFixtureError.pathNotFound(modelName)
        }
        return pathInfo
    }
    
    /// Get test audio file URL
    static func getTestAudioURL(filename: String) -> URL {
        return getAudioFixturesDirectory().appendingPathComponent(filename)
    }
    
    /// Check if test audio file exists
    static func testAudioFileExists(filename: String) -> Bool {
        let url = getTestAudioURL(filename: filename)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // MARK: - Test Setup Helpers
    
    /// Generate all test audio files if they don't exist
    static func ensureTestAudioFilesExist() throws {
        let audioDir = getAudioFixturesDirectory()
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioDir.path) {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        
        // Check if we need to generate audio files
        let requiredFiles = [
            "silence.wav",
            "hello_world.wav",
            "quick_brown_fox.wav",
            "numbers_123.wav",
            "multilingual_sample.wav",
            "noisy_audio.wav",
            "long_sentence.wav"
        ]
        
        let missingFiles = requiredFiles.filter { !testAudioFileExists(filename: $0) }
        
        if !missingFiles.isEmpty {
            try AudioGenerator.generateAllTestAudio()
        }
    }
    
    /// Convert TestModelInfo to ProviderModelInfo format
    static func convertToProviderModelInfo(_ testModel: TestModelInfo) -> ProviderModelInfo {
        return ProviderModelInfo(
            internalName: testModel.internalName,
            displayName: testModel.displayName,
            providerType: TranscriptionProviderType(rawValue: testModel.provider) ?? .whisperKit,
            estimatedSize: testModel.storageSize,
            isRecommended: testModel.isRecommended,
            isDownloaded: false // Default to not downloaded in fixtures
        )
    }
    
    /// Convert test models to ProviderModelInfo array
    static func getAllProviderModelInfo() throws -> [ProviderModelInfo] {
        let testModels = try loadTestModels()
        return testModels.models.map(convertToProviderModelInfo)
    }
    
    /// Get ProviderModelInfo for specific provider type
    static func getProviderModelInfo(for providerType: TranscriptionProviderType) throws -> [ProviderModelInfo] {
        let allModels = try getAllProviderModelInfo()
        return allModels.filter { $0.providerType == providerType }
    }
    
    // MARK: - Private Helpers
    
    private static func getFixtureURL(filename: String) -> URL {
        return getFixturesDirectory().appendingPathComponent(filename)
    }
    
    private static func getFixturesDirectory() -> URL {
        // Try to find the fixtures directory relative to the current file
        let currentFileURL = URL(fileURLWithPath: #file)
        let fixturesURL = currentFileURL.deletingLastPathComponent()
        
        // Verify the fixtures directory exists
        let fixturesPath = fixturesURL.path
        if FileManager.default.fileExists(atPath: fixturesPath) {
            return fixturesURL
        }
        
        // Fallback: try to find via Bundle
        if let testBundle = Bundle.allBundles.first(where: { $0.bundlePath.contains("VocorizeTests") }) {
            return testBundle.bundleURL.appendingPathComponent("Fixtures")
        }
        
        // Final fallback: use temp directory
        return FileManager.default.temporaryDirectory.appendingPathComponent("VocorizeTests/Fixtures")
    }
    
    private static func getAudioFixturesDirectory() -> URL {
        return getFixturesDirectory().appendingPathComponent("Audio")
    }
}

// MARK: - Fixture Data Models

struct TestModelsFixture: Codable {
    let version: String
    let description: String
    let models: [TestModelInfo]
    let deviceRequirements: DeviceRequirements
    let testConfiguration: TestConfiguration
}

struct TestModelInfo: Codable {
    let displayName: String
    let internalName: String
    let provider: String
    let size: String
    let accuracyStars: Int
    let speedStars: Int
    let storageSize: String
    let isRecommended: Bool
    let minimumRAM: String
    let description: String
    let downloadUrl: String
    let modelType: String
    let languages: [String]
    let sampleRate: Int
    let supportsMultilingual: Bool
    let averageDownloadTime: Int
    let testCompatible: Bool
}

struct DeviceRequirements: Codable {
    let minimum: DeviceSpec
    let recommended: DeviceSpec
}

struct DeviceSpec: Codable {
    let ram: String
    let storage: String
    let coreMLSupport: Bool
    let neuralEngine: Bool?
    let appleSilicon: Bool?
}

struct TestConfiguration: Codable {
    let fastTestModels: [String]
    let accuracyTestModels: [String]
    let multilingualTestModels: [String]
    let defaultTestModel: String
    let mockDownloadDelay: Double
    let mockTranscriptionDelay: Double
}

struct ExpectedTranscriptionsFixture: Codable {
    let version: String
    let description: String
    let transcriptions: [String: TranscriptionResult]
    let modelSpecificResults: [String: ModelModifiers]
    let errorScenarios: [String: ErrorScenario]
}

struct TranscriptionResult: Codable {
    let text: String
    let confidence: Double
    let language: String
    let duration: Double
    let segments: [TranscriptionSegment]
}

struct TranscriptionSegment: Codable {
    let start: Double
    let end: Double
    let text: String
    let confidence: Double
}

struct ModelModifiers: Codable {
    let accuracyModifier: Double
    let speedMultiplier: Double
    let confidenceModifier: Double
}

struct ErrorScenario: Codable {
    let error: String
    let description: String
}

struct MockPathsFixture: Codable {
    let version: String
    let description: String
    let basePaths: [String: String]
    let modelPaths: [String: ModelPathInfo]
    let downloadUrls: [String: String]
    let testConfiguration: PathTestConfiguration
    let deviceLimitations: [String: DeviceLimitation]
}

struct ModelPathInfo: Codable {
    let modelPath: String
    let configPath: String
    let tokenizerPath: String
    let weightsPath: String
    let metadataPath: String
    let exists: Bool
    let sizeOnDisk: Int
}

struct PathTestConfiguration: Codable {
    let mockFileSystem: Bool
    let simulateSlowDownloads: Bool
    let simulateNetworkErrors: Bool
    let maxConcurrentDownloads: Int
    let downloadTimeoutSeconds: Int
    let cleanupAfterTests: Bool
    let preserveDownloadedModels: Bool
}

struct DeviceLimitation: Codable {
    let maxModelSize: String
    let excludeModels: [String]
}

// MARK: - Errors

enum TestFixtureError: Error, LocalizedError {
    case modelNotFound(String)
    case transcriptionNotFound(String)
    case pathNotFound(String)
    case fixtureLoadFailed(String)
    case audioGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Test model '\(name)' not found in fixtures"
        case .transcriptionNotFound(let filename):
            return "Expected transcription for '\(filename)' not found in fixtures"
        case .pathNotFound(let modelName):
            return "Mock path for model '\(modelName)' not found in fixtures"
        case .fixtureLoadFailed(let reason):
            return "Failed to load fixture: \(reason)"
        case .audioGenerationFailed(let reason):
            return "Failed to generate test audio: \(reason)"
        }
    }
}