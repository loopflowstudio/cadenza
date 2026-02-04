import Foundation

final class APIClient: APIClientProtocol, @unchecked Sendable {
    static let shared = APIClient()

    let baseURL: URL

    init(baseURL: String? = nil) {
        let urlString = baseURL ?? Self.defaultBaseURL()
        guard let url = URL(string: urlString) else {
            fatalError("Invalid base URL: \(urlString)")
        }
        self.baseURL = url
    }

    /// Determines the default base URL based on environment
    /// - Simulator: Uses localhost:8000 (simulator shares host network)
    /// - Device: Would use production URL or configurable endpoint
    private static func defaultBaseURL() -> String {
        #if DEBUG
        // Check if running on simulator vs device
        #if targetEnvironment(simulator)
        // Simulator can use localhost directly
        return "http://localhost:8000"
        #else
        // Physical device needs real IP or ngrok/tunnel
        // For now, fall back to localhost (won't work on device)
        // TODO: Configure with real server URL for device testing
        return "http://localhost:8000"
        #endif
        #else
        // Production build - use real server
        // TODO: Configure production server URL
        return "https://api.cadenza.app"
        #endif
    }

    // Use shared decoder/encoder for consistency with mock
    private var decoder: JSONDecoder { NetworkingConfig.decoder }
    private var encoder: JSONEncoder { NetworkingConfig.encoder }

    // MARK: - Auth

    func authenticateWithApple(idToken: String) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("/auth/apple")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["idToken": idToken]
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }

        return try decoder.decode(AuthResponse.self, from: data)
    }

    func getCurrentUser(token: String) async throws -> User {
        let url = baseURL.appendingPathComponent("/auth/me")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        return try decoder.decode(User.self, from: data)
    }

    #if DEBUG
    func devLogin(email: String) async throws -> AuthResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/auth/dev-login"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "email", value: email)]

        guard let url = components?.url else {
            throw APIError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(AuthResponse.self, from: data)
    }
    #endif

    // MARK: - Teacher/Student

    func getMyTeacher(token: String) async throws -> User? {
        let url = baseURL.appendingPathComponent("/users/my-teacher")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        if httpResponse.statusCode == 200 {
            if data.count <= 4 { return nil } // "null" response
            return try decoder.decode(User.self, from: data)
        }

        throw APIError.requestFailed
    }

    func getMyStudents(token: String) async throws -> [User] {
        let url = baseURL.appendingPathComponent("/users/my-students")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode([User].self, from: data)
    }

    func setTeacher(email: String, token: String) async throws -> User {
        var components = URLComponents(url: baseURL.appendingPathComponent("/users/set-teacher"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "teacher_email", value: email)]

        guard let url = components?.url else {
            throw APIError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        let resp = try decoder.decode(SetTeacherResponse.self, from: data)
        return resp.teacher
    }

    func removeTeacher(token: String) async throws {
        let url = baseURL.appendingPathComponent("/users/remove-teacher")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    // MARK: - Pieces

    func getPieces(token: String) async throws -> [PieceDTO] {
        let url = baseURL.appendingPathComponent("/pieces")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode([PieceDTO].self, from: data)
    }

    func createPiece(title: String, pdfData: Data, pdfFilename: String, token: String) async throws -> PieceDTO {
        let boundary = UUID().uuidString
        let url = baseURL.appendingPathComponent("/pieces")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(title)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf_file\"; filename=\"\(pdfFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(PieceDTO.self, from: data)
    }

    func updatePiece(id: UUID, title: String, token: String) async throws -> PieceDTO {
        var components = URLComponents(url: baseURL.appendingPathComponent("/pieces/\(id.uuidString)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "title", value: title)]

        guard let url = components?.url else {
            throw APIError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(PieceDTO.self, from: data)
    }

    func deletePiece(id: UUID, token: String) async throws {
        let url = baseURL.appendingPathComponent("/pieces/\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    func getStudentPieces(studentId: Int, token: String) async throws -> [PieceDTO] {
        let url = baseURL.appendingPathComponent("/students/\(studentId)/pieces")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode([PieceDTO].self, from: data)
    }

    func sharePiece(pieceId: UUID, studentId: Int, token: String) async throws -> PieceDTO {
        let url = baseURL.appendingPathComponent("/pieces/\(pieceId.uuidString)/share/\(studentId)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(PieceDTO.self, from: data)
    }

    func getPieceDownloadUrl(pieceId: UUID, token: String) async throws -> PieceDownloadUrlResponse {
        let url = baseURL.appendingPathComponent("/pieces/\(pieceId.uuidString)/download-url")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(PieceDownloadUrlResponse.self, from: data)
    }

    // MARK: - Routines

    func getRoutines(token: String) async throws -> [RoutineDTO] {
        let url = baseURL.appendingPathComponent("/routines")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode([RoutineDTO].self, from: data)
    }

    func createRoutine(title: String, description: String?, token: String) async throws -> RoutineDTO {
        let url = baseURL.appendingPathComponent("/routines")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any?] = ["title": title, "description": description]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(RoutineDTO.self, from: data)
    }

    func getRoutine(id: UUID, token: String) async throws -> RoutineDTO {
        let url = baseURL.appendingPathComponent("/routines/\(id.uuidString)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        let result = try decoder.decode(RoutineWithExercisesResponse.self, from: data)
        var routine = result.routine
        routine.exercises = result.exercises
        return routine
    }

    func deleteRoutine(id: UUID, token: String) async throws {
        let url = baseURL.appendingPathComponent("/routines/\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    func getMyAssignments(token: String) async throws -> [RoutineAssignmentWithRoutineDTO] {
        let url = baseURL.appendingPathComponent("/my-current-routine")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        if httpResponse.statusCode == 200 {
            if data.count <= 4 { return [] } // "null" response
            let result = try decoder.decode(CurrentRoutineResponse.self, from: data)
            var routine = result.routine
            routine.exercises = result.exercises
            let assignment = RoutineAssignmentWithRoutineDTO(
                id: result.assignment.id,
                studentId: result.assignment.studentId,
                routineId: result.assignment.routineId,
                assignedById: result.assignment.assignedById,
                assignedAt: result.assignment.assignedAt,
                routine: routine
            )
            return [assignment]
        }

        throw APIError.requestFailed
    }

    func addExerciseToRoutine(routineId: UUID, pieceId: UUID, orderIndex: Int, recommendedTimeSeconds: Int?, intentions: String?, startPage: Int?, token: String) async throws -> ExerciseDTO {
        let url = baseURL.appendingPathComponent("/routines/\(routineId.uuidString)/exercises")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "piece_id": pieceId.uuidString,
            "order_index": orderIndex
        ]
        if let time = recommendedTimeSeconds {
            body["recommended_time_seconds"] = time
        }
        if let text = intentions {
            body["intentions"] = text
        }
        if let page = startPage {
            body["start_page"] = page
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(ExerciseDTO.self, from: data)
    }

    func assignRoutineToStudent(studentId: Int, routineId: UUID, token: String) async throws -> AssignRoutineResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/students/\(studentId)/assign-routine"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "routine_id", value: routineId.uuidString)]

        guard let url = components?.url else {
            throw APIError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(AssignRoutineResponse.self, from: data)
    }

    // MARK: - Practice Sessions

    func startPracticeSession(routineId: UUID, token: String) async throws -> PracticeSessionDTO {
        var components = URLComponents(url: baseURL.appendingPathComponent("/sessions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "routine_id", value: routineId.uuidString)]

        guard let url = components?.url else {
            throw APIError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(PracticeSessionDTO.self, from: data)
    }

    func completePracticeSession(sessionId: UUID, token: String) async throws -> PracticeSessionDTO {
        let url = baseURL.appendingPathComponent("/sessions/\(sessionId.uuidString)/complete")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(PracticeSessionDTO.self, from: data)
    }

    func completeExerciseInSession(sessionId: UUID, exerciseId: UUID, actualTimeSeconds: Int?, reflections: String?, token: String) async throws -> ExerciseSessionDTO {
        let url = baseURL.appendingPathComponent("/sessions/\(sessionId.uuidString)/exercises/\(exerciseId.uuidString)/complete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if let time = actualTimeSeconds {
            body["actual_time_seconds"] = time
        }
        if let text = reflections {
            body["reflections"] = text
        }

        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(ExerciseSessionDTO.self, from: data)
    }

    func updateExerciseCompletion(sessionId: UUID, exerciseId: UUID, isComplete: Bool, actualTimeSeconds: Int?, reflections: String?, token: String) async throws -> ExerciseSessionDTO {
        let url = baseURL.appendingPathComponent("/sessions/\(sessionId.uuidString)/exercises/\(exerciseId.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["is_complete": isComplete]
        if let time = actualTimeSeconds {
            body["actual_time_seconds"] = time
        }
        if let text = reflections {
            body["reflections"] = text
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode(ExerciseSessionDTO.self, from: data)
    }

    func getPracticeCalendar(token: String) async throws -> [CalendarDayDTO] {
        let url = baseURL.appendingPathComponent("/sessions/calendar")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode([CalendarDayDTO].self, from: data)
    }

    func getPracticeCompletions(token: String) async throws -> [SessionCompletionDTO] {
        let url = baseURL.appendingPathComponent("/sessions/completions")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try decoder.decode([SessionCompletionDTO].self, from: data)
    }
}

struct SetTeacherResponse: Codable {
    let message: String
    let teacher: User
}
