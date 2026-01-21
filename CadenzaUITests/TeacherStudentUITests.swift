import XCTest

/// UI tests for teacher/student relationship workflows.
/// Focus: Can a teacher navigate to see their students and share music with them?
@MainActor
final class TeacherStudentUITests: XCTestCase {
    func testTeacherCanSeeTheirStudents() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        // Navigate to teacher/student view
        let teacherButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Teacher'")).element
        XCTAssertTrue(teacherButton.waitForExistence(timeout: 5))
        teacherButton.tap()

        // Teacher (user 1) should see their students
        // Mock data has 2 students assigned to teacher
        let cells = app.cells
        XCTAssertTrue(cells.element(boundBy: 0).waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(cells.count, 2, "Teacher should see their students")
    }

    func testTeacherCanNavigateToStudentAndShare() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        let teacherButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Teacher'")).element
        teacherButton.tap()

        // Tap a student
        let firstStudent = app.cells.firstMatch
        XCTAssertTrue(firstStudent.waitForExistence(timeout: 3))
        firstStudent.tap()

        // Should be able to share music with this student
        // The share action should be accessible (button in toolbar or action)
        let hasShareCapability = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Share'")).element.exists ||
                                  app.images["square.and.arrow.up"].exists
        XCTAssertTrue(hasShareCapability, "Should be able to share music with student")
    }
}
