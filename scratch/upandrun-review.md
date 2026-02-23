# upandrun Branch: Design Review

## What was implemented

This branch adds local dev and dogfooding infrastructure plus enhanced score viewing features:

1. **Local Dev CLI** (`dev.py`) — Commands to run the full Cadenza stack locally without needing Xcode IDE:
   - `python dev.py server` — Start postgres + uvicorn with branch-isolated database
   - `python dev.py simulator` — Build and launch iOS simulator
   - `python dev.py reset --scenario X` — Reset DB and seed with test data
   - `python dev.py research --scenarios X` — Capture screenshots + Claude UX analysis
   - `python dev.py fetch-bundles` — Download PDFs from Dropbox

2. **Branch Isolation** — Each git branch gets its own database port (5433-5532 range), Docker containers, and volumes. Enables parallel agent work on different worktrees.

3. **Seed Scenarios** (`server/seed_scenario.py`) — Three scenarios for testing:
   - `empty` — Fresh database
   - `teacher-with-students` — Teacher + 2 students + pieces + routines
   - `student-with-assignment` — Student with assigned routine and practice history

4. **Score Viewing Features** (SheetMusicView.swift, ~700 new lines):
   - Half-page turns for portrait mode (shows bottom of page N + top of page N+1)
   - Performance mode (hides controls, blocks gestures except page turns, keeps screen awake)
   - Crop editor (per-page crop rectangle, apply to page/all, persisted locally)

5. **Cleanup** — Removed video submission feature (model, endpoints, views, tests).

## Key choices

| Decision | Rationale | Alternatives Rejected |
|----------|-----------|----------------------|
| Branch-isolated DB via hash | Deterministic ports, no coordination needed | Dynamic port allocation (requires state sharing) |
| Bundled PDFs fetched from Dropbox | Keeps repo small, avoids binary bloat | Git LFS (overkill for dev-only assets) |
| Half-page via `PDFPage.thumbnail` | Clean split rendering without PDFKit hacks | Custom PDF renderer (too complex) |
| Crop settings in `@AppStorage` | Simple persistence, no server sync needed yet | UserDefaults directly (less SwiftUI idiomatic) |
| xcodegen for project management | Declarative config, easier to version control | Manual .xcodeproj edits (merge conflicts) |

## How it fits together

```
┌─────────────────────────────────────────────────────────────┐
│                        dev.py CLI                           │
├─────────┬─────────┬──────────┬──────────┬──────────────────┤
│ server  │simulator│  reset   │ research │  fetch-bundles   │
└────┬────┴────┬────┴────┬─────┴────┬─────┴───────┬──────────┘
     │         │         │          │             │
     v         v         v          v             v
┌─────────┐ ┌──────┐ ┌────────┐ ┌────────┐ ┌───────────┐
│postgres │ │xcode │ │ seed   │ │XCUITest│ │ Dropbox   │
│+uvicorn │ │build │ │scenario│ │+Claude │ │   ZIP     │
└─────────┘ └──────┘ └────────┘ └────────┘ └───────────┘
     │         │         │          │
     └─────────┴─────────┴──────────┘
                   │
                   v
           ┌──────────────┐
           │  Simulator   │
           │   (iOS)      │
           └──────────────┘
```

Score viewer architecture:
- `EnhancedSheetMusicViewer` — Main coordinator, manages mode state
- `SheetMusicContainer` — UIViewRepresentable wrapping PDFView
- `HalfPageView` — Renders half-page split using thumbnails
- `CropEditorOverlay` — Draggable crop rectangle with handles
- `PerformanceModeOverlay` — Gesture blocker with tap zones

## Risks and bottlenecks

1. **PDFKit rendering** — `thumbnail` generation is synchronous and uncached. Large scores (50+ pages) may feel sluggish during half-page navigation.

2. **Seed scenarios hardcode IDs** — The `BUNDLED_PDFS` list must match actual filenames after `fetch-bundles`. If PDFs are renamed upstream, seeds will silently create pieces referencing missing files.

3. **Crop settings grow unbounded** — `@AppStorage` stores all document crop settings in a single JSON blob. With many documents, this could hit size limits or slow down.

4. **Research command depends on XCUITest** — If UI element identifiers change, screenshot scenarios break silently (they don't fail, just skip elements).

## What's not included

- **Server sync of view settings** — Crop/half-page preferences stay local
- **Landscape half-page mode** — Only portrait supported
- **De-skew/rotation for scanned PDFs** — Manual crop only
- **Bluetooth pedal support** — Page turns are tap-only
- **Production deployment** — This is local dev infrastructure only
- **iOS unit tests for score features** — Relies on SwiftUI Previews for now

## Files changed

| Path | Change |
|------|--------|
| `dev.py` | +360 lines — new CLI commands |
| `server/seed_scenario.py` | +390 lines — seed scenarios |
| `Cadenza/Views/SheetMusicView.swift` | +700 lines — score viewing features |
| `project.yml` | +82 lines — xcodegen config |
| `CadenzaUITests/ScreenshotPipelineTests.swift` | +135 lines — screenshot automation |
| `server/docker-compose.yml` | +2 lines — env var for port |
| Various | Deleted video submission feature (~1500 lines removed) |
