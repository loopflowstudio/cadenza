import XCTest

/// UI tests for piece management workflows.
/// Focus: Can users view, add, and manage their sheet music?
@MainActor
final class PieceManagementUITests: XCTestCase {

    func testUserCanViewTheirPieces() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        let sheetMusicButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Sheet Music'")).element
        XCTAssertTrue(sheetMusicButton.waitForExistence(timeout: 5))
        sheetMusicButton.tap()

        // User 1 (teacher) has 3 pieces in mock data
        let cells = app.cells
        XCTAssertTrue(cells.element(boundBy: 0).waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(cells.count, 1, "User should see their pieces")
    }

    func testUserCanDeletePiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        let sheetMusicButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Sheet Music'")).element
        sheetMusicButton.tap()

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3))

        // Standard iOS delete gesture
        firstCell.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "Should be able to delete pieces")
    }

    func testUserCanOpenPiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        let sheetMusicButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Sheet Music'")).element
        sheetMusicButton.tap()

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3))
        let initialCellCount = app.cells.count
        firstCell.tap()

        // Should navigate away from list (either modal or push navigation)
        // Check that we're no longer on the list view by waiting for navigation change
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count != %d", initialCellCount),
            object: app.cells
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 3)

        // Either navigation happened or we're viewing something else
        let hasNavigated = result == .completed || app.navigationBars.count > 1
        XCTAssertTrue(hasNavigated, "Tapping a piece should open it")
    }
}
