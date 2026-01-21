import Foundation
import SwiftData

@Model
final class Piece: Identifiable {
    @Attribute(.unique) var id: UUID
    var ownerId: Int
    var title: String
    var pdfFilename: String?
    var sharedFromPieceId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID? = nil, ownerId: Int, title: String, pdfFilename: String? = nil, sharedFromPieceId: UUID? = nil) {
        self.id = id ?? UUID()
        self.ownerId = ownerId
        self.title = title
        self.pdfFilename = pdfFilename
        self.sharedFromPieceId = sharedFromPieceId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - PDF URL Resolution

    var pdfURL: URL? {
        guard let filename = pdfFilename else { return nil }

        // Check bundle for bundled resources
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: "pdf") {
            return bundleURL
        }

        // Check documents directory for imported files
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        return nil
    }
}

// MARK: - Data Transfer Object

struct PieceDTO: Codable {
    let id: UUID
    let ownerId: Int
    let title: String
    let pdfFilename: String
    let s3Key: String?
    let sharedFromPieceId: UUID?
    let createdAt: Date
    let updatedAt: Date

    func toPiece() -> Piece {
        Piece(
            id: id,
            ownerId: ownerId,
            title: title,
            pdfFilename: pdfFilename,
            sharedFromPieceId: sharedFromPieceId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct PieceDownloadUrlResponse: Codable {
    let downloadUrl: String
    let expiresIn: Int
}

extension Piece {
    convenience init(id: UUID, ownerId: Int, title: String, pdfFilename: String, sharedFromPieceId: UUID?, createdAt: Date, updatedAt: Date) {
        self.init(id: id, ownerId: ownerId, title: title, pdfFilename: pdfFilename, sharedFromPieceId: sharedFromPieceId)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Sample Data

extension Piece {
    static var samplePieces: [Piece] {
        [
            Piece(ownerId: 1, title: "Sample Sheet Music", pdfFilename: "sample")
        ]
    }
}
