# Crop & Margins

Picked from `roadmap/score/01-table-stakes.md` Priority 1: Core Viewing.

## Problem

Scanned PDFs often have excessive whitespace, uneven margins, or slight rotation from imperfect scanning. Musicians need to:
- Crop individual pages to focus on the music
- Adjust margins globally for a document
- De-skew crooked scans

forScore saves crop settings per-page without modifying the original PDF.

## Solution

Add a crop editor that lets users define visible regions per page. The crop settings are stored separately from the PDF and applied at render time.

### Core Features

1. **Per-page crop regions**: Define a rectangle that represents the visible area
2. **Global margin adjustment**: Apply uniform margins to all pages at once
3. **Copy crop to all pages**: Apply one page's crop settings to the entire document
4. **Reset to original**: Clear crop settings for a page or document

### UI Flow

1. User taps a "crop" button in the control bar
2. Enters crop editing mode with draggable handles on current page
3. Adjusts the crop region
4. Options: "Apply to this page", "Apply to all pages", "Cancel"
5. Exits crop mode, returns to normal viewing with crop applied

## Scope

- Crop region editor with draggable corner/edge handles
- Per-page crop storage (local preference, no server sync initially)
- Apply crop at render time without modifying PDF
- Global margin controls (top/bottom/left/right sliders)
- Copy crop settings across pages

### Out of Scope (for now)

- De-skew/rotation correction (more complex, can add later)
- Server sync of crop settings (Phase 2 with annotations)
- Automatic whitespace detection

## Data Model

```swift
struct CropSettings: Codable {
    /// Normalized rect (0-1 range) representing visible area
    var visibleRect: CGRect

    static let full = CropSettings(visibleRect: CGRect(x: 0, y: 0, width: 1, height: 1))
}

struct DocumentCropSettings: Codable {
    /// PDF file identifier (URL or hash)
    var documentId: String
    /// Per-page crop settings, keyed by page index
    var pageSettings: [Int: CropSettings]
    /// Default settings for pages without explicit crop
    var defaultSettings: CropSettings
}
```

Storage: UserDefaults or a local JSON file, keyed by document URL/hash.

## Implementation Notes

### Rendering Cropped Pages

Two approaches:

1. **Image-based**: Render page to image, then crop the image
   - Simpler to implement
   - May lose quality at high zoom
   - Works well with half-page turns (already using images)

2. **Transform-based**: Apply transforms to PDFView
   - Better quality at all zoom levels
   - More complex to coordinate with PDFKit's built-in gestures
   - May conflict with scroll/zoom behavior

Recommend starting with image-based approach since we're already heading that direction for half-page turns. Can optimize later if quality is an issue.

### Crop Editor UI

Use a SwiftUI overlay on top of the PDF view:
- Semi-transparent dimming outside the crop region
- Draggable handles at corners and edges
- Live preview as user adjusts

### Integration with Half-Page Turns

When half-page mode is active, crop applies to each half independently. The crop region is applied before splitting the page into halves.

## Open Questions

- Should we auto-detect and suggest crop regions based on content? (Nice to have, not MVP)
- How do we handle documents where pages have very different content areas? (Per-page is the answer, but UX for managing many pages?)
