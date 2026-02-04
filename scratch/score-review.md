# Tap Zones for Page Turning - Design Review

## What was implemented

Added tap zones to `EnhancedSheetMusicViewer` that allow musicians to turn pages by tapping the left/right edges of the screen. Tapping the left 20% goes to the previous page; tapping the right 20% goes to the next page. The center 60% remains available for PDFView's pan/zoom gestures.

**Files changed:**
- `Cadenza/Views/SheetMusicView.swift` — Added `TapZoneOverlay` and `TapZone` components
- `roadmap/score/01-table-stakes.md` — Updated tap zones item to reference extracted design doc
- `scratch/score-tap-zones.md` — Design doc for this feature (new)

## Key choices

**20% zones instead of 33%**
The roadmap suggested splitting into thirds, but this leaves too little space for pan/zoom (33%). We chose 20% edges (60% center) to preserve generous space for score interaction while still providing comfortable tap targets (75pt+ on iPhone, 160pt+ on iPad).

**SwiftUI overlay, not UIKit gesture recognizers**
Per STYLE guide, we avoid UIKit when possible. The overlay approach keeps tap zone logic in pure SwiftUI while `SheetMusicContainer` handles the PDFKit integration. This also makes it straightforward to disable tap zones when annotation mode is added later.

**Brief flash feedback**
On successful page turn, we show a chevron icon for 150ms. This confirms the tap registered, teaches users where zones are through exploration, and doesn't clutter the UI.

**Silent no-op at boundaries**
Tapping left on page 1 or right on the last page does nothing—no error, no bounce animation. The page counter already shows position, so extra feedback would be redundant.

## How it fits together

```
EnhancedSheetMusicViewer
├── ZStack
│   ├── SheetMusicContainer (PDFKit wrapper, UIViewRepresentable)
│   └── TapZoneOverlay (SwiftUI, intercepts edge taps)
│       ├── TapZone (left, 20% width)
│       └── TapZone (right, 20% width)
└── controlBar (existing page nav + zoom controls)
```

The `TapZoneOverlay` sits on top of `SheetMusicContainer` in a `ZStack`. Taps in the edge zones are handled by SwiftUI; taps in the center pass through to PDFView for pan/zoom.

## Risks and bottlenecks

**Gesture conflict potential**: The overlay uses `Color.clear` with `.contentShape(Rectangle())` to create a tap target. If PDFView's gestures are updated in a future iOS version, there could be edge cases where taps don't propagate correctly. Current testing shows this works well, but worth monitoring.

**No unit tests for tap zones**: The tap zone components are view-only with no complex logic. Testing would require UI tests, which seems overkill for this minimal feature. The "Done when" criteria rely on manual simulator verification.

## What's not included

- **Settings to adjust zone width**: Premature configurability. Add when we have a settings screen.
- **Haptic feedback**: Nice-to-have, add later if users request.
- **Performance mode integration**: That feature doesn't exist yet.
- **Annotation mode disabling**: That feature doesn't exist yet.
- **Vertical tap zones**: We use horizontal page turns; vertical scrolling is a separate mode.

## Test status

iOS tests pass except for one pre-existing failure (`testStudentCanSeeAssignedRoutine`) which tests the Mock API client for teacher-student assignment workflows—unrelated to tap zones.

## Manual verification checklist

- [ ] Tap left 20% of screen → previous page (when not on page 1)
- [ ] Tap right 20% of screen → next page (when not on last page)
- [ ] Tap center 60% → pan/zoom works normally
- [ ] Chevron feedback appears briefly on successful page turn
- [ ] Works in both portrait and landscape
- [ ] Works on iPhone and iPad simulators
