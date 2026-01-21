import XCTest
@testable import Cadenza

let testToken = "test_token_123"

extension User {
    static let testTeacher = User(
        id: 1,
        appleUserId: "test_apple_1",
        email: "teacher@test.com",
        fullName: "Test Teacher",
        userType: .teacher,
        teacherId: nil,
        createdAt: Date()
    )

    static let testStudent = User(
        id: 2,
        appleUserId: "test_apple_2",
        email: "student@test.com",
        fullName: "Test Student",
        userType: .student,
        teacherId: 1,
        createdAt: Date()
    )
}

extension PieceDTO {
    static let testPiece = PieceDTO(
        id: UUID(),
        ownerId: 1,
        title: "Test Piece",
        pdfFilename: "test.pdf",
        s3Key: "test/test.pdf",
        sharedFromPieceId: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
