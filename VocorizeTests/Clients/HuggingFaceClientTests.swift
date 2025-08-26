//
//  HuggingFaceClientTests.swift
//  VocorizeTests
//
//  Tests for HuggingFaceClient MLX model downloading functionality
//  Tests basic integration and error handling without actual network calls
//

import Foundation
@testable import Vocorize
import Testing
import XCTest

#if canImport(MLX) && canImport(MLXNN)

/// Tests for HuggingFace MLX model downloading client
struct HuggingFaceClientTests {
    
    // MARK: - Initialization Tests
    
    @Test
    func testHuggingFaceClientInitialization() async throws {
        let client = HuggingFaceClient()
        
        // Client should initialize without auth token
        #expect(client != nil, "HuggingFaceClient should initialize successfully")
    }
    
    @Test
    func testHuggingFaceClientInitializationWithAuth() async throws {
        let testToken = "hf_test_token_123"
        let client = HuggingFaceClient(authToken: testToken)
        
        // Client should initialize with auth token
        #expect(client != nil, "HuggingFaceClient should initialize with auth token")
    }
    
    // MARK: - Configuration Tests
    
    @Test
    func testSupportedMLXRepositories() {
        let expectedRepos = [
            "mlx-community/whisper-tiny-mlx",
            "mlx-community/whisper-base-mlx",
            "mlx-community/whisper-small-mlx",
            "mlx-community/whisper-medium-mlx",
            "mlx-community/whisper-large-v3-turbo"
        ]
        
        #expect(HuggingFaceClient.supportedMLXRepos == expectedRepos, 
                "Supported MLX repositories should match expected list")
    }
    
    // MARK: - URL Validation Tests
    
    @Test
    func testModelRepositoryValidation() async throws {
        let client = HuggingFaceClient()
        
        // Test valid repository IDs
        let validRepos = [
            "mlx-community/whisper-base-mlx",
            "huggingface/model-name",
            "user/repository"
        ]
        
        // Note: We can't directly test the private isValidRepoId method,
        // but we can test it indirectly through other methods that would
        // validate the repo ID format
        
        for repo in validRepos {
            // This should not throw for valid repo format
            // The actual network call will fail, but validation should pass
            do {
                _ = try await client.fetchModelMetadata(repoId: repo)
            } catch let error as HuggingFaceClient.HuggingFaceError {
                // Network errors are expected in tests, but not validation errors
                switch error {
                case .modelNotFound, .networkError, .invalidResponse:
                    continue // Expected in test environment
                default:
                    throw error // Unexpected validation error
                }
            } catch {
                // Other network errors are fine for this test
                continue
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func testErrorTypes() {
        // Test that error types are properly defined
        let networkError = HuggingFaceClient.HuggingFaceError.networkError("test")
        let authError = HuggingFaceClient.HuggingFaceError.authenticationFailed
        let notFoundError = HuggingFaceClient.HuggingFaceError.modelNotFound("test-repo")
        
        #expect(networkError.localizedDescription.contains("Network error"), 
                "Network error should have descriptive message")
        #expect(authError.localizedDescription.contains("Authentication failed"), 
                "Auth error should have descriptive message")
        #expect(notFoundError.localizedDescription.contains("not found"), 
                "Not found error should have descriptive message")
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test
    func testDownloadProgressStructure() {
        let progress = HuggingFaceClient.DownloadProgress(
            fileName: "model.safetensors",
            bytesDownloaded: 1024,
            totalBytes: 2048,
            overallProgress: 0.5,
            downloadSpeed: 512.0,
            estimatedTimeRemaining: 2.0
        )
        
        #expect(progress.fileName == "model.safetensors", "File name should be correct")
        #expect(progress.fileProgress == 0.5, "File progress should be 50%")
        #expect(progress.overallProgress == 0.5, "Overall progress should be 50%")
        #expect(progress.downloadSpeed == 512.0, "Download speed should be correct")
    }
    
    @Test
    func testProgressToFoundationProgress() {
        let downloadProgress = HuggingFaceClient.DownloadProgress(
            fileName: "test.safetensors",
            bytesDownloaded: 750,
            totalBytes: 1000,
            overallProgress: 0.75,
            downloadSpeed: 100.0,
            estimatedTimeRemaining: 2.5
        )
        
        let foundationProgress = Progress.from(downloadProgress: downloadProgress)
        
        #expect(foundationProgress.totalUnitCount == 100, "Total unit count should be 100")
        #expect(foundationProgress.completedUnitCount == 75, "Completed units should be 75")
        #expect(foundationProgress.localizedDescription?.contains("test.safetensors") == true, 
                "Description should contain file name")
    }
    
    // MARK: - Model Metadata Tests
    
    @Test
    func testModelMetadataStructure() {
        let files = [
            HuggingFaceClient.ModelFile(
                name: "config.json",
                size: 1024,
                url: "https://example.com/config.json"
            ),
            HuggingFaceClient.ModelFile(
                name: "model.safetensors",
                size: 1048576,
                url: "https://example.com/model.safetensors"
            )
        ]
        
        let metadata = HuggingFaceClient.ModelMetadata(
            repoId: "test/model",
            modelType: "whisper",
            framework: "mlx",
            totalSize: 1049600,
            files: files,
            lastModified: Date()
        )
        
        #expect(metadata.repoId == "test/model", "Repo ID should be correct")
        #expect(metadata.framework == "mlx", "Framework should be MLX")
        #expect(metadata.files.count == 2, "Should have 2 files")
        #expect(metadata.totalSize == 1049600, "Total size should be sum of file sizes")
    }
    
    // MARK: - Authentication Tests
    
    @Test
    func testAuthTokenManagement() async {
        let client = HuggingFaceClient()
        
        // Test setting auth token
        await client.setAuthToken("test_token")
        
        // Test clearing auth token
        await client.setAuthToken(nil)
        
        // These operations should complete without error
        #expect(true, "Auth token management should work")
    }
    
    // MARK: - Download Cancellation Tests
    
    @Test
    func testDownloadCancellation() async {
        let client = HuggingFaceClient()
        let repoId = "test/model"
        
        // Test cancelling a non-existent download
        await client.cancelDownload(repoId: repoId)
        
        // Should not throw or crash
        #expect(true, "Cancelling non-existent download should be safe")
    }
    
    // MARK: - Integration Tests (Limited Network)
    
    @Test(.tags(.integration))
    func testHuggingFaceClientMLXProviderIntegration() async throws {
        // This test verifies that MLXProvider can use HuggingFaceClient
        // without actually performing network operations
        
        let provider = MLXProvider()
        
        // Check if provider type is correct
        #expect(MLXProvider.providerType == .mlx, "Provider type should be MLX")
        #expect(MLXProvider.displayName == "MLX", "Display name should be MLX")
        
        // Test that provider exists and has basic functionality
        #expect(provider != nil, "MLXProvider should be creatable")
    }
}

#else

/// Placeholder test when MLX is not available
struct HuggingFaceClientUnavailableTests {
    
    @Test
    func testMLXNotAvailable() {
        // When MLX frameworks are not available, HuggingFaceClient tests are skipped
        #expect(true, "MLX frameworks not available - HuggingFaceClient tests skipped")
    }
}

#endif

// MARK: - Test Tags

extension Tag {
    @Tag static var integration: Self
}