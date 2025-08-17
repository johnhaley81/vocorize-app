//
//  BasicTranscriptionClientTests.swift
//  VocorizeTests
//
//  Basic functionality tests for TranscriptionClient
//

import Dependencies
import Foundation
@testable import Vocorize
import Testing

struct BasicTranscriptionClientTests {
    
    @Test
    func transcriptionClient_canInitialize() async throws {
        // GIVEN: A TranscriptionClient dependency
        let client = withDependencies {
            $0.transcription = .liveValue
        } operation: {
            @Dependency(\.transcription) var transcription
            return transcription
        }
        
        // WHEN: We check if it's initialized
        // THEN: It should exist and be usable
        let models = try await client.getAvailableModels()
        #expect(!models.isEmpty, "Should have some available models")
    }
    
    @Test 
    func transcriptionClient_hasLiveImplementation() async throws {
        // GIVEN: Live TranscriptionClient
        let client = TranscriptionClient.liveValue
        
        // WHEN: We request recommended models
        let recommendations = try await client.getRecommendedModels()
        
        // THEN: Should return valid recommendations
        #expect(!recommendations.default.isEmpty, "Should have a default recommendation")
        #expect(!recommendations.supported.isEmpty, "Should have supported models")
    }
    
    @Test
    func transcriptionClient_canCheckModelDownloadStatus() async throws {
        // GIVEN: TranscriptionClient
        let client = TranscriptionClient.liveValue
        
        // WHEN: We check if a model is downloaded
        let isDownloaded = await client.isModelDownloaded("nonexistent-model")
        
        // THEN: Should return false for nonexistent model
        #expect(isDownloaded == false, "Nonexistent model should not be downloaded")
    }
}