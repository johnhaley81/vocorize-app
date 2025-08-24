//
//  ModelsConfiguration.swift
//  Vocorize
//
//  Consolidated schema configuration for multi-provider model support.
//  This replaces the duplicate private structs across multiple files.
//

import Foundation

/// Schema wrapper for the versioned models.json configuration
public struct ModelsConfiguration: Codable {
    public let version: String
    public let models: [CuratedModelInfo]
    
    public init(version: String, models: [CuratedModelInfo]) {
        self.version = version
        self.models = models
    }
}