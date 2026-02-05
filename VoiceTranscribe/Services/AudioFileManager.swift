//
//  AudioFileManager.swift
//  VoiceTranscribe
//

import Foundation
import Combine
import AVFoundation

@MainActor
class AudioFileManager: ObservableObject {
    @Published var audioFiles: [AudioFile] = []

    private let fileManager = FileManager.default

    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceMemos", isDirectory: true)
    }

    init() {
        createDirectoryIfNeeded()
        loadSavedFiles()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }
    }

    private func loadSavedFiles() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let audioExtensions = ["m4a", "mp3", "wav", "caf", "aac", "mp4"]
        audioFiles = urls
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap { url in
                let duration = getAudioDuration(url: url)
                return AudioFile(url: url, duration: duration)
            }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    func importAudio(from sourceURL: URL) async throws -> AudioFile {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)

        // Handle duplicate names
        var finalURL = destinationURL
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let name = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            finalURL = documentsDirectory.appendingPathComponent("\(name)_\(counter).\(ext)")
            counter += 1
        }

        // Start accessing security-scoped resource if needed
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.copyItem(at: sourceURL, to: finalURL)

        let duration = getAudioDuration(url: finalURL)
        let audioFile = AudioFile(url: finalURL, duration: duration)

        audioFiles.insert(audioFile, at: 0)

        return audioFile
    }

    func deleteFile(_ audioFile: AudioFile) {
        try? fileManager.removeItem(at: audioFile.url)
        audioFiles.removeAll { $0.id == audioFile.id }
    }

    func updateTranscription(for audioFile: AudioFile, transcription: String) {
        if let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) {
            audioFiles[index].transcription = transcription
            audioFiles[index].isTranscribing = false
        }
    }

    func setTranscribing(_ audioFile: AudioFile, isTranscribing: Bool) {
        if let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) {
            audioFiles[index].isTranscribing = isTranscribing
        }
    }

    func setError(for audioFile: AudioFile, error: String) {
        if let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) {
            audioFiles[index].error = error
            audioFiles[index].isTranscribing = false
        }
    }

    private func getAudioDuration(url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        guard duration.timescale > 0 else { return nil }
        return CMTimeGetSeconds(duration)
    }
}
