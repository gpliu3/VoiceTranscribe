//
//  AudioFile.swift
//  VoiceTranscribe
//

import Foundation

struct AudioFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let duration: TimeInterval?
    let dateAdded: Date
    var transcription: String?
    var isTranscribing: Bool = false
    var error: String?

    init(url: URL, name: String? = nil, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name ?? url.deletingPathExtension().lastPathComponent
        self.duration = duration
        self.dateAdded = Date()
    }

    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        lhs.id == rhs.id
    }
}
