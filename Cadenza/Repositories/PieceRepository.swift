import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.loopflow.cadenza", category: "sync")

@MainActor
class PieceRepository {
    private let apiClient: any APIClientProtocol
    private let modelContext: ModelContext

    init(apiClient: (any APIClientProtocol)? = nil, modelContext: ModelContext) {
        self.apiClient = apiClient ?? ServiceProvider.shared.apiClient
        self.modelContext = modelContext
    }

    // MARK: - Sync Operations

    func syncFromServer(token: String) async throws {
        logger.info("Syncing pieces from server...")
        let serverPieceDTOs = try await apiClient.getPieces(token: token)
        logger.info("Server returned \(serverPieceDTOs.count) pieces")

        var piecesNeedingDownload: [Piece] = []

        for dto in serverPieceDTOs {
            let fetchDescriptor = FetchDescriptor<Piece>(
                predicate: #Predicate { $0.id == dto.id }
            )

            if let existingPiece = try? modelContext.fetch(fetchDescriptor).first {
                // Update existing piece
                logger.debug("Updating existing piece \(dto.id) '\(dto.title)'")
                existingPiece.title = dto.title
                existingPiece.pdfFilename = dto.pdfFilename
                existingPiece.sharedFromPieceId = dto.sharedFromPieceId
                existingPiece.updatedAt = dto.updatedAt

                // Track pieces needing PDF download
                if existingPiece.pdfURL == nil && dto.s3Key != nil {
                    piecesNeedingDownload.append(existingPiece)
                }
            } else {
                // Insert new piece
                logger.debug("Inserting new piece \(dto.id) '\(dto.title)'")
                let piece = dto.toPiece()
                modelContext.insert(piece)

                // Track pieces needing PDF download
                if dto.s3Key != nil {
                    piecesNeedingDownload.append(piece)
                }
            }
        }

        // Save immediately so UI updates
        try modelContext.save()
        logger.info("Sync complete - saved \(serverPieceDTOs.count) pieces to SwiftData")

        // Download PDFs in background (don't block UI)
        if !piecesNeedingDownload.isEmpty {
            logger.info("Downloading PDFs for \(piecesNeedingDownload.count) pieces in background...")
            for piece in piecesNeedingDownload {
                await downloadPDFIfNeeded(for: piece, token: token)
            }
        }
    }

    private func downloadPDFIfNeeded(for piece: Piece, token: String) async {
        // Check if PDF already exists locally
        guard piece.pdfURL == nil else {
            logger.debug("PDF already exists locally for piece \(piece.id)")
            return
        }

        guard let filename = piece.pdfFilename else {
            logger.warning("No PDF filename for piece \(piece.id)")
            return
        }

        do {
            logger.info("Downloading PDF for piece \(piece.id) '\(piece.title)'...")

            // Get presigned download URL from server
            let urlResponse = try await apiClient.getPieceDownloadUrl(pieceId: piece.id, token: token)

            // Download the PDF
            guard let downloadUrl = URL(string: urlResponse.downloadUrl) else {
                logger.error("Invalid download URL for piece \(piece.id)")
                return
            }

            let (data, response) = try await URLSession.shared.data(from: downloadUrl)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logger.error("Failed to download PDF for piece \(piece.id)")
                return
            }

            // Save to documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent(filename)

            try data.write(to: fileURL)
            logger.info("Successfully downloaded PDF for piece \(piece.id) to \(fileURL.path)")

        } catch {
            logger.error("Failed to download PDF for piece \(piece.id): \(error)")
        }
    }

    func createPieceWithUpload(title: String, pdfData: Data, pdfFilename: String, ownerId: Int, token: String) async throws -> PieceDTO {
        // Server generates UUID and creates piece
        let dto = try await apiClient.createPiece(
            title: title,
            pdfData: pdfData,
            pdfFilename: pdfFilename,
            token: token
        )

        return dto
    }

    func updatePiece(_ piece: Piece, token: String) async throws {
        _ = try await apiClient.updatePiece(
            id: piece.id,
            title: piece.title,
            token: token
        )

        piece.updatedAt = Date()
        try modelContext.save()
    }

    func deletePiece(_ piece: Piece, token: String) async throws {
        try await apiClient.deletePiece(id: piece.id, token: token)

        modelContext.delete(piece)
        try modelContext.save()
    }
}

