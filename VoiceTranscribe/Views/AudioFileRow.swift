//
//  AudioFileRow.swift
//  VoiceTranscribe
//

import SwiftUI

struct AudioFileRow: View {
    let audioFile: AudioFile
    let onTranscribe: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioFile.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(audioFile.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if audioFile.isTranscribing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if audioFile.transcription != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if audioFile.error != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            if let transcription = audioFile.transcription {
                Text(transcription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }

            if let error = audioFile.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if audioFile.transcription == nil && !audioFile.isTranscribing {
                Button {
                    onTranscribe()
                } label: {
                    Label("Transcribe", systemImage: "waveform")
                }
                .tint(.blue)
            }
        }
    }
}
