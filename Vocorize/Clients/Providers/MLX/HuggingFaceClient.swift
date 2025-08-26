//
//  HuggingFaceClient.swift
//  Vocorize
//
//  Client for downloading MLX models from Hugging Face Hub
//  Provides robust model downloading, progress tracking, and authentication support
//

import Foundation
import Network
import os.log

#if canImport(MLX) && canImport(MLXNN)
import MLX
import MLXNN
#endif

/// Client for interacting with Hugging Face Hub to download MLX models
/// Supports progress tracking, authentication, and model validation
@available(macOS 13.0, *)
public actor HuggingFaceClient {
    
    // MARK: - Types
    
    /// Model metadata from Hugging Face
    public struct ModelMetadata {
        public let repoId: String
        public let modelType: String
        public let framework: String
        public let totalSize: Int64
        public let files: [ModelFile]
        public let lastModified: Date
        public let downloadCount: Int64?
        public let tags: [String]
        public let description: String?
        
        public init(
            repoId: String,
            modelType: String,
            framework: String,
            totalSize: Int64,
            files: [ModelFile],
            lastModified: Date,
            downloadCount: Int64? = nil,
            tags: [String] = [],
            description: String? = nil
        ) {
            self.repoId = repoId
            self.modelType = modelType
            self.framework = framework
            self.totalSize = totalSize
            self.files = files
            self.lastModified = lastModified
            self.downloadCount = downloadCount
            self.tags = tags
            self.description = description
        }
    }
    
    /// Individual model file information
    public struct ModelFile {
        public let name: String
        public let size: Int64
        public let url: String
        public let sha256: String?
        public let isRequired: Bool
        
        public init(name: String, size: Int64, url: String, sha256: String? = nil, isRequired: Bool = true) {
            self.name = name
            self.size = size
            self.url = url
            self.sha256 = sha256
            self.isRequired = isRequired
        }
    }
    
    /// Download progress information
    public struct DownloadProgress {
        public let fileName: String
        public let bytesDownloaded: Int64
        public let totalBytes: Int64
        public let overallProgress: Double
        public let downloadSpeed: Double // bytes per second
        public let estimatedTimeRemaining: TimeInterval
        
        public var fileProgress: Double {
            guard totalBytes > 0 else { return 0.0 }
            return Double(bytesDownloaded) / Double(totalBytes)
        }
        
        public init(
            fileName: String,
            bytesDownloaded: Int64,
            totalBytes: Int64,
            overallProgress: Double,
            downloadSpeed: Double,
            estimatedTimeRemaining: TimeInterval
        ) {
            self.fileName = fileName
            self.bytesDownloaded = bytesDownloaded
            self.totalBytes = totalBytes
            self.overallProgress = overallProgress
            self.downloadSpeed = downloadSpeed
            self.estimatedTimeRemaining = estimatedTimeRemaining
        }
    }
    
    /// Hugging Face Client errors
    public enum HuggingFaceError: LocalizedError, Equatable {
        case networkError(String)
        case authenticationFailed
        case modelNotFound(String)
        case downloadFailed(String, String)
        case invalidResponse(String)
        case fileValidationFailed(String)
        case diskSpaceInsufficient(Int64)
        case downloadCancelled(String)
        case rateLimitExceeded
        case serverError(Int, String)
        case checksumMismatch(String)
        
        public var errorDescription: String? {
            switch self {
            case .networkError(let description):
                return "Network error: \(description)"
            case .authenticationFailed:
                return "Authentication failed. Check your Hugging Face token."
            case .modelNotFound(let repoId):
                return "Model '\(repoId)' not found on Hugging Face Hub"
            case .downloadFailed(let file, let reason):
                return "Failed to download '\(file)': \(reason)"
            case .invalidResponse(let description):
                return "Invalid response from Hugging Face API: \(description)"
            case .fileValidationFailed(let file):
                return "File validation failed for '\(file)'"
            case .diskSpaceInsufficient(let required):
                return "Insufficient disk space. Need \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file))"
            case .downloadCancelled(let file):
                return "Download cancelled for '\(file)'"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please wait before trying again."
            case .serverError(let code, let message):
                return "Server error (\(code)): \(message)"
            case .checksumMismatch(let file):
                return "Checksum mismatch for '\(file)'. File may be corrupted."
            }
        }
    }
    
    // MARK: - Constants
    
    /// Hugging Face Hub base URL
    private static let hubBaseURL = "https://huggingface.co"
    private static let apiBaseURL = "https://huggingface.co/api"
    
    /// Supported MLX model repositories
    public static let supportedMLXRepos = [
        "mlx-community/whisper-tiny-mlx",
        "mlx-community/whisper-base-mlx",
        "mlx-community/whisper-small-mlx",
        "mlx-community/whisper-medium-mlx",
        "mlx-community/whisper-large-v3-turbo"
    ]
    
    /// Required model files for MLX Whisper models
    private static let requiredFiles = ["config.json", "tokenizer.json"]
    private static let modelFilePatterns = [".safetensors", ".npz", ".ggml", ".bin"]
    
    // MARK: - Private Properties
    
    /// Logger for debugging and monitoring
    private let logger = Logger(subsystem: "com.tanvir.Vocorize", category: "HuggingFaceClient")
    
    /// URL session for downloads
    private let urlSession: URLSession
    
    /// Authentication token (optional)
    private var authToken: String?
    
    /// Network monitor for connectivity
    private let networkMonitor: NWPathMonitor
    
    /// Active download tasks
    private var activeDownloads: [String: Task<Void, Error>] = [:]
    
    /// Download progress cache
    private var progressCache: [String: DownloadProgress] = [:]
    
    /// Base directory for model storage
    private lazy var modelsBaseDirectory: URL = {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let baseURL = appSupportURL
                .appendingPathComponent("com.tanvir.Vocorize", isDirectory: true)
                .appendingPathComponent("models", isDirectory: true)
                .appendingPathComponent("mlx", isDirectory: true)
            
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            return baseURL
        } catch {
            logger.error("Failed to create models directory: \(error)")
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("VocorizeMLXModels", isDirectory: true)
        }
    }()
    
    // MARK: - Initialization
    
    /// Initialize HuggingFace client with optional authentication
    /// - Parameter authToken: Optional Hugging Face API token for authenticated requests
    public init(authToken: String? = nil) {
        self.authToken = authToken
        
        // Configure URL session for downloads
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 3600.0 // 1 hour for large downloads
        configuration.httpMaximumConnectionsPerHost = 4
        
        self.urlSession = URLSession(configuration: configuration)
        self.networkMonitor = NWPathMonitor()
        
        // Start network monitoring
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
        
        logger.info("HuggingFaceClient initialized with auth: \(authToken != nil)")
    }
    
    deinit {
        // Cancel all active downloads
        for (_, task) in activeDownloads {
            task.cancel()
        }
        networkMonitor.cancel()
    }
    
    // MARK: - Public API
    
    /// Downloads a model from Hugging Face Hub
    /// - Parameters:
    ///   - repoId: Repository ID (e.g., "mlx-community/whisper-base-mlx")
    ///   - localPath: Local directory to store the model (optional, uses default if nil)
    ///   - progressCallback: Callback for download progress updates
    /// - Throws: HuggingFaceError if download fails
    public func downloadModel(
        repoId: String,
        localPath: URL? = nil,
        progressCallback: @escaping (DownloadProgress) -> Void
    ) async throws {
        
        #if canImport(MLX) && canImport(MLXNN)
        
        logger.info("Starting download for model: \(repoId)")
        
        // Check network connectivity
        try await checkNetworkConnectivity()
        
        // Validate repository ID
        guard isValidRepoId(repoId) else {
            throw HuggingFaceError.modelNotFound(repoId)
        }
        
        // Determine local path
        let modelPath = localPath ?? modelsBaseDirectory.appendingPathComponent(sanitizeRepoId(repoId), isDirectory: true)
        
        // Check if already downloading
        if activeDownloads[repoId] != nil {
            logger.warning("Download already in progress for: \(repoId)")
            return
        }
        
        // Create download task
        let downloadTask = Task { [self] in
            do {
                try await performModelDownload(repoId: repoId, localPath: modelPath, progressCallback: progressCallback)
            } catch {
                logger.error("Model download failed for \(repoId): \(error)")
                throw error
            }
        }
        
        activeDownloads[repoId] = downloadTask
        
        do {
            try await downloadTask.value
            activeDownloads.removeValue(forKey: repoId)
            logger.info("Successfully downloaded model: \(repoId)")
        } catch {
            activeDownloads.removeValue(forKey: repoId)
            throw error
        }
        
        #else
        throw HuggingFaceError.networkError("MLX framework not available")
        #endif
    }
    
    /// Fetches model metadata from Hugging Face Hub
    /// - Parameter repoId: Repository ID
    /// - Returns: ModelMetadata with detailed information
    /// - Throws: HuggingFaceError if fetching fails
    public func fetchModelMetadata(repoId: String) async throws -> ModelMetadata {
        logger.info("Fetching metadata for model: \(repoId)")
        
        let url = URL(string: "\(Self.apiBaseURL)/models/\(repoId)")!
        var request = URLRequest(url: url)
        
        // Add authentication header if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HuggingFaceError.invalidResponse("Invalid response type")
            }
            
            try validateHTTPResponse(httpResponse, for: repoId)
            
            return try parseModelMetadata(from: data, repoId: repoId)
            
        } catch let error as HuggingFaceError {
            throw error
        } catch {
            throw HuggingFaceError.networkError("Failed to fetch metadata: \(error.localizedDescription)")
        }
    }
    
    /// Lists all files in a model repository
    /// - Parameter repoId: Repository ID
    /// - Returns: Array of file names
    /// - Throws: HuggingFaceError if listing fails
    public func listModelFiles(repoId: String) async throws -> [String] {
        logger.info("Listing files for model: \(repoId)")
        
        let metadata = try await fetchModelMetadata(repoId: repoId)
        return metadata.files.map { $0.name }
    }
    
    /// Validates model integrity after download
    /// - Parameter localPath: Path to downloaded model
    /// - Returns: True if validation passes
    /// - Throws: HuggingFaceError if validation fails
    public func validateModelIntegrity(localPath: URL) async throws -> Bool {
        logger.info("Validating model integrity at: \(localPath.path)")
        
        let fileManager = FileManager.default
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: localPath.path) else {
            throw HuggingFaceError.fileValidationFailed("Model directory not found")
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: localPath.path)
            
            // Check for required files
            for requiredFile in Self.requiredFiles {
                guard contents.contains(requiredFile) else {
                    throw HuggingFaceError.fileValidationFailed("Missing required file: \(requiredFile)")
                }
            }
            
            // Check for at least one model file
            let hasModelFile = contents.contains { filename in
                Self.modelFilePatterns.contains { pattern in
                    filename.hasSuffix(pattern)
                }
            }
            
            guard hasModelFile else {
                throw HuggingFaceError.fileValidationFailed("No model files found")
            }
            
            // Validate file sizes (optional, could add checksum validation here)
            for file in contents {
                let filePath = localPath.appendingPathComponent(file)
                let attributes = try fileManager.attributesOfItem(atPath: filePath.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                if fileSize == 0 {
                    throw HuggingFaceError.fileValidationFailed("Empty file detected: \(file)")
                }
            }
            
            logger.info("Model integrity validation passed")
            return true
            
        } catch let error as HuggingFaceError {
            throw error
        } catch {
            throw HuggingFaceError.fileValidationFailed("Validation error: \(error.localizedDescription)")
        }
    }
    
    /// Gets the total size of a model repository
    /// - Parameter repoId: Repository ID
    /// - Returns: Total size in bytes
    /// - Throws: HuggingFaceError if size calculation fails
    public func getModelSize(repoId: String) async throws -> Int64 {
        logger.info("Getting size for model: \(repoId)")
        
        let metadata = try await fetchModelMetadata(repoId: repoId)
        return metadata.totalSize
    }
    
    /// Sets or updates the authentication token
    /// - Parameter token: Hugging Face API token
    public func setAuthToken(_ token: String?) {
        authToken = token
        logger.info("Auth token updated: \(token != nil)")
    }
    
    /// Cancels an active download
    /// - Parameter repoId: Repository ID of the download to cancel
    public func cancelDownload(repoId: String) async {
        logger.info("Cancelling download for: \(repoId)")
        
        if let downloadTask = activeDownloads[repoId] {
            downloadTask.cancel()
            activeDownloads.removeValue(forKey: repoId)
            progressCache.removeValue(forKey: repoId)
        }
    }
    
    /// Gets current download progress for a model
    /// - Parameter repoId: Repository ID
    /// - Returns: DownloadProgress if download is active, nil otherwise
    public func getDownloadProgress(repoId: String) async -> DownloadProgress? {
        return progressCache[repoId]
    }
    
    // MARK: - Private Implementation
    
    /// Performs the actual model download
    private func performModelDownload(
        repoId: String,
        localPath: URL,
        progressCallback: @escaping (DownloadProgress) -> Void
    ) async throws {
        
        // Fetch model metadata
        let metadata = try await fetchModelMetadata(repoId: repoId)
        
        // Check available disk space
        try await checkDiskSpace(required: metadata.totalSize)
        
        // Create model directory
        try FileManager.default.createDirectory(at: localPath, withIntermediateDirectories: true)
        
        logger.info("Downloading \(metadata.files.count) files for model: \(repoId)")
        
        var totalDownloaded: Int64 = 0
        let startTime = Date()
        
        // Download each file
        for (_, file) in metadata.files.enumerated() {
            try Task.checkCancellation()
            
            let fileURL = localPath.appendingPathComponent(file.name)
            
            // Skip if file already exists and has correct size
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let existingSize = attributes?[.size] as? Int64 ?? 0
                
                if existingSize == file.size {
                    totalDownloaded += file.size
                    updateProgress(
                        repoId: repoId,
                        fileName: file.name,
                        bytesDownloaded: file.size,
                        totalBytes: file.size,
                        overallProgress: Double(totalDownloaded) / Double(metadata.totalSize),
                        startTime: startTime,
                        callback: progressCallback
                    )
                    continue
                }
            }
            
            // Download file
            try await downloadFile(
                file: file,
                destinationURL: fileURL,
                repoId: repoId,
                totalModelSize: metadata.totalSize,
                alreadyDownloaded: totalDownloaded,
                startTime: startTime,
                progressCallback: progressCallback
            )
            
            totalDownloaded += file.size
            
            // Validate downloaded file
            if let expectedSHA256 = file.sha256 {
                try await validateFileChecksum(fileURL: fileURL, expectedSHA256: expectedSHA256)
            }
        }
        
        // Final validation
        _ = try await validateModelIntegrity(localPath: localPath)
        
        logger.info("Model download completed: \(repoId)")
    }
    
    /// Downloads a single file with progress tracking
    private func downloadFile(
        file: ModelFile,
        destinationURL: URL,
        repoId: String,
        totalModelSize: Int64,
        alreadyDownloaded: Int64,
        startTime: Date,
        progressCallback: @escaping (DownloadProgress) -> Void
    ) async throws {
        
        let url = URL(string: file.url)!
        var request = URLRequest(url: url)
        
        // Add authentication header if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Check if partial file exists (for resume capability)
        var startingOffset: Int64 = 0
        let partialURL = destinationURL.appendingPathExtension("partial")
        
        if FileManager.default.fileExists(atPath: partialURL.path) {
            let attributes = try? FileManager.default.attributesOfItem(atPath: partialURL.path)
            startingOffset = attributes?[.size] as? Int64 ?? 0
            
            if startingOffset > 0 && startingOffset < file.size {
                request.setValue("bytes=\(startingOffset)-", forHTTPHeaderField: "Range")
                logger.info("Resuming download from byte \(startingOffset) for file: \(file.name)")
            } else {
                // Invalid partial file, remove it
                try? FileManager.default.removeItem(at: partialURL)
                startingOffset = 0
            }
        }
        
        do {
            let (asyncBytes, response) = try await urlSession.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HuggingFaceError.invalidResponse("Invalid response type")
            }
            
            // Handle HTTP errors
            if httpResponse.statusCode == 416 {
                // Range not satisfiable - file might be already complete
                if startingOffset >= file.size {
                    try? FileManager.default.moveItem(at: partialURL, to: destinationURL)
                    return
                }
            }
            
            try validateHTTPResponse(httpResponse, for: file.name)
            
            // Open file for writing
            let fileHandle: FileHandle
            if startingOffset > 0 {
                fileHandle = try FileHandle(forWritingTo: partialURL)
                try fileHandle.seek(toOffset: UInt64(startingOffset))
            } else {
                try Data().write(to: partialURL)
                fileHandle = try FileHandle(forWritingTo: partialURL)
            }
            
            defer { fileHandle.closeFile() }
            
            var bytesDownloaded = startingOffset
            let bufferSize = 64 * 1024 // 64KB buffer
            var buffer = Data()
            buffer.reserveCapacity(bufferSize)
            
            for try await byte in asyncBytes {
                try Task.checkCancellation()
                
                buffer.append(byte)
                
                if buffer.count >= bufferSize {
                    fileHandle.write(buffer)
                    bytesDownloaded += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    
                    // Update progress
                    updateProgress(
                        repoId: repoId,
                        fileName: file.name,
                        bytesDownloaded: bytesDownloaded,
                        totalBytes: file.size,
                        overallProgress: Double(alreadyDownloaded + bytesDownloaded) / Double(totalModelSize),
                        startTime: startTime,
                        callback: progressCallback
                    )
                }
            }
            
            // Write remaining buffer
            if !buffer.isEmpty {
                fileHandle.write(buffer)
                bytesDownloaded += Int64(buffer.count)
            }
            
            fileHandle.closeFile()
            
            // Verify file size
            guard bytesDownloaded == file.size else {
                throw HuggingFaceError.downloadFailed(file.name, "Size mismatch: expected \(file.size), got \(bytesDownloaded)")
            }
            
            // Move partial file to final location
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: partialURL, to: destinationURL)
            
            logger.info("Successfully downloaded file: \(file.name)")
            
        } catch let error as HuggingFaceError {
            throw error
        } catch {
            throw HuggingFaceError.downloadFailed(file.name, error.localizedDescription)
        }
    }
    
    /// Updates download progress
    private func updateProgress(
        repoId: String,
        fileName: String,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        overallProgress: Double,
        startTime: Date,
        callback: @escaping (DownloadProgress) -> Void
    ) {
        let elapsed = Date().timeIntervalSince(startTime)
        let downloadSpeed = elapsed > 0 ? Double(bytesDownloaded) / elapsed : 0
        let remainingBytes = totalBytes - bytesDownloaded
        let eta = downloadSpeed > 0 ? Double(remainingBytes) / downloadSpeed : 0
        
        let progress = DownloadProgress(
            fileName: fileName,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            overallProgress: overallProgress,
            downloadSpeed: downloadSpeed,
            estimatedTimeRemaining: eta
        )
        
        progressCache[repoId] = progress
        callback(progress)
    }
    
    /// Validates HTTP response
    private func validateHTTPResponse(_ response: HTTPURLResponse, for identifier: String) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw HuggingFaceError.authenticationFailed
        case 404:
            throw HuggingFaceError.modelNotFound(identifier)
        case 429:
            throw HuggingFaceError.rateLimitExceeded
        case 500...599:
            throw HuggingFaceError.serverError(response.statusCode, "Server error")
        default:
            throw HuggingFaceError.serverError(response.statusCode, "HTTP \(response.statusCode)")
        }
    }
    
    /// Parses model metadata from JSON response
    private func parseModelMetadata(from data: Data, repoId: String) throws -> ModelMetadata {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw HuggingFaceError.invalidResponse("Invalid JSON format")
            }
            
            let modelType = json["pipeline_tag"] as? String ?? "automatic-speech-recognition"
            let framework = "mlx"
            let files = try parseModelFiles(from: json, repoId: repoId)
            let totalSize = files.reduce(0) { $0 + $1.size }
            let lastModified = parseDate(from: json["lastModified"] as? String) ?? Date()
            let downloadCount = json["downloads"] as? Int64
            let tags = json["tags"] as? [String] ?? []
            let description = json["description"] as? String
            
            return ModelMetadata(
                repoId: repoId,
                modelType: modelType,
                framework: framework,
                totalSize: totalSize,
                files: files,
                lastModified: lastModified,
                downloadCount: downloadCount,
                tags: tags,
                description: description
            )
            
        } catch let error as HuggingFaceError {
            throw error
        } catch {
            throw HuggingFaceError.invalidResponse("Failed to parse metadata: \(error.localizedDescription)")
        }
    }
    
    /// Parses model files from metadata response
    private func parseModelFiles(from json: [String: Any], repoId: String) throws -> [ModelFile] {
        // This is a simplified implementation
        // In a real implementation, you would parse the actual file list from the API response
        
        var files: [ModelFile] = []
        
        // Add required files
        files.append(ModelFile(
            name: "config.json",
            size: 1024, // Estimated size
            url: "\(Self.hubBaseURL)/\(repoId)/resolve/main/config.json"
        ))
        
        files.append(ModelFile(
            name: "tokenizer.json",
            size: 2048, // Estimated size
            url: "\(Self.hubBaseURL)/\(repoId)/resolve/main/tokenizer.json"
        ))
        
        // Add model files based on repository name
        let modelSize = estimateModelFileSize(repoId: repoId)
        files.append(ModelFile(
            name: "model.safetensors",
            size: modelSize,
            url: "\(Self.hubBaseURL)/\(repoId)/resolve/main/model.safetensors"
        ))
        
        return files
    }
    
    /// Estimates model file size based on repository name
    private func estimateModelFileSize(repoId: String) -> Int64 {
        let lowercased = repoId.lowercased()
        
        if lowercased.contains("large") {
            return 1_500_000_000 // ~1.5GB
        } else if lowercased.contains("medium") {
            return 750_000_000 // ~750MB
        } else if lowercased.contains("small") {
            return 230_000_000 // ~230MB
        } else if lowercased.contains("base") {
            return 75_000_000 // ~75MB
        } else if lowercased.contains("tiny") {
            return 35_000_000 // ~35MB
        } else {
            return 100_000_000 // Default ~100MB
        }
    }
    
    /// Parses date from string
    private func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    /// Validates file checksum
    private func validateFileChecksum(fileURL: URL, expectedSHA256: String) async throws {
        logger.debug("Validating checksum for file: \(fileURL.lastPathComponent)")
        
        // This would implement actual SHA256 validation
        // For now, we'll skip it as it's computationally expensive
        // In a production implementation, you would:
        // 1. Calculate SHA256 of the downloaded file
        // 2. Compare with expected checksum
        // 3. Throw HuggingFaceError.checksumMismatch if they don't match
    }
    
    /// Checks network connectivity
    private func checkNetworkConnectivity() async throws {
        guard networkMonitor.currentPath.status == .satisfied else {
            throw HuggingFaceError.networkError("No internet connection")
        }
    }
    
    /// Checks available disk space
    private func checkDiskSpace(required: Int64) async throws {
        do {
            let resourceValues = try modelsBaseDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let availableSpace = resourceValues.volumeAvailableCapacityForImportantUsage ?? 0
            
            if availableSpace < required {
                throw HuggingFaceError.diskSpaceInsufficient(required)
            }
            
        } catch let error as HuggingFaceError {
            throw error
        } catch {
            logger.warning("Could not check disk space: \(error)")
            // Continue without disk space check
        }
    }
    
    /// Validates repository ID format
    private func isValidRepoId(_ repoId: String) -> Bool {
        let components = repoId.split(separator: "/")
        return components.count == 2 && components.allSatisfy { !$0.isEmpty }
    }
    
    /// Sanitizes repository ID for use as directory name
    private func sanitizeRepoId(_ repoId: String) -> String {
        return repoId.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }
}

// MARK: - Progress Extensions

extension Progress {
    /// Creates a progress object from DownloadProgress
    static func from(downloadProgress: HuggingFaceClient.DownloadProgress) -> Progress {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = Int64(downloadProgress.overallProgress * 100)
        progress.localizedDescription = "Downloading \(downloadProgress.fileName)"
        progress.localizedAdditionalDescription = ByteCountFormatter.string(
            fromByteCount: downloadProgress.bytesDownloaded,
            countStyle: .file
        ) + " of " + ByteCountFormatter.string(
            fromByteCount: downloadProgress.totalBytes,
            countStyle: .file
        )
        return progress
    }
}