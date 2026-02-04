# Score: Core Viewing Features

Unify half-page turns, performance mode, and crop editing into a coherent score viewer for live performance use.

## Current status

- Performance mode is session-only (not persisted).
- PDF page-change observers are cleaned up on view teardown.
- Performance mode blocks center taps as well as drag/magnify gestures.

## Problem

Cadenza's sheet music viewer is a PDFKit wrapper. It works for reading, not for performing. Musicians face three problems:

1. **Page turns blind you.** A full page turn means losing sight of where you were.
2. **Accidental gestures derail you.** Mid-performance, a stray finger zooms, pans, or opens UI.
3. **Scanned PDFs waste screen space.** Excessive margins and uneven scans make music too small.

## Feature design

### Half-page turns

- Portrait-only mode that shows bottom of page N + top of page N+1.
- Position-based navigation: there are `2N - 1` positions for N pages.
- Image-based rendering via `PDFPage.thumbnail` to allow clean split rendering.
- Planned: draggable divider per page (saved per-page), to match musical phrasing.

### Performance mode

- Hide control bar and block all gestures except page turns.
- Expanded forward tap zone (right 2/3), back zone on left 1/3.
- Triple-tap anywhere exits.
- Keep screen awake while active.

### Crop editor

- Per-page crop rectangle with draggable handles.
- Apply to current page, apply to all pages, reset to original.
- Stored locally per document; no server sync in this phase.
- No de-skew or auto-detection yet.

## Scope

**In scope**
- Half-page toggle, position-based navigation, portrait only.
- Performance mode toggle, gesture blocking, lock indicator.
- Crop editor overlay with per-page storage and apply-to-all.

**Out of scope (this iteration)**
- Margin slider / global zoom controls for whitespace.
- De-skew / rotation correction.
- Auto-detecting crop regions.
- Landscape half-page mode.
- Server sync of view settings.
- Bluetooth pedal / AirPods head gestures.

## Data model (local)

```swift
struct CropSettings: Codable {
    var visibleRect: CGRect  // Normalized 0-1
    static let full = CropSettings(visibleRect: CGRect(x: 0, y: 0, width: 1, height: 1))
}

struct DocumentCropSettings: Codable {
    var documentId: String
    var pageSettings: [Int: CropSettings]
    var defaultSettings: CropSettings
}
```

Planned: store half-page divider offsets per document and per page if the divider becomes adjustable.

## Risks and bottlenecks

- PDFKit rendering and `thumbnail` generation remain uncached; large scores can feel sluggish.
- Half-page thumbnails may blur at extreme zoom levels.

## Open questions

See `scratch/questions.md`.
