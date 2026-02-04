# Score: Core Viewing Features

Three features that make sheet music usable for real performance: half-page turns, performance mode, and crop/margins. This design treats them as a unified system—they share state, interact predictably, and ship together.

## Problem

Cadenza's sheet music viewer is a PDFKit wrapper. It works for reading, not for performing. Musicians face three problems:

1. **Page turns blind you.** A full page turn means losing sight of where you were. Awkward page breaks force memorization or pauses. forScore solved this with half-page turns in 2011.

2. **Accidental gestures derail you.** Mid-performance, a stray finger zooms in, opens a menu, or jumps pages. Performance mode locks out everything except page turns.

3. **Scanned PDFs waste screen space.** Excessive margins, uneven crops, scanner artifacts. Musicians need to crop pages to focus on the music.

Every serious sheet music app has these features. Without them, Cadenza fails the "would I use this for a real gig?" test.

## Approach

Add three modes to `EnhancedSheetMusicViewer`:

| Mode | Purpose | Interactions |
|------|---------|--------------|
| **Normal** | Default viewing | Full gestures, zoom, pan, control bar |
| **Half-page** | See page transitions | Tap zones only, no zoom, split view |
| **Performance** | Distraction-free playing | Tap zones only, no UI, screen stays awake |
| **Crop editing** | Adjust visible region | Drag handles, apply/cancel |

These compose: you can use half-page mode in performance mode. Crop settings apply to all modes.

### Half-Page Turns

Replace PDFView with an image-based dual-pane renderer:

```
┌─────────────────────┐
│   Bottom half of    │
│      Page N         │
├─────────────────────┤
│    Top half of      │
│     Page N+1        │
└─────────────────────┘
```

Position-based navigation: position 0 = page 1 full, position 1 = bottom of page 1 + top of page 2, position 2 = page 2 full, etc. For N pages, there are 2N-1 positions.

Why image-based: PDFView's page model doesn't support half-page boundaries. We render pages to UIImage via `PDFPage.thumbnail(of:for:)` and composite. This integrates cleanly with crop (apply crop before rendering) and keeps the normal PDFView path unchanged.

### Performance Mode

Hide all UI. Block all gestures except tap zones. Keep screen awake.

Entry: tap lock icon in control bar.
Exit: triple-tap anywhere (intentionally awkward to prevent accidents).

The overlay approach: a transparent view over the PDF that consumes pinch/pan gestures but lets taps through to the edge zones. Simpler than trying to disable PDFView's gesture recognizers selectively.

### Crop & Margins

Per-page crop regions stored as normalized rects (0-1 coordinates). Applied at render time, never modifies the PDF.

UI: enter crop mode from control bar, drag corner/edge handles, choose "Apply to this page" or "Apply to all pages".

Storage: `@AppStorage` with JSON encoding, keyed by document URL. Local-only for now; server sync comes with Phase 2 annotations.

## Alternatives considered

| Approach | Tradeoff | Why not |
|----------|----------|---------|
| Scroll PDFView to half-page offsets | Reuses PDFView | `goToNextPage` fights you; half-page boundaries don't align with PDFKit's model |
| Two stacked PDFViews clipped | Native rendering | Heavy instances, complex gesture coordination |
| Transform-based crop (scale/offset PDFView) | Better zoom quality | Conflicts with PDFView's built-in gesture handling |
| Confirmation dialog for performance mode exit | Prevents accidents | Adds friction; triple-tap is awkward enough |
| Landscape half-page mode | More use cases | Screen too short for two halves; forScore doesn't do it either |

## Key decisions

### Unified state model

All three features read from shared state:

```swift
// Local preferences (device-specific, not synced)
@AppStorage("halfPageModeEnabled") private var halfPageMode = false
@AppStorage("performanceModeEnabled") private var performanceMode = false

// Per-document state
@State private var halfPagePosition = 0
@State private var cropSettings: DocumentCropSettings?
@State private var isCropEditing = false
```

Following `01-table-stakes.md`: "Some settings can stay device-local: display preferences, current page position, half-page turn toggle state."

### Portrait-only for half-page

forScore restricts half-page mode to portrait. In landscape, you already see more content horizontally, and the screen is too short to stack halves usefully. We'll hide/disable the toggle in landscape via horizontal size class check.

### No zoom in half-page mode

Half-page mode is for seeing transitions, not examining details. If you need to zoom, exit half-page mode. This simplifies implementation and matches forScore.

### Triple-tap to exit performance mode

Single tap: too easy to hit accidentally.
Double tap: standard gesture, could conflict with other interactions.
Triple tap: awkward enough to be intentional, fast enough to not be frustrating.

No confirmation dialog—immediate exit. If a musician triple-taps mid-performance, they meant it.

### Image-based rendering for crop and half-page

Both crop and half-page need to render page regions to images. Unify the rendering path:

```swift
func renderPage(_ page: PDFPage, crop: CropSettings, size: CGSize) -> UIImage? {
    // Render at 2x for quality
    let renderSize = CGSize(width: size.width * 2, height: size.height * 2)
    guard let fullImage = page.thumbnail(of: renderSize, for: .mediaBox) else { return nil }

    // Apply crop
    let cropRect = CGRect(
        x: crop.visibleRect.origin.x * fullImage.size.width,
        y: crop.visibleRect.origin.y * fullImage.size.height,
        width: crop.visibleRect.width * fullImage.size.width,
        height: crop.visibleRect.height * fullImage.size.height
    )
    guard let cgImage = fullImage.cgImage?.cropping(to: cropRect) else { return nil }
    return UIImage(cgImage: cgImage, scale: fullImage.scale, orientation: fullImage.imageOrientation)
}
```

For half-page mode, call this twice per position (bottom half of current page, top half of next page).

### Crop storage format

```swift
struct CropSettings: Codable {
    /// Normalized rect (0-1 range) representing visible area
    var visibleRect: CGRect

    static let full = CropSettings(visibleRect: CGRect(x: 0, y: 0, width: 1, height: 1))
}

struct DocumentCropSettings: Codable {
    var documentId: String  // URL or content hash
    var pageSettings: [Int: CropSettings]  // page index -> settings
    var defaultSettings: CropSettings  // for pages without explicit crop
}
```

Stored in UserDefaults via `@AppStorage` with JSON encoding. Simple, works offline, migrates easily to server storage in Phase 2.

## Scope

### In scope

**Half-page turns:**
- Toggle button in control bar (icon: `rectangle.split.1x2`)
- Dual-pane renderer showing bottom-of-N + top-of-N+1
- Position-based navigation via tap zones
- Position indicator: "3-4 / 10" when showing transition
- Portrait orientation only
- Persists via @AppStorage

**Performance mode:**
- Toggle button in control bar (icon: `lock`)
- Hide control bar
- Block pinch/pan/long-press gestures
- Allow tap zone page turns
- Small lock icon indicator in corner
- Keep screen awake (`isIdleTimerDisabled`)
- Triple-tap to exit

**Crop & margins:**
- Crop button in control bar (icon: `crop`)
- Drag handles at corners and edges
- Semi-transparent dimming outside crop region
- "Apply to this page" / "Apply to all pages" / "Reset" / "Cancel" actions
- Per-page storage
- Applied at render time

**Integration:**
- Half-page + performance mode work together
- Crop applies to all modes
- Crop mode cannot be entered during performance mode

### Out of scope

- Landscape half-page mode
- Zoom in half-page mode
- Animated transitions between half-page positions
- De-skew/rotation correction
- Auto-detect crop regions
- Server sync of crop settings
- Customizable performance mode gestures
- Bluetooth pedal support (separate feature)
- AirPods head gestures (separate feature)

## Data flow

```
┌─────────────────────────────────────────────────────────────┐
│                  EnhancedSheetMusicViewer                   │
├─────────────────────────────────────────────────────────────┤
│ @AppStorage:                                                │
│   - halfPageMode: Bool                                      │
│   - cropSettings: [String: DocumentCropSettings]            │
│                                                             │
│ @State:                                                     │
│   - performanceMode: Bool                                   │
│   - halfPagePosition: Int                                   │
│   - isCropEditing: Bool                                     │
│   - currentPage: Int                                        │
│   - totalPages: Int                                         │
│   - pdfDocument: PDFDocument?                               │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
     │ Normal View │  │ HalfPageView│  │ CropEditor  │
     │ (PDFView)   │  │ (Image×2)   │  │ (Overlay)   │
     └─────────────┘  └─────────────┘  └─────────────┘
              │               │               │
              └───────────────┴───────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  TapZoneOverlay │
                    │  (always active │
                    │   except crop)  │
                    └─────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     ┌─────────────────────┐     ┌────────────────────────┐
     │ ControlBar (hidden  │     │ PerformanceModeOverlay │
     │ in performance mode)│     │ (blocks center, shows  │
     │                     │     │  indicator)            │
     └─────────────────────┘     └────────────────────────┘
```

## Implementation outline

### 1. State additions to EnhancedSheetMusicViewer

```swift
// Persisted preferences
@AppStorage("halfPageModeEnabled") private var halfPageMode = false
@AppStorage("documentCropSettings") private var cropSettingsData: Data = Data()

// View state
@State private var performanceMode = false
@State private var halfPagePosition = 0
@State private var isCropEditing = false
@State private var pdfDocument: PDFDocument?
@State private var editingCropRect: CGRect = .init(x: 0, y: 0, width: 1, height: 1)

// Computed
private var cropSettings: DocumentCropSettings? {
    // Decode from cropSettingsData, keyed by url
}

private var maxHalfPagePosition: Int {
    max(0, 2 * totalPages - 2)
}
```

### 2. View body restructure

```swift
var body: some View {
    ZStack {
        // Main content
        if halfPageMode {
            HalfPageView(
                document: pdfDocument,
                position: halfPagePosition,
                totalPages: totalPages,
                cropSettings: cropSettingsForCurrentDocument
            )
        } else {
            SheetMusicContainer(...)  // existing
        }

        // Tap zones (unless crop editing)
        if !isCropEditing {
            TapZoneOverlay(...)
        }

        // Crop editor overlay
        if isCropEditing {
            CropEditorOverlay(
                rect: $editingCropRect,
                onApplyToPage: applyToCurrentPage,
                onApplyToAll: applyToAllPages,
                onReset: resetCurrentPageCrop,
                onCancel: cancelCropEditing
            )
        }

        // Performance mode gesture blocker
        if performanceMode {
            PerformanceModeOverlay()
        }

        // Performance mode indicator
        if performanceMode {
            PerformanceModeIndicator()
        }
    }

    // Control bar (hidden in performance mode)
    if !performanceMode {
        controlBar
    }
}
```

### 3. HalfPageView component

```swift
struct HalfPageView: View {
    let document: PDFDocument?
    let position: Int
    let totalPages: Int
    let cropSettings: DocumentCropSettings?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Bottom half of current page (or full page at position 0)
                if let bottomImage = renderBottomHalf(for: position, size: geo.size) {
                    Image(uiImage: bottomImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: isFullPagePosition ? .infinity : geo.size.height / 2)
                }

                // Top half of next page (if not at a full-page position)
                if !isFullPagePosition, let topImage = renderTopHalf(for: position, size: geo.size) {
                    Divider()
                    Image(uiImage: topImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: geo.size.height / 2)
                }
            }
        }
        .background(Color(UIColor.systemGray6))
    }

    private var isFullPagePosition: Bool {
        position == 0 || position == 2 * totalPages - 2
    }

    private func renderBottomHalf(for position: Int, size: CGSize) -> UIImage? {
        let pageIndex = position / 2
        guard let page = document?.page(at: pageIndex) else { return nil }
        let crop = cropSettings?.settings(for: pageIndex) ?? .full

        if isFullPagePosition {
            return renderPage(page, crop: crop, size: size)
        } else {
            return renderPage(page, crop: crop, half: .bottom, size: size)
        }
    }

    private func renderTopHalf(for position: Int, size: CGSize) -> UIImage? {
        let pageIndex = (position / 2) + 1
        guard let page = document?.page(at: pageIndex) else { return nil }
        let crop = cropSettings?.settings(for: pageIndex) ?? .full
        return renderPage(page, crop: crop, half: .top, size: size)
    }
}
```

### 4. CropEditorOverlay component

```swift
struct CropEditorOverlay: View {
    @Binding var rect: CGRect  // normalized 0-1 coordinates
    let onApplyToPage: () -> Void
    let onApplyToAll: () -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimming outside crop area
                DimmingMask(rect: rect, size: geo.size)

                // Crop rectangle with handles
                CropRectangle(rect: $rect, size: geo.size)
            }

            // Action buttons at bottom
            VStack {
                Spacer()
                CropActionBar(
                    onApplyToPage: onApplyToPage,
                    onApplyToAll: onApplyToAll,
                    onReset: onReset,
                    onCancel: onCancel
                )
            }
        }
    }
}

struct CropRectangle: View {
    @Binding var rect: CGRect
    let size: CGSize

    var body: some View {
        let actualRect = CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )

        ZStack {
            // Border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: actualRect.width, height: actualRect.height)
                .position(x: actualRect.midX, y: actualRect.midY)

            // Corner handles
            ForEach(Corner.allCases, id: \.self) { corner in
                CropHandle(corner: corner)
                    .position(cornerPosition(corner, in: actualRect))
                    .gesture(dragGesture(for: corner))
            }

            // Edge handles
            ForEach(Edge.allCases, id: \.self) { edge in
                CropHandle(edge: edge)
                    .position(edgePosition(edge, in: actualRect))
                    .gesture(dragGesture(for: edge))
            }
        }
    }
}
```

### 5. PerformanceModeOverlay component

```swift
struct PerformanceModeOverlay: View {
    var body: some View {
        GeometryReader { geo in
            // Invisible rectangle that consumes pan/pinch
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { _ in }  // Consume drag
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { _ in }  // Consume pinch
                )
                // Allow tap-through to edges for tap zones
                .allowsHitTesting(true)
        }
    }
}

struct PerformanceModeIndicator: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.3))
                    .padding(8)
            }
            Spacer()
        }
    }
}
```

### 6. Control bar modifications

```swift
private var controlBar: some View {
    HStack(spacing: 16) {
        // Page navigation
        pageNavigationControls

        Divider().frame(height: 20)

        // Mode toggles
        modeControls

        // Zoom (hidden in half-page mode)
        if !halfPageMode {
            Divider().frame(height: 20)
            zoomControls
        }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Color(UIColor.systemBackground))
}

private var modeControls: some View {
    HStack(spacing: 12) {
        // Half-page toggle (portrait only)
        if isPortrait {
            Button {
                toggleHalfPageMode()
            } label: {
                Image(systemName: halfPageMode ? "rectangle.split.1x2.fill" : "rectangle.split.1x2")
                    .font(.system(size: 18))
            }
        }

        // Crop button
        Button {
            isCropEditing = true
        } label: {
            Image(systemName: "crop")
                .font(.system(size: 18))
        }

        // Performance mode
        Button {
            enterPerformanceMode()
        } label: {
            Image(systemName: "lock")
                .font(.system(size: 18))
        }
    }
}

private var pageIndicatorText: String {
    if halfPageMode {
        let bottomPage = (halfPagePosition / 2) + 1
        let topPage = (halfPagePosition / 2) + (halfPagePosition % 2 == 0 ? 0 : 1) + 1
        if bottomPage == topPage || halfPagePosition == 0 || halfPagePosition == maxHalfPagePosition {
            return "\(bottomPage) / \(totalPages)"
        } else {
            return "\(bottomPage)-\(topPage) / \(totalPages)"
        }
    } else {
        return "\(currentPage) / \(totalPages)"
    }
}
```

### 7. Triple-tap exit for performance mode

```swift
// In EnhancedSheetMusicViewer body, wrap content in:
.onTapGesture(count: 3) {
    if performanceMode {
        exitPerformanceMode()
    }
}

private func enterPerformanceMode() {
    performanceMode = true
    UIApplication.shared.isIdleTimerDisabled = true
}

private func exitPerformanceMode() {
    performanceMode = false
    UIApplication.shared.isIdleTimerDisabled = false
}
```

### 8. Navigation logic updates

```swift
private var canGoPrevious: Bool {
    halfPageMode ? halfPagePosition > 0 : currentPage > 1
}

private var canGoNext: Bool {
    halfPageMode ? halfPagePosition < maxHalfPagePosition : currentPage < totalPages
}

private func goToPrevious() {
    if halfPageMode {
        halfPagePosition = max(0, halfPagePosition - 1)
    } else {
        pdfView?.goToPreviousPage(nil)
    }
}

private func goToNext() {
    if halfPageMode {
        halfPagePosition = min(maxHalfPagePosition, halfPagePosition + 1)
    } else {
        pdfView?.goToNextPage(nil)
    }
}

private func toggleHalfPageMode() {
    halfPageMode.toggle()
    if halfPageMode {
        // Sync position from current page
        halfPagePosition = (currentPage - 1) * 2
    } else {
        // Sync page from position
        currentPage = (halfPagePosition / 2) + 1
        // Scroll PDFView to that page
        if let page = pdfDocument?.page(at: currentPage - 1) {
            pdfView?.go(to: page)
        }
    }
}
```

## Done when

1. **Build succeeds**: `python dev.py test --ios` passes

2. **Half-page turns**:
   - Toggle appears in control bar (portrait only)
   - Enabling shows bottom-of-current + top-of-next
   - Position 0 shows full page 1
   - Last position shows full last page
   - Tap zones advance by half-page
   - Page indicator shows "N-M / total" format for splits
   - Zoom controls hidden in half-page mode
   - Toggle persists across app restarts

3. **Performance mode**:
   - Lock icon in control bar enters mode
   - Control bar hides
   - Small lock indicator in corner
   - Pinch/pan/long-press blocked
   - Tap zones still work
   - Triple-tap exits immediately
   - Screen stays awake

4. **Crop & margins**:
   - Crop button in control bar
   - Drag handles at corners and edges
   - Dimming outside crop region
   - "Apply to page" / "Apply to all" / "Reset" / "Cancel" actions
   - Crop applied at render time
   - Persists per-document

5. **Integration**:
   - Half-page mode works inside performance mode
   - Crop applies to both normal and half-page modes
   - Cannot enter crop mode during performance mode

## Open questions

Logged in `scratch/questions.md`:

1. Should crop auto-suggest based on content detection? (Not MVP, but nice future enhancement)
2. How to handle documents with wildly different page dimensions? (Per-page crop handles this, but bulk operations get awkward)
3. Should performance mode remember half-page position when toggled off/on? (Current design: yes, it's just state)
