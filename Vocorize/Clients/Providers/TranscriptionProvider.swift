//
//  TranscriptionProvider.swift
//  Vocorize
//
//  Created for Phase 1.1 - TranscriptionProvider Protocol
//

import Foundation
import AVFoundation
import WhisperKit

/// Protocol for transcription providers (WhisperKit, MLX, etc.)
public protocol TranscriptionProvider: Actor {
    
    /// Unique identifier for this provider type
    static var providerType: TranscriptionProviderType { get }
    
    /// Human-readable name for UI display
    static var displayName: String { get }
    
    /// Transcribes audio file and returns text
    /// - Parameters:
    ///   - audioURL: Local file URL to audio file
    ///   - modelName: Internal model name (provider-specific)
    ///   - options: Decoding options for transcription
    ///   - progressCallback: Progress updates during transcription
    /// - Returns: Transcribed text
    func transcribe(
        audioURL: URL,
        modelName: String,
        options: DecodingOptions,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> String
    
    /// Downloads and loads a model, reporting overall progress
    /// - Parameters:
    ///   - modelName: Internal model name to download
    ///   - progressCallback: Progress updates (0.0 to 1.0)
    func downloadModel(
        _ modelName: String,
        progressCallback: @escaping (Progress) -> Void
    ) async throws -> Void
    
    /// Deletes a downloaded model from disk
    /// - Parameter modelName: Internal model name to delete
    func deleteModel(_ modelName: String) async throws -> Void
    
    /// Checks if model is already downloaded and valid
    /// - Parameter modelName: Internal model name to check
    /// - Returns: true if model exists and is usable
    func isModelDownloaded(_ modelName: String) async -> Bool
    
    /// Returns list of models available for this provider
    /// - Returns: Array of model info for this provider
    func getAvailableModels() async throws -> [ProviderModelInfo]
    
    /// Returns recommended model for current hardware
    /// - Returns: Model name that's recommended for this device
    func getRecommendedModel() async throws -> String
    
    /// Loads a model into memory for immediate use
    /// - Parameter modelName: Internal model name to load into memory
    /// - Returns: true if successfully loaded, false otherwise
    func loadModelIntoMemory(_ modelName: String) async throws -> Bool
    
    /// Checks if a model is currently loaded in memory
    /// - Parameter modelName: Internal model name to check
    /// - Returns: true if model is loaded in memory, false otherwise
    func isModelLoadedInMemory(_ modelName: String) async -> Bool
}