# User Research Simulation

**What to build**: A system that simulates different user personas navigating the app, captures screenshots at each step, and feeds them to Claude for UX analysis.

## Personas

Three personas, each with distinct data and goals:

```swift
enum Persona: String, CaseIterable {
    case teacher      // Has students, creates routines, assigns work
    case student      // Has teacher, receives assignments, practices
    case selfTaught   // No teacher, manages own routines
}

struct PersonaConfig {
    let persona: Persona
    let userId: Int
    let token: String
    let seedData: PersonaSeedData
}

struct PersonaSeedData {
    let pieces: [PieceDTO]
    let routines: [RoutineDTO]
    let hasTeacher: Bool
    let students: [User]?
}
```

Mock data per persona:

| Persona | User ID | Has pieces | Has routines | Has teacher | Has students |
|---------|---------|------------|--------------|-------------|--------------|
| teacher | 1 | 3 | 1 | no | 2 |
| student | 2 | 0 | 1 (assigned) | yes (id=1) | no |
| selfTaught | 4 | 1 | 0 | no | no |

## Scenarios

Each scenario is a named sequence of navigation steps:

```swift
struct Scenario {
    let name: String
    let persona: Persona
    let steps: [ScenarioStep]
}

enum ScenarioStep {
    case launch
    case navigate(to: String)  // accessibility identifier
    case tap(element: String)
    case wait(seconds: Double)
    case screenshot(name: String)
}
```

Example scenarios:

```swift
let scenarios = [
    Scenario(
        name: "teacher-assigns-routine",
        persona: .teacher,
        steps: [
            .launch,
            .screenshot(name: "home"),
            .navigate(to: "nav-teacher-students"),
            .screenshot(name: "students-list"),
            .tap(element: "student-row-2"),
            .screenshot(name: "student-detail"),
            .tap(element: "assign-routine-button"),
            .screenshot(name: "assign-sheet")
        ]
    ),
    Scenario(
        name: "student-starts-practice",
        persona: .student,
        steps: [
            .launch,
            .screenshot(name: "home"),
            .navigate(to: "nav-practice"),
            .screenshot(name: "routines"),
            .tap(element: "start-practice-button"),
            .screenshot(name: "practice-session")
        ]
    ),
    Scenario(
        name: "self-taught-creates-routine",
        persona: .selfTaught,
        steps: [
            .launch,
            .screenshot(name: "home"),
            .navigate(to: "nav-practice"),
            .screenshot(name: "empty-routines"),
            .tap(element: "create-routine-button"),
            .screenshot(name: "create-routine-sheet")
        ]
    )
]
```

## Screenshot Pipeline

Reuse the loopflow pattern: XCTest harness → environment config → NSView capture.

```swift
// CadenzaUITests/ScreenshotPipelineTests.swift
@MainActor
final class ScreenshotPipelineTests: XCTestCase {

    func testCaptureScenario() throws {
        let env = ProcessInfo.processInfo.environment
        let scenarioName = env["CADENZA_SCENARIO"] ?? "teacher-assigns-routine"
        let outputDir = env["CADENZA_OUTPUT_DIR"] ?? NSTemporaryDirectory()

        let app = XCUIApplication()
        app.launchArguments += ["--mock-api", "--scenario", scenarioName]
        app.launch()

        let scenario = Scenarios.find(named: scenarioName)
        for step in scenario.steps {
            execute(step, in: app, outputDir: outputDir)
        }
    }

    private func execute(_ step: ScenarioStep, in app: XCUIApplication, outputDir: String) {
        switch step {
        case .launch:
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        case .navigate(let id):
            app.buttons[id].firstMatch.tap()
        case .tap(let id):
            app.buttons[id].firstMatch.tap()
        case .wait(let seconds):
            Thread.sleep(forTimeInterval: seconds)
        case .screenshot(let name):
            let screenshot = XCUIScreen.main.screenshot()
            let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
```

## CLI Runner

Python script orchestrates the process:

```python
# dev.py additions

def cmd_research(args):
    """Run simulated user research"""
    scenarios = args.scenarios or ["all"]
    output_dir = Path("scratch/research") / datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir.mkdir(parents=True, exist_ok=True)

    for scenario in get_scenarios(scenarios):
        run_scenario(scenario, output_dir)

    # After all screenshots captured, analyze
    analyze_screenshots(output_dir)

def run_scenario(scenario: str, output_dir: Path):
    scenario_dir = output_dir / scenario
    scenario_dir.mkdir(exist_ok=True)

    subprocess.run([
        "xcodebuild", "test",
        "-project", "Cadenza.xcodeproj",
        "-scheme", "CadenzaUITests",
        "-destination", "platform=iOS Simulator,name=iPhone 15",
        "-only-testing:CadenzaUITests/ScreenshotPipelineTests/testCaptureScenario",
    ], env={
        **os.environ,
        "CADENZA_SCENARIO": scenario,
        "CADENZA_OUTPUT_DIR": str(scenario_dir),
    })

def analyze_screenshots(output_dir: Path):
    """Feed screenshots to Claude for UX analysis"""
    # Collect all PNGs
    screenshots = list(output_dir.rglob("*.png"))

    # Build prompt with images
    prompt = build_analysis_prompt(screenshots)

    # Call Claude API with vision
    response = anthropic.messages.create(
        model="claude-sonnet-4-20250514",
        messages=[{"role": "user", "content": prompt}],
    )

    # Write report
    (output_dir / "analysis.md").write_text(response.content[0].text)
```

## Analysis Prompt

The prompt should focus on UX issues, not technical bugs:

```
You are reviewing screenshots from a music practice app used by:
- Teachers: assign routines to students, track progress
- Students: practice assigned routines, view sheet music
- Self-taught: manage their own learning

For each screenshot sequence, identify:
1. Confusing UI elements or unclear affordances
2. Missing information a user would need
3. Friction points in the workflow
4. What works well

Be specific. Reference exact UI elements visible in the screenshots.
```

## Constraints

- **iOS only**: No macOS. Use XCUITest, not NSView snapshotting.
- **Simulator**: Screenshots from iOS Simulator, not device.
- **Mock data**: All scenarios use `--mock-api`. No network calls.
- **No auth flow**: Skip sign-in; mock starts authenticated.

## Done When

```bash
python dev.py research --scenarios teacher-assigns-routine
```

Produces:
1. `scratch/research/<timestamp>/teacher-assigns-routine/*.png` - screenshots
2. `scratch/research/<timestamp>/analysis.md` - Claude's UX analysis

The analysis identifies at least one actionable UX improvement.
