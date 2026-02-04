import Foundation
import SwiftData

@Model
final class VideoSubmission: Identifiable {
    @Attribute(.unique) var id: UUID
    var userId: Int
    var exerciseId: UUID?
    var pieceId: UUID?
    var sessionId: UUID?

    var s3Key: String
    var thumbnailS3Key: String?
    var durationSeconds: Int

    var notes: String?
    var reviewedAt: Date?
    var reviewedById: Int?

    var createdAt: Date

    var localVideoPath: String?
    var localThumbnailPath: String?
    @Transient var uploadStatus: UploadStatus = .pending

    init(
        id: UUID,
        userId: Int,
        exerciseId: UUID? = nil,
        pieceId: UUID? = nil,
        sessionId: UUID? = nil,
        s3Key: String,
        thumbnailS3Key: String? = nil,
        durationSeconds: Int,
        notes: String? = nil,
        reviewedAt: Date? = nil,
        reviewedById: Int? = nil,
        createdAt: Date,
        localVideoPath: String? = nil,
        localThumbnailPath: String? = nil,
        uploadStatus: UploadStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.exerciseId = exerciseId
        self.pieceId = pieceId
        self.sessionId = sessionId
        self.s3Key = s3Key
        self.thumbnailS3Key = thumbnailS3Key
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.reviewedAt = reviewedAt
        self.reviewedById = reviewedById
        self.createdAt = createdAt
        self.localVideoPath = localVideoPath
        self.localThumbnailPath = localThumbnailPath
        self.uploadStatus = uploadStatus
    }
}

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed
}

// MARK: - Data Transfer Objects

struct VideoSubmissionDTO: Codable {
    let id: UUID
    let userId: Int
    let exerciseId: UUID?
    let pieceId: UUID?
    let sessionId: UUID?
    let s3Key: String
    let thumbnailS3Key: String?
    let durationSeconds: Int
    let notes: String?
    let reviewedAt: Date?
    let reviewedById: Int?
    let createdAt: Date

    func toSubmission() -> VideoSubmission {
        VideoSubmission(
            id: id,
            userId: userId,
            exerciseId: exerciseId,
            pieceId: pieceId,
            sessionId: sessionId,
            s3Key: s3Key,
            thumbnailS3Key: thumbnailS3Key,
            durationSeconds: durationSeconds,
            notes: notes,
            reviewedAt: reviewedAt,
            reviewedById: reviewedById,
            createdAt: createdAt
        )
    }
}

struct VideoSubmissionCreateRequest: Codable {
    let exerciseId: UUID?
    let pieceId: UUID?
    let sessionId: UUID?
    let durationSeconds: Int
    let notes: String?
}

struct VideoSubmissionCreateResponse: Codable {
    let submission: VideoSubmissionDTO
    let uploadUrl: String
    let thumbnailUploadUrl: String
    let expiresIn: Int
}

struct VideoSubmissionUploadUrlsResponse: Codable {
    let uploadUrl: String
    let thumbnailUploadUrl: String
    let expiresIn: Int
}

struct VideoSubmissionVideoUrlResponse: Codable {
    let videoUrl: String
    let thumbnailUrl: String?
    let expiresIn: Int
}

// MARK: - Sample Data

extension VideoSubmission {
    static var preview: VideoSubmission {
        VideoSubmission(
            id: UUID(),
            userId: 1,
            exerciseId: UUID(),
            pieceId: UUID(),
            sessionId: UUID(),
            s3Key: "cadenza/videos/1/sample.mp4",
            thumbnailS3Key: "cadenza/videos/1/sample_thumb.jpg",
            durationSeconds: 32,
            notes: "Having trouble with fingering.",
            reviewedAt: nil,
            reviewedById: nil,
            createdAt: Date()
        )
    }

    func toSubmissionDTO() -> VideoSubmissionDTO {
        VideoSubmissionDTO(
            id: id,
            userId: userId,
            exerciseId: exerciseId,
            pieceId: pieceId,
            sessionId: sessionId,
            s3Key: s3Key,
            thumbnailS3Key: thumbnailS3Key,
            durationSeconds: durationSeconds,
            notes: notes,
            reviewedAt: reviewedAt,
            reviewedById: reviewedById,
            createdAt: createdAt
        )
    }
}
