# Tap Zones for Page Turning

## Problem

Musicians can't turn pages manually while playing. Their hands are occupied with their instrument. Tap zones provide the simplest fallback for hands-free page navigation—a musician can quickly tap a foot or use an elbow to trigger a page turn without needing specialized hardware like Bluetooth pedals.

This is table stakes for any serious sheet music app. forScore has had this for years. Without it, Cadenza's PDF viewer is toy-grade.

## Approach

Overlay transparent tap zones on the left and right edges of `EnhancedSheetMusicViewer`. Taps in these zones trigger page navigation. The center remains untouched for PDFView's native pan/zoom gestures.

**Zone layout**: Left 20% and right 20% of screen width, full height.

The existing ingested doc suggested thirds, but 20% is better:
- More generous center area for pan/zoom (60% vs 33%)
- Still large enough for comfortable tapping (80pt minimum on iPhone SE)
- Matches forScore's behavior more closely

**Implementation strategy**: SwiftUI overlay with `.onTapGesture`, not UIKit gesture recognizers on PDFView. Reasons:
1. Cleaner separation—PDFView handles document interaction, SwiftUI handles navigation UI
2. No need to fight PDFView's built-in gestures
3. Easier to disable zones when annotation mode is added later
4. The overlay intercepts taps before they reach PDFView

## Alternatives considered

| Approach | Tradeoff | Why not |
|----------|----------|---------|
| UITapGestureRecognizer on PDFView | More direct control | Fights PDFView's built-in gesture handling; requires coordinator complexity |
| Thirds layout (33% each) | Industry standard | Too little center area; zooming/panning becomes frustrating |
| Invisible buttons (no feedback) | Cleaner UI | Users won't discover the feature; no confirmation tap registered |
| Swipe gestures instead | More intentional | Harder to trigger while playing; conflicts with PDFView scrolling |

## Key decisions

**20% edge zones instead of 33%**
The roadmap states "center third: normal interactions (pan, zoom, tap to show controls)" but this splits the difference poorly. Musicians need generous space for score interaction. 20% edges still provide comfortable tap targets (at least 75pt on iPhone, 160pt on iPad) while preserving 60% for document manipulation.

**Flash feedback on tap**
When a tap zone is activated, briefly flash the zone with a semi-transparent chevron indicator (< or >) that fades after 150ms. This:
- Confirms the tap registered
- Shows which direction the page turned
- Teaches users where tap zones are through natural exploration
- Doesn't persist or clutter the UI

**No feedback when at boundary**
Tapping the left zone on page 1 or right zone on last page does nothing—no error, no "bump" animation. Silent no-op is clearer than fake affordance. The page counter ("1 / 12") already shows position.

**SwiftUI overlay, not PDFView modification**
Per STYLE guide: "Avoid UIKit at all costs. Just use SwiftUI." The overlay approach stays in SwiftUI-land. The `SheetMusicContainer` UIViewRepresentable handles PDFKit; the tap zones are pure SwiftUI on top.

**Tap zones work at any zoom level**
Zones are defined in screen coordinates, not document coordinates. A user zoomed in on a passage can still tap the screen edge to turn pages. This matches user expectation—"the edges of my screen turn pages."

## Scope

**In scope:**
- Tap zone overlays on EnhancedSheetMusicViewer
- Left zone → previous page, right zone → next page
- Brief visual feedback on successful page turn
- Respects page boundaries (no action at first/last page)
- Works in all orientations and device sizes

**Out of scope:**
- Settings to adjust zone width (premature configurability)
- Settings to disable tap zones (add when we have a settings screen)
- Vertical tap zones (for vertical scrolling mode—we use horizontal page turns)
- Haptic feedback (nice-to-have, add later if users request)
- Performance mode integration (that feature doesn't exist yet)
- Annotation mode disabling (that feature doesn't exist yet)

## Implementation

Modify `EnhancedSheetMusicViewer` in `Cadenza/Views/SheetMusicView.swift`:

```swift
// MARK: - Tap Zone Overlay

private struct TapZoneOverlay: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let canGoPrevious: Bool
    let canGoNext: Bool

    @State private var showLeftFeedback = false
    @State private var showRightFeedback = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left zone (20%)
                tapZone(
                    width: geometry.size.width * 0.2,
                    showFeedback: showLeftFeedback,
                    direction: .left
                ) {
                    if canGoPrevious {
                        showLeftFeedback = true
                        onPrevious()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showLeftFeedback = false
                        }
                    }
                }

                // Center area (60%) - passthrough
                Color.clear
                    .frame(width: geometry.size.width * 0.6)
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)

                // Right zone (20%)
                tapZone(
                    width: geometry.size.width * 0.2,
                    showFeedback: showRightFeedback,
                    direction: .right
                ) {
                    if canGoNext {
                        showRightFeedback = true
                        onNext()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showRightFeedback = false
                        }
                    }
                }
            }
        }
    }

    private enum Direction { case left, right }

    @ViewBuilder
    private func tapZone(
        width: CGFloat,
        showFeedback: Bool,
        direction: Direction,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: action)

            if showFeedback {
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.primary.opacity(0.3))
                    .transition(.opacity)
            }
        }
        .frame(width: width)
        .animation(.easeOut(duration: 0.15), value: showFeedback)
    }
}
```

Then wrap `SheetMusicContainer` in the `EnhancedSheetMusicViewer.body`:

```swift
var body: some View {
    VStack(spacing: 0) {
        ZStack {
            SheetMusicContainer(...)
                .background(Color(UIColor.systemGray6))

            TapZoneOverlay(
                onPrevious: goToPreviousPage,
                onNext: goToNextPage,
                canGoPrevious: currentPage > 1,
                canGoNext: currentPage < totalPages
            )
        }

        controlBar
    }
}
```

## Done when

1. `python dev.py test --ios` passes (no regressions)
2. Manual verification in simulator:
   - Tap left 20% of screen → previous page (when not on page 1)
   - Tap right 20% of screen → next page (when not on last page)
   - Tap center 60% → pan/zoom works normally
   - Chevron feedback appears briefly on successful page turn
   - Works in both portrait and landscape
   - Works on iPhone and iPad simulators
