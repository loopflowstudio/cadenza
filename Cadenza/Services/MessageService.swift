import Foundation
import SwiftData
import os

private let messageLogger = Logger(subsystem: "com.loopflow.cadenza", category: "messages")

protocol MessageServiceProtocol {
    func getMessages(submissionId: UUID) async throws -> [MessageDTO]
    func createMessage(
        submissionId: UUID,
        text: String?,
        includeVideo: Bool,
        videoDurationSeconds: Int?
    ) async throws -> MessageCreateResponse
    func uploadVideo(localURL: URL, thumbnailURL: URL?, uploadUrl: String, thumbnailUploadUrl: String?) async throws
    func getPlaybackUrls(messageId: UUID) async throws -> MessageVideoUrlResponse
}

@MainActor
final class MessageService: MessageServiceProtocol {
    private let apiClient: any APIClientProtocol
    private let modelContext: ModelContext

    init(apiClient: (any APIClientProtocol)? = nil, modelContext: ModelContext) {
        self.apiClient = apiClient ?? ServiceProvider.shared.apiClient
        self.modelContext = modelContext
    }

    func getMessages(submissionId: UUID) async throws -> [MessageDTO] {
        let token = try requireToken()
        return try await apiClient.getMessages(submissionId: submissionId, token: token)
    }

    func createMessage(
        submissionId: UUID,
        text: String?,
        includeVideo: Bool,
        videoDurationSeconds: Int?
    ) async throws -> MessageCreateResponse {
        let token = try requireToken()
        let request = MessageCreateRequest(
            text: text,
            includeVideo: includeVideo,
            videoDurationSeconds: videoDurationSeconds
        )

        let response = try await apiClient.createMessage(
            submissionId: submissionId,
            request: request,
            token: token
        )

        let message = response.message.toMessage()
        message.uploadStatus = includeVideo ? .pending : .uploaded
        modelContext.insert(message)
        try modelContext.save()

        return response
    }

    func uploadVideo(localURL: URL, thumbnailURL: URL?, uploadUrl: String, thumbnailUploadUrl: String?) async throws {
        try await uploadFile(localURL, to: uploadUrl, contentType: "video/mp4")

        if let thumbnailURL, let thumbnailUploadUrl {
            try await uploadFile(thumbnailURL, to: thumbnailUploadUrl, contentType: "image/jpeg")
        }

        try? FileManager.default.removeItem(at: localURL)
        if let thumbnailURL {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
    }

    func getPlaybackUrls(messageId: UUID) async throws -> MessageVideoUrlResponse {
        let token = try requireToken()
        return try await apiClient.getMessageVideoUrl(messageId: messageId, token: token)
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
            messageLogger.error("Upload failed with status: \\(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            throw APIError.requestFailed
        }
    }
}
