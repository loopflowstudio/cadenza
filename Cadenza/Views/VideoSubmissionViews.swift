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
            VideoPlayerView(submission: submission, onReviewed: onReviewed)
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

struct VideoPlayerView: View {
    let submission: VideoSubmissionDTO
    let onReviewed: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reviewedAt: Date?
    @State private var isMarkingReviewed = false

    var body: some View {
        VStack(spacing: 16) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if (reviewedAt ?? submission.reviewedAt) == nil {
                Button(isMarkingReviewed ? "Marking..." : "Mark Reviewed") {
                    Task {
                        await markReviewed()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMarkingReviewed)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadVideo()
        }
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
}

#Preview("Pending Videos") {
    NavigationStack {
        List {
            PendingVideosSection(studentId: 1)
        }
    }
    .modelContainer(for: [VideoSubmission.self])
}

#Preview("Video Player") {
    NavigationStack {
        VideoPlayerView(submission: VideoSubmission.preview.toSubmissionDTO(), onReviewed: {})
    }
    .modelContainer(for: [VideoSubmission.self])
}
