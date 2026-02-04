# upandrun: Local Dev & Dogfooding Infrastructure

## What Was Built

Scripts and config to run the full Cadenza stack locally (server + iOS simulator) without Xcode IDE, with branch-isolated databases and seed data for dogfooding.

## Commands

```bash
python dev.py generate                    # Generate Xcode project from project.yml
python dev.py server                      # Start postgres + uvicorn (branch-isolated port)
python dev.py simulator                   # Build and launch iOS
python dev.py simulator --build-only      # Build without launching
python dev.py reset --scenario teacher-with-students  # Reset DB and seed
python dev.py seed --list                 # List available scenarios
python dev.py research --scenarios foo    # Capture screenshots + Claude analysis
```

## Branch Isolation

Each git branch gets its own:
- **DB port**: derived from branch name (5433-5532 range)
- **Docker containers**: isolated via `COMPOSE_PROJECT_NAME`
- **Volumes**: separate postgres data per branch

This allows multiple coding agents to work on different worktrees in parallel without port conflicts.

## Bundled PDFs

Set `CADENZA_BUNDLES` to a directory of PDFs (can be nested). They sync to the app on build:

```bash
export CADENZA_BUNDLES=~/Music/SheetMusic
python dev.py simulator
```

PDFs are copied to `Cadenza/Resources/Bundles/` (gitignored). Works across worktrees since they all read from the same source.

## Seed Scenarios

### `empty`
- Fresh database, no data

### `teacher-with-students`
- teacher@example.com (id=1)
- student1@example.com, student2@example.com (linked to teacher)
- 3 pieces from bundled PDFs
- 1 routine with 2 exercises
- Student1 has routine assigned

### `student-with-assignment`
- student1@example.com with assigned routine
- 3 exercises
- 2 completed practice sessions
- 1 in-progress session

## UX Research

```bash
python dev.py research --scenarios teacher-assigns-routine
```

1. Runs XCUITest scenarios
2. Captures screenshots to `scratch/research/<timestamp>/`
3. Sends to Claude for UX analysis
4. Writes `analysis.md` to same directory

Curate findings manually into `roadmap/ux/`.

## Files Created

- `project.yml` — xcodegen config
- `server/seed_scenario.py` — seed data scenarios
- `server/docker-compose.yml` — now uses `CADENZA_DB_PORT` env var
- `CadenzaUITests/ScreenshotPipelineTests.swift` — screenshot scenarios
