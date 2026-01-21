import Foundation
import SwiftData

@Model
final class PracticeSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var userId: Int
    var routineId: UUID
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int?

    init(id: UUID? = nil, userId: Int, routineId: UUID, startedAt: Date? = nil, completedAt: Date? = nil, durationSeconds: Int? = nil) {
        self.id = id ?? UUID()
        self.userId = userId
        self.routineId = routineId
        self.startedAt = startedAt ?? Date()
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Data Transfer Object

struct PracticeSessionDTO: Codable {
    let id: UUID
    let userId: Int
    let routineId: UUID
    let startedAt: Date
    let completedAt: Date?
    let durationSeconds: Int?

    func toPracticeSession() -> PracticeSession {
        PracticeSession(
            id: id,
            userId: userId,
            routineId: routineId,
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: durationSeconds
        )
    }
}

// MARK: - Helper Properties

extension PracticeSession {
    var isCompleted: Bool {
        completedAt != nil
    }

    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "—" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Calendar Day DTO

struct CalendarDayDTO: Codable, Identifiable {
    let date: String  // YYYY-MM-DD
    let sessionCount: Int

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case sessionCount = "session_count"
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dateValue: Date? {
        Self.dateFormatter.date(from: date)
    }

    static func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

// MARK: - Session Completion DTO

struct SessionCompletionDTO: Codable, Identifiable {
    let completedAt: Date

    var id: Date { completedAt }

    enum CodingKeys: String, CodingKey {
        case completedAt = "completed_at"
    }
}
