import Foundation
import SwiftData

@Model
final class Routine: Identifiable {
    @Attribute(.unique) var id: UUID
    var ownerId: Int
    var title: String
    var routineDescription: String?
    var assignedById: Int?
    var assignedAt: Date?
    var sharedFromRoutineId: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID? = nil, ownerId: Int, title: String, routineDescription: String? = nil, assignedById: Int? = nil, assignedAt: Date? = nil, sharedFromRoutineId: UUID? = nil) {
        self.id = id ?? UUID()
        self.ownerId = ownerId
        self.title = title
        self.routineDescription = routineDescription
        self.assignedById = assignedById
        self.assignedAt = assignedAt
        self.sharedFromRoutineId = sharedFromRoutineId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Data Transfer Object

struct RoutineDTO: Codable, Identifiable {
    let id: UUID
    let ownerId: Int
    let title: String
    let description: String?
    let assignedById: Int?
    let assignedAt: Date?
    let sharedFromRoutineId: UUID?
    let createdAt: Date
    let updatedAt: Date
    var exercises: [ExerciseDTO] = []

    func toRoutine() -> Routine {
        Routine(
            id: id,
            ownerId: ownerId,
            title: title,
            routineDescription: description,
            assignedById: assignedById,
            assignedAt: assignedAt,
            sharedFromRoutineId: sharedFromRoutineId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, ownerId, title, description, assignedById, assignedAt, sharedFromRoutineId, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerId = try container.decode(Int.self, forKey: .ownerId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        assignedById = try container.decodeIfPresent(Int.self, forKey: .assignedById)
        assignedAt = try container.decodeIfPresent(Date.self, forKey: .assignedAt)
        sharedFromRoutineId = try container.decodeIfPresent(UUID.self, forKey: .sharedFromRoutineId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        exercises = []
    }

    init(id: UUID, ownerId: Int, title: String, description: String?, assignedById: Int? = nil, assignedAt: Date? = nil, sharedFromRoutineId: UUID? = nil, createdAt: Date, updatedAt: Date, exercises: [ExerciseDTO] = []) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.description = description
        self.assignedById = assignedById
        self.assignedAt = assignedAt
        self.sharedFromRoutineId = sharedFromRoutineId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exercises = exercises
    }
}

struct RoutineWithExercisesResponse: Codable {
    let routine: RoutineDTO
    let exercises: [ExerciseDTO]
}

struct RoutineAssignmentWithRoutineDTO: Codable, Identifiable {
    let id: UUID
    let studentId: Int
    let routineId: UUID
    let assignedById: Int
    let assignedAt: Date
    var routine: RoutineDTO

    init(id: UUID, studentId: Int, routineId: UUID, assignedById: Int, assignedAt: Date, routine: RoutineDTO) {
        self.id = id
        self.studentId = studentId
        self.routineId = routineId
        self.assignedById = assignedById
        self.assignedAt = assignedAt
        self.routine = routine
    }
}

struct CurrentRoutineResponse: Codable {
    let assignment: RoutineAssignmentDTO
    let routine: RoutineDTO
    let exercises: [ExerciseDTO]
}

struct AssignRoutineResponse: Codable {
    let message: String
    let routine: RoutineDTO
    let piecesShared: Int
}

extension Routine {
    convenience init(id: UUID, ownerId: Int, title: String, routineDescription: String?, assignedById: Int? = nil, assignedAt: Date? = nil, sharedFromRoutineId: UUID? = nil, createdAt: Date, updatedAt: Date) {
        self.init(id: id, ownerId: ownerId, title: title, routineDescription: routineDescription, assignedById: assignedById, assignedAt: assignedAt, sharedFromRoutineId: sharedFromRoutineId)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Sample Data

extension Routine {
    static var sampleRoutines: [Routine] {
        [
            Routine(ownerId: 1, title: "Morning Practice", routineDescription: "Daily warm-up routine"),
            Routine(ownerId: 1, title: "Bach Studies", routineDescription: "Focus on baroque technique")
        ]
    }
}
