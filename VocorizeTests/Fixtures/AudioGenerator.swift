//
//  AudioGenerator.swift
//  VocorizeTests
//
//  Test audio file generator for creating minimal WAV files for testing
//  Generates predictable, small audio files for fixture data
//

import Foundation
import AVFoundation

struct AudioGenerator {
    static let sampleRate: Double = 16000
    static let channelCount: UInt32 = 1
    static let bitDepth: UInt32 = 16
    
    /// Generate a silent audio file for testing
    static func generateSilence(duration: TimeInterval, filename: String) throws -> URL {
        let url = getTestAudioURL(filename: filename)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        
        // Fill with silence (zeros)
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(frameCount) {
                channelData[0][frame] = 0.0
            }
        }
        
        try audioFile.write(from: buffer)
        return url
    }
    
    /// Generate a simple tone for testing speech-like patterns
    static func generateTone(frequency: Float, duration: TimeInterval, amplitude: Float = 0.1, filename: String) throws -> URL {
        let url = getTestAudioURL(filename: filename)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        
        // Generate a simple sine wave
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(frameCount) {
                let time = Float(frame) / Float(sampleRate)
                let sample = amplitude * sin(2.0 * Float.pi * frequency * time)
                channelData[0][frame] = sample
            }
        }
        
        try audioFile.write(from: buffer)
        return url
    }
    
    /// Generate a multi-tone sequence to simulate speech patterns
    static func generateSpeechLikeTones(durations: [TimeInterval], frequencies: [Float], filename: String) throws -> URL {
        let url = getTestAudioURL(filename: filename)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        let totalDuration = durations.reduce(0, +)
        let totalFrameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrameCount)!
        
        buffer.frameLength = totalFrameCount
        
        if let channelData = buffer.floatChannelData {
            var currentFrame = 0
            
            for (duration, frequency) in zip(durations, frequencies) {
                let segmentFrameCount = Int(duration * sampleRate)
                
                for frame in 0..<segmentFrameCount {
                    let time = Float(frame) / Float(sampleRate)
                    let amplitude: Float = 0.08 // Quieter than single tone
                    let sample = amplitude * sin(2.0 * Float.pi * frequency * time)
                    
                    if currentFrame < Int(totalFrameCount) {
                        channelData[0][currentFrame] = sample
                        currentFrame += 1
                    }
                }
            }
        }
        
        try audioFile.write(from: buffer)
        return url
    }
    
    /// Generate audio with background noise to simulate challenging conditions
    static func generateNoisyAudio(signalFrequency: Float, noiseLevels: Float = 0.02, duration: TimeInterval, filename: String) throws -> URL {
        let url = getTestAudioURL(filename: filename)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(frameCount) {
                let time = Float(frame) / Float(sampleRate)
                
                // Main signal
                let signal = 0.06 * sin(2.0 * Float.pi * signalFrequency * time)
                
                // Add some noise
                let noise = noiseLevels * (Float.random(in: -1...1))
                
                channelData[0][frame] = signal + noise
            }
        }
        
        try audioFile.write(from: buffer)
        return url
    }
    
    /// Generate all test audio files
    static func generateAllTestAudio() throws {
        // Create the audio directory if needed
        let audioDir = getAudioFixturesDirectory()
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        // Generate silence
        _ = try generateSilence(duration: 1.0, filename: "silence.wav")
        
        // Generate speech-like patterns for different test phrases
        _ = try generateSpeechLikeTones(
            durations: [0.4, 0.3, 0.5, 0.6, 0.7],
            frequencies: [220, 330, 440, 550, 330],
            filename: "hello_world.wav"
        )
        
        _ = try generateSpeechLikeTones(
            durations: [0.3, 0.4, 0.3, 0.4, 0.5, 0.4, 0.3, 0.5, 0.5],
            frequencies: [200, 350, 280, 420, 380, 300, 250, 320, 280],
            filename: "quick_brown_fox.wav"
        )
        
        _ = try generateSpeechLikeTones(
            durations: [0.4, 0.4, 0.5, 0.6, 0.5],
            frequencies: [300, 400, 350, 450, 380],
            filename: "numbers_123.wav"
        )
        
        _ = try generateSpeechLikeTones(
            durations: [0.5, 0.4, 0.6],
            frequencies: [250, 380, 320],
            filename: "multilingual_sample.wav"
        )
        
        // Generate noisy audio
        _ = try generateNoisyAudio(
            signalFrequency: 300,
            noiseLevels: 0.04,
            duration: 3.5,
            filename: "noisy_audio.wav"
        )
        
        // Generate longer sequence for complex testing
        _ = try generateSpeechLikeTones(
            durations: [0.4, 0.3, 0.2, 0.5, 0.4, 0.3, 0.4, 0.6, 0.5, 0.4, 0.3, 0.6, 0.7, 0.4, 0.5, 0.3, 0.8, 0.4],
            frequencies: [220, 330, 280, 440, 380, 320, 360, 420, 300, 350, 280, 460, 340, 310, 390, 270, 450, 290],
            filename: "long_sentence.wav"
        )
        
        // Generate error scenario files
        
        // Empty audio (zero duration)
        _ = try generateSilence(duration: 0.0, filename: "empty_audio.wav")
        
        // Corrupted audio (we'll create an invalid WAV file)
        try createCorruptedAudio(filename: "corrupted_audio.wav")
        
        // Unsupported format (create a fake MP3 file)
        try createFakeMP3(filename: "unsupported_format.mp3")
        
        // Too long audio (simulate very long file)
        _ = try generateSilence(duration: 301.0, filename: "too_long_audio.wav") // Over 5 minutes
    }
    
    private static func createCorruptedAudio(filename: String) throws {
        let url = getTestAudioURL(filename: filename)
        let corruptedData = Data([0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00]) // Invalid WAV header
        try corruptedData.write(to: url)
    }
    
    private static func createFakeMP3(filename: String) throws {
        let url = getTestAudioURL(filename: filename)
        let fakeMP3Data = Data("Not a real MP3 file".utf8) // Invalid MP3 content
        try fakeMP3Data.write(to: url)
    }
    
    private static func getTestAudioURL(filename: String) -> URL {
        return getAudioFixturesDirectory().appendingPathComponent(filename)
    }
    
    private static func getAudioFixturesDirectory() -> URL {
        // This would be called from test code, so we can get the bundle path
        let bundle = Bundle.main
        if let bundlePath = bundle.resourcePath {
            return URL(fileURLWithPath: bundlePath).appendingPathComponent("VocorizeTests/Fixtures/Audio")
        } else {
            // Fallback to a temp directory for tests
            return FileManager.default.temporaryDirectory.appendingPathComponent("VocorizeTests/Fixtures/Audio")
        }
    }
    
    /// Cleanup all generated test audio files
    static func cleanupTestAudio() throws {
        let audioDir = getAudioFixturesDirectory()
        if FileManager.default.fileExists(atPath: audioDir.path) {
            try FileManager.default.removeItem(at: audioDir)
        }
    }
}