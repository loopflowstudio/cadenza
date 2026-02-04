# PR 3: Timestamped Markers

Teachers can leave feedback at specific moments in a video.

## User Stories

**Teacher**: "At exactly 0:23, the student rushes. I want to mark that moment with a note."

**Student**: "I want to see exactly where in my video my teacher left feedback."

## Builds On

PR2: Teacher Video Response

## Why This Matters

Generic feedback: "You're rushing in the middle section."

Timestamped feedback: "At 0:23, right when you hit the C#, you speed up. Watch here."

The second is dramatically more useful. This is what in-person teaching provides naturally—pointing at the exact moment. Timestamps recreate that precision asynchronously.

## What Ships

### Server

New model: `VideoMarker`

```python
class VideoMarker(SQLModel, table=True):
    __tablename__ = "video_markers"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    message_id: UUID = Field(foreign_key="messages.id", index=True)
    author_id: int = Field(foreign_key="users.id")

    timestamp_ms: int  # position in video
    text: str
    marker_type: str = "feedback"  # "feedback", "question", "praise"

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
```

Note: Markers are attached to messages, not directly to submissions. This allows:
- Teacher marks a moment in student's original video (marker on the implicit "original" message)
- Teacher marks a moment in their own response video (for student to study)
- Student marks a moment asking "what am I doing wrong here?"

For simplicity in PR3, we'll treat the original submission video as `message_id = null` (or create an implicit message). Refine in implementation.

New endpoints:

```python
# Get markers for a video (submission or message)
GET /video-submissions/{id}/markers
GET /messages/{id}/markers

# Add marker
POST /video-submissions/{id}/markers
POST /messages/{id}/markers
Body: { timestamp_ms, text, marker_type? }

# Delete marker
DELETE /markers/{id}
```

### iOS

New model: `VideoMarker`

```swift
@Model
final class VideoMarker: Identifiable {
    @Attribute(.unique) var id: UUID
    var messageId: UUID?  // null for submission's original video
    var submissionId: UUID?  // for querying
    var authorId: Int

    var timestampMs: Int
    var text: String
    var markerType: String

    var createdAt: Date
}
```

Updated views:

```swift
// Video player with marker overlay
VideoPlayerView
  ├── AVPlayerViewController  // or custom player
  ├── MarkerTimeline  // dots on the scrubber showing marker positions
  │     └── MarkerDot  // tap to jump and show text
  └── MarkerPopover  // shows marker text when viewing

// Add marker mode
VideoPlayerView (marking mode)
  ├── "Tap to add marker" instruction
  ├── AddMarkerSheet  // appears on tap, input text, select type
  └── MarkerPreviewList  // show pending markers before save
```

### Marker Timeline UX

The video scrubber shows colored dots at marker positions:
- Yellow dot: feedback marker
- Blue dot: question marker
- Green dot: praise marker

Tap dot → video jumps to that timestamp, popover shows text.

While paused, teacher can tap anywhere on video to add marker at current position.

### Mobile Recording Workflow

When teacher is watching on mobile and wants to add marker:
1. Pause video at moment of interest
2. Tap "Add Marker" button
3. Sheet slides up with:
   - Current timestamp displayed (e.g., "0:23")
   - Text field for feedback
   - Type picker (feedback/question/praise)
   - Save button
4. Marker appears immediately on timeline
5. Continue watching, add more markers
6. Markers auto-save (no explicit "submit all" step)

## Done When

1. Teacher watches student's submission video
2. Teacher pauses at 0:23 (where student rushes)
3. Teacher taps "Add Marker"
4. Teacher types "You're speeding up here—try counting 1-2-3-4"
5. Teacher saves marker
6. Teacher continues, adds 2 more markers
7. Student opens submission
8. Student sees 3 dots on video timeline
9. Student taps first dot
10. Video jumps to 0:23, shows teacher's feedback
11. Student plays through, sees remaining markers at their timestamps

## Test Plan

Server:
```python
def test_add_marker():
    # Teacher can add marker to student's submission
    # Marker appears in GET /video-submissions/{id}/markers

def test_marker_on_response():
    # Teacher can add marker to their own response video
    # Student can view but not edit teacher's markers

def test_student_can_add_markers():
    # Student can add markers to their own video (questions)
    # Useful for "what am I doing wrong at 0:45?"

def test_delete_marker():
    # Author can delete their own marker
    # Non-author cannot delete
```

iOS:
- Preview: VideoPlayerView with sample markers on timeline
- Preview: MarkerPopover showing feedback text
- Preview: AddMarkerSheet with form
