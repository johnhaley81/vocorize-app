//
//  TranscriptionProviderTypes.swift
//  Vocorize
//
//  Created for Phase 1.1 - TranscriptionProvider Protocol
//

import Foundation

/// Enumeration of supported transcription provider types
public enum TranscriptionProviderType: String, CaseIterable, Codable {
    case whisperKit = "whisperkit"
    case mlx = "mlx"
    
    var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit (Core ML)"
        case .mlx: return "MLX"
        }
    }
}

/// Model information specific to a provider
public struct ProviderModelInfo: Equatable, Identifiable, Codable {
    public let id: String
    public let internalName: String
    public let displayName: String
    public let providerType: TranscriptionProviderType
    public let estimatedSize: String
    public let isRecommended: Bool
    public var isDownloaded: Bool
    
    public init(
        internalName: String,
        displayName: String,
        providerType: TranscriptionProviderType,
        estimatedSize: String,
        isRecommended: Bool = false,
        isDownloaded: Bool = false
    ) {
        self.internalName = internalName
        self.displayName = displayName
        self.providerType = providerType
        self.estimatedSize = estimatedSize
        self.isRecommended = isRecommended
        self.isDownloaded = isDownloaded
        self.id = "\(providerType.rawValue):\(internalName)"
    }
}

/// Error types for transcription providers
public enum TranscriptionProviderError: LocalizedError, Equatable {
    case modelNotFound(String)
    case modelDownloadFailed(String, Error)
    case transcriptionFailed(String, Error)
    case modelLoadFailed(String, Error)
    case unsupportedModelFormat(String)
    case providerNotAvailable(TranscriptionProviderType)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "Model '\(model)' not found"
        case .modelDownloadFailed(let model, let error):
            return "Failed to download model '\(model)': \(error.localizedDescription)"
        case .transcriptionFailed(let model, let error):
            return "Transcription failed with model '\(model)': \(error.localizedDescription)"
        case .modelLoadFailed(let model, let error):
            return "Failed to load model '\(model)': \(error.localizedDescription)"
        case .unsupportedModelFormat(let model):
            return "Unsupported model format for '\(model)'"
        case .providerNotAvailable(let type):
            return "Provider '\(type.displayName)' is not available"
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: TranscriptionProviderError, rhs: TranscriptionProviderError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotFound(let lModel), .modelNotFound(let rModel)):
            return lModel == rModel
        case (.modelDownloadFailed(let lModel, let lError), .modelDownloadFailed(let rModel, let rError)):
            return lModel == rModel && lError.localizedDescription == rError.localizedDescription
        case (.transcriptionFailed(let lModel, let lError), .transcriptionFailed(let rModel, let rError)):
            return lModel == rModel && lError.localizedDescription == rError.localizedDescription
        case (.modelLoadFailed(let lModel, let lError), .modelLoadFailed(let rModel, let rError)):
            return lModel == rModel && lError.localizedDescription == rError.localizedDescription
        case (.unsupportedModelFormat(let lModel), .unsupportedModelFormat(let rModel)):
            return lModel == rModel
        case (.providerNotAvailable(let lType), .providerNotAvailable(let rType)):
            return lType == rType
        default:
            return false
        }
    }
}

/// Error types specific to TranscriptionProviderFactory operations
public enum TranscriptionProviderFactoryError: LocalizedError, Equatable {
    case modelNotSupported(String)
    case providerNotRegistered(TranscriptionProviderType)
    case invalidModelName(String)
    case factoryNotInitialized
    
    public var errorDescription: String? {
        switch self {
        case .modelNotSupported(let model):
            return "Model '\(model)' is not supported by any registered provider"
        case .providerNotRegistered(let type):
            return "Provider '\(type.displayName)' is not registered with the factory"
        case .invalidModelName(let model):
            return "Invalid model name: '\(model)'"
        case .factoryNotInitialized:
            return "TranscriptionProviderFactory has not been properly initialized"
        }
    }
    
    public static func == (lhs: TranscriptionProviderFactoryError, rhs: TranscriptionProviderFactoryError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotSupported(let lModel), .modelNotSupported(let rModel)):
            return lModel == rModel
        case (.providerNotRegistered(let lType), .providerNotRegistered(let rType)):
            return lType == rType
        case (.invalidModelName(let lModel), .invalidModelName(let rModel)):
            return lModel == rModel
        case (.factoryNotInitialized, .factoryNotInitialized):
            return true
        default:
            return false
        }
    }
}