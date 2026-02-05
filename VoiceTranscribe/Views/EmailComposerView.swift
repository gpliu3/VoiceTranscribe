//
//  EmailComposerView.swift
//  VoiceTranscribe
//

import SwiftUI
import MessageUI

struct EmailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let isPresented: Binding<Bool>

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: isPresented)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let isPresented: Binding<Bool>

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented.wrappedValue = false
        }
    }
}

struct MailUnavailableView: View {
    let emailBody: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("Mail Not Available")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Mail is not configured on this device. You can copy the transcription to paste into your preferred email app.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button {
                    UIPasteboard.general.string = emailBody
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
