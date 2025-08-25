import Testing
@testable import Vocorize
import Foundation

struct ModelConfigurationTests {
    
    // MARK: - New Schema Format Tests
    
    @Test func testNewSchemaFormat() async throws {
        // Test new schema format with version and models array
        let newSchemaJSON = """
        {
            "version": "1.0",
            "models": [
                {
                    "displayName": "MLX Test Model",
                    "internalName": "mlx-test",
                    "provider": "mlx",
                    "size": "Large",
                    "accuracyStars": 5,
                    "speedStars": 4,
                    "storageSize": "1.2GB",
                    "isRecommended": true,
                    "minimumRAM": "8GB",
                    "description": "Test MLX model"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let config = try JSONDecoder().decode(ModelsConfiguration.self, from: newSchemaJSON)
        
        #expect(config.version == "1.0")
        #expect(config.models.count == 1)
        
        let model = config.models[0]
        #expect(model.provider == "mlx")
        #expect(model.isRecommended == true)
        #expect(model.minimumRAM == "8GB")
        #expect(model.description == "Test MLX model")
        #expect(model.isMLXModel == true)
        #expect(model.isWhisperKitModel == false)
    }
    
    @Test func testBackwardCompatibilityWithOldSchema() async throws {
        // Test that old schema format still works
        let oldSchemaJSON = """
        [
            {
                "displayName": "Test Model",
                "internalName": "test-model",
                "size": "Small",
                "accuracyStars": 3,
                "speedStars": 4,
                "storageSize": "100MB"
            }
        ]
        """.data(using: .utf8)!
        
        let models = try JSONDecoder().decode([CuratedModelInfo].self, from: oldSchemaJSON)
        
        #expect(models.count == 1)
        #expect(models[0].provider == "whisperkit")  // Default value
        #expect(models[0].isRecommended == false)    // Default value
        #expect(models[0].minimumRAM == nil)         // Default value
        #expect(models[0].description == nil)        // Default value
    }
    
    @Test func testModelIDGeneration() async throws {
        let whisperModel = CuratedModelInfo(
            displayName: "Test WhisperKit",
            internalName: "whisper-test",
            provider: "whisperkit",
            size: "Medium",
            accuracyStars: 3,
            speedStars: 3,
            storageSize: "500MB"
        )
        
        let mlxModel = CuratedModelInfo(
            displayName: "Test MLX",
            internalName: "mlx-test",
            provider: "mlx",
            size: "Large",
            accuracyStars: 4,
            speedStars: 4,
            storageSize: "1GB"
        )
        
        #expect(whisperModel.id == "whisperkit:whisper-test")
        #expect(mlxModel.id == "mlx:mlx-test")
        #expect(whisperModel.id != mlxModel.id)
    }
    
    @Test func testProviderTypeExtensions() async throws {
        let model = CuratedModelInfo(
            displayName: "MLX Model",
            internalName: "mlx-model",
            provider: "mlx",
            size: "Large",
            accuracyStars: 5,
            speedStars: 4,
            storageSize: "1.2GB",
            isRecommended: true,
            minimumRAM: "8GB",
            description: "High-performance MLX model"
        )
        
        #expect(model.providerType == .mlx)
        #expect(model.isMLXModel == true)
        #expect(model.isWhisperKitModel == false)
    }
    
    @Test func testModelValidation() async throws {
        // Test validation logic
        let result = ModelValidation.validateModelsConfiguration()
        
        // This will fail initially as we haven't implemented the validation
        #expect(result.isValid)
        #expect(result.errorMessage == nil)
    }
    
    @Test func testDuplicateModelDetection() async throws {
        let models = [
            CuratedModelInfo(
                displayName: "Model 1",
                internalName: "test-model",
                provider: "whisperkit",
                size: "Small",
                accuracyStars: 3,
                speedStars: 3,
                storageSize: "100MB"
            ),
            CuratedModelInfo(
                displayName: "Model 2",
                internalName: "test-model",  // Duplicate internal name
                provider: "whisperkit",       // Same provider
                size: "Medium",
                accuracyStars: 4,
                speedStars: 2,
                storageSize: "200MB"
            )
        ]
        
        let result = ModelValidation.validateModels(models)
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("Duplicate model IDs") == true)
    }
    
    @Test func testInvalidStarRatings() async throws {
        let model = CuratedModelInfo(
            displayName: "Invalid Model",
            internalName: "invalid",
            provider: "whisperkit",
            size: "Small",
            accuracyStars: 6,  // Invalid: > 5
            speedStars: 0,     // Invalid: < 1
            storageSize: "100MB"
        )
        
        let result = ModelValidation.validateModels([model])
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("invalid accuracyStars") == true)
        #expect(result.errorMessage?.contains("invalid speedStars") == true)
    }
    
    @Test func testUnsupportedProvider() async throws {
        // Test that validation catches unsupported providers
        let invalidProviderJSON = """
        {
            "displayName": "Invalid Provider Model",
            "internalName": "invalid-provider",
            "provider": "unsupported_provider",
            "size": "Small",
            "accuracyStars": 3,
            "speedStars": 3,
            "storageSize": "100MB"
        }
        """.data(using: .utf8)!
        
        let model = try JSONDecoder().decode(CuratedModelInfo.self, from: invalidProviderJSON)
        let result = ModelValidation.validateModels([model])
        
        #expect(result.isValid == false)
        #expect(result.errorMessage?.contains("unsupported provider") == true)
    }
    
    @Test func testCuratedModelLoaderWithNewFormat() async throws {
        // This test will fail initially until we update the loader
        let models = CuratedModelLoader.load()
        
        // After implementation, this should load models from the new schema
        #expect(models.count > 0)
        
        // Check that loaded models have the new fields
        if let firstModel = models.first {
            #expect(firstModel.provider != nil)
            // The actual models.json will have provider field after implementation
        }
    }
    
    @Test func testModelConfigurationVersion() async throws {
        // Test that we can read the version from new schema
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json") ??
              Bundle.main.url(forResource: "models", withExtension: "json", subdirectory: "Data") else {
            throw ModelTestError("models.json not found")
        }
        
        let data = try Data(contentsOf: url)
        
        // Try to decode as new format
        if let config = try? JSONDecoder().decode(ModelsConfiguration.self, from: data) {
            #expect(config.version == "1.0")
        } else {
            // If it fails, it means we're still using old format (expected in RED phase)
            Issue.record("models.json is still in old format - expected for RED phase")
        }
    }
}

// Test helper for CuratedModelLoader
enum CuratedModelLoader {
    static func load() -> [CuratedModelInfo] {
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json") ??
              Bundle.main.url(forResource: "models", withExtension: "json", subdirectory: "Data") else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Try new schema format first
            if let newFormat = try? JSONDecoder().decode(ModelsConfiguration.self, from: data) {
                return newFormat.models
            }
            
            // Fallback to old schema format for backward compatibility  
            if let oldFormat = try? JSONDecoder().decode([CuratedModelInfo].self, from: data) {
                return oldFormat
            }
            
            return []
        } catch {
            return []
        }
    }
}

private enum ModelTestError: Error {
    case fileNotFound(String)
    
    init(_ message: String) {
        self = .fileNotFound(message)
    }
}