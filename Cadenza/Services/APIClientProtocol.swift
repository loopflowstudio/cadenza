import Foundation

/// Protocol defining all API client operations
/// Allows for dependency injection and mocking in tests
protocol APIClientProtocol: Sendable {
    // MARK: - Auth
    func authenticateWithApple(idToken: String) async throws -> AuthResponse
    func getCurrentUser(token: String) async throws -> User

    // MARK: - Teacher/Student
    func getMyTeacher(token: String) async throws -> User?
    func getMyStudents(token: String) async throws -> [User]
    func setTeacher(email: String, token: String) async throws -> User
    func removeTeacher(token: String) async throws

    // MARK: - Pieces
    func getPieces(token: String) async throws -> [PieceDTO]
    func createPiece(title: String, pdfData: Data, pdfFilename: String, token: String) async throws -> PieceDTO
    func updatePiece(id: UUID, title: String, token: String) async throws -> PieceDTO
    func deletePiece(id: UUID, token: String) async throws
    func getStudentPieces(studentId: Int, token: String) async throws -> [PieceDTO]
    func sharePiece(pieceId: UUID, studentId: Int, token: String) async throws -> PieceDTO
    func getPieceDownloadUrl(pieceId: UUID, token: String) async throws -> PieceDownloadUrlResponse

    // MARK: - Routines
    func getRoutines(token: String) async throws -> [RoutineDTO]
    func createRoutine(title: String, description: String?, token: String) async throws -> RoutineDTO
    func getRoutine(id: UUID, token: String) async throws -> RoutineDTO
    func deleteRoutine(id: UUID, token: String) async throws
    func getMyAssignments(token: String) async throws -> [RoutineAssignmentWithRoutineDTO]
    func addExerciseToRoutine(routineId: UUID, pieceId: UUID, orderIndex: Int, recommendedTimeSeconds: Int?, intentions: String?, startPage: Int?, token: String) async throws -> ExerciseDTO
    func assignRoutineToStudent(studentId: Int, routineId: UUID, token: String) async throws -> AssignRoutineResponse

    // MARK: - Practice Sessions
    func startPracticeSession(routineId: UUID, token: String) async throws -> PracticeSessionDTO
    func completePracticeSession(sessionId: UUID, token: String) async throws -> PracticeSessionDTO
    func completeExerciseInSession(sessionId: UUID, exerciseId: UUID, actualTimeSeconds: Int?, reflections: String?, token: String) async throws -> ExerciseSessionDTO
    func updateExerciseCompletion(sessionId: UUID, exerciseId: UUID, isComplete: Bool, actualTimeSeconds: Int?, reflections: String?, token: String) async throws -> ExerciseSessionDTO
    func getPracticeCalendar(token: String) async throws -> [CalendarDayDTO]
    func getPracticeCompletions(token: String) async throws -> [SessionCompletionDTO]

}
