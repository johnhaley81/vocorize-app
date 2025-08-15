import Foundation
import Dependencies

// MARK: - Transcription Models

struct Transcript: Codable, Equatable, Identifiable {
    var id: UUID
    var timestamp: Date
    var text: String
    var audioPath: URL
    var duration: TimeInterval
    
    init(id: UUID = UUID(), timestamp: Date, text: String, audioPath: URL, duration: TimeInterval) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.audioPath = audioPath
        self.duration = duration
    }
}

struct TranscriptionHistory: Codable, Equatable {
    var history: [Transcript] = []
}


