//
//  TranscriptionClient.swift
//  Vocorize
//
//  Created by Kit Langton on 1/24/25.
//

import AVFoundation
import Dependencies
import DependenciesMacros
import Foundation
import WhisperKit

/// A client that downloads and loads WhisperKit models, then transcribes audio files using the loaded model.
/// Exposes progress callbacks to report overall download-and-load percentage and transcription progress.
@DependencyClient
struct TranscriptionClient {
  /// Transcribes an audio file at the specified `URL` using the named `model`.
  /// Reports transcription progress via `progressCallback`.
  var transcribe: @Sendable (URL, String, DecodingOptions, @escaping (Progress) -> Void) async throws -> String

  /// Ensures a model is downloaded (if missing) and loaded into memory, reporting progress via `progressCallback`.
  var downloadModel: @Sendable (String, @escaping (Progress) -> Void) async throws -> Void

  /// Deletes a model from disk if it exists
  var deleteModel: @Sendable (String) async throws -> Void

  /// Checks if a named model is already downloaded on this system.
  var isModelDownloaded: @Sendable (String) async -> Bool = { _ in false }

  /// Fetches a recommended set of models for the user's hardware from Hugging Face's `argmaxinc/whisperkit-coreml`.
  var getRecommendedModels: @Sendable () async throws -> ModelSupport

  /// Lists all model variants found in `argmaxinc/whisperkit-coreml`.
  var getAvailableModels: @Sendable () async throws -> [String]
}

extension TranscriptionClient: DependencyKey {
  static var liveValue: Self {
    let factory = TranscriptionProviderFactory()
    let live = TranscriptionClientLive(factory: factory)
    return Self(
      transcribe: { try await live.transcribe(url: $0, model: $1, options: $2, progressCallback: $3) },
      downloadModel: { try await live.downloadModel(variant: $0, progressCallback: $1) },
      deleteModel: { try await live.deleteModel(variant: $0) },
      isModelDownloaded: { await live.isModelDownloaded($0) },
      getRecommendedModels: { await live.getRecommendedModels() },
      getAvailableModels: { try await live.getAvailableModels() }
    )
  }
  
  /// Default test value that uses fast mock providers for unit tests
  /// This ensures test performance while maintaining full API compatibility
  static var testValue: Self {
    return Self(
      transcribe: { url, model, options, progressCallback in
        // Fast mock transcription - simulate realistic progress
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        progress.completedUnitCount = 50
        progressCallback(progress)
        progress.completedUnitCount = 100
        progressCallback(progress)
        return "Mock transcription result for model \(model)"
      },
      downloadModel: { variant, progressCallback in
        // Fast mock download - complete immediately
        let progress = Progress(totalUnitCount: 100)
        progressCallback(progress)
        progress.completedUnitCount = 100
        progressCallback(progress)
      },
      deleteModel: { _ in
        // Mock deletion - no-op
      },
      isModelDownloaded: { _ in
        // Mock models are always "downloaded" for testing convenience
        return true
      },
      getRecommendedModels: {
        return ModelSupport(
          default: "tiny",
          supported: ["tiny", "base", "small"],
          disabled: []
        )
      },
      getAvailableModels: {
        return ["tiny", "base", "small", "medium"]
      }
    )
  }
}

extension DependencyValues {
  var transcription: TranscriptionClient {
    get { self[TranscriptionClient.self] }
    set { self[TranscriptionClient.self] = newValue }
  }
}

/// An `actor` that routes transcription operations to appropriate providers using TranscriptionProviderFactory
actor TranscriptionClientLive {
  // MARK: - Stored Properties

  /// Factory for managing transcription providers
  private let factory: TranscriptionProviderFactory
  
  /// Initialization flag to ensure providers are registered
  private var isInitialized = false

  // MARK: - Initialization
  
  init(factory: TranscriptionProviderFactory) {
    self.factory = factory
  }
  
  private func ensureInitialized() async {
    guard !isInitialized else { return }
    
    // Register WhisperKit provider
    let whisperKitProvider = WhisperKitProvider()
    await factory.registerProvider(whisperKitProvider, for: .whisperKit)
    
    // Register MLX provider conditionally based on availability
    if MLXAvailability.isAvailable {
      // MLX provider will be implemented in next issue
      // For now, log that MLX is available for future registration
      print("✅ MLX framework is available for future provider registration")
    } else {
      let compatInfo = MLXAvailability.compatibilityInfo
      let statusMessage = generateMLXStatusMessage(from: compatInfo)
      print("⚠️ MLX framework not available: \(statusMessage)")
    }
    
    isInitialized = true
  }
  
  // MARK: - Public Methods

  /// Downloads and loads a model, routing to the appropriate provider
  func downloadModel(variant: String, progressCallback: @escaping (Progress) -> Void) async throws {
    await ensureInitialized()
    
    let (providerModelName, provider) = try await resolveModelAndProvider(variant)
    
    try await provider.downloadModel(providerModelName, progressCallback: progressCallback)
  }

  /// Deletes a model from disk if it exists
  func deleteModel(variant: String) async throws {
    await ensureInitialized()
    
    let (providerModelName, provider) = try await resolveModelAndProvider(variant)
    
    try await provider.deleteModel(providerModelName)
  }

  /// Returns `true` if the model is already downloaded to the local folder.
  func isModelDownloaded(_ modelName: String) async -> Bool {
    await ensureInitialized()
    
    do {
      let (providerModelName, provider) = try await resolveModelAndProvider(modelName)
      return await provider.isModelDownloaded(providerModelName)
    } catch {
      // If we can't resolve the model/provider, it's not downloaded
      return false
    }
  }

  /// Returns a list of recommended models based on current device hardware.
  func getRecommendedModels() async -> ModelSupport {
    await ensureInitialized()
    
    // Get recommendations from all available providers
    var allSupported: [String] = []
    var recommended = "tiny" // Default fallback
    
    // Try to get WhisperKit recommendations first (primary provider)
    if await factory.isProviderRegistered(.whisperKit) {
      do {
        if let provider = await getProviderByType(.whisperKit) {
          let whisperRecommendations = await WhisperKit.recommendedRemoteModels()
          // Add WhisperKit models with provider prefix
          allSupported.append(contentsOf: whisperRecommendations.supported.map { "whisperkit:\($0)" })
          recommended = "whisperkit:\(whisperRecommendations.default)"
        }
      } catch {
        // Silently fall back to legacy behavior
      }
    }
    
    // Add models from other providers if available
    for providerType in await factory.getAllRegisteredProviderTypes() {
      if providerType != .whisperKit, let provider = await getProviderByType(providerType) {
        do {
          let models = try await provider.getAvailableModels()
          allSupported.append(contentsOf: models.map { "\(providerType.rawValue):\($0.internalName)" })
        } catch {
          // Ignore providers that fail to provide models
        }
      }
    }
    
    // If no provider-specific models found, fall back to legacy WhisperKit behavior
    if allSupported.isEmpty {
      let legacyRecommendations = await WhisperKit.recommendedRemoteModels()
      return ModelSupport(
        default: legacyRecommendations.default,
        supported: legacyRecommendations.supported,
        disabled: legacyRecommendations.disabled
      )
    }
    
    return ModelSupport(
      default: recommended,
      supported: allSupported,
      disabled: []
    )
  }

  /// Lists all model variants available from all registered providers.
  func getAvailableModels() async throws -> [String] {
    await ensureInitialized()
    
    var allModels: [String] = []
    
    // Collect models from all registered providers
    for providerType in await factory.getAllRegisteredProviderTypes() {
      do {
        // Get provider directly by type
        if let provider = await getProviderByType(providerType) {
          let providerModels = try await provider.getAvailableModels()
          // Add models with provider prefix for non-WhisperKit providers
          if providerType == .whisperKit {
            // For WhisperKit, provide both legacy format and prefixed format for compatibility
            allModels.append(contentsOf: providerModels.map { $0.internalName })
            allModels.append(contentsOf: providerModels.map { "whisperkit:\($0.internalName)" })
          } else {
            allModels.append(contentsOf: providerModels.map { "\(providerType.rawValue):\($0.internalName)" })
          }
        }
      } catch {
        // Ignore providers that fail - graceful degradation
      }
    }
    
    // If no providers are available, fall back to legacy WhisperKit behavior
    if allModels.isEmpty {
      return try await WhisperKit.fetchAvailableModels()
    }
    
    // Remove duplicates and sort
    return Array(Set(allModels)).sorted()
  }

  /// Transcribes the audio file at `url` using a `model` name.
  /// The model is routed to the appropriate provider and downloaded/loaded if needed.
  func transcribe(
    url: URL,
    model: String,
    options: DecodingOptions,
    progressCallback: @escaping (Progress) -> Void
  ) async throws -> String {
    await ensureInitialized()
    
    let (providerModelName, provider) = try await resolveModelAndProvider(model)
    
    return try await provider.transcribe(
      audioURL: url,
      modelName: providerModelName,
      options: options,
      progressCallback: progressCallback
    )
  }

  // MARK: - Private Helpers
  
  /// Resolves a model name to the appropriate provider and internal model name
  /// Supports both provider-prefixed formats (e.g., "whisperkit:tiny") and legacy formats (e.g., "tiny")
  private func resolveModelAndProvider(_ modelName: String) async throws -> (String, any TranscriptionProvider) {
    // Check if model name contains provider prefix
    if modelName.contains(":") {
      let components = modelName.split(separator: ":", maxSplits: 1)
      guard components.count == 2 else {
        throw TranscriptionProviderFactoryError.invalidModelName(modelName)
      }
      
      let providerString = String(components[0])
      let internalModelName = String(components[1])
      
      guard let providerType = TranscriptionProviderType(rawValue: providerString) else {
        throw TranscriptionProviderFactoryError.invalidModelName(modelName)
      }
      
      guard await factory.isProviderRegistered(providerType) else {
        throw TranscriptionProviderFactoryError.providerNotRegistered(providerType)
      }
      
      // Get provider directly by type instead of using getProviderForModel
      guard let provider = await getProviderByType(providerType) else {
        throw TranscriptionProviderFactoryError.providerNotRegistered(providerType)
      }
      
      return (internalModelName, provider)
    } else {
      // Legacy format - default to WhisperKit
      guard await factory.isProviderRegistered(.whisperKit) else {
        throw TranscriptionProviderFactoryError.providerNotRegistered(.whisperKit)
      }
      
      guard let provider = await getProviderByType(.whisperKit) else {
        throw TranscriptionProviderFactoryError.providerNotRegistered(.whisperKit)
      }
      
      return (modelName, provider)
    }
  }
  
  /// Gets a provider by type directly from the factory
  private func getProviderByType(_ providerType: TranscriptionProviderType) async -> (any TranscriptionProvider)? {
    let allProviders = await factory.getAllRegisteredProviders()
    return allProviders.first { type(of: $0).providerType == providerType }
  }
  
  /// Generates a human-readable status message from MLX compatibility info
  private func generateMLXStatusMessage(from compatInfo: [String: Any]) -> String {
    var reasons: [String] = []
    
    if let frameworkAvailable = compatInfo["framework_available"] as? Bool, !frameworkAvailable {
      reasons.append("framework not integrated")
    }
    
    if let productsAvailable = compatInfo["products_available"] as? Bool, !productsAvailable {
      reasons.append("MLX products not available")
    }
    
    if let versionCompatible = compatInfo["version_compatible"] as? Bool, !versionCompatible {
      reasons.append("incompatible version")
    }
    
    if let systemCompatible = compatInfo["system_compatible"] as? Bool, !systemCompatible {
      if let architecture = compatInfo["architecture"] as? String {
        reasons.append("requires Apple Silicon (current: \(architecture))")
      } else {
        reasons.append("requires Apple Silicon")
      }
    }
    
    return reasons.isEmpty ? "unknown compatibility issue" : reasons.joined(separator: ", ")
  }
}