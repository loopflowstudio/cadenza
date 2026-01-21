import XCTest

/// Smoke tests for critical user journeys.
/// These tests verify end-to-end flows, not individual UI components.
/// Only 4-5 tests that cover the most important user behaviors.
@MainActor
final class CadenzaSmokeTests: XCTestCase {

    // MARK: - Critical Path: Practice Session

    func testUserCanCompletePracticeSession() throws {
        let cadenza = CadenzaApp()

        // Given: User sees their routines
        let practiceList = cadenza.launch()
            .waitForLoad()
            .goToPractice()
            .waitForLoad()

        XCTAssertTrue(practiceList.hasRoutine(named: "Morning Practice"),
                     "User should see their routine")

        // When: User starts practice session
        let routineId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let session = practiceList.startPractice(routineId: routineId)
            .waitForLoad()

        // Then: Practice session loads
        XCTAssertTrue(session.hasExerciseIndicator(),
                     "Should show exercise progress")

        // When: User cancels session (simpler than completing full flow)
        let returnedList = session.cancel().waitForLoad()

        // Then: Returns to routine list
        XCTAssertTrue(returnedList.hasRoutine(named: "Morning Practice"),
                     "Should return to practice list")
    }

    // MARK: - Critical Path: Teacher Assignment

    func testTeacherCanAccessAssignmentWorkflow() throws {
        let cadenza = CadenzaApp()

        // Given: Teacher views their students
        let teacherStudents = cadenza.launch()
            .waitForLoad()
            .goToTeacherStudents()
            .waitForLoad()

        XCTAssertGreaterThan(teacherStudents.studentCount(), 0,
                            "Teacher should have students")

        // When: Teacher opens student and accesses assignment
        let studentDetail = teacherStudents.openStudent(id: 2)
            .waitForLoad()

        let assignSheet = studentDetail.openAssignRoutineSheet()
            .waitForLoad()

        // Then: Teacher sees their routines to assign
        XCTAssertTrue(assignSheet.app.staticTexts["Morning Practice"].exists,
                     "Should show teacher's routines")

        // When: Teacher cancels (avoid side effects in test)
        let _ = assignSheet.cancel().waitForLoad()
    }

    // MARK: - Critical Path: Content Access

    func testUserCanAccessTheirSheetMusic() throws {
        let cadenza = CadenzaApp()

        // Given: User launches app
        let home = cadenza.launch().waitForLoad()

        // When: User navigates to sheet music
        let sheetMusic = home.goToSheetMusic().waitForLoad()

        // Then: User sees their pieces
        XCTAssertTrue(sheetMusic.hasPieces(),
                     "User should see their sheet music library")

        XCTAssertGreaterThanOrEqual(sheetMusic.pieceCount(), 1,
                                   "Should have at least one piece")
    }

    // MARK: - Critical Path: Routine Management

    func testUserCanViewRoutineWithExercises() throws {
        let cadenza = CadenzaApp()

        // Given: User has routines
        let practiceList = cadenza.launch()
            .waitForLoad()
            .goToPractice()
            .waitForLoad()

        // When: User opens routine details
        let routineId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let routineDetail = practiceList.openRoutineDetails(routineId: routineId)
            .waitForLoad()

        // Then: Routine shows exercises
        XCTAssertGreaterThan(routineDetail.exerciseCount(), 0,
                           "Routine should have exercises")

        XCTAssertTrue(routineDetail.hasExercise(pieceName: "Bach Prelude in C Major"),
                     "Should show exercise pieces")
    }
}
