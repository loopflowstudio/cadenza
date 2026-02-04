# Score Review

## What was implemented
- Made performance mode session-only by keeping it in view state instead of persisted storage.
- Added teardown cleanup for PDF page-change notifications to avoid observer leaks.
- Ensured performance mode blocks center taps as well as drag/magnify gestures.

## Key choices
- Keep performance mode non-persistent to match the intended “session-only” behavior.
- Use `dismantleUIView` to unregister PDFKit observers in the correct SwiftUI lifecycle hook.
- Consume center taps in performance mode so PDFView doesn’t receive accidental interactions.

## How it fits together
The viewer still renders either PDFKit or the half-page image view, with tap zones layered on top. Performance mode overlays remain the gesture gatekeeper, but now also swallow center taps, while PDFKit observer cleanup happens when the view is dismantled.

## Risks and bottlenecks
- PDFKit rendering and image thumbnails remain uncached; heavy scores could still feel sluggish.
- Half-page mode still relies on `thumbnail` rendering, which may blur at extreme zoom.

## What’s not included
- No changes to half-page divider behavior or margin controls beyond existing implementation.
- No new caching or prefetching for half-page thumbnails.
