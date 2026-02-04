import Foundation

/// Mock API client for UI testing
/// This implementation lives in the main app target so it can be used during UI tests
/// Only compiled in DEBUG builds
#if DEBUG
@MainActor
class MockAPIClientImpl: APIClientProtocol {
    static let shared = MockAPIClientImpl()

    // Mock data storage
    private var users: [User] = []
    private var pieces: [PieceDTO] = []
    private var routines: [RoutineDTO] = []
    private var teacherStudentRelations: [Int: Int] = [:] // studentId: teacherId
    private var videoSubmissions: [VideoSubmissionDTO] = []
    private var messages: [MessageDTO] = []

    // Track which user each token represents
    private var tokenToUserId: [String: Int] = [:]

    private init() {
        setupDefaultData()
    }

    private func setupDefaultData() {
        // Create test users matching DeveloperMenu
        users = [
            User(
                id: 1,
                appleUserId: "mock_1",
                email: "teacher@example.com",
                fullName: "Test Teacher",
                userType: .teacher,
                teacherId: nil,
                createdAt: Date()
            ),
            User(
                id: 2,
                appleUserId: "mock_2",
                email: "student1@example.com",
                fullName: "Test Student 1",
                userType: .student,
                teacherId: 1,
                createdAt: Date()
            ),
            User(
                id: 3,
                appleUserId: "mock_3",
                email: "student2@example.com",
                fullName: "Test Student 2",
                userType: .student,
                teacherId: 1,
                createdAt: Date()
            )
        ]

        // Map dev tokens to user IDs
        tokenToUserId = [
            "dev_token_user_1": 1,
            "dev_token_user_2": 2,
            "dev_token_user_3": 3
        ]

        // Set up teacher-student relationships
        // Student 1 and Student 2 both have Teacher 1
        teacherStudentRelations = [
            2: 1,  // Student 1 has Teacher 1
            3: 1   // Student 2 has Teacher 1
        ]

        // Create test pieces for teacher
        pieces = [
            PieceDTO(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                ownerId: 1,
                title: "Bach Prelude in C Major",
                pdfFilename: "bach-prelude-c.pdf",
                s3Key: "cadenza/pieces/00000000-0000-0000-0000-000000000001.pdf",
                sharedFromPieceId: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            PieceDTO(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                ownerId: 1,
                title: "Mozart Sonata No. 16",
                pdfFilename: "mozart-sonata-16.pdf",
                s3Key: "cadenza/pieces/00000000-0000-0000-0000-000000000002.pdf",
                sharedFromPieceId: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            PieceDTO(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                ownerId: 1,
                title: "Beethoven Moonlight Sonata",
                pdfFilename: "beethoven-moonlight.pdf",
                s3Key: "cadenza/pieces/00000000-0000-0000-0000-000000000003.pdf",
                sharedFromPieceId: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        // Create sample routines with exercises
        let routineId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        routines = [
            RoutineDTO(
                id: routineId,
                ownerId: 1,
                title: "Morning Practice",
                description: "Daily warm-up routine",
                assignedById: 2,
                assignedAt: Date().addingTimeInterval(-86400),
                sharedFromRoutineId: UUID(uuidString: "00000000-0000-0000-0000-000000000011"),
                createdAt: Date(),
                updatedAt: Date(),
                exercises: [
                    ExerciseDTO(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                        routineId: routineId,
                        pieceId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                        orderIndex: 0,
                        recommendedTimeSeconds: 600,
                        intentions: "Focus on tone quality",
                        startPage: 1
                    ),
                    ExerciseDTO(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                        routineId: routineId,
                        pieceId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                        orderIndex: 1,
                        recommendedTimeSeconds: 900,
                        intentions: "Work on dynamics",
                        startPage: 1
                    )
                ]
            )
        ]

        videoSubmissions = [
            VideoSubmissionDTO(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                userId: 2,
                exerciseId: routines.first?.exercises.first?.id,
                pieceId: pieces.first?.id,
                sessionId: UUID(),
                s3Key: "cadenza/videos/2/00000000-0000-0000-0000-000000000201.mp4",
                thumbnailS3Key: "cadenza/videos/2/00000000-0000-0000-0000-000000000201_thumb.jpg",
                durationSeconds: 42,
                notes: "Tempo feels uneven in the middle.",
                reviewedAt: nil,
                reviewedById: nil,
                createdAt: Date().addingTimeInterval(-3600)
            )
        ]
    }

    private func getUserId(from token: String) -> Int {
        return tokenToUserId[token] ?? 1
    }

    // MARK: - Auth

    func authenticateWithApple(idToken: String) async throws -> AuthResponse {
        // For mock, just return first user
        return AuthResponse(accessToken: "dev_token_user_1", user: users[0])
    }

    func getCurrentUser(token: String) async throws -> User {
        let userId = getUserId(from: token)
        guard let user = users.first(where: { $0.id == userId }) else {
            throw APIError.unauthorized  // Use shared error type
        }
        return user
    }

    // MARK: - Teacher/Student

    func getMyTeacher(token: String) async throws -> User? {
        let userId = getUserId(from: token)
        if let teacherId = teacherStudentRelations[userId] {
            return users.first { $0.id == teacherId }
        }
        return nil
    }

    func getMyStudents(token: String) async throws -> [User] {
        let userId = getUserId(from: token)
        let studentIds = teacherStudentRelations.filter { $0.value == userId }.keys
        return users.filter { studentIds.contains($0.id) }
    }

    func setTeacher(email: String, token: String) async throws -> User {
        let userId = getUserId(from: token)

        guard let teacher = users.first(where: { $0.email == email }) else {
            throw APIError.requestFailed
        }

        teacherStudentRelations[userId] = teacher.id

        // Update user object
        if let index = users.firstIndex(where: { $0.id == userId }) {
            users[index] = User(
                id: users[index].id,
                appleUserId: users[index].appleUserId,
                email: users[index].email,
                fullName: users[index].fullName,
                userType: users[index].userType,
                teacherId: teacher.id,
                createdAt: users[index].createdAt
            )
        }

        return teacher
    }

    func removeTeacher(token: String) async throws {
        let userId = getUserId(from: token)
        teacherStudentRelations.removeValue(forKey: userId)

        // Update user object
        if let index = users.firstIndex(where: { $0.id == userId }) {
            users[index] = User(
                id: users[index].id,
                appleUserId: users[index].appleUserId,
                email: users[index].email,
                fullName: users[index].fullName,
                userType: users[index].userType,
                teacherId: nil,
                createdAt: users[index].createdAt
            )
        }
    }

    // MARK: - Pieces

    func getPieces(token: String) async throws -> [PieceDTO] {
        let userId = getUserId(from: token)
        return pieces.filter { $0.ownerId == userId }
    }

    func createPiece(title: String, pdfData: Data, pdfFilename: String, token: String) async throws -> PieceDTO {
        let userId = getUserId(from: token)
        let pieceId = UUID()

        let piece = PieceDTO(
            id: pieceId,
            ownerId: userId,
            title: title,
            pdfFilename: pdfFilename,
            s3Key: "cadenza/pieces/\(pieceId.uuidString).pdf",
            sharedFromPieceId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        pieces.append(piece)
        return piece
    }

    func updatePiece(id: UUID, title: String, token: String) async throws -> PieceDTO {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else {
            throw APIError.requestFailed
        }

        let updated = PieceDTO(
            id: pieces[index].id,
            ownerId: pieces[index].ownerId,
            title: title,
            pdfFilename: pieces[index].pdfFilename,
            s3Key: pieces[index].s3Key,
            sharedFromPieceId: pieces[index].sharedFromPieceId,
            createdAt: pieces[index].createdAt,
            updatedAt: Date()
        )

        pieces[index] = updated
        return updated
    }

    func deletePiece(id: UUID, token: String) async throws {
        pieces.removeAll { $0.id == id }
    }

    func getStudentPieces(studentId: Int, token: String) async throws -> [PieceDTO] {
        return pieces.filter { $0.ownerId == studentId }
    }

    func sharePiece(pieceId: UUID, studentId: Int, token: String) async throws -> PieceDTO {
        guard let original = pieces.first(where: { $0.id == pieceId }) else {
            throw APIError.requestFailed
        }

        let sharedId = UUID()
        let shared = PieceDTO(
            id: sharedId,
            ownerId: studentId,
            title: original.title,
            pdfFilename: original.pdfFilename,
            s3Key: "cadenza/pieces/\(sharedId.uuidString).pdf",
            sharedFromPieceId: original.id,
            createdAt: Date(),
            updatedAt: Date()
        )

        pieces.append(shared)
        return shared
    }

    func getPieceDownloadUrl(pieceId: UUID, token: String) async throws -> PieceDownloadUrlResponse {
        // Mock doesn't actually provide real S3 URLs
        // In real tests, we'd use local files
        return PieceDownloadUrlResponse(
            downloadUrl: "https://mock-s3.example.com/cadenza/pieces/\(pieceId.uuidString).pdf",
            expiresIn: 3600
        )
    }

    // MARK: - Routines

    func getRoutines(token: String) async throws -> [RoutineDTO] {
        let userId = getUserId(from: token)
        return routines.filter { $0.ownerId == userId }
    }

    func createRoutine(title: String, description: String?, token: String) async throws -> RoutineDTO {
        let routineId = UUID()
        let userId = getUserId(from: token)
        let routine = RoutineDTO(
            id: routineId,
            ownerId: userId,
            title: title,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            exercises: []
        )
        routines.append(routine)
        return routine
    }

    func getRoutine(id: UUID, token: String) async throws -> RoutineDTO {
        // Return a sample routine
        return RoutineDTO(
            id: id,
            ownerId: getUserId(from: token),
            title: "Sample Routine",
            description: nil,
            createdAt: Date(),
            updatedAt: Date(),
            exercises: []
        )
    }

    func deleteRoutine(id: UUID, token: String) async throws {
        // No-op for mock
    }

    func getMyAssignments(token: String) async throws -> [RoutineAssignmentWithRoutineDTO] {
        // Return empty list for now
        return []
    }

    func addExerciseToRoutine(routineId: UUID, pieceId: UUID, orderIndex: Int, recommendedTimeSeconds: Int?, intentions: String?, startPage: Int?, token: String) async throws -> ExerciseDTO {
        return ExerciseDTO(
            id: UUID(),
            routineId: routineId,
            pieceId: pieceId,
            orderIndex: orderIndex,
            recommendedTimeSeconds: recommendedTimeSeconds,
            intentions: intentions,
            startPage: startPage
        )
    }

    func assignRoutineToStudent(studentId: Int, routineId: UUID, token: String) async throws -> AssignRoutineResponse {
        let userId = getUserId(from: token)

        // Verify teacher owns the student
        guard teacherStudentRelations[studentId] == userId else {
            throw APIError.unauthorized
        }

        // Create a copy of the routine for the student
        let routineId = UUID()
        let studentRoutine = RoutineDTO(
            id: routineId,
            ownerId: studentId,
            title: "Assigned Routine",
            description: nil,
            createdAt: Date(),
            updatedAt: Date(),
            exercises: []
        )

        return AssignRoutineResponse(
            message: "Routine assigned successfully",
            routine: studentRoutine,
            piecesShared: 0
        )
    }

    // MARK: - Practice Sessions

    func startPracticeSession(routineId: UUID, token: String) async throws -> PracticeSessionDTO {
        let userId = getUserId(from: token)
        return PracticeSessionDTO(
            id: UUID(),
            userId: userId,
            routineId: routineId,
            startedAt: Date(),
            completedAt: nil,
            durationSeconds: nil
        )
    }

    func completePracticeSession(sessionId: UUID, token: String) async throws -> PracticeSessionDTO {
        let userId = getUserId(from: token)
        return PracticeSessionDTO(
            id: sessionId,
            userId: userId,
            routineId: UUID(),
            startedAt: Date().addingTimeInterval(-1800),
            completedAt: Date(),
            durationSeconds: 1800
        )
    }

    func completeExerciseInSession(sessionId: UUID, exerciseId: UUID, actualTimeSeconds: Int?, reflections: String?, token: String) async throws -> ExerciseSessionDTO {
        return ExerciseSessionDTO(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: exerciseId,
            completedAt: Date(),
            actualTimeSeconds: actualTimeSeconds,
            reflections: reflections
        )
    }

    func updateExerciseCompletion(sessionId: UUID, exerciseId: UUID, isComplete: Bool, actualTimeSeconds: Int?, reflections: String?, token: String) async throws -> ExerciseSessionDTO {
        return ExerciseSessionDTO(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: exerciseId,
            completedAt: isComplete ? Date() : nil,
            actualTimeSeconds: isComplete ? actualTimeSeconds : nil,
            reflections: isComplete ? reflections : nil
        )
    }

    func getPracticeCalendar(token: String) async throws -> [CalendarDayDTO] {
        // Return sample calendar data with some practice days
        let today = Date()
        let calendar = Calendar.current

        var days: [CalendarDayDTO] = []
        for offset in [0, -1, -3, -5, -7] {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                let sessionCount = abs(offset) % 3 + 1
                days.append(CalendarDayDTO(
                    date: CalendarDayDTO.dateString(from: date),
                    sessionCount: sessionCount
                ))
            }
        }

        return days.sorted { $0.date < $1.date }
    }

    func getPracticeCompletions(token: String) async throws -> [SessionCompletionDTO] {
        let today = Date()
        let calendar = Calendar.current

        return [-1, -2, -4].compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            return SessionCompletionDTO(completedAt: date)
        }
    }

    // MARK: - Video Submissions

    func createVideoSubmission(request: VideoSubmissionCreateRequest, token: String) async throws -> VideoSubmissionCreateResponse {
        let userId = getUserId(from: token)
        let submissionId = UUID()
        let submission = VideoSubmissionDTO(
            id: submissionId,
            userId: userId,
            exerciseId: request.exerciseId,
            pieceId: request.pieceId,
            sessionId: request.sessionId,
            s3Key: "cadenza/videos/\(userId)/\(submissionId.uuidString).mp4",
            thumbnailS3Key: "cadenza/videos/\(userId)/\(submissionId.uuidString)_thumb.jpg",
            durationSeconds: request.durationSeconds,
            notes: request.notes,
            reviewedAt: nil,
            reviewedById: nil,
            createdAt: Date()
        )

        videoSubmissions.append(submission)

        return VideoSubmissionCreateResponse(
            submission: submission,
            uploadUrl: "https://example.com/upload",
            thumbnailUploadUrl: "https://example.com/thumb-upload",
            expiresIn: 3600
        )
    }

    func getVideoSubmissionUploadUrl(submissionId: UUID, token: String) async throws -> VideoSubmissionUploadUrlsResponse {
        return VideoSubmissionUploadUrlsResponse(
            uploadUrl: "https://example.com/upload",
            thumbnailUploadUrl: "https://example.com/thumb-upload",
            expiresIn: 3600
        )
    }

    func getMyVideoSubmissions(pieceId: UUID?, exerciseId: UUID?, token: String) async throws -> [VideoSubmissionDTO] {
        let userId = getUserId(from: token)
        return videoSubmissions.filter { submission in
            guard submission.userId == userId else { return false }
            if let pieceId, submission.pieceId != pieceId { return false }
            if let exerciseId, submission.exerciseId != exerciseId { return false }
            return true
        }
    }

    func getStudentVideoSubmissions(studentId: Int, pieceId: UUID?, exerciseId: UUID?, pendingReviewOnly: Bool, token: String) async throws -> [VideoSubmissionDTO] {
        return videoSubmissions.filter { submission in
            guard submission.userId == studentId else { return false }
            if let pieceId, submission.pieceId != pieceId { return false }
            if let exerciseId, submission.exerciseId != exerciseId { return false }
            if pendingReviewOnly && submission.reviewedAt != nil { return false }
            return true
        }
    }

    func markVideoSubmissionReviewed(submissionId: UUID, token: String) async throws -> VideoSubmissionDTO {
        guard let index = videoSubmissions.firstIndex(where: { $0.id == submissionId }) else {
            throw APIError.notFound
        }

        let reviewerId = getUserId(from: token)
        let submission = videoSubmissions[index]
        let updated = VideoSubmissionDTO(
            id: submission.id,
            userId: submission.userId,
            exerciseId: submission.exerciseId,
            pieceId: submission.pieceId,
            sessionId: submission.sessionId,
            s3Key: submission.s3Key,
            thumbnailS3Key: submission.thumbnailS3Key,
            durationSeconds: submission.durationSeconds,
            notes: submission.notes,
            reviewedAt: Date(),
            reviewedById: reviewerId,
            createdAt: submission.createdAt
        )

        videoSubmissions[index] = updated
        return updated
    }

    func getVideoSubmissionVideoUrl(submissionId: UUID, token: String) async throws -> VideoSubmissionVideoUrlResponse {
        return VideoSubmissionVideoUrlResponse(
            videoUrl: "https://example.com/video",
            thumbnailUrl: "https://example.com/thumb",
            expiresIn: 3600
        )
    }

    // MARK: - Video Submission Messages

    func getMessages(submissionId: UUID, token: String) async throws -> [MessageDTO] {
        return messages.filter { $0.submissionId == submissionId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createMessage(submissionId: UUID, request: MessageCreateRequest, token: String) async throws -> MessageCreateResponse {
        let senderId = getUserId(from: token)
        let messageId = UUID()
        let includeVideo = request.includeVideo
        let message = MessageDTO(
            id: messageId,
            submissionId: submissionId,
            senderId: senderId,
            text: request.text,
            videoS3Key: includeVideo ? "cadenza/videos/\(senderId)/messages/\(messageId).mp4" : nil,
            videoDurationSeconds: request.videoDurationSeconds,
            thumbnailS3Key: includeVideo ? "cadenza/videos/\(senderId)/messages/\(messageId)_thumb.jpg" : nil,
            createdAt: Date()
        )

        messages.append(message)

        if includeVideo {
            return MessageCreateResponse(
                message: message,
                uploadUrl: "https://example.com/message-upload",
                thumbnailUploadUrl: "https://example.com/message-thumb-upload",
                expiresIn: 3600
            )
        }

        return MessageCreateResponse(message: message, uploadUrl: nil, thumbnailUploadUrl: nil, expiresIn: nil)
    }

    func getMessageVideoUrl(messageId: UUID, token: String) async throws -> MessageVideoUrlResponse {
        return MessageVideoUrlResponse(
            videoUrl: "https://example.com/message-video",
            thumbnailUrl: "https://example.com/message-thumb",
            expiresIn: 3600
        )
    }
}
#endif
