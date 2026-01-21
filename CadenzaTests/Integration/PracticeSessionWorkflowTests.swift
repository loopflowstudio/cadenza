import XCTest
@testable import Cadenza

@MainActor
final class PracticeSessionWorkflowTests: XCTestCase {

    func testCompletePracticeSessionFlow() async throws {
        let mockAPI = MockAPIClientImpl.shared
        let token = "dev_token_user_1"

        let routines = try await mockAPI.getRoutines(token: token)
        XCTAssertGreaterThan(routines.count, 0)
        let routine = routines.first!
        XCTAssertGreaterThan(routine.exercises.count, 0)

        let session = try await mockAPI.startPracticeSession(
            routineId: routine.id,
            token: token
        )

        XCTAssertEqual(session.routineId, routine.id)
        XCTAssertNil(session.completedAt)

        for exercise in routine.exercises {
            let exerciseSession = try await mockAPI.completeExerciseInSession(
                sessionId: session.id,
                exerciseId: exercise.id,
                actualTimeSeconds: 300,
                reflections: "Good practice",
                token: token
            )

            XCTAssertEqual(exerciseSession.exerciseId, exercise.id)
            XCTAssertEqual(exerciseSession.actualTimeSeconds, 300)
        }

        let completedSession = try await mockAPI.completePracticeSession(
            sessionId: session.id,
            token: token
        )

        XCTAssertNotNil(completedSession.completedAt)
        XCTAssertNotNil(completedSession.durationSeconds)
    }

    func testPracticeSessionTracksTime() async throws {
        let mockAPI = MockAPIClientImpl.shared
        let token = "dev_token_user_1"
        let routines = try await mockAPI.getRoutines(token: token)
        let routine = routines.first!

        let session = try await mockAPI.startPracticeSession(
            routineId: routine.id,
            token: token
        )

        try await Task.sleep(nanoseconds: 100_000_000)

        let completedSession = try await mockAPI.completePracticeSession(
            sessionId: session.id,
            token: token
        )

        XCTAssertNotNil(completedSession.durationSeconds)
        if let duration = completedSession.durationSeconds {
            XCTAssertGreaterThan(duration, 0)
        }
    }
}
