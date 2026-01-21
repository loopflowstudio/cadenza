import XCTest

/**
 UI tests for the home screen and navigation.
 */
@MainActor
final class HomeUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cadenza"].waitForExistence(timeout: 5))
    }

    func testCanNavigateToSheetMusic() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        // NavigationLinks appear as buttons - look for one containing "Sheet Music"
        let sheetMusicButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Sheet Music'")).element
        XCTAssertTrue(sheetMusicButton.waitForExistence(timeout: 5))

        sheetMusicButton.tap()
        XCTAssertTrue(app.navigationBars.containing(NSPredicate(format: "identifier CONTAINS[c] 'Sheet Music'")).element.waitForExistence(timeout: 2))
    }

    func testCanNavigateToTeacherStudents() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        // NavigationLinks appear as buttons - look for one containing "Teacher"
        let teacherStudentsButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Teacher'")).element
        XCTAssertTrue(teacherStudentsButton.waitForExistence(timeout: 5))

        teacherStudentsButton.tap()
        XCTAssertTrue(app.navigationBars.containing(NSPredicate(format: "identifier CONTAINS[c] 'Teacher'")).element.waitForExistence(timeout: 2))
    }
}
