import Foundation
import SwiftData

@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID
    var submissionId: UUID
    var senderId: Int

    var text: String?
    var videoS3Key: String?
    var videoDurationSeconds: Int?
    var thumbnailS3Key: String?

    var createdAt: Date

    var localVideoPath: String?
    var localThumbnailPath: String?
    @Transient var uploadStatus: UploadStatus = .pending

    init(
        id: UUID,
        submissionId: UUID,
        senderId: Int,
        text: String? = nil,
        videoS3Key: String? = nil,
        videoDurationSeconds: Int? = nil,
        thumbnailS3Key: String? = nil,
        createdAt: Date,
        localVideoPath: String? = nil,
        localThumbnailPath: String? = nil,
        uploadStatus: UploadStatus = .pending
    ) {
        self.id = id
        self.submissionId = submissionId
        self.senderId = senderId
        self.text = text
        self.videoS3Key = videoS3Key
        self.videoDurationSeconds = videoDurationSeconds
        self.thumbnailS3Key = thumbnailS3Key
        self.createdAt = createdAt
        self.localVideoPath = localVideoPath
        self.localThumbnailPath = localThumbnailPath
        self.uploadStatus = uploadStatus
    }
}

// MARK: - Data Transfer Objects

struct MessageDTO: Codable {
    let id: UUID
    let submissionId: UUID
    let senderId: Int
    let text: String?
    let videoS3Key: String?
    let videoDurationSeconds: Int?
    let thumbnailS3Key: String?
    let createdAt: Date

    func toMessage() -> Message {
        Message(
            id: id,
            submissionId: submissionId,
            senderId: senderId,
            text: text,
            videoS3Key: videoS3Key,
            videoDurationSeconds: videoDurationSeconds,
            thumbnailS3Key: thumbnailS3Key,
            createdAt: createdAt
        )
    }
}

struct MessageCreateRequest: Codable {
    let text: String?
    let includeVideo: Bool
    let videoDurationSeconds: Int?
}

struct MessageCreateResponse: Codable {
    let message: MessageDTO
    let uploadUrl: String?
    let thumbnailUploadUrl: String?
    let expiresIn: Int?
}

struct MessageVideoUrlResponse: Codable {
    let videoUrl: String
    let thumbnailUrl: String?
    let expiresIn: Int
}

// MARK: - Sample Data

extension MessageDTO {
    static var previewText: MessageDTO {
        MessageDTO(
            id: UUID(),
            submissionId: UUID(),
            senderId: 2,
            text: "Great progress on the rhythm!",
            videoS3Key: nil,
            videoDurationSeconds: nil,
            thumbnailS3Key: nil,
            createdAt: Date()
        )
    }

    static var previewVideo: MessageDTO {
        MessageDTO(
            id: UUID(),
            submissionId: UUID(),
            senderId: 2,
            text: "Watch my hand position here.",
            videoS3Key: "cadenza/videos/2/messages/sample.mp4",
            videoDurationSeconds: 12,
            thumbnailS3Key: "cadenza/videos/2/messages/sample_thumb.jpg",
            createdAt: Date()
        )
    }
}
