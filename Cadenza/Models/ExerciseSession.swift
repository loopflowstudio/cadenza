import Foundation
import SwiftData

@Model
final class ExerciseSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var exerciseId: UUID
    var completedAt: Date?
    var actualTimeSeconds: Int?
    var reflections: String?

    init(id: UUID? = nil, sessionId: UUID, exerciseId: UUID, completedAt: Date? = nil, actualTimeSeconds: Int? = nil, reflections: String? = nil) {
        self.id = id ?? UUID()
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.completedAt = completedAt
        self.actualTimeSeconds = actualTimeSeconds
        self.reflections = reflections
    }
}

// MARK: - Data Transfer Object

struct ExerciseSessionDTO: Codable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let completedAt: Date?
    let actualTimeSeconds: Int?
    let reflections: String?

    func toExerciseSession() -> ExerciseSession {
        ExerciseSession(
            id: id,
            sessionId: sessionId,
            exerciseId: exerciseId,
            completedAt: completedAt,
            actualTimeSeconds: actualTimeSeconds,
            reflections: reflections
        )
    }
}

// MARK: - Helper Properties

extension ExerciseSession {
    var formattedTime: String {
        guard let seconds = actualTimeSeconds else { return "—" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
