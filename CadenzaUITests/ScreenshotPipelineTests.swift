import XCTest

/// Config for research screenshots, written by dev.py
struct ResearchConfig: Codable {
    let scenario: String
    let outputDir: String
}

/// Automated screenshot capture for UX research.
/// Config is read from /tmp/cadenza-research-config.json
@MainActor
final class ScreenshotPipelineTests: XCTestCase {

    func testCaptureScenario() throws {
        // Read config from file (written by dev.py research command)
        let configURL = URL(fileURLWithPath: "/tmp/cadenza-research-config.json")
        let config = try? JSONDecoder().decode(ResearchConfig.self, from: Data(contentsOf: configURL))

        let scenarioName = config?.scenario ?? "teacher-assigns-routine"
        let outputDir = config?.outputDir ?? NSTemporaryDirectory()

        let scenario = Scenarios.find(named: scenarioName)
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api", "--scenario", scenarioName]
        app.launch()

        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(2) // Let UI stabilize

        var stepIndex = 0
        for step in scenario.steps {
            execute(step, in: app, outputDir: outputDir, index: &stepIndex)
        }
    }

    private func execute(
        _ step: ScenarioStep,
        in app: XCUIApplication,
        outputDir: String,
        index: inout Int
    ) {
        switch step {
        case .wait(let seconds):
            Thread.sleep(forTimeInterval: seconds)

        case .navigate(let identifier):
            let element = app.buttons[identifier]
            if element.waitForExistence(timeout: 5) {
                element.tap()
                sleep(1)
            }

        case .tap(let identifier):
            let element = app.buttons[identifier]
            if element.waitForExistence(timeout: 5) {
                element.tap()
                sleep(1)
            }

        case .screenshot(let name):
            let screenshot = XCUIScreen.main.screenshot()
            let filename = String(format: "%02d-%@.png", index, name)
            let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
            do {
                try screenshot.pngRepresentation.write(to: url)
                index += 1
            } catch {
                XCTFail("Failed to write screenshot: \(error)")
            }
        }
    }
}

// MARK: - Scenario Definitions

enum ScenarioStep {
    case wait(seconds: Double)
    case navigate(to: String)
    case tap(element: String)
    case screenshot(name: String)
}

struct Scenario {
    let name: String
    let steps: [ScenarioStep]
}

enum Scenarios {
    static func find(named name: String) -> Scenario {
        switch name {
        case "teacher-assigns-routine":
            return teacherAssignsRoutine
        case "student-starts-practice":
            return studentStartsPractice
        case "self-taught-creates-routine":
            return selfTaughtCreatesRoutine
        default:
            return teacherAssignsRoutine
        }
    }

    static let teacherAssignsRoutine = Scenario(
        name: "teacher-assigns-routine",
        steps: [
            .screenshot(name: "home"),
            .navigate(to: "nav-teacher-students"),
            .wait(seconds: 1),
            .screenshot(name: "students-list"),
            .tap(element: "student-2"),
            .wait(seconds: 1),
            .screenshot(name: "student-detail"),
        ]
    )

    static let studentStartsPractice = Scenario(
        name: "student-starts-practice",
        steps: [
            .screenshot(name: "home"),
            .navigate(to: "nav-practice"),
            .wait(seconds: 1),
            .screenshot(name: "routines"),
        ]
    )

    static let selfTaughtCreatesRoutine = Scenario(
        name: "self-taught-creates-routine",
        steps: [
            .screenshot(name: "home"),
            .navigate(to: "nav-practice"),
            .wait(seconds: 1),
            .screenshot(name: "routines-empty"),
        ]
    )
}
