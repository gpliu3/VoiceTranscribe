//
//  TranscriptionService.swift
//  VoiceTranscribe
//

import Foundation
import Combine
import WhisperKit

@MainActor
class TranscriptionService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isLoadingModel = false
    @Published var loadingProgress: String = ""
    @Published var errorMessage: String?

    private var whisperKit: WhisperKit?

    func loadModel() async {
        guard !isModelLoaded && !isLoadingModel else { return }

        isLoadingModel = true
        errorMessage = nil

        do {
            // Check if model is already cached in Documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cachedModelPath = documentsURL
                .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base")

            let isCached = FileManager.default.fileExists(atPath: cachedModelPath.path)

            if isCached {
                loadingProgress = "Loading model..."
                print("Model cached at: \(cachedModelPath.path)")
            } else {
                loadingProgress = "Downloading model (first time)..."
                print("Model not cached, will download to: \(cachedModelPath.path)")
            }

            let config = WhisperKitConfig(
                model: "base",
                verbose: true,
                logLevel: .debug,
                prewarm: true,
                load: true,
                download: true  // Will use cache if exists
            )
            whisperKit = try await WhisperKit(config)

            isModelLoaded = true
            loadingProgress = "Model ready"
            print("WhisperKit model loaded successfully")
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            loadingProgress = ""
            print("WhisperKit error: \(error)")
        }

        isLoadingModel = false
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        print("Starting transcription for: \(audioURL.path)")

        // Configure for multilingual transcription (Simplified Chinese + English)
        // Whisper base model outputs Simplified Chinese by default
        // Using auto-detect for mixed Chinese/English content
        let options = DecodingOptions(
            task: .transcribe,
            language: "chinese",  // Forces Simplified Chinese output
            usePrefillPrompt: false,
            detectLanguage: false
        )

        let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)

        print("Transcription results count: \(results.count)")

        // Combine all segments
        let fullText = results
            .map { segment in
                segment.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            .joined(separator: " ")

        print("Transcription result: \(fullText)")
        return fullText
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelNotFound
    case noResults
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded"
        case .modelNotFound:
            return "Whisper model not found in app bundle"
        case .noResults:
            return "No transcription results"
        case .audioConversionFailed:
            return "Failed to convert audio format"
        }
    }
}
