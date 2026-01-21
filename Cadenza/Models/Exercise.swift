import Foundation
import SwiftData

@Model
final class Exercise: Identifiable {
    @Attribute(.unique) var id: UUID
    var routineId: UUID
    var pieceId: UUID
    var orderIndex: Int
    var recommendedTimeSeconds: Int?
    var intentions: String?
    var startPage: Int?

    init(id: UUID? = nil, routineId: UUID, pieceId: UUID, orderIndex: Int, recommendedTimeSeconds: Int? = nil, intentions: String? = nil, startPage: Int? = nil) {
        self.id = id ?? UUID()
        self.routineId = routineId
        self.pieceId = pieceId
        self.orderIndex = orderIndex
        self.recommendedTimeSeconds = recommendedTimeSeconds
        self.intentions = intentions
        self.startPage = startPage
    }
}

// MARK: - Data Transfer Object

struct ExerciseDTO: Codable {
    let id: UUID
    let routineId: UUID
    let pieceId: UUID
    let orderIndex: Int
    let recommendedTimeSeconds: Int?
    let intentions: String?
    let startPage: Int?

    func toExercise() -> Exercise {
        Exercise(
            id: id,
            routineId: routineId,
            pieceId: pieceId,
            orderIndex: orderIndex,
            recommendedTimeSeconds: recommendedTimeSeconds,
            intentions: intentions,
            startPage: startPage
        )
    }
}

// MARK: - Sample Data

extension Exercise {
    static var sampleExercises: [Exercise] {
        [
            Exercise(routineId: UUID(), pieceId: UUID(), orderIndex: 0, recommendedTimeSeconds: 300, intentions: "Focus on tone quality"),
            Exercise(routineId: UUID(), pieceId: UUID(), orderIndex: 1, recommendedTimeSeconds: 600, intentions: "Work on dynamics")
        ]
    }
}
