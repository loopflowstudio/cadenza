# Performance Mode

Picked from `roadmap/score/01-table-stakes.md` Priority 1: Core Viewing.

## Problem

During a performance, musicians need to focus entirely on the music. Accidental gestures can:
- Trigger menus or settings
- Enter annotation mode
- Change zoom unexpectedly
- Navigate to wrong pages

forScore's "Performance mode" locks out most interactions, allowing only page turns.

## Solution

A dedicated performance mode that disables all gestures except page navigation. One tap to enter, one tap to exit.

### Behavior in Performance Mode

**Enabled:**
- Tap zones for page forward/back
- Bluetooth pedal page turns
- AirPods head gestures (when implemented)

**Disabled:**
- Pinch to zoom
- Pan/scroll (locked to current view)
- Long press
- Control bar interactions (hidden)
- Annotation mode
- Crop mode
- Any menu access

**Visual Changes:**
- Control bar hidden
- Minimal UI - just the score
- Small, unobtrusive indicator that performance mode is active (e.g., subtle icon in corner)
- Screen stays awake (disable auto-lock)

### Entry/Exit

**Enter:** Tap a "performance mode" button in the control bar, or use a keyboard shortcut (for Bluetooth keyboards).

**Exit:** Triple-tap anywhere on screen, or press a designated keyboard key (Escape). The triple-tap is intentionally awkward to prevent accidental exit.

## Scope

- Toggle to enter/exit performance mode
- Disable all gestures except page turns
- Hide control bar
- Keep screen awake
- Small mode indicator

### Out of Scope (for now)

- Customizable gesture allowlist
- Scheduled auto-exit (e.g., after setlist completes)
- Integration with metronome auto-start

## Implementation Notes

### State Management

```swift
@Observable
class SheetMusicState {
    var isPerformanceMode: Bool = false
    // ... other state
}
```

The `EnhancedSheetMusicViewer` reads this state and conditionally:
- Shows/hides the control bar
- Enables/disables gesture recognizers
- Shows/hides the mode indicator

### Gesture Blocking

In SwiftUI, we can use `.allowsHitTesting(false)` or conditionally attach gestures. For the underlying PDFView, we may need to:

1. Disable `PDFView`'s built-in gestures when in performance mode
2. Or overlay a transparent view that intercepts unwanted gestures

```swift
// Option 1: Disable PDFView interactions
pdfView.isUserInteractionEnabled = false  // Too aggressive - blocks tap zones too

// Option 2: Overlay that passes through only tap zone areas
struct PerformanceModeOverlay: View {
    var body: some View {
        GeometryReader { geo in
            // Block center area, allow edges
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(DragGesture().onChanged { _ in })  // Consume drags
        }
    }
}
```

The tap zones already exist as separate views, so they can remain interactive while the center area blocks other gestures.

### Screen Wake Lock

```swift
UIApplication.shared.isIdleTimerDisabled = true  // In performance mode
UIApplication.shared.isIdleTimerDisabled = false // On exit
```

Remember to reset this in `onDisappear` or when the view is dismissed.

### Mode Indicator

A small, low-opacity icon in a corner (e.g., top-right) showing a lock or "P" symbol. Tapping it does nothing (part of the blocked area). The triple-tap exit works anywhere.

## Integration with Other Features

- **Half-page mode**: Works with performance mode. Page turns advance by half-page.
- **Crop mode**: Cannot enter crop mode while in performance mode.
- **Annotations**: Cannot annotate while in performance mode.
- **Metronome**: Could auto-start metronome when entering performance mode (future enhancement).

## Open Questions

- Should there be a confirmation when entering performance mode? (Probably not - quick entry is the point)
- Should triple-tap show a brief "Exit performance mode?" prompt, or exit immediately? (Immediate is simpler)
- What about external display mirroring - should performance mode affect that? (Probably not in scope)
