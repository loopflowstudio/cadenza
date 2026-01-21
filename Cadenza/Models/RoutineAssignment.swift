import Foundation
import SwiftData

@Model
final class RoutineAssignment: Identifiable {
    @Attribute(.unique) var id: UUID
    var studentId: Int
    var routineId: UUID
    var assignedById: Int
    var assignedAt: Date

    init(id: UUID? = nil, studentId: Int, routineId: UUID, assignedById: Int, assignedAt: Date? = nil) {
        self.id = id ?? UUID()
        self.studentId = studentId
        self.routineId = routineId
        self.assignedById = assignedById
        self.assignedAt = assignedAt ?? Date()
    }
}

// MARK: - Data Transfer Object

struct RoutineAssignmentDTO: Codable {
    let id: UUID
    let studentId: Int
    let routineId: UUID
    let assignedById: Int
    let assignedAt: Date

    func toRoutineAssignment() -> RoutineAssignment {
        RoutineAssignment(
            id: id,
            studentId: studentId,
            routineId: routineId,
            assignedById: assignedById,
            assignedAt: assignedAt
        )
    }
}
