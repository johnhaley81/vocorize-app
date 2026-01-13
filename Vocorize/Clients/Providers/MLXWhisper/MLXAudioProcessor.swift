//
//  MLXAudioProcessor.swift
//  Vocorize
//
//  Audio preprocessing for MLX Whisper - converts audio to mel spectrograms
//

import Foundation
import AVFoundation
import Accelerate

#if canImport(MLX)
import MLX
#endif

/// Audio processor for converting audio files to mel spectrograms
public class MLXAudioProcessor {

    // MARK: - Constants

    /// Sample rate expected by Whisper (16kHz)
    public static let sampleRate: Double = 16000.0

    /// Number of FFT points
    public static let nFFT: Int = 400

    /// Hop length between frames
    public static let hopLength: Int = 160

    /// Number of mel filterbank bins
    public static let nMels: Int = 128

    /// Maximum audio length in samples (30 seconds)
    public static let maxSamples: Int = 480000  // 30 * 16000

    /// Chunk length in seconds
    public static let chunkLength: Int = 30

    // MARK: - Mel Filterbank

    private var melFilterbank: [[Float]]?

    public init() {
        self.melFilterbank = createMelFilterbank()
    }

    // MARK: - Public Methods

    /// Load and process audio file to mel spectrogram
    /// - Parameter url: URL to audio file
    /// - Returns: Mel spectrogram as 2D array [numMels, frames]
    public func processAudioFile(at url: URL) throws -> [[Float]] {
        // Load audio samples
        let samples = try loadAudio(from: url)

        // Pad or truncate to max length
        let paddedSamples = padOrTruncate(samples)

        // Compute mel spectrogram
        return computeMelSpectrogram(from: paddedSamples)
    }

    #if canImport(MLX)
    /// Load and process audio file to MLXArray mel spectrogram
    /// - Parameter url: URL to audio file
    /// - Returns: Mel spectrogram as MLXArray [1, numMels, frames]
    public func processAudioFileToMLX(at url: URL) throws -> MLXArray {
        let melSpec = try processAudioFile(at: url)

        // Convert to MLXArray with batch dimension [1, numMels, frames]
        let flatData = melSpec.flatMap { $0 }
        let numMels = melSpec.count
        let numFrames = melSpec.first?.count ?? 0

        return MLXArray(flatData).reshaped([1, numMels, numFrames])
    }
    #endif

    // MARK: - Audio Loading

    /// Load audio from file and convert to mono float samples at target sample rate
    private func loadAudio(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)

        // Create format for 16kHz mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw MLXAudioProcessorError.formatCreationFailed
        }

        // Create converter
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
            throw MLXAudioProcessorError.converterCreationFailed
        }

        // Calculate output buffer size
        let ratio = Self.sampleRate / audioFile.processingFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(audioFile.length) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            throw MLXAudioProcessorError.bufferCreationFailed
        }

        // Read source audio
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw MLXAudioProcessorError.bufferCreationFailed
        }

        try audioFile.read(into: sourceBuffer)

        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            throw MLXAudioProcessorError.conversionFailed(error)
        }

        // Extract float samples
        guard let channelData = outputBuffer.floatChannelData else {
            throw MLXAudioProcessorError.noChannelData
        }

        let frameCount = Int(outputBuffer.frameLength)
        var samples = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            samples[i] = channelData[0][i]
        }

        return samples
    }

    /// Pad audio to max length or truncate
    private func padOrTruncate(_ samples: [Float]) -> [Float] {
        if samples.count >= Self.maxSamples {
            return Array(samples.prefix(Self.maxSamples))
        } else {
            // Pad with zeros
            var padded = samples
            padded.append(contentsOf: [Float](repeating: 0, count: Self.maxSamples - samples.count))
            return padded
        }
    }

    // MARK: - Mel Spectrogram Computation

    /// Compute mel spectrogram from audio samples
    private func computeMelSpectrogram(from samples: [Float]) -> [[Float]] {
        // Compute STFT magnitudes
        let stftMagnitudes = computeSTFT(from: samples)

        // Apply mel filterbank
        guard let filterbank = melFilterbank else {
            return []
        }

        var melSpec = [[Float]](repeating: [Float](repeating: 0, count: stftMagnitudes.count), count: Self.nMels)

        for (frameIdx, frame) in stftMagnitudes.enumerated() {
            for melIdx in 0..<Self.nMels {
                var sum: Float = 0
                for freqIdx in 0..<min(frame.count, filterbank[melIdx].count) {
                    sum += frame[freqIdx] * filterbank[melIdx][freqIdx]
                }
                melSpec[melIdx][frameIdx] = sum
            }
        }

        // Convert to log scale
        let maxVal: Float = 1e-10
        for melIdx in 0..<Self.nMels {
            for frameIdx in 0..<melSpec[melIdx].count {
                melSpec[melIdx][frameIdx] = log10(max(melSpec[melIdx][frameIdx], maxVal))
            }
        }

        // Normalize
        let globalMax = melSpec.flatMap { $0 }.max() ?? 1.0
        let globalMin = melSpec.flatMap { $0 }.min() ?? 0.0
        let range = globalMax - globalMin

        if range > 0 {
            for melIdx in 0..<Self.nMels {
                for frameIdx in 0..<melSpec[melIdx].count {
                    melSpec[melIdx][frameIdx] = (melSpec[melIdx][frameIdx] - globalMin) / range * 2.0 - 1.0
                }
            }
        }

        return melSpec
    }

    /// Compute Short-Time Fourier Transform magnitudes
    private func computeSTFT(from samples: [Float]) -> [[Float]] {
        let fftSize = Self.nFFT
        let hopSize = Self.hopLength
        let numFrames = (samples.count - fftSize) / hopSize + 1

        // Setup FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var stftMagnitudes = [[Float]]()
        stftMagnitudes.reserveCapacity(numFrames)

        // Process each frame
        for frameIdx in 0..<numFrames {
            let start = frameIdx * hopSize

            // Extract frame and apply window
            var frame = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                if start + i < samples.count {
                    frame[i] = samples[start + i] * window[i]
                }
            }

            // Perform FFT
            var realPart = [Float](repeating: 0, count: fftSize / 2)
            var imagPart = [Float](repeating: 0, count: fftSize / 2)

            frame.withUnsafeBufferPointer { framePtr in
                var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
                framePtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            }

            // Compute magnitudes
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvabs(&DSPSplitComplex(realp: &realPart, imagp: &imagPart), 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // Square for power spectrum
            vDSP_vsq(magnitudes, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            stftMagnitudes.append(magnitudes)
        }

        return stftMagnitudes
    }

    // MARK: - Mel Filterbank Creation

    /// Create mel filterbank matrix
    private func createMelFilterbank() -> [[Float]] {
        let fftBins = Self.nFFT / 2 + 1
        let fMin: Float = 0.0
        let fMax: Float = Float(Self.sampleRate) / 2.0

        // Convert frequencies to mel scale
        func hzToMel(_ hz: Float) -> Float {
            return 2595.0 * log10(1.0 + hz / 700.0)
        }

        func melToHz(_ mel: Float) -> Float {
            return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
        }

        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        // Create mel points evenly spaced in mel scale
        var melPoints = [Float](repeating: 0, count: Self.nMels + 2)
        for i in 0...(Self.nMels + 1) {
            melPoints[i] = melMin + Float(i) * (melMax - melMin) / Float(Self.nMels + 1)
        }

        // Convert mel points back to Hz
        let hzPoints = melPoints.map { melToHz($0) }

        // Convert Hz points to FFT bin indices
        let binPoints = hzPoints.map { Int(($0 * Float(Self.nFFT)) / Float(Self.sampleRate)) }

        // Create filterbank
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: fftBins), count: Self.nMels)

        for i in 0..<Self.nMels {
            let startBin = binPoints[i]
            let centerBin = binPoints[i + 1]
            let endBin = binPoints[i + 2]

            // Rising slope
            for j in startBin..<centerBin {
                if j >= 0 && j < fftBins && centerBin != startBin {
                    filterbank[i][j] = Float(j - startBin) / Float(centerBin - startBin)
                }
            }

            // Falling slope
            for j in centerBin..<endBin {
                if j >= 0 && j < fftBins && endBin != centerBin {
                    filterbank[i][j] = Float(endBin - j) / Float(endBin - centerBin)
                }
            }
        }

        return filterbank
    }
}

// MARK: - Errors

public enum MLXAudioProcessorError: LocalizedError {
    case formatCreationFailed
    case converterCreationFailed
    case bufferCreationFailed
    case conversionFailed(Error)
    case noChannelData
    case fileReadFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .conversionFailed(let error):
            return "Audio conversion failed: \(error.localizedDescription)"
        case .noChannelData:
            return "No channel data available in audio buffer"
        case .fileReadFailed(let error):
            return "Failed to read audio file: \(error.localizedDescription)"
        }
    }
}
