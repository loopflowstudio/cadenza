import AVFoundation
import AVKit
import SwiftData
import SwiftUI
import UIKit

struct MessageRecordingSheet: View {
    let submissionId: UUID
    let initialText: String?
    let onSubmit: (MessageDTO) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var cameraManager = CameraManager()
    @State private var text: String
    @State private var submissionError: String?
    @State private var isSubmitting = false

    private let maxDurationSeconds = 180

    init(submissionId: UUID, initialText: String? = nil, onSubmit: @escaping (MessageDTO) -> Void) {
        self.submissionId = submissionId
        self.initialText = initialText
        self.onSubmit = onSubmit
        _text = State(initialValue: initialText ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let recordedURL = cameraManager.recordedURL {
                    VideoPlayer(player: AVPlayer(url: recordedURL))
                        .ignoresSafeArea()
                } else {
                    CameraPreview(session: cameraManager.session)
                        .ignoresSafeArea()
                }

                VStack {
                    HStack {
                        Spacer()
                        if cameraManager.isRecording {
                            Text(timeRemaining)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                    }
                    .padding()

                    Spacer()

                    VStack(spacing: 12) {
                        if let error = cameraManager.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }

                        if let error = submissionError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }

                        if cameraManager.recordedURL != nil {
                            TextField("Add a note with your video", text: $text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                        }

                        HStack(spacing: 24) {
                            if cameraManager.recordedURL == nil {
                                Button {
                                    cameraManager.isRecording ? cameraManager.stopRecording() : cameraManager.startRecording()
                                } label: {
                                    Circle()
                                        .fill(cameraManager.isRecording ? Color.red : Color.white)
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.7), lineWidth: 4)
                                        )
                                }
                                .accessibilityLabel(cameraManager.isRecording ? "Stop Recording" : "Start Recording")
                            } else {
                                Button("Retake") {
                                    clearRecording()
                                }
                                .buttonStyle(.bordered)

                                Button(isSubmitting ? "Submitting..." : "Submit") {
                                    Task {
                                        await submitRecording()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isSubmitting)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Record Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .task {
                await cameraManager.startSession()
            }
            .onDisappear {
                cameraManager.stopSession()
                clearRecording()
            }
        }
    }

    private var timeRemaining: String {
        let remaining = maxDurationSeconds - cameraManager.elapsedSeconds
        let minutes = max(0, remaining) / 60
        let seconds = max(0, remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func submitRecording() async {
        guard let recordedURL = cameraManager.recordedURL else { return }
        isSubmitting = true
        submissionError = nil
        defer { isSubmitting = false }

        do {
            let persistedURL = try persistVideo(at: recordedURL)
            let thumbnailURL = try generateThumbnail(for: persistedURL)
            let durationSeconds = try fetchDurationSeconds(for: persistedURL)

            let service = MessageService(modelContext: modelContext)
            let response = try await service.createMessage(
                submissionId: submissionId,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text,
                includeVideo: true,
                videoDurationSeconds: durationSeconds
            )

            if let uploadUrl = response.uploadUrl {
                try await service.uploadVideo(
                    localURL: persistedURL,
                    thumbnailURL: thumbnailURL,
                    uploadUrl: uploadUrl,
                    thumbnailUploadUrl: response.thumbnailUploadUrl
                )
            }

            onSubmit(response.message)
            dismiss()
        } catch {
            submissionError = error.localizedDescription
        }
    }

    private func persistVideo(at url: URL) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent("\(UUID().uuidString).mp4")
        try FileManager.default.copyItem(at: url, to: destinationURL)
        try? FileManager.default.removeItem(at: url)
        return destinationURL
    }

    private func generateThumbnail(for videoURL: URL) throws -> URL {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let image = UIImage(cgImage: cgImage)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.requestFailed
        }

        let thumbnailURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: thumbnailURL)
        return thumbnailURL
    }

    private func fetchDurationSeconds(for url: URL) throws -> Int {
        let asset = AVAsset(url: url)
        let seconds = asset.duration.seconds
        if seconds.isNaN || seconds.isInfinite {
            throw APIError.requestFailed
        }
        return Int(seconds.rounded())
    }

    private func clearRecording() {
        if let recordedURL = cameraManager.recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        cameraManager.recordedURL = nil
    }
}

#Preview("Message Recording") {
    MessageRecordingSheet(submissionId: UUID(), initialText: "Great work!") { _ in }
        .modelContainer(for: [Message.self])
}
