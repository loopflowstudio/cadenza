# PR 4: Score-Linked Video

Videos and markers can reference specific pages/measures in the sheet music.

## User Stories

**Teacher**: "I want to link my feedback marker to measure 17 so the student can see exactly where on the score I mean."

**Student**: "When I'm looking at page 3 of the sheet music, I want to see all the videos about that page."

## Builds On

PR3: Timestamped Markers

## What Ships

### Server

Extended fields on existing models:

```python
# VideoSubmission: add optional page reference
page_number: int | None = None  # page student was practicing

# Message: add optional page reference
page_number: int | None = None  # page teacher is discussing

# VideoMarker: add optional page/measure reference
page_number: int | None = None
measure_number: int | None = None  # future: requires OMR
```

New endpoint:

```python
# Get videos/markers for a specific page of a piece
GET /pieces/{id}/videos?page=3
Returns: { submissions: [...], markers: [...] }
```

### iOS

Updated models with page fields.

New views:

```swift
// Sheet music view with video sidebar
SheetMusicView
  ├── PDFKitView (existing)
  └── VideoSidebarButton  // "3 videos about this page"

// Video list for current page
PageVideoListSheet
  ├── VideoSubmission thumbnails for this page
  └── Markers referencing this page

// Recording now captures current page
VideoRecordingSheet
  └── pageNumber passed from SheetMusicView
```

### Recording While Viewing Score

1. Student viewing page 3 of sheet music
2. Taps "Record Practice Video"
3. Camera UI opens with page number captured
4. Student records themselves playing that page
5. Submission automatically tagged with `page_number: 3`
6. Teacher later sees this submission linked to page 3

### Markers Link to Score

When teacher adds marker:
1. Option to link to page (default: page from submission)
2. Option to specify measure number (manual entry for now; OMR later)

When student views marker:
1. "View in Score" button
2. Opens sheet music, navigates to that page
3. (Future: highlights measure)

## Done When

1. Student is viewing page 3 of "Bach Cello Suite"
2. Student taps "Record Practice" → records video
3. Submission has `page_number: 3`
4. Teacher reviews video, adds marker at 0:15
5. Teacher links marker to page 3, measure 17
6. Student opens sheet music for page 3
7. Student sees "1 video" indicator
8. Student opens video list, sees their submission
9. Student sees marker says "measure 17—watch the C#"
10. Student taps "View in Score" → jumps to page 3

## Future: OMR Integration

When notation parsing ships (see roadmap/score/03-notation-parsing.md):
- Marker could reference specific notes, not just measures
- Video playback could highlight current measure in score
- "Jump to measure 17" becomes precise

For now, measure numbers are teacher-entered integers—useful but not magic.

## Test Plan

```python
def test_submission_with_page():
    # Student can create submission with page_number
    # Submission returned in GET /pieces/{id}/videos?page=3

def test_marker_with_page_measure():
    # Teacher can add marker with page_number and measure_number
    # Marker returned in piece videos endpoint

def test_videos_for_page():
    # GET /pieces/{id}/videos?page=3 returns correct submissions
```
