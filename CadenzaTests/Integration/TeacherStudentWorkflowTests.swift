import XCTest
@testable import Cadenza

@MainActor
final class TeacherStudentWorkflowTests: XCTestCase {

    func testTeacherCanAssignRoutineToStudent() async throws {
        let mockAPI = MockAPIClientImpl.shared
        let teacherToken = "dev_token_user_1"
        let routine = try await mockAPI.createRoutine(
            title: "Test Routine",
            description: "For testing",
            token: teacherToken
        )

        let students = try await mockAPI.getMyStudents(token: teacherToken)
        XCTAssertGreaterThan(students.count, 0)
        let student = students.first!

        let response = try await mockAPI.assignRoutineToStudent(
            studentId: student.id,
            routineId: routine.id,
            token: teacherToken
        )

        XCTAssertNotNil(response.routine)
        XCTAssertEqual(response.routine.ownerId, student.id)
    }

    func testStudentCanSeeAssignedRoutine() async throws {
        let mockAPI = MockAPIClientImpl.shared
        let teacherToken = "dev_token_user_1"
        let studentToken = "dev_token_user_2"

        let routine = try await mockAPI.createRoutine(
            title: "Assigned Routine",
            description: nil,
            token: teacherToken
        )

        let students = try await mockAPI.getMyStudents(token: teacherToken)
        let student = students.first!

        _ = try await mockAPI.assignRoutineToStudent(
            studentId: student.id,
            routineId: routine.id,
            token: teacherToken
        )

        let assignments = try await mockAPI.getMyAssignments(token: studentToken)

        XCTAssertGreaterThan(assignments.count, 0)
    }

    func testTeacherCanSharePieceWithStudent() async throws {
        let mockAPI = MockAPIClientImpl.shared
        let teacherToken = "dev_token_user_1"
        let pieces = try await mockAPI.getPieces(token: teacherToken)
        let students = try await mockAPI.getMyStudents(token: teacherToken)

        XCTAssertGreaterThan(pieces.count, 0)
        XCTAssertGreaterThan(students.count, 0)

        let piece = pieces.first!
        let student = students.first!

        let sharedPiece = try await mockAPI.sharePiece(
            pieceId: piece.id,
            studentId: student.id,
            token: teacherToken
        )

        XCTAssertEqual(sharedPiece.ownerId, student.id)
        XCTAssertEqual(sharedPiece.sharedFromPieceId, piece.id)
        XCTAssertEqual(sharedPiece.title, piece.title)
    }
}
