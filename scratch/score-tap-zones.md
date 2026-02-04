# Tap Zones for Page Turning

Extracted from `roadmap/score/01-table-stakes.md` Priority 2: Page Turning.

## Problem

Musicians can't turn pages manually while playing. Tap zones provide the simplest fallback for hands-free page navigation.

## Scope

Implement tap zones on the sheet music view:
- Tap left edge → previous page
- Tap right edge → next page
- Center area remains for pan/zoom interactions

## Design Considerations

### Zone Layout

Standard approach: divide screen into thirds horizontally.
- Left third: previous page
- Right third: next page
- Center third: normal interactions (pan, zoom, tap to show controls)

### Visual Feedback

Options:
1. **No visual indication** - cleaner, but discoverable only through exploration
2. **Subtle highlight on tap** - brief flash to confirm the tap registered
3. **Always-visible zones** - visual guides showing tap areas (too cluttered?)

Recommendation: Option 2 - brief visual feedback on tap, no persistent indicators.

### Interaction with Other Features

- Performance Mode (future): tap zones should still work, possibly as the *only* interaction
- Annotation Mode (future): tap zones disabled when annotating
- Zoom: tap zones work at any zoom level, always relative to screen edges

### Edge Cases

- First page: left tap zone does nothing (or shows subtle "at start" indicator)
- Last page: right tap zone does nothing (or shows subtle "at end" indicator)
- Single-page documents: both zones disabled

## Implementation

Modify `SheetMusicView.swift`:
1. Add tap gesture recognizers for left/right zones
2. Calculate zone boundaries based on view width
3. On tap in zone, call existing page navigation methods
4. Add optional brief visual feedback

## Success Criteria

- User can navigate through multi-page PDF by tapping screen edges
- Tap zones don't interfere with pan/zoom in center area
- Works on both iPhone and iPad
- Works in portrait and landscape orientations
