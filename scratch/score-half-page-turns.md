# Half-Page Turns

Picked from `roadmap/score/01-table-stakes.md` Priority 1: Core Viewing.

## Problem

In portrait orientation, a full page turn means the musician loses sight of the current page entirely. For pieces with awkward page breaks (e.g., a phrase continuing across pages), this forces memorization or an uncomfortable pause.

## Solution

Show half of the current page and half of the next page simultaneously. The musician sees:
- Bottom half of page N
- Top half of page N+1

This provides visual continuity across page breaks.

## Scope

- Toggle for half-page turn mode (local preference, no server sync needed)
- Display mode that shows two half-pages vertically stacked
- Page navigation advances by half-page increments in this mode
- Works with existing tap zones and control bar

## Open Questions

- Should half-page mode affect zoom behavior? (Probably auto-fit to show both halves)
- Portrait only, or also landscape? (forScore does portrait only)
- How does this interact with pinch-to-zoom? (Likely disable in half-page mode)

## Implementation Notes

This is a display mode change in `EnhancedSheetMusicViewer`. The PDFKit `PDFView` doesn't natively support half-page rendering, so we'll need to:

1. Use `PDFPage.thumbnail(of:for:)` or draw into a custom view
2. Calculate visible regions for each half-page
3. Composite two half-page images vertically

Or alternatively, use `PDFView`'s page display but crop/position it within a container view.
