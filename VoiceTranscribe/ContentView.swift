//
//  ContentView.swift
//  VoiceTranscribe
//

import SwiftUI
import MessageUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var audioManager = AudioFileManager()
    @StateObject private var transcriptionService = TranscriptionService()

    @State private var isImporting = false
    @State private var showingEmail = false
    @State private var showingMailUnavailable = false
    @State private var emailBody = ""
    @State private var isTranscribingAll = false

    var transcribedFiles: [AudioFile] {
        audioManager.audioFiles.filter { $0.transcription != nil }
    }

    var untranscribedFiles: [AudioFile] {
        audioManager.audioFiles.filter { $0.transcription == nil && !$0.isTranscribing }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content
                Group {
                    if audioManager.audioFiles.isEmpty {
                        emptyStateView
                    } else {
                        fileListView
                    }
                }

                // Bottom action bar
                bottomActionBar
            }
            .navigationTitle("Voice Transcribe")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav, .aiff],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    await handleFileImport(result)
                }
            }
            .sheet(isPresented: $showingEmail) {
                let body = generateEmailBody()
                if MFMailComposeViewController.canSendMail() {
                    EmailComposerView(
                        subject: "Voice Memo Transcriptions",
                        body: body,
                        isPresented: $showingEmail
                    )
                } else {
                    MailUnavailableView(emailBody: body, isPresented: $showingEmail)
                }
            }
        }
        .task {
            // Auto-load model on launch
            if !transcriptionService.isModelLoaded {
                await transcriptionService.loadModel()
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                // Left side: Model/Transcribe button
                if transcriptionService.isLoadingModel {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(transcriptionService.loadingProgress)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                } else if !transcriptionService.isModelLoaded {
                    Button {
                        Task {
                            await transcriptionService.loadModel()
                        }
                    } label: {
                        Label("Load Model", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else if isTranscribingAll {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Transcribing...")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                } else if !untranscribedFiles.isEmpty {
                    Button {
                        Task {
                            await transcribeAllFiles()
                        }
                    } label: {
                        Label("Transcribe All (\(untranscribedFiles.count))", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else if !audioManager.audioFiles.isEmpty {
                    Label("All Transcribed", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Import audio files to start")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                // Right side: Send Email button
                if !transcribedFiles.isEmpty {
                    Button {
                        composeEmail()
                    } label: {
                        Label("Email", systemImage: "envelope")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.bar)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No Voice Memos")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import voice memos from the Voice Memos app or Files to transcribe them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: 1, text: "Open Voice Memos app")
                instructionRow(number: 2, text: "Tap a recording, then tap ...")
                instructionRow(number: 3, text: "Choose \"Share\" then select this app")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                isImporting = true
            } label: {
                Label("Import from Files", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }

    private var fileListView: some View {
        List {
            if let error = transcriptionService.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                    }
                }
            }

            Section {
                ForEach(audioManager.audioFiles) { audioFile in
                    AudioFileRow(
                        audioFile: audioFile,
                        onTranscribe: {
                            Task {
                                await transcribeFile(audioFile)
                            }
                        },
                        onDelete: {
                            audioManager.deleteFile(audioFile)
                        }
                    )
                }
            } header: {
                HStack {
                    Text("\(audioManager.audioFiles.count) files")
                    Spacer()
                    Text("\(transcribedFiles.count) transcribed")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    _ = try await audioManager.importAudio(from: url)
                } catch {
                    print("Failed to import \(url.lastPathComponent): \(error)")
                }
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }

    private func transcribeFile(_ audioFile: AudioFile) async {
        if !transcriptionService.isModelLoaded {
            await transcriptionService.loadModel()
            guard transcriptionService.isModelLoaded else { return }
        }

        audioManager.setTranscribing(audioFile, isTranscribing: true)

        do {
            let transcription = try await transcriptionService.transcribe(audioURL: audioFile.url)
            audioManager.updateTranscription(for: audioFile, transcription: transcription)
        } catch {
            audioManager.setError(for: audioFile, error: error.localizedDescription)
        }
    }

    private func transcribeAllFiles() async {
        isTranscribingAll = true
        defer { isTranscribingAll = false }

        for audioFile in untranscribedFiles {
            await transcribeFile(audioFile)
        }
    }

    private func composeEmail() {
        showingEmail = true
    }

    private func generateEmailBody() -> String {
        var body = "Voice Memo Transcriptions\n"
        body += "Generated on \(Date().formatted(date: .long, time: .shortened))\n"
        body += String(repeating: "=", count: 40) + "\n\n"

        for (index, file) in transcribedFiles.enumerated() {
            body += "[\(index + 1)] \(file.name)\n"
            if let duration = file.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                body += "Duration: \(minutes):\(String(format: "%02d", seconds))\n"
            }
            body += "\n"
            body += file.transcription ?? ""
            body += "\n\n"
            body += String(repeating: "-", count: 40) + "\n\n"
        }

        print("Email body generated: \(body.prefix(200))...")
        return body
    }
}

#Preview {
    ContentView()
}
