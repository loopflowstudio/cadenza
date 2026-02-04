# Score: Core Viewing Features

Three features that make sheet music usable for real performance: half-page turns, performance mode, and crop/margins. This design treats them as a unified system—they share state, interact predictably, and ship together.

## Problem

Cadenza's sheet music viewer is a PDFKit wrapper. It works for reading, not for performing. Musicians face three problems:

1. **Page turns blind you.** A full page turn means losing sight of where you were. Awkward page breaks force memorization or pauses. forScore solved this with half-page turns in 2011.

2. **Accidental gestures derail you.** Mid-performance, a stray finger zooms in, opens a menu, or jumps pages. Performance mode locks out everything except page turns.

3. **Scanned PDFs waste screen space.** Excessive margins, uneven crops, scanner artifacts. Musicians need to crop pages to focus on the music.

Every serious sheet music app has these features. Without them, Cadenza fails the "would I use this for a real gig?" test.

## Research: What forScore Actually Does

Based on [forScore's documentation](https://forscore.co/kb/):

**Half-page turns:** A blue horizontal divider shows where the page splits. Users can drag this divider to any position (0.3-0.7 of page height) and the position is saved per-page. This is critical—musical phrases rarely end at exactly 50%.

**Performance mode:** Disables most gestures. The forward page turn zone expands to the right two-thirds of the screen. Exit via small × button in corner. Screen gestures activate on touch (not on release), making turns instantaneous.

**Crop:** Two tools: (1) Margin adjustment—a single slider that zooms all pages toward center equally. (2) Full crop editor—per-page repositioning with drag/pinch, de-skew rotation, and speed control for precision. Cropped pages ignore the margin slider.

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
├───────[═══]─────────┤  ← Draggable divider
│    Top half of      │
│     Page N+1        │
└─────────────────────┘
```

Position-based navigation: position 0 = page 1 full, position 1 = bottom of page 1 + top of page 2, position 2 = page 2 full, etc. For N pages, there are 2N-1 positions.

**Key insight from forScore:** The divider position is adjustable per-page. A phrase ending at 60% down the page? Drag the divider there. This turns a "good enough" feature into a "perfect" one. Store divider offsets in `@AppStorage` keyed by document+page.

Why image-based: PDFView's page model doesn't support half-page boundaries. We render pages to UIImage via `PDFPage.thumbnail(of:for:)` and composite. This integrates cleanly with crop (apply crop before rendering) and keeps the normal PDFView path unchanged.

### Performance Mode

Hide all UI. Block all gestures except tap zones. Keep screen awake.

Entry: tap lock icon in control bar.
Exit: triple-tap anywhere (intentionally awkward to prevent accidents).

**Key insight from forScore:** The forward tap zone expands to 2/3 of the screen width. Musicians page forward far more than backward. Also, gestures activate on touch, not on release—this makes page turns feel instantaneous.

The overlay approach: a transparent view over the PDF that consumes pinch/pan gestures but lets taps through to the edge zones. Simpler than trying to disable PDFView's gesture recognizers selectively.

### Crop & Margins

**Bold decision: Ship margin adjustment first, full crop editor later.**

forScore has two tools: margin adjustment (simple slider, applies to all pages) and full crop (per-page precision). The margin slider solves 80% of cases—scanned PDFs with uniform whitespace. The full crop editor is complex (handles, gestures, batch operations, de-skew).

Ship the margin slider in this iteration. It's a single slider in a settings panel. Musicians can make notes bigger immediately. Full crop can follow if demand warrants.

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

// Per-document settings
@AppStorage("documentSettings") private var documentSettingsData: Data = Data()
// Decodes to: [String: DocumentViewSettings] keyed by document hash

// Session state (not persisted)
@State private var performanceMode = false  // Always start in normal mode
@State private var halfPagePosition = 0
```

Following `01-table-stakes.md`: "Some settings can stay device-local: display preferences, current page position, half-page turn toggle state."

### Draggable half-page divider (per-page)

This is the critical UX detail. A fixed 50/50 split is mediocre—phrases rarely end at page center. forScore lets users drag the divider and remembers the position per-page.

Store in `DocumentViewSettings.dividerOffsets: [Int: CGFloat]` (page index → offset 0.3-0.7).

### Portrait-only for half-page

forScore restricts half-page mode to portrait. In landscape, you already see more content horizontally, and the screen is too short to stack halves usefully. We'll hide/disable the toggle in landscape via horizontal size class check.

### No zoom in half-page mode

Half-page mode is for seeing transitions, not examining details. If you need to zoom, exit half-page mode. This simplifies implementation and matches forScore.

### Expanded forward tap zone in performance mode

forScore expands the forward zone to 2/3 of screen width in performance mode. Musicians page forward far more than backward. We'll match this: left 1/3 backward, right 2/3 forward.

### Triple-tap to exit performance mode

Single tap: too easy to hit accidentally.
Double tap: standard gesture, could conflict with other interactions.
Triple tap: awkward enough to be intentional, fast enough to not be frustrating.

No confirmation dialog—immediate exit. If a musician triple-taps mid-performance, they meant it.

### Margin slider first, full crop later

The existing design jumps to full crop editor with handles, de-skew, batch operations. That's over-engineering for MVP.

A margin slider (0-30%) that zooms all pages toward center solves 80% of whitespace problems. Ship that. Full crop can follow if users need per-page precision.

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

### Data model

```swift
/// Per-document view settings, stored in UserDefaults
struct DocumentViewSettings: Codable {
    /// Margin zoom percentage (0.0 to 0.3). Zooms all pages toward center.
    var marginPercent: Double = 0

    /// Half-page divider position per page (page index → offset 0.3-0.7).
    /// Default is 0.5 (center). Only stored for pages where user adjusted.
    var dividerOffsets: [Int: CGFloat] = [:]
}

// Phase 2: Add per-page crop when needed
// struct CropSettings: Codable {
//     var visibleRect: CGRect  // Normalized 0-1
//     var rotation: Double = 0  // Degrees, -5 to +5
// }
```

Stored in UserDefaults via `@AppStorage` with JSON encoding, keyed by document hash (SHA256 of URL string). Simple, works offline, migrates easily to server storage in Phase 2.

## Scope

### In scope

**Half-page turns:**
- Toggle button in control bar (icon: `rectangle.split.1x2`)
- Dual-pane renderer showing bottom-of-N + top-of-N+1
- Draggable divider with grip handle, position saved per-page
- Position-based navigation via tap zones
- Position indicator: "3-4 / 10" when showing transition
- Portrait orientation only
- Persists via @AppStorage

**Performance mode:**
- Toggle button in control bar (icon: `lock`)
- Hide control bar
- Block pinch/pan/long-press gestures
- Expand forward tap zone to 2/3 screen width
- Allow tap zone page turns (activate on touch, not release)
- Small lock icon indicator in corner
- Keep screen awake (`isIdleTimerDisabled`)
- Triple-tap to exit

**Margin adjustment:**
- Settings button in control bar (icon: `slider.horizontal.3`)
- Opens sheet with margin slider (0-30%)
- Applied at render time to all pages
- Per-document persistence

**Integration:**
- Half-page + performance mode work together
- Margin adjustment applies to all modes
- Settings cannot be accessed during performance mode

### Out of scope (this iteration)

- Full crop editor with handles and per-page regions
- De-skew/rotation correction
- Auto-detect crop regions
- Landscape half-page mode
- Zoom in half-page mode
- Animated transitions between half-page positions
- Server sync of view settings
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
│   - allDocumentSettingsData: Data  → [String: Settings]     │
│                                                             │
│ @State:                                                     │
│   - performanceMode: Bool                                   │
│   - halfPagePosition: Int                                   │
│   - showSettings: Bool                                      │
│   - documentSettings: DocumentViewSettings                  │
│     - marginPercent: Double                                 │
│     - dividerOffsets: [Int: CGFloat]                        │
│   - currentPage: Int                                        │
│   - totalPages: Int                                         │
│   - pdfDocument: PDFDocument?                               │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     ┌─────────────────┐            ┌─────────────────────┐
     │ Normal View     │            │ HalfPageView        │
     │ (PDFView with   │            │ (Image×2 + divider) │
     │  margin zoom)   │            │                     │
     └─────────────────┘            └─────────────────────┘
              │                               │
              └───────────────┬───────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     ┌─────────────────┐            ┌────────────────────────┐
     │ TapZoneOverlay  │  ──OR──    │ PerformanceModeOverlay │
     │ (20%/60%/20%)   │            │ (33%/67% expanded)     │
     └─────────────────┘            └────────────────────────┘
              │
              ▼
     ┌─────────────────────────────────────────┐
     │ ControlBar (hidden in performance mode) │
     │ [page nav] | [half-page] [settings]     │
     │            | [lock] | [zoom]            │
     └─────────────────────────────────────────┘
              │
              ▼ (sheet)
     ┌─────────────────────────────┐
     │ ScoreSettingsSheet          │
     │ - Margin slider (0-30%)     │
     │ - Future: metronome, etc.   │
     └─────────────────────────────┘
```

## Implementation outline

### 1. State additions to EnhancedSheetMusicViewer

```swift
// Persisted preferences
@AppStorage("halfPageModeEnabled") private var halfPageMode = false
@AppStorage("allDocumentSettings") private var allDocumentSettingsData: Data = Data()

// View state
@State private var performanceMode = false
@State private var halfPagePosition = 0
@State private var showSettings = false
@State private var pdfDocument: PDFDocument?
@State private var documentSettings = DocumentViewSettings()

// Computed
private var documentId: String {
    url.absoluteString.sha256()  // or some stable identifier
}

private var maxHalfPagePosition: Int {
    max(0, 2 * totalPages - 2)
}

private var currentBottomPage: Int {
    halfPagePosition / 2
}

// Persistence helpers
private func loadDocumentSettings() {
    guard let allSettings = try? JSONDecoder().decode([String: DocumentViewSettings].self, from: allDocumentSettingsData),
          let settings = allSettings[documentId] else {
        documentSettings = DocumentViewSettings()
        return
    }
    documentSettings = settings
}

private func saveDocumentSettings() {
    var allSettings = (try? JSONDecoder().decode([String: DocumentViewSettings].self, from: allDocumentSettingsData)) ?? [:]
    allSettings[documentId] = documentSettings
    allDocumentSettingsData = (try? JSONEncoder().encode(allSettings)) ?? Data()
}
```

### 2. View body restructure

```swift
var body: some View {
    VStack(spacing: 0) {
        ZStack {
            // Main content
            if halfPageMode {
                HalfPageView(
                    document: pdfDocument,
                    position: halfPagePosition,
                    totalPages: totalPages,
                    marginPercent: documentSettings.marginPercent,
                    dividerOffset: documentSettings.dividerOffsets[currentBottomPage] ?? 0.5,
                    onDividerChanged: { offset in
                        documentSettings.dividerOffsets[currentBottomPage] = offset
                        saveDocumentSettings()
                    }
                )
            } else {
                SheetMusicContainer(...)  // existing, with margin applied
            }

            // Tap zones or performance mode overlay
            if performanceMode {
                PerformanceModeOverlay(onPrevious: goToPrevious, onNext: goToNext)
                PerformanceModeIndicator()
            } else {
                TapZoneOverlay(...)
            }
        }

        // Control bar (hidden in performance mode)
        if !performanceMode {
            controlBar
        }
    }
    .sheet(isPresented: $showSettings) {
        ScoreSettingsSheet(settings: $documentSettings)
    }
    .onTapGesture(count: 3) {
        if performanceMode { exitPerformanceMode() }
    }
}
```

### 3. HalfPageView component

```swift
struct HalfPageView: View {
    let document: PDFDocument?
    let position: Int
    let totalPages: Int
    let marginPercent: Double
    let dividerOffset: CGFloat  // 0.3 to 0.7, default 0.5
    let onDividerChanged: (CGFloat) -> Void

    @State private var isDraggingDivider = false

    var body: some View {
        GeometryReader { geo in
            let isFullPage = position == 0 || position == 2 * totalPages - 2
            let dividerY = geo.size.height * dividerOffset

            ZStack {
                VStack(spacing: 0) {
                    // Bottom half of current page (or full page at position 0)
                    if let bottomImage = renderBottomHalf(size: geo.size) {
                        Image(uiImage: bottomImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: isFullPage ? geo.size.height : dividerY)
                    }

                    // Top half of next page (if not at a full-page position)
                    if !isFullPage, let topImage = renderTopHalf(size: geo.size) {
                        Image(uiImage: topImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: geo.size.height - dividerY)
                    }
                }

                // Draggable divider (only when showing split)
                if !isFullPage {
                    DraggableDivider(
                        offset: dividerY,
                        totalHeight: geo.size.height,
                        isDragging: $isDraggingDivider,
                        onOffsetChanged: { newY in
                            let newOffset = (newY / geo.size.height).clamped(to: 0.3...0.7)
                            onDividerChanged(newOffset)
                        }
                    )
                }
            }
        }
        .background(Color(UIColor.systemGray6))
    }

    private func renderBottomHalf(size: CGSize) -> UIImage? {
        let pageIndex = position / 2
        guard let page = document?.page(at: pageIndex) else { return nil }
        let isFullPage = position == 0 || position == 2 * totalPages - 2

        if isFullPage {
            return renderPage(page, marginPercent: marginPercent, size: size)
        } else {
            return renderPage(page, marginPercent: marginPercent, half: .bottom(dividerOffset), size: size)
        }
    }

    private func renderTopHalf(size: CGSize) -> UIImage? {
        let pageIndex = (position / 2) + 1
        guard let page = document?.page(at: pageIndex) else { return nil }
        return renderPage(page, marginPercent: marginPercent, half: .top(1 - dividerOffset), size: size)
    }
}

struct DraggableDivider: View {
    let offset: CGFloat
    let totalHeight: CGFloat
    @Binding var isDragging: Bool
    let onOffsetChanged: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: offset)

            // Divider line with grip handle
            ZStack {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)

                // Grip handle (three horizontal lines)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 16)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 2)
                            }
                        }
                    )
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        onOffsetChanged(offset + value.translation.height)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Spacer()
        }
    }
}
```

### 4. ScoreSettingsSheet component

```swift
struct ScoreSettingsSheet: View {
    @Binding var settings: DocumentViewSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Margins") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zoom in to remove whitespace")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("0%")
                                .font(.caption2)
                            Slider(value: $settings.marginPercent, in: 0...0.3, step: 0.01)
                            Text("30%")
                                .font(.caption2)
                        }

                        Text("\(Int(settings.marginPercent * 100))% margin removed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Future: add metronome settings, display preferences, etc.
            }
            .navigationTitle("Score Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

### 5. PerformanceModeOverlay component

```swift
struct PerformanceModeOverlay: View {
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left 1/3: backward
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onPrevious() }
                    .frame(width: geo.size.width / 3)

                // Right 2/3: forward (expanded zone)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onNext() }
            }
            // Block other gestures
            .gesture(DragGesture().onChanged { _ in })
            .gesture(MagnificationGesture().onChanged { _ in })
            .gesture(LongPressGesture().onEnded { _ in })
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

        // Settings (margin adjustment, future metronome settings)
        Button {
            showSettings = true
        } label: {
            Image(systemName: "slider.horizontal.3")
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

// Add to body:
// .sheet(isPresented: $showSettings) {
//     ScoreSettingsSheet(settings: $documentSettings)
// }

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
   - Position 0 shows full page 1, last position shows full last page
   - Blue divider line between halves with grip handle
   - Divider is draggable (constrained to 30%-70% of height)
   - Divider position saves per-page, persists across app restarts
   - Tap zones advance by half-page
   - Page indicator shows "N-M / total" format for splits
   - Zoom controls hidden in half-page mode

3. **Performance mode**:
   - Lock icon in control bar enters mode
   - Control bar hides
   - Small lock indicator in corner
   - Forward tap zone expanded to right 2/3 of screen
   - Pinch/pan/long-press blocked
   - Triple-tap anywhere exits immediately
   - Screen stays awake

4. **Margin adjustment**:
   - Settings button in control bar opens sheet
   - Slider adjusts margin 0-30%
   - Preview updates live
   - Applied at render time to all pages
   - Persists per-document across app restarts

5. **Integration**:
   - Half-page mode works inside performance mode
   - Margin adjustment applies to both normal and half-page modes
   - Cannot open settings during performance mode

## Open questions

Logged in `scratch/questions.md`:

1. Should divider positions sync to server for teacher-shared scores? (Probably yes in Phase 2)
2. How do we handle documents with wildly different page dimensions? (Normalize rendering to consistent aspect ratio)
3. Should margin adjustment have per-page overrides? (Not for MVP—that's what full crop editor is for)
4. Should performance mode auto-enable when starting from a setlist/routine? (Good UX but adds coupling—revisit later)
