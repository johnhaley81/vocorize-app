//
//  MLXAudioProcessor.swift
//  Vocorize
//
//  MLX Audio Processing Utility for Whisper Model Compatibility
//  Converts audio files to MLX tensor format with mel spectrogram generation
//  and preprocessing compatible with OpenAI Whisper models.
//

import Foundation
import AVFoundation
import Accelerate

#if canImport(MLX) && canImport(MLXNN)
import MLX
import MLXNN
#endif

/// Audio format processing errors specific to MLX operations
public enum MLXAudioProcessorError: LocalizedError, Equatable {
    case mlxNotAvailable
    case unsupportedAudioFormat(String)
    case audioFileReadFailed(String)
    case audioConversionFailed(String)
    case melSpectrogramComputationFailed(String)
    case memoryAllocationFailed
    case invalidSampleRate(Int, expected: Int)
    case audioTooLong(Double, maxSeconds: Double)
    case audioTooShort(Double, minSeconds: Double)
    
    public var errorDescription: String? {
        switch self {
        case .mlxNotAvailable:
            return "MLX framework is not available on this system"
        case .unsupportedAudioFormat(let format):
            return "Unsupported audio format: \(format)"
        case .audioFileReadFailed(let path):
            return "Failed to read audio file: \(path)"
        case .audioConversionFailed(let reason):
            return "Audio conversion failed: \(reason)"
        case .melSpectrogramComputationFailed(let reason):
            return "Mel spectrogram computation failed: \(reason)"
        case .memoryAllocationFailed:
            return "Failed to allocate memory for audio processing"
        case .invalidSampleRate(let actual, let expected):
            return "Invalid sample rate: \(actual)Hz, expected: \(expected)Hz"
        case .audioTooLong(let duration, let maxSeconds):
            return "Audio too long: \(duration)s, maximum: \(maxSeconds)s"
        case .audioTooShort(let duration, let minSeconds):
            return "Audio too short: \(duration)s, minimum: \(minSeconds)s"
        }
    }
    
    public static func == (lhs: MLXAudioProcessorError, rhs: MLXAudioProcessorError) -> Bool {
        switch (lhs, rhs) {
        case (.mlxNotAvailable, .mlxNotAvailable): return true
        case (.unsupportedAudioFormat(let l), .unsupportedAudioFormat(let r)): return l == r
        case (.audioFileReadFailed(let l), .audioFileReadFailed(let r)): return l == r
        case (.audioConversionFailed(let l), .audioConversionFailed(let r)): return l == r
        case (.melSpectrogramComputationFailed(let l), .melSpectrogramComputationFailed(let r)): return l == r
        case (.memoryAllocationFailed, .memoryAllocationFailed): return true
        case (.invalidSampleRate(let l1, let l2), .invalidSampleRate(let r1, let r2)): return l1 == r1 && l2 == r2
        case (.audioTooLong(let l1, let l2), .audioTooLong(let r1, let r2)): return l1 == r1 && l2 == r2
        case (.audioTooShort(let l1, let l2), .audioTooShort(let r1, let r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }
}

/// Progress reporting callback for long-running audio operations
public typealias AudioProcessingProgressCallback = (Double) -> Void

/// Audio processing configuration for Whisper model compatibility
public struct MLXAudioConfig {
    /// Target sample rate (16kHz standard for Whisper)
    public let sampleRate: Int
    /// Number of mel filter banks
    public let melFilters: Int
    /// FFT frame size in samples (25ms at 16kHz)
    public let frameSize: Int
    /// Hop length in samples (10ms at 16kHz)
    public let hopLength: Int
    /// Maximum audio duration in seconds
    public let maxDurationSeconds: Double
    /// Minimum audio duration in seconds
    public let minDurationSeconds: Double
    
    public static let whisperDefault = MLXAudioConfig(
        sampleRate: 16000,
        melFilters: 80,
        frameSize: 400,
        hopLength: 160,
        maxDurationSeconds: 30.0,
        minDurationSeconds: 0.1
    )
    
    public init(
        sampleRate: Int = 16000,
        melFilters: Int = 80,
        frameSize: Int = 400,
        hopLength: Int = 160,
        maxDurationSeconds: Double = 30.0,
        minDurationSeconds: Double = 0.1
    ) {
        self.sampleRate = sampleRate
        self.melFilters = melFilters
        self.frameSize = frameSize
        self.hopLength = hopLength
        self.maxDurationSeconds = maxDurationSeconds
        self.minDurationSeconds = minDurationSeconds
    }
}

/// MLX Audio Processor for converting audio files to MLX-compatible tensors
/// Implements Whisper-compatible preprocessing including mel spectrogram generation
@available(macOS 13.0, *)
public class MLXAudioProcessor: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let config: MLXAudioConfig
    private let supportedFormats: Set<String>
    
    // MARK: - Initialization
    
    public init(config: MLXAudioConfig = .whisperDefault) {
        self.config = config
        self.supportedFormats = Set([
            "wav", "wave", "m4a", "mp3", "aac", "flac", "aiff", "caf"
        ])
    }
    
    // MARK: - Public Interface
    
    /// Returns list of supported audio formats
    public func getSupportedFormats() -> [String] {
        return Array(supportedFormats).sorted()
    }
    
    /// Validates if an audio format is supported
    public func validateAudioFormat(_ fileURL: URL) throws -> Bool {
        let pathExtension = fileURL.pathExtension.lowercased()
        
        guard supportedFormats.contains(pathExtension) else {
            throw MLXAudioProcessorError.unsupportedAudioFormat(pathExtension)
        }
        
        return true
    }
    
    /// Main entry point: Process audio file and return MLX tensor
    public func processAudioFile(
        _ fileURL: URL,
        progressCallback: AudioProcessingProgressCallback? = nil
    ) async throws -> MLXArray {
        #if canImport(MLX) && canImport(MLXNN)
        // Validate MLX availability
        guard MLXAvailability.areProductsAvailable else {
            throw MLXAudioProcessorError.mlxNotAvailable
        }
        
        // Validate audio format
        _ = try validateAudioFormat(fileURL)
        
        progressCallback?(0.1)
        
        // Load and convert audio to target sample rate
        let audioSamples = try await loadAudioFile(fileURL)
        
        progressCallback?(0.3)
        
        // Validate audio duration
        let duration = Double(audioSamples.count) / Double(config.sampleRate)
        try validateAudioDuration(duration)
        
        // Normalize audio samples
        let normalizedAudio = try normalizeAudio(audioSamples)
        
        progressCallback?(0.5)
        
        // Compute mel spectrogram
        let melSpectrogram = try await computeMelSpectrogram(normalizedAudio)
        
        progressCallback?(0.8)
        
        // Convert to MLX tensor
        let mlxTensor = try convertToMLXArray(melSpectrogram)
        
        progressCallback?(1.0)
        
        return mlxTensor
        #else
        throw MLXAudioProcessorError.mlxNotAvailable
        #endif
    }
    
    // MARK: - Private Audio Processing Methods
    
    private func loadAudioFile(_ fileURL: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let audioFile = try AVAudioFile(forReading: fileURL)
                    let audioFormat = audioFile.processingFormat
                    
                    // Create target format (16kHz mono)
                    guard let targetFormat = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: Double(self.config.sampleRate),
                        channels: 1,
                        interleaved: false
                    ) else {
                        continuation.resume(throwing: MLXAudioProcessorError.audioConversionFailed("Failed to create target format"))
                        return
                    }
                    
                    // Calculate target frame count
                    let sourceFrameCount = AVAudioFrameCount(audioFile.length)
                    let targetFrameCount = AVAudioFrameCount(
                        Double(sourceFrameCount) * targetFormat.sampleRate / audioFormat.sampleRate
                    )
                    
                    // Create converter
                    guard let converter = AVAudioConverter(from: audioFormat, to: targetFormat) else {
                        continuation.resume(throwing: MLXAudioProcessorError.audioConversionFailed("Failed to create audio converter"))
                        return
                    }
                    
                    // Create target buffer
                    guard let targetBuffer = AVAudioPCMBuffer(
                        pcmFormat: targetFormat,
                        frameCapacity: targetFrameCount
                    ) else {
                        continuation.resume(throwing: MLXAudioProcessorError.memoryAllocationFailed)
                        return
                    }
                    
                    // Read and convert audio
                    let inputBuffer = AVAudioPCMBuffer(
                        pcmFormat: audioFormat,
                        frameCapacity: sourceFrameCount
                    )!
                    
                    try audioFile.read(into: inputBuffer)
                    
                    var error: NSError?
                    let status = converter.convert(to: targetBuffer, error: &error) { _, outStatus in
                        outStatus.pointee = .haveData
                        return inputBuffer
                    }
                    
                    if status == .error {
                        continuation.resume(throwing: error ?? MLXAudioProcessorError.audioConversionFailed("Unknown conversion error"))
                        return
                    }
                    
                    // Extract float samples
                    let channelData = targetBuffer.floatChannelData![0]
                    let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(targetBuffer.frameLength)))
                    
                    continuation.resume(returning: samples)
                } catch {
                    continuation.resume(throwing: MLXAudioProcessorError.audioFileReadFailed(error.localizedDescription))
                }
            }
        }
    }
    
    private func validateAudioDuration(_ duration: Double) throws {
        if duration > config.maxDurationSeconds {
            throw MLXAudioProcessorError.audioTooLong(duration, maxSeconds: config.maxDurationSeconds)
        }
        
        if duration < config.minDurationSeconds {
            throw MLXAudioProcessorError.audioTooShort(duration, minSeconds: config.minDurationSeconds)
        }
    }
    
    private func normalizeAudio(_ samples: [Float]) throws -> [Float] {
        guard !samples.isEmpty else {
            throw MLXAudioProcessorError.audioConversionFailed("Empty audio samples")
        }
        
        var normalizedSamples = samples
        
        // Find max absolute value for normalization
        let maxAbsValue = samples.map { abs($0) }.max() ?? 1.0
        
        // Avoid division by zero
        if maxAbsValue > Float.ulpOfOne {
            vDSP_vsdiv(samples, 1, [maxAbsValue], &normalizedSamples, 1, vDSP_Length(samples.count))
        }
        
        return normalizedSamples
    }
    
    private func computeMelSpectrogram(_ audioSamples: [Float]) async throws -> [[Float]] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let spectrogram = try self.computeSTFT(audioSamples)
                    let melFilters = self.createMelFilterBank()
                    let melSpectrogram = try self.applyMelFilters(spectrogram, melFilters: melFilters)
                    continuation.resume(returning: melSpectrogram)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func computeSTFT(_ samples: [Float]) throws -> [[Float]] {
        let frameCount = (samples.count - config.frameSize) / config.hopLength + 1
        let fftSize = config.frameSize
        let halfFftSize = fftSize / 2 + 1
        
        guard frameCount > 0 else {
            throw MLXAudioProcessorError.melSpectrogramComputationFailed("Audio too short for STFT")
        }
        
        // Setup FFT
        guard let fftSetup = vDSP_create_fftsetup(
            vDSP_Length(log2(Float(fftSize))),
            FFTRadix(kFFTRadix2)
        ) else {
            throw MLXAudioProcessorError.melSpectrogramComputationFailed("Failed to create FFT setup")
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var spectrogram: [[Float]] = []
        
        // Hann window
        let piConstant = Float.pi
        let fftSizeFloat = Float(fftSize)
        let fftSizeMinusOne = Float(fftSize - 1)
        let window = (0..<fftSize).map { i in
            let indexFloat = Float(i)
            let angle = 2 * piConstant * indexFloat / fftSizeMinusOne
            return 0.5 * (1 - cos(angle))
        }
        
        for frameIndex in 0..<frameCount {
            let startIndex = frameIndex * config.hopLength
            let endIndex = min(startIndex + fftSize, samples.count)
            
            // Extract frame and apply window
            var frame = Array(samples[startIndex..<endIndex])
            
            // Zero-pad if necessary
            while frame.count < fftSize {
                frame.append(0.0)
            }
            
            // Apply Hann window
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))
            
            // Prepare complex buffer for FFT
            var realPart = Array<Float>(repeating: 0, count: halfFftSize)
            var imagPart = Array<Float>(repeating: 0, count: halfFftSize)
            
            // Use withUnsafeMutableBufferPointer for proper pointer management
            let fftResult = realPart.withUnsafeMutableBufferPointer { realBuffer in
                imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                    var complexBuffer = DSPSplitComplex(
                        realp: realBuffer.baseAddress!,
                        imagp: imagBuffer.baseAddress!
                    )
            
                    // Convert to complex format
                    vDSP_ctoz(frame.withUnsafeBufferPointer { bufferPointer in
                        bufferPointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { $0 }
                    }, 2, &complexBuffer, 1, vDSP_Length(halfFftSize))
                    
                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &complexBuffer, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
                    
                    // Compute magnitude spectrum
                    var magnitudes = Array<Float>(repeating: 0, count: halfFftSize)
                    vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(halfFftSize))
                    
                    return magnitudes
                }
            }
            
            // Convert to log scale
            var logMagnitudes = Array<Float>(repeating: 0, count: halfFftSize)
            var one: Float = 1.0
            vDSP_vdbcon(fftResult, 1, &one, &logMagnitudes, 1, vDSP_Length(halfFftSize), 0)
            
            spectrogram.append(logMagnitudes)
        }
        
        return spectrogram
    }
    
    private func createMelFilterBank() -> [[Float]] {
        let fftBins = config.frameSize / 2 + 1
        let melFilters = config.melFilters
        let sampleRate = Float(config.sampleRate)
        
        // Convert frequency to mel scale
        func hzToMel(_ hz: Float) -> Float {
            return 2595.0 * log10(1.0 + hz / 700.0)
        }
        
        // Convert mel to frequency
        func melToHz(_ mel: Float) -> Float {
            return 700.0 * (pow(10, mel / 2595.0) - 1.0)
        }
        
        // Create mel scale points
        let minMel = hzToMel(0)
        let maxMel = hzToMel(sampleRate / 2)
        let melPoints = (0...melFilters + 1).map { i in
            melToHz(minMel + Float(i) * (maxMel - minMel) / Float(melFilters + 1))
        }
        
        // Convert to FFT bin indices
        let binPoints = melPoints.map { freq in
            Int(floor(Float(fftBins) * freq / (sampleRate / 2)))
        }
        
        // Create filter bank
        var filterBank: [[Float]] = []
        
        for m in 1...melFilters {
            var filter = Array<Float>(repeating: 0, count: fftBins)
            
            let leftBin = binPoints[m - 1]
            let centerBin = binPoints[m]
            let rightBin = binPoints[m + 1]
            
            // Rising slope
            for k in leftBin..<centerBin {
                if centerBin > leftBin {
                    filter[k] = Float(k - leftBin) / Float(centerBin - leftBin)
                }
            }
            
            // Falling slope
            for k in centerBin..<rightBin {
                if rightBin > centerBin {
                    filter[k] = Float(rightBin - k) / Float(rightBin - centerBin)
                }
            }
            
            filterBank.append(filter)
        }
        
        return filterBank
    }
    
    private func applyMelFilters(_ spectrogram: [[Float]], melFilters: [[Float]]) throws -> [[Float]] {
        guard !spectrogram.isEmpty && !melFilters.isEmpty else {
            throw MLXAudioProcessorError.melSpectrogramComputationFailed("Empty spectrogram or mel filters")
        }
        
        let frameCount = spectrogram.count
        let melBins = melFilters.count
        
        var melSpectrogram: [[Float]] = []
        
        for frameIndex in 0..<frameCount {
            let frame = spectrogram[frameIndex]
            var melFrame = Array<Float>(repeating: 0, count: melBins)
            
            for (melIndex, filter) in melFilters.enumerated() {
                let filterLength = min(filter.count, frame.count)
                var result: Float = 0
                
                vDSP_dotpr(
                    Array(frame.prefix(filterLength)), 1,
                    Array(filter.prefix(filterLength)), 1,
                    &result,
                    vDSP_Length(filterLength)
                )
                
                melFrame[melIndex] = max(result, Float.ulpOfOne) // Avoid log(0)
            }
            
            // Apply log to mel spectrogram
            var logMelFrame = Array<Float>(repeating: 0, count: melBins)
            vvlogf(&logMelFrame, melFrame, [Int32(melBins)])
            
            melSpectrogram.append(logMelFrame)
        }
        
        return melSpectrogram
    }
    
    #if canImport(MLX) && canImport(MLXNN)
    private func convertToMLXArray(_ melSpectrogram: [[Float]]) throws -> MLXArray {
        guard !melSpectrogram.isEmpty else {
            throw MLXAudioProcessorError.melSpectrogramComputationFailed("Empty mel spectrogram")
        }
        
        let timeSteps = melSpectrogram.count
        let melBins = melSpectrogram[0].count
        
        // Flatten spectrogram data
        var flatData: [Float] = []
        for frame in melSpectrogram {
            flatData.append(contentsOf: frame)
        }
        
        // Create MLX array with shape [time_steps, mel_bins]
        let shape = [timeSteps, melBins]
        let mlxArray = MLXArray(flatData, shape)
        
        return mlxArray
    }
    #endif
}

// MARK: - Extensions for Convenience

@available(macOS 13.0, *)
extension MLXAudioProcessor {
    
    /// Convenience method to process audio with default configuration
    public static func processAudio(
        _ fileURL: URL,
        progressCallback: AudioProcessingProgressCallback? = nil
    ) async throws -> MLXArray {
        let processor = MLXAudioProcessor()
        return try await processor.processAudioFile(fileURL, progressCallback: progressCallback)
    }
    
    /// Check if MLX is available for audio processing
    public static var isMLXAvailable: Bool {
        #if canImport(MLX) && canImport(MLXNN)
        return MLXAvailability.areProductsAvailable
        #else
        return false
        #endif
    }
}

// MARK: - Audio Utilities

@available(macOS 13.0, *)
extension MLXAudioProcessor {
    
    /// Get audio file metadata without processing
    public static func getAudioMetadata(_ fileURL: URL) throws -> (duration: Double, sampleRate: Double, channels: Int) {
        let audioFile = try AVAudioFile(forReading: fileURL)
        let format = audioFile.processingFormat
        
        let frameCount = audioFile.length
        let duration = Double(frameCount) / format.sampleRate
        
        return (
            duration: duration,
            sampleRate: format.sampleRate,
            channels: Int(format.channelCount)
        )
    }
    
    /// Estimate processing memory requirements
    public static func estimateMemoryRequirements(
        audioDurationSeconds: Double,
        config: MLXAudioConfig = .whisperDefault
    ) -> Int {
        let sampleCount = Int(audioDurationSeconds * Double(config.sampleRate))
        let frameCount = (sampleCount - config.frameSize) / config.hopLength + 1
        let spectrogramSize = frameCount * config.melFilters * MemoryLayout<Float>.size
        
        // Estimate total memory including intermediate buffers (roughly 3x spectrogram size)
        return spectrogramSize * 3
    }
}