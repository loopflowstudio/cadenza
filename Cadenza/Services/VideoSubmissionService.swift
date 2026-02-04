import Foundation
import SwiftData
import os

private let videoLogger = Logger(subsystem: "com.loopflow.cadenza", category: "video")

protocol VideoSubmissionServiceProtocol {
    func createSubmission(
        exerciseId: UUID?,
        pieceId: UUID?,
        sessionId: UUID?,
        durationSeconds: Int,
        notes: String?,
        localVideoURL: URL?,
        localThumbnailURL: URL?
    ) async throws -> VideoSubmission

    func uploadVideo(
        localURL: URL,
        thumbnailURL: URL?,
        for submission: VideoSubmission
    ) async throws

    func getMySubmissions(pieceId: UUID?, exerciseId: UUID?) async throws -> [VideoSubmissionDTO]
    func getStudentSubmissions(studentId: Int, pendingReviewOnly: Bool, pieceId: UUID?, exerciseId: UUID?) async throws -> [VideoSubmissionDTO]
    func markReviewed(submissionId: UUID) async throws -> VideoSubmissionDTO
    func getPlaybackUrls(submissionId: UUID) async throws -> VideoSubmissionVideoUrlResponse
}

@MainActor
final class VideoSubmissionService: VideoSubmissionServiceProtocol {
    private let apiClient: any APIClientProtocol
    private let modelContext: ModelContext

    init(apiClient: (any APIClientProtocol)? = nil, modelContext: ModelContext) {
        self.apiClient = apiClient ?? ServiceProvider.shared.apiClient
        self.modelContext = modelContext
    }

    func createSubmission(
        exerciseId: UUID?,
        pieceId: UUID?,
        sessionId: UUID?,
        durationSeconds: Int,
        notes: String?,
        localVideoURL: URL?,
        localThumbnailURL: URL?
    ) async throws -> VideoSubmission {
        let token = try requireToken()
        let request = VideoSubmissionCreateRequest(
            exerciseId: exerciseId,
            pieceId: pieceId,
            sessionId: sessionId,
            durationSeconds: durationSeconds,
            notes: notes
        )

        let response = try await apiClient.createVideoSubmission(request: request, token: token)
        let submission = response.submission.toSubmission()
        submission.localVideoPath = localVideoURL?.absoluteString
        submission.localThumbnailPath = localThumbnailURL?.absoluteString
        submission.uploadStatus = .pending

        modelContext.insert(submission)
        try modelContext.save()

        return submission
    }

    func uploadVideo(localURL: URL, thumbnailURL: URL?, for submission: VideoSubmission) async throws {
        let token = try requireToken()
        submission.uploadStatus = .uploading
        try modelContext.save()

        do {
            let uploadUrls = try await apiClient.getVideoSubmissionUploadUrl(
                submissionId: submission.id,
                token: token
            )

            try await uploadFile(localURL, to: uploadUrls.uploadUrl, contentType: "video/mp4")

            if let thumbnailURL {
                try await uploadFile(thumbnailURL, to: uploadUrls.thumbnailUploadUrl, contentType: "image/jpeg")
            }

            submission.uploadStatus = .uploaded
            submission.localVideoPath = nil
            submission.localThumbnailPath = nil
            try modelContext.save()

            try? FileManager.default.removeItem(at: localURL)
            if let thumbnailURL {
                try? FileManager.default.removeItem(at: thumbnailURL)
            }
        } catch {
            submission.uploadStatus = .failed
            try? modelContext.save()
            throw error
        }
    }

    func getMySubmissions(pieceId: UUID?, exerciseId: UUID?) async throws -> [VideoSubmissionDTO] {
        let token = try requireToken()
        return try await apiClient.getMyVideoSubmissions(pieceId: pieceId, exerciseId: exerciseId, token: token)
    }

    func getStudentSubmissions(studentId: Int, pendingReviewOnly: Bool, pieceId: UUID?, exerciseId: UUID?) async throws -> [VideoSubmissionDTO] {
        let token = try requireToken()
        return try await apiClient.getStudentVideoSubmissions(
            studentId: studentId,
            pieceId: pieceId,
            exerciseId: exerciseId,
            pendingReviewOnly: pendingReviewOnly,
            token: token
        )
    }

    func markReviewed(submissionId: UUID) async throws -> VideoSubmissionDTO {
        let token = try requireToken()
        return try await apiClient.markVideoSubmissionReviewed(submissionId: submissionId, token: token)
    }

    func getPlaybackUrls(submissionId: UUID) async throws -> VideoSubmissionVideoUrlResponse {
        let token = try requireToken()
        return try await apiClient.getVideoSubmissionVideoUrl(submissionId: submissionId, token: token)
    }

    private func requireToken() throws -> String {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            throw APIError.unauthorized
        }
        return token
    }

    private func uploadFile(_ fileURL: URL, to uploadURLString: String, contentType: String) async throws {
        guard let uploadURL = URL(string: uploadURLString) else {
            throw APIError.requestFailed
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            videoLogger.error("Upload failed with status: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            throw APIError.requestFailed
        }
    }
}
