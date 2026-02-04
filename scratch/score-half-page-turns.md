# Half-Page Turns

## Problem

In portrait orientation, a full page turn means the musician loses sight of the current page entirely. For pieces with awkward page breaks—a phrase continuing across pages, a difficult passage split in two—the musician must either memorize the transition or pause awkwardly.

This is a solved problem. forScore and every serious sheet music app offers half-page turns. Without it, Cadenza fails the "would I use this for a real performance?" test.

## Approach

Replace the standard full-page PDFView with a custom dual-pane renderer when half-page mode is active:

```
┌─────────────────────┐
│                     │
│   Bottom half of    │
│      Page N         │
│                     │
├─────────────────────┤
│                     │
│    Top half of      │
│     Page N+1        │
│                     │
└─────────────────────┘
```

Navigation advances by half-page increments. Position 0 shows page 1 full. Position 1 shows bottom-half of page 1 + top-half of page 2. Position 2 shows page 2 full. And so on.

The musician always sees what's coming without losing context of where they are.

## Alternatives considered

| Approach | Tradeoff | Why not |
|----------|----------|---------|
| Scroll PDFView to half-page offsets | Reuses existing PDFView, simpler | PDFView fights you—`goToNextPage` jumps full pages, scroll position tracking is fragile, half-page boundaries don't align with PDFKit's page model |
| Render PDF pages into single composite UIImage | Simple compositing | Memory issues with high-res scores, loses zoom/pan interactions |
| Two stacked PDFViews clipped to halves | Native rendering quality | PDFView instances are heavy, gesture coordination between two views is complex |
| **Thumbnail composition with SwiftUI Image** | Fast, controllable, integrates well | Slightly lower quality at extreme zoom, but half-page mode is for "see both halves at once" not "zoom into details" |

Choosing thumbnail composition. It's the right tool: we want to show two regions at once, not navigate a continuous document. We render each half as a UIImage via `PDFPage.thumbnail(of:for:)`, crop to the relevant half, and display in a VStack. Clean separation from the normal PDFView path.

## Key decisions

### Portrait only

forScore restricts half-page mode to portrait. Good instinct—in landscape, you can already see more horizontal content, and the screen is too short to stack two halves usefully. Following that precedent.

Half-page toggle appears only when `UIDevice.current.orientation.isPortrait` (or equivalent size class check).

### No zoom in half-page mode

Half-page mode exists for one purpose: see the transition between pages. If you need to zoom in on detail, exit half-page mode. This simplifies implementation (no gesture handling complexity) and aligns with forScore's behavior.

The zoom controls in the control bar hide when half-page mode is active. Tap zones and page navigation remain.

### Position model, not page model

Current implementation tracks `currentPage: Int`. Half-page mode needs `currentPosition: Int` where:
- Position 0: full page 1
- Position 1: half-page split (bottom of 1 + top of 2)
- Position 2: full page 2
- Position 3: half-page split (bottom of 2 + top of 3)
- ...

For a document with N pages, there are `2*N - 1` positions. Last position shows full last page.

Alternatively, simpler: always show a split view, where position M shows bottom of page `(M+1)/2` and top of page `(M+2)/2`. But this means you can never see a full page in half-page mode. forScore allows full-page views at the start and end. We'll match that.

### Toggle location: control bar

Add a button to the control bar (icon: `rectangle.split.1x2` or similar). Tap toggles half-page mode. State persists via `@AppStorage` (local device preference, per wave requirements).

### Rendering approach

```swift
func renderHalfPage(_ page: PDFPage, half: PageHalf, size: CGSize) -> UIImage? {
    // Render full page to image at 2x display size for quality
    let fullSize = CGSize(width: size.width * 2, height: size.height * 4)
    guard let fullImage = page.thumbnail(of: fullSize, for: .mediaBox) else { return nil }

    // Crop to top or bottom half
    let cropRect: CGRect
    switch half {
    case .top:
        cropRect = CGRect(x: 0, y: 0, width: fullImage.size.width, height: fullImage.size.height / 2)
    case .bottom:
        cropRect = CGRect(x: 0, y: fullImage.size.height / 2, width: fullImage.size.width, height: fullImage.size.height / 2)
    }

    guard let cgImage = fullImage.cgImage?.cropping(to: cropRect) else { return nil }
    return UIImage(cgImage: cgImage, scale: fullImage.scale, orientation: fullImage.imageOrientation)
}
```

Cache rendered half-pages for the visible position ± 1 to enable smooth transitions.

### Display indicator

Control bar shows position differently in half-page mode:
- Normal: `3 / 10` (page 3 of 10)
- Half-page: `3-4 / 10` (showing transition between pages 3 and 4)

When showing a full page in half-page mode (positions 0 and last): `1 / 10` as normal.

## Scope

### In scope

- Half-page toggle button in control bar
- Dual-pane renderer showing bottom-of-N + top-of-N+1
- Position-based navigation (tap zones advance by half-page)
- Position indicator in control bar
- Local persistence via @AppStorage
- Works in portrait orientation

### Out of scope

- Landscape half-page mode
- Zoom/pan gestures in half-page mode
- Pinch-to-toggle between modes
- Animated transitions between positions (simple crossfade is fine)
- Server sync of preference (explicitly local per roadmap)

## Implementation outline

### 1. State model

```swift
// In EnhancedSheetMusicViewer
@AppStorage("halfPageModeEnabled") private var halfPageMode = false
@State private var halfPagePosition = 0  // 0 to 2*totalPages - 2
```

### 2. View structure

```swift
var body: some View {
    VStack(spacing: 0) {
        ZStack {
            if halfPageMode {
                HalfPageView(
                    document: pdfDocument,
                    position: $halfPagePosition,
                    totalPages: totalPages
                )
            } else {
                SheetMusicContainer(...)  // existing
            }

            TapZoneOverlay(
                onPrevious: goToPrevious,
                onNext: goToNext,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext
            )
        }
        controlBar
    }
}
```

### 3. HalfPageView component

New file or section in SheetMusicView.swift:

```swift
struct HalfPageView: View {
    let document: PDFDocument?
    @Binding var position: Int
    let totalPages: Int

    var body: some View {
        GeometryReader { geo in
            let halfHeight = geo.size.height / 2

            if let (topImage, bottomImage) = renderedHalves(for: position, size: geo.size) {
                VStack(spacing: 0) {
                    Image(uiImage: bottomImage)  // bottom of current page
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: halfHeight)

                    Divider()

                    Image(uiImage: topImage)  // top of next page
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: halfHeight)
                }
            }
        }
        .background(Color(UIColor.systemGray6))
    }
}
```

### 4. Navigation logic

```swift
private var canGoPrevious: Bool {
    halfPageMode ? halfPagePosition > 0 : currentPage > 1
}

private var canGoNext: Bool {
    halfPageMode ? halfPagePosition < maxHalfPagePosition : currentPage < totalPages
}

private var maxHalfPagePosition: Int {
    max(0, 2 * totalPages - 2)
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
```

### 5. Control bar modifications

```swift
// Add toggle button
Button {
    halfPageMode.toggle()
    if halfPageMode {
        // Sync position from current page
        halfPagePosition = (currentPage - 1) * 2
    } else {
        // Sync page from position
        currentPage = (halfPagePosition / 2) + 1
    }
} label: {
    Image(systemName: halfPageMode ? "rectangle.split.1x2.fill" : "rectangle.split.1x2")
}

// Hide zoom controls in half-page mode
if !halfPageMode {
    zoomControls
}

// Update page indicator
private var pageIndicatorText: String {
    if halfPageMode {
        let (bottomPage, topPage) = pagesForPosition(halfPagePosition)
        if bottomPage == topPage {
            return "\(bottomPage) / \(totalPages)"
        } else {
            return "\(bottomPage)-\(topPage) / \(totalPages)"
        }
    } else {
        return "\(currentPage) / \(totalPages)"
    }
}
```

## Done when

1. Build succeeds: `python dev.py test --ios` passes
2. Manual verification in simulator:
   - Toggle appears in control bar
   - Enabling shows bottom-of-current + top-of-next
   - Tap zones advance by half-page
   - Page indicator shows `N-M / total` format
   - Zoom controls hidden in half-page mode
   - Toggle persists across app restarts
   - Works only in portrait (toggle hidden/disabled in landscape)
