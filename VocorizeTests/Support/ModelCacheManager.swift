//
//  ModelCacheManager.swift
//  VocorizeTests
//
//  Core model caching system for integration tests
//  Reduces model download times from 5-30 minutes to <30 seconds on cache hits
//

import Foundation
import CryptoKit

/// Manages model caching for integration tests to reduce download times and improve CI/CD performance
public actor ModelCacheManager {
    
    // MARK: - Configuration
    
    /// Cache configuration settings
    public struct CacheConfiguration {
        /// Maximum total cache size in bytes (default: 2GB)
        public let maxCacheSize: Int64
        
        /// Maximum age for cached models in seconds (default: 7 days)
        public let maxAge: TimeInterval
        
        /// Cache directory path
        public let cacheDirectory: URL
        
        /// Whether to enable cache compression
        public let enableCompression: Bool
        
        public init(
            maxCacheSize: Int64 = 2_147_483_648, // 2GB
            maxAge: TimeInterval = 7 * 24 * 60 * 60, // 7 days
            cacheDirectory: URL? = nil,
            enableCompression: Bool = false
        ) {
            self.maxCacheSize = maxCacheSize
            self.maxAge = maxAge
            self.enableCompression = enableCompression
            
            if let customDir = cacheDirectory {
                self.cacheDirectory = customDir
            } else {
                // Use DerivedData for test caches to avoid conflicts with user models
                let derivedData = URL(fileURLWithPath: "/Users/john/Library/Developer/Xcode/DerivedData")
                self.cacheDirectory = derivedData
                    .appendingPathComponent("VocorizeTests")
                    .appendingPathComponent("ModelCache")
            }
        }
    }
    
    /// Cache statistics for monitoring
    public struct CacheStatistics {
        public let totalSize: Int64
        public let modelCount: Int
        public let hitRate: Double
        public let oldestModel: Date?
        public let newestModel: Date?
        public let availableSpace: Int64
        
        public var formattedTotalSize: String {
            ByteCountFormatter().string(fromByteCount: totalSize)
        }
        
        public var formattedAvailableSpace: String {
            ByteCountFormatter().string(fromByteCount: availableSpace)
        }
    }
    
    /// Model cache metadata
    private struct ModelCacheMetadata: Codable {
        let modelName: String
        let originalURL: URL?
        let checksum: String
        let cachedDate: Date
        let lastAccessDate: Date
        let size: Int64
        let version: String
        let isCompressed: Bool
        
        var fileName: String {
            return "\(modelName.replacingOccurrences(of: "/", with: "_"))"
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(cachedDate)
        }
        
        var lastAccessAge: TimeInterval {
            Date().timeIntervalSince(lastAccessDate)
        }
    }
    
    // MARK: - Properties
    
    private let configuration: CacheConfiguration
    private var statistics = CacheStatistics(
        totalSize: 0, 
        modelCount: 0, 
        hitRate: 0.0, 
        oldestModel: nil, 
        newestModel: nil,
        availableSpace: 0
    )
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private let metadataFileName = "cache_metadata.json"
    
    // MARK: - Initialization
    
    public init(configuration: CacheConfiguration = CacheConfiguration()) {
        self.configuration = configuration
    }
    
    // MARK: - Public Interface
    
    /// Retrieves a cached model if available and valid
    /// - Parameter modelName: Name of the model to retrieve
    /// - Returns: URL of cached model or nil if not available
    public func getCachedModel(_ modelName: String) async -> URL? {
        do {
            await ensureCacheDirectoryExists()
            
            guard let metadata = await loadMetadata(),
                  let modelMetadata = metadata.first(where: { $0.modelName == modelName })
            else {
                await recordCacheMiss()
                return nil
            }
            
            let cachedModelPath = getCachedModelPath(for: modelMetadata)
            
            // Verify cached model exists and is valid
            guard FileManager.default.fileExists(atPath: cachedModelPath.path),
                  await validateCachedModel(metadata: modelMetadata)
            else {
                // Remove invalid cache entry
                try await removeCachedModel(modelName)
                await recordCacheMiss()
                return nil
            }
            
            // Update last access time
            await updateLastAccessTime(for: modelName)
            await recordCacheHit()
            
            print("🎯 Cache HIT: \(modelName) (age: \(formatTimeInterval(modelMetadata.age)))")
            return cachedModelPath
            
        } catch {
            print("⚠️ Cache error retrieving \(modelName): \(error)")
            await recordCacheMiss()
            return nil
        }
    }
    
    /// Caches a model from the given URL
    /// - Parameters:
    ///   - modelName: Name of the model to cache
    ///   - sourceURL: URL where the model is located (file or directory)
    /// - Throws: CacheError if caching fails
    public func cacheModel(_ modelName: String, from sourceURL: URL) async throws {
        print("💾 Caching model: \(modelName)")
        
        await ensureCacheDirectoryExists()
        
        // Verify source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CacheError.sourceNotFound(sourceURL)
        }
        
        // Calculate checksum for validation
        let checksum = try await calculateChecksum(for: sourceURL)
        let size = try calculateSize(for: sourceURL)
        
        // Check if we have space for this model
        try await ensureCacheSpace(requiredSize: size)
        
        // Create cache metadata
        let metadata = ModelCacheMetadata(
            modelName: modelName,
            originalURL: sourceURL,
            checksum: checksum,
            cachedDate: Date(),
            lastAccessDate: Date(),
            size: size,
            version: "1.0",
            isCompressed: configuration.enableCompression
        )
        
        let cachedPath = getCachedModelPath(for: metadata)
        
        // Copy model to cache
        if configuration.enableCompression {
            try await compressAndCache(from: sourceURL, to: cachedPath)
        } else {
            try await copyToCache(from: sourceURL, to: cachedPath)
        }
        
        // Update metadata
        await saveModelMetadata(metadata)
        await updateStatistics()
        
        print("✅ Cached model: \(modelName) (\(ByteCountFormatter().string(fromByteCount: size)))")
    }
    
    /// Removes a cached model
    /// - Parameter modelName: Name of the model to remove
    /// - Throws: CacheError if removal fails
    public func removeCachedModel(_ modelName: String) async throws {
        await ensureCacheDirectoryExists()
        
        guard var metadata = await loadMetadata(),
              let modelIndex = metadata.firstIndex(where: { $0.modelName == modelName })
        else {
            throw CacheError.modelNotFound(modelName)
        }
        
        let modelMetadata = metadata[modelIndex]
        let cachedPath = getCachedModelPath(for: modelMetadata)
        
        // Remove model files
        try FileManager.default.removeItem(at: cachedPath)
        
        // Remove from metadata
        metadata.remove(at: modelIndex)
        await saveMetadata(metadata)
        await updateStatistics()
        
        print("🗑️ Removed cached model: \(modelName)")
    }
    
    /// Validates that a cached model is still valid
    /// - Parameter modelName: Name of the model to validate
    /// - Returns: true if model is valid, false otherwise
    public func validateCachedModel(_ modelName: String) async -> Bool {
        guard let metadata = await loadMetadata(),
              let modelMetadata = metadata.first(where: { $0.modelName == modelName })
        else {
            return false
        }
        
        return await validateCachedModel(metadata: modelMetadata)
    }
    
    /// Clears cache entries older than the specified age
    /// - Parameter maxAge: Maximum age in seconds (defaults to configuration maxAge)
    public func clearCache(olderThan maxAge: TimeInterval? = nil) async {
        let ageLimit = maxAge ?? configuration.maxAge
        
        guard let metadata = await loadMetadata() else { return }
        
        let expiredModels = metadata.filter { $0.age > ageLimit }
        
        for model in expiredModels {
            do {
                try await removeCachedModel(model.modelName)
                print("🧹 Removed expired model: \(model.modelName) (age: \(formatTimeInterval(model.age)))")
            } catch {
                print("⚠️ Failed to remove expired model \(model.modelName): \(error)")
            }
        }
        
        if !expiredModels.isEmpty {
            print("✅ Cache cleanup completed: removed \(expiredModels.count) expired models")
        }
    }
    
    /// Gets current cache size in bytes
    /// - Returns: Total size of all cached models
    public func getCacheSize() async -> Int64 {
        await updateStatistics()
        return statistics.totalSize
    }
    
    /// Gets comprehensive cache statistics
    /// - Returns: CacheStatistics with current state
    public func getStatistics() async -> CacheStatistics {
        await updateStatistics()
        return statistics
    }
    
    /// Prints cache status for debugging
    public func printCacheStatus() async {
        let stats = await getStatistics()
        
        print("📊 Model Cache Status:")
        print("   Total Size: \(stats.formattedTotalSize)")
        print("   Model Count: \(stats.modelCount)")
        print("   Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
        print("   Available Space: \(stats.formattedAvailableSpace)")
        
        if let oldest = stats.oldestModel {
            print("   Oldest Model: \(formatTimeInterval(Date().timeIntervalSince(oldest))) ago")
        }
        
        if let newest = stats.newestModel {
            print("   Newest Model: \(formatTimeInterval(Date().timeIntervalSince(newest))) ago")
        }
    }
    
    /// Optimizes cache by removing least recently used models if needed
    public func optimizeCache() async {
        let currentSize = await getCacheSize()
        
        if currentSize <= configuration.maxCacheSize {
            return // No optimization needed
        }
        
        print("🔧 Optimizing cache: current size \(ByteCountFormatter().string(fromByteCount: currentSize))")
        
        guard var metadata = await loadMetadata() else { return }
        
        // Sort by last access time (oldest first)
        metadata.sort { $0.lastAccessAge > $1.lastAccessAge }
        
        var removedSize: Int64 = 0
        let targetReduction = currentSize - configuration.maxCacheSize
        
        for model in metadata {
            if removedSize >= targetReduction {
                break
            }
            
            do {
                removedSize += model.size
                try await removeCachedModel(model.modelName)
                print("🧹 Removed LRU model: \(model.modelName) (\(formatTimeInterval(model.lastAccessAge)) since last access)")
            } catch {
                print("⚠️ Failed to remove model \(model.modelName): \(error)")
            }
        }
        
        print("✅ Cache optimization completed: freed \(ByteCountFormatter().string(fromByteCount: removedSize))")
    }
    
    // MARK: - Private Methods
    
    private func ensureCacheDirectoryExists() async {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: configuration.cacheDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: configuration.cacheDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("📁 Created cache directory: \(configuration.cacheDirectory.path)")
            } catch {
                print("⚠️ Failed to create cache directory: \(error)")
            }
        }
    }
    
    private func getCachedModelPath(for metadata: ModelCacheMetadata) -> URL {
        let filename = metadata.fileName + (metadata.isCompressed ? ".tar.gz" : "")
        return configuration.cacheDirectory.appendingPathComponent(filename)
    }
    
    private func getMetadataPath() -> URL {
        return configuration.cacheDirectory.appendingPathComponent(metadataFileName)
    }
    
    private func loadMetadata() async -> [ModelCacheMetadata]? {
        let metadataPath = getMetadataPath()
        
        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: metadataPath)
            return try JSONDecoder().decode([ModelCacheMetadata].self, from: data)
        } catch {
            print("⚠️ Failed to load cache metadata: \(error)")
            return []
        }
    }
    
    private func saveMetadata(_ metadata: [ModelCacheMetadata]) async {
        let metadataPath = getMetadataPath()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: metadataPath)
        } catch {
            print("⚠️ Failed to save cache metadata: \(error)")
        }
    }
    
    private func saveModelMetadata(_ newMetadata: ModelCacheMetadata) async {
        guard var metadata = await loadMetadata() else {
            await saveMetadata([newMetadata])
            return
        }
        
        // Remove existing entry if present
        metadata.removeAll { $0.modelName == newMetadata.modelName }
        
        // Add new entry
        metadata.append(newMetadata)
        
        await saveMetadata(metadata)
    }
    
    private func updateLastAccessTime(for modelName: String) async {
        guard var metadata = await loadMetadata(),
              let index = metadata.firstIndex(where: { $0.modelName == modelName })
        else { return }
        
        var updatedMetadata = metadata[index]
        updatedMetadata = ModelCacheMetadata(
            modelName: updatedMetadata.modelName,
            originalURL: updatedMetadata.originalURL,
            checksum: updatedMetadata.checksum,
            cachedDate: updatedMetadata.cachedDate,
            lastAccessDate: Date(),
            size: updatedMetadata.size,
            version: updatedMetadata.version,
            isCompressed: updatedMetadata.isCompressed
        )
        
        metadata[index] = updatedMetadata
        await saveMetadata(metadata)
    }
    
    private func validateCachedModel(metadata: ModelCacheMetadata) async -> Bool {
        let cachedPath = getCachedModelPath(for: metadata)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: cachedPath.path) else {
            return false
        }
        
        // Validate checksum for integrity
        do {
            let currentChecksum = try await calculateChecksum(for: cachedPath)
            return currentChecksum == metadata.checksum
        } catch {
            print("⚠️ Failed to validate cached model \(metadata.modelName): \(error)")
            return false
        }
    }
    
    private func calculateChecksum(for url: URL) async throws -> String {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CacheError.sourceNotFound(url)
        }
        
        if isDirectory.boolValue {
            // Calculate checksum for directory contents
            return try await calculateDirectoryChecksum(for: url)
        } else {
            // Calculate checksum for single file
            return try await calculateFileChecksum(for: url)
        }
    }
    
    private func calculateFileChecksum(for url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func calculateDirectoryChecksum(for url: URL) async throws -> String {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .contentModificationDateKey]
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            throw CacheError.directoryEnumerationFailed(url)
        }
        
        var hasher = SHA256()
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isDirectory == true {
                continue
            }
            
            // Hash file path and content
            let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
            hasher.update(data: relativePath.data(using: .utf8) ?? Data())
            
            let fileData = try Data(contentsOf: fileURL)
            hasher.update(data: fileData)
        }
        
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func calculateSize(for url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CacheError.sourceNotFound(url)
        }
        
        if isDirectory.boolValue {
            return try calculateDirectorySize(for: url)
        } else {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        }
    }
    
    private func calculateDirectorySize(for url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    private func copyToCache(from sourceURL: URL, to destinationURL: URL) async throws {
        let fileManager = FileManager.default
        
        // Remove existing cached version if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    
    private func compressAndCache(from sourceURL: URL, to destinationURL: URL) async throws {
        // For now, just copy - compression can be added later if needed
        try await copyToCache(from: sourceURL, to: destinationURL)
    }
    
    private func ensureCacheSpace(requiredSize: Int64) async throws {
        let currentSize = await getCacheSize()
        let availableAfterCache = configuration.maxCacheSize - currentSize - requiredSize
        
        if availableAfterCache < 0 {
            // Need to free up space
            let spaceToFree = abs(availableAfterCache)
            print("🧹 Need to free \(ByteCountFormatter().string(fromByteCount: spaceToFree)) for new model")
            await optimizeCache()
            
            // Check if we now have space
            let newSize = await getCacheSize()
            if newSize + requiredSize > configuration.maxCacheSize {
                throw CacheError.insufficientSpace(required: requiredSize, available: configuration.maxCacheSize - newSize)
            }
        }
    }
    
    private func updateStatistics() async {
        guard let metadata = await loadMetadata() else {
            statistics = CacheStatistics(
                totalSize: 0, 
                modelCount: 0, 
                hitRate: 0.0, 
                oldestModel: nil, 
                newestModel: nil, 
                availableSpace: configuration.maxCacheSize
            )
            return
        }
        
        let totalSize = metadata.reduce(0) { $0 + $1.size }
        let modelCount = metadata.count
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        
        let oldestModel = metadata.min(by: { $0.cachedDate < $1.cachedDate })?.cachedDate
        let newestModel = metadata.max(by: { $0.cachedDate < $1.cachedDate })?.cachedDate
        
        statistics = CacheStatistics(
            totalSize: totalSize,
            modelCount: modelCount,
            hitRate: hitRate,
            oldestModel: oldestModel,
            newestModel: newestModel,
            availableSpace: configuration.maxCacheSize - totalSize
        )
    }
    
    private func recordCacheHit() async {
        hitCount += 1
    }
    
    private func recordCacheMiss() async {
        missCount += 1
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during cache operations
public enum CacheError: Error, LocalizedError {
    case sourceNotFound(URL)
    case modelNotFound(String)
    case directoryEnumerationFailed(URL)
    case insufficientSpace(required: Int64, available: Int64)
    case checksumValidationFailed(String)
    case cacheCorruption(String)
    
    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let url):
            return "Source file/directory not found: \(url.path)"
        case .modelNotFound(let modelName):
            return "Cached model not found: \(modelName)"
        case .directoryEnumerationFailed(let url):
            return "Failed to enumerate directory contents: \(url.path)"
        case .insufficientSpace(let required, let available):
            let requiredFormatted = ByteCountFormatter().string(fromByteCount: required)
            let availableFormatted = ByteCountFormatter().string(fromByteCount: available)
            return "Insufficient cache space. Required: \(requiredFormatted), Available: \(availableFormatted)"
        case .checksumValidationFailed(let modelName):
            return "Checksum validation failed for cached model: \(modelName)"
        case .cacheCorruption(let details):
            return "Cache corruption detected: \(details)"
        }
    }
}

// MARK: - Extensions

extension ModelCacheManager {
    
    /// Convenience method for test scenarios - warms cache with common models
    public func warmCache(with modelNames: [String]) async {
        print("🔥 Warming cache with \(modelNames.count) models...")
        
        for modelName in modelNames {
            if await getCachedModel(modelName) != nil {
                print("✅ \(modelName) already cached")
            } else {
                print("⏳ \(modelName) not in cache - will be downloaded on first use")
            }
        }
        
        await printCacheStatus()
    }
    
    /// Resets all cache statistics (useful for testing)
    public func resetStatistics() async {
        hitCount = 0
        missCount = 0
        await updateStatistics()
    }
}