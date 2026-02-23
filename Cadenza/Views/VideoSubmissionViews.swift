import AVKit
import SwiftData
import SwiftUI

struct PendingVideosSection: View {
    let studentId: Int

    @Environment(\.modelContext) private var modelContext
    @State private var submissions: [VideoSubmissionDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if isLoading {
                ProgressView()
            } else if submissions.isEmpty {
                ContentUnavailableView {
                    Label("No Pending Videos", systemImage: "video")
                } description: {
                    Text("This student has no videos awaiting review")
                }
            } else {
                ForEach(submissions, id: \.id) { submission in
                    VideoSubmissionRow(submission: submission) {
                        Task {
                            await loadSubmissions()
                        }
                    }
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } header: {
            Text("Pending Videos")
        }
        .task {
            await loadSubmissions()
        }
    }

    private func loadSubmissions() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = VideoSubmissionService(modelContext: modelContext)
            submissions = try await service.getStudentSubmissions(
                studentId: studentId,
                pendingReviewOnly: true,
                pieceId: nil,
                exerciseId: nil
            )
        } catch {
            errorMessage = "Failed to load videos: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

struct VideoSubmissionRow: View {
    let submission: VideoSubmissionDTO
    let onReviewed: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var thumbnailURL: URL?

    var body: some View {
        NavigationLink {
            VideoSubmissionDetailView(submission: submission, onReviewed: onReviewed)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if let thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 72, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 72, height: 48)
                            .overlay(
                                Image(systemName: "video")
                                    .foregroundStyle(.secondary)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(submission.notes ?? "Practice Video")
                        .font(.headline)
                        .lineLimit(1)
                    Text(submission.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        do {
            let service = VideoSubmissionService(modelContext: modelContext)
            let response = try await service.getPlaybackUrls(submissionId: submission.id)
            if let thumbnailUrl = response.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                thumbnailURL = url
            }
        } catch {
            // Non-blocking
        }
    }
}

struct VideoSubmissionDetailView: View {
    let submission: VideoSubmissionDTO
    let onReviewed: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reviewedAt: Date?
    @State private var isMarkingReviewed = false
    @State private var messages: [MessageDTO] = []
    @State private var isLoadingMessages = false
    @State private var messageError: String?
    @State private var composeText = ""
    @State private var isRecordingMessage = false
    @State private var isSendingMessage = false

    var body: some View {
        VStack(spacing: 16) {
            videoSection
            submissionInfoSection
            messagesSection
            ComposeBar(
                text: $composeText,
                isSending: isSendingMessage,
                onSend: { Task { await sendTextMessage() } },
                onRecordVideo: { isRecordingMessage = true }
            )
            Spacer()
        }
        .padding()
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadVideo()
            await loadMessages()
        }
        .sheet(isPresented: $isRecordingMessage) {
            MessageRecordingSheet(
                submissionId: submission.id,
                initialText: composeText
            ) { newMessage in
                messages.append(newMessage)
                composeText = ""
            }
        }
    }

    private var videoSection: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .frame(maxHeight: 280)
            } else if isLoading {
                ProgressView()
            } else {
                Color.black
                    .frame(height: 240)
                    .overlay(Text("Video unavailable").foregroundStyle(.white))
            }
        }
    }

    private var submissionInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notes = submission.notes {
                Text(notes)
                    .font(.body)
            }

            if let reviewedAt = reviewedAt ?? submission.reviewedAt {
                Text("Reviewed \(reviewedAt, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not yet reviewed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if (reviewedAt ?? submission.reviewedAt) == nil {
                Button(isMarkingReviewed ? "Marking..." : "Mark Reviewed") {
                    Task {
                        await markReviewed()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMarkingReviewed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Messages")
                .font(.headline)

            if isLoadingMessages {
                ProgressView()
            } else if messages.isEmpty {
                Text("No messages yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(messages, id: \.id) { message in
                    MessageRow(message: message)
                }
            }

            if let messageError = messageError {
                Text(messageError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadVideo() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = VideoSubmissionService(modelContext: modelContext)
            let urls = try await service.getPlaybackUrls(submissionId: submission.id)
            if let url = URL(string: urls.videoUrl) {
                player = AVPlayer(url: url)
            }
        } catch {
            errorMessage = "Failed to load video."
        }

        isLoading = false
    }

    private func markReviewed() async {
        isMarkingReviewed = true
        defer { isMarkingReviewed = false }

        do {
            let service = VideoSubmissionService(modelContext: modelContext)
            let updated = try await service.markReviewed(submissionId: submission.id)
            reviewedAt = updated.reviewedAt
            onReviewed()
        } catch {
            errorMessage = "Failed to mark reviewed."
        }
    }

    private func loadMessages() async {
        isLoadingMessages = true
        messageError = nil

        do {
            let service = MessageService(modelContext: modelContext)
            messages = try await service.getMessages(submissionId: submission.id)
        } catch {
            messageError = "Failed to load messages."
        }

        isLoadingMessages = false
    }

    private func sendTextMessage() async {
        let trimmed = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSendingMessage = true
        defer { isSendingMessage = false }

        do {
            let service = MessageService(modelContext: modelContext)
            let response = try await service.createMessage(
                submissionId: submission.id,
                text: trimmed,
                includeVideo: false,
                videoDurationSeconds: nil
            )
            messages.append(response.message)
            composeText = ""
        } catch {
            messageError = "Failed to send message."
        }
    }
}

struct MessageRow: View {
    let message: MessageDTO

    @Environment(\.modelContext) private var modelContext
    @State private var thumbnailURL: URL?
    @State private var videoURL: URL?
    @State private var isShowingPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .font(.body)
            }

            if message.videoS3Key != nil {
                Button {
                    isShowingPlayer = true
                } label: {
                    ZStack {
                        if let thumbnailURL {
                            AsyncImage(url: thumbnailURL) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 140)
                                .overlay(
                                    Image(systemName: "video")
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isShowingPlayer) {
                    MessageVideoPlayerView(videoURL: videoURL)
                }
            }

            Text(message.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            await loadVideoUrls()
        }
    }

    private func loadVideoUrls() async {
        guard message.videoS3Key != nil, thumbnailURL == nil, videoURL == nil else { return }
        do {
            let service = MessageService(modelContext: modelContext)
            let response = try await service.getPlaybackUrls(messageId: message.id)
            if let url = URL(string: response.thumbnailUrl ?? "") {
                thumbnailURL = url
            }
            if let url = URL(string: response.videoUrl) {
                videoURL = url
            }
        } catch {
            // Non-blocking
        }
    }
}

struct MessageVideoPlayerView: View {
    let videoURL: URL?

    var body: some View {
        VStack {
            if let videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(maxHeight: 300)
            } else {
                ProgressView()
            }
        }
        .padding()
    }
}

struct ComposeBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    let onRecordVideo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Send a message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button {
                onRecordVideo()
            } label: {
                Image(systemName: "video.fill")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Record video message")

            Button(isSending ? "Sending..." : "Send") {
                onSend()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview("Pending Videos") {
    NavigationStack {
        List {
            PendingVideosSection(studentId: 1)
        }
    }
    .modelContainer(for: [VideoSubmission.self, Message.self])
}

#Preview("Video Player") {
    NavigationStack {
        VideoSubmissionDetailView(submission: VideoSubmission.preview.toSubmissionDTO(), onReviewed: {})
    }
    .modelContainer(for: [VideoSubmission.self, Message.self])
}

#Preview("Message Thread") {
    NavigationStack {
        VideoSubmissionDetailView(submission: VideoSubmission.preview.toSubmissionDTO(), onReviewed: {})
    }
    .modelContainer(for: [VideoSubmission.self, Message.self])
}

#Preview("Compose Bar") {
    ComposeBar(text: .constant("Great progress!"), isSending: false, onSend: {}, onRecordVideo: {})
        .padding()
}

#Preview("Text Message") {
    MessageRow(message: .previewText)
        .padding()
}

#Preview("Video Message") {
    MessageRow(message: .previewVideo)
        .padding()
}
