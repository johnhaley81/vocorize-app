import Foundation

/// Validation utilities for model configuration
public struct ModelValidation {
    
    /// Validates the models.json configuration
    public static func validateModelsConfiguration() -> ValidationResult {
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json") ??
              Bundle.main.url(forResource: "models", withExtension: "json", subdirectory: "Data") else {
            return .failure("models.json not found in bundle")
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Try new schema format first
            if let config = try? JSONDecoder().decode(ModelsConfiguration.self, from: data) {
                return validateModels(config.models)
            }
            
            // Try old schema format
            if let models = try? JSONDecoder().decode([CuratedModelInfo].self, from: data) {
                return validateModels(models)
            }
            
            return .failure("Failed to parse models.json in any known format")
        } catch {
            return .failure("Failed to read models.json: \(error.localizedDescription)")
        }
    }
    
    /// Validates an array of CuratedModelInfo
    public static func validateModels(_ models: [CuratedModelInfo]) -> ValidationResult {
        var errors: [String] = []
        
        // Check for duplicate IDs
        let ids = models.map(\.id)
        let uniqueIds = Set(ids)
        if ids.count != uniqueIds.count {
            errors.append("Duplicate model IDs found")
        }
        
        // Validate each model
        for model in models {
            // Check required fields
            if model.displayName.isEmpty {
                errors.append("Model \(model.id) has empty displayName")
            }
            
            if model.internalName.isEmpty {
                errors.append("Model \(model.id) has empty internalName")
            }
            
            // Validate star ratings
            if model.accuracyStars < 1 || model.accuracyStars > 5 {
                errors.append("Model \(model.id) has invalid accuracyStars: \(model.accuracyStars)")
            }
            
            if model.speedStars < 1 || model.speedStars > 5 {
                errors.append("Model \(model.id) has invalid speedStars: \(model.speedStars)")
            }
            
            // Validate provider
            if TranscriptionProviderType(rawValue: model.provider) == nil {
                errors.append("Model \(model.id) has unsupported provider: \(model.provider)")
            }
        }
        
        return errors.isEmpty ? .success : .failure(errors.joined(separator: "; "))
    }
}

public enum ValidationResult {
    case success
    case failure(String)
    
    public var isValid: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    public var errorMessage: String? {
        switch self {
        case .success: return nil
        case .failure(let message): return message
        }
    }
}

// Private wrapper for new schema format
private struct ModelsConfiguration: Codable {
    let version: String
    let models: [CuratedModelInfo]
}