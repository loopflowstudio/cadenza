import XCTest

// MARK: - App Entry Point

@MainActor
struct CadenzaApp {
    let app: XCUIApplication

    init() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
    }

    func launch() -> HomePage {
        app.launch()
        return HomePage(app: app)
    }
}

// MARK: - Home Page

@MainActor
struct HomePage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.staticTexts["Cadenza"].waitForExistence(timeout: 5))
        return self
    }

    func goToPractice() -> PracticeListPage {
        app.buttons["nav-practice"].tap()
        return PracticeListPage(app: app)
    }

    func goToSheetMusic() -> SheetMusicPage {
        app.buttons["nav-sheet-music"].tap()
        return SheetMusicPage(app: app)
    }

    func goToTeacherStudents() -> TeacherStudentPage {
        app.buttons["nav-teacher-students"].tap()
        return TeacherStudentPage(app: app)
    }
}

// MARK: - Practice List Page

@MainActor
struct PracticeListPage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: 3))
        return self
    }

    func hasRoutine(named name: String) -> Bool {
        app.staticTexts[name].waitForExistence(timeout: 3)
    }

    func startPractice(routineId: UUID) -> PracticeSessionPage {
        let routineElement = app.buttons["routine-\(routineId.uuidString)"]
        XCTAssertTrue(routineElement.waitForExistence(timeout: 3))

        routineElement.swipeLeft()

        let practiceButton = app.buttons["practice-routine-\(routineId.uuidString)"]
        XCTAssertTrue(practiceButton.waitForExistence(timeout: 2))
        practiceButton.tap()

        return PracticeSessionPage(app: app)
    }

    func openRoutineDetails(routineId: UUID) -> RoutineDetailPage {
        let routineElement = app.buttons["routine-\(routineId.uuidString)"]
        XCTAssertTrue(routineElement.waitForExistence(timeout: 3))
        routineElement.tap()
        return RoutineDetailPage(app: app)
    }
}

// MARK: - Practice Session Page

@MainActor
struct PracticeSessionPage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.buttons["practice-session-done"].waitForExistence(timeout: 5))
        return self
    }

    func hasExerciseIndicator() -> Bool {
        app.navigationBars.element.identifier.contains("Exercise") ||
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Exercise'")).count > 0
    }

    @discardableResult
    func addReflection(text: String) -> Self {
        app.buttons["practice-session-add-reflection"].tap()

        XCTAssertTrue(app.navigationBars["Reflections"].waitForExistence(timeout: 2))

        let textEditor = app.textViews.firstMatch
        textEditor.tap()
        textEditor.typeText(text)

        app.buttons["Save"].tap()
        return self
    }

    func finish() -> PracticeListPage {
        while !app.buttons["Finish"].waitForExistence(timeout: 1) {
            let nextButton = app.buttons["chevron.right"].firstMatch
            if nextButton.exists && nextButton.isEnabled {
                nextButton.tap()
                sleep(1)
            } else {
                break
            }
        }

        if app.buttons["Finish"].exists {
            app.buttons["Finish"].tap()
        }

        return PracticeListPage(app: app)
    }

    func cancel() -> PracticeListPage {
        app.buttons["practice-session-done"].tap()
        return PracticeListPage(app: app)
    }
}

// MARK: - Sheet Music Page

@MainActor
struct SheetMusicPage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.navigationBars["Sheet Music"].waitForExistence(timeout: 3))
        return self
    }

    func hasPieces() -> Bool {
        app.cells.count > 0
    }

    func pieceCount() -> Int {
        app.cells.count
    }
}

// MARK: - Teacher Student Page

@MainActor
struct TeacherStudentPage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(
            app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Teacher'"))
                .element.waitForExistence(timeout: 3)
        )
        return self
    }

    func studentCount() -> Int {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'student-'")).count
    }

    func openStudent(id: Int) -> StudentDetailPage {
        app.buttons["student-\(id)"].tap()
        return StudentDetailPage(app: app)
    }
}

// MARK: - Student Detail Page

@MainActor
struct StudentDetailPage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.navigationBars["Student Details"].waitForExistence(timeout: 3))
        return self
    }

    func openAssignRoutineSheet() -> AssignRoutineSheet {
        app.buttons["ellipsis.circle"].tap()
        app.buttons["Assign Routine"].tap()
        return AssignRoutineSheet(app: app)
    }
}

// MARK: - Assign Routine Sheet

@MainActor
struct AssignRoutineSheet {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.navigationBars["Assign Routine"].waitForExistence(timeout: 2))
        return self
    }

    @discardableResult
    func selectRoutine(named name: String) -> Self {
        app.staticTexts[name].tap()
        return self
    }

    func assign() -> StudentDetailPage {
        let assignButton = app.buttons["Assign"]
        XCTAssertTrue(assignButton.isEnabled)
        assignButton.tap()

        sleep(2)

        return StudentDetailPage(app: app)
    }

    func cancel() -> StudentDetailPage {
        app.buttons["Cancel"].tap()
        return StudentDetailPage(app: app)
    }
}

// MARK: - Routine Detail Page

@MainActor
struct RoutineDetailPage {
    let app: XCUIApplication

    @discardableResult
    func waitForLoad() -> Self {
        XCTAssertTrue(app.staticTexts["Exercises"].waitForExistence(timeout: 3))
        return self
    }

    func exerciseCount() -> Int {
        app.cells.count
    }

    func hasExercise(pieceName: String) -> Bool {
        app.staticTexts[pieceName].exists
    }
}
