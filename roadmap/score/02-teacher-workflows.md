# Teacher-Student Sheet Music Workflows

Features that leverage Cadenza's unique teacher-student relationship. Things forScore can't do because it's single-user.

## Current State

Cadenza already has:
- Teacher/student user types
- Piece model with `sharedFromPieceId` for teacher→student sharing
- Routine/Exercise structure for assignments
- Practice session tracking with reflections
- API endpoints for sharing pieces and assigning routines

The foundation exists. These features build on it.

## Priority 1: Annotated Piece Sharing

### Teacher Marks Up, Student Receives

When a teacher shares a piece with a student, include the teacher's annotations:
- Fingerings the teacher wants the student to use
- Bowings for string players
- Breath marks for wind players
- "Watch out here" warnings
- Practice suggestions written on the score

Student sees teacher's marks as a read-only layer. Student can add their own annotations on a separate layer.

### Annotation Layers by Author

Extend the layer system to track authorship:
- **Teacher layer**: Read-only for student, visible by default
- **Student layer**: Student's own marks
- **Shared layer**: Either can edit (for collaborative work)

When teacher reviews student's piece, they see both layers.

### Annotation Sync

When teacher updates their annotations, student's copy updates. Requires:
- Server storage of annotation data (not just local)
- Push notification or poll for updates
- Conflict resolution (student marks preserved, teacher marks updated)

## Priority 2: Practice Region Marking

### Teacher Defines Practice Sections

Rather than "practice this piece," teacher marks specific regions:
- "Work on measures 17-24 this week"
- "Focus on the coda"
- "Skip the cadenza for now"

Implementation:
- Teacher draws boxes around regions on the PDF
- Labels each region with a name and optional instructions
- Student sees highlighted regions in their assignment

### Exercise Start Page → Exercise Region

The current `Exercise.startPage` field is primitive. Extend to:
```swift
struct ExerciseRegion {
    let pageNumber: Int
    let boundingBox: CGRect  // normalized coordinates
    let label: String?
    let instructions: String?
}
```

Student's practice view could zoom/scroll to the assigned region automatically.

### Progress Per Region

Track practice time per region, not just per piece. Student spends 10 minutes on "measures 17-24" vs. 5 minutes on "coda." Teacher sees breakdown.

## Priority 3: Visual Feedback Loop

### Student Records Problem Spots

Student marks places they're struggling:
- Long-press on a measure → "I'm stuck here"
- Add a voice note: "I can't get this rhythm"
- Flag for teacher attention

Teacher sees flags when reviewing student's piece. Can respond with annotations, voice notes, or video.

### Teacher Leaves Audio/Video Comments

Beyond written annotations:
- Teacher records themselves playing the passage correctly
- Teacher records verbal explanation
- Attached to specific locations in the score

Student taps a marker to hear/watch the teacher's guidance.

### Before/After Recordings

Student records themselves at start of practice week. Records again at end. Teacher compares. Attached to specific pieces/regions.

## Priority 4: Assignment-Driven Navigation

### Assignment as Setlist

When student opens "My Assignment," they get a guided flow:
1. First exercise in routine
2. Automatic navigation to correct page/region
3. Timer starts
4. When timer expires or student marks complete, prompt for next exercise
5. At end, prompt for reflections

This exists in `PracticeSessionView` but could be tighter with sheet music:
- Auto-scroll to `startPage` when exercise begins
- Highlight teacher's focus regions
- Show teacher's annotations for this exercise

### Smart Page Suggestions

If a routine has exercises from the same piece but different pages:
- Exercise 1: Bach Cello Suite, pages 1-2 (Prelude)
- Exercise 2: Bach Cello Suite, pages 5-6 (Sarabande)

Navigation should jump directly. No manual page hunting.

## Priority 5: Shared Repertoire Library

### Teacher's Curated Library

Teacher builds a library of pieces for their studio:
- Standard repertoire for each level
- Etude books
- Scale sheets
- Sight-reading excerpts

New students receive appropriate subset. No need to re-upload for each student.

### Repertoire Progression

Track which pieces a student has learned:
- "In progress" → "Learned" → "Performance ready" → "Memorized"
- Teacher can see progression across all students
- Identify patterns: "Most students struggle with this piece at measure 32"

### Piece-Level Notes (Teacher-Wide)

Teacher notes that apply to all students on a piece:
- "Common mistake: rushing the development section"
- "Good recording to study: Yo-Yo Ma 1997"
- Links to resources

Distinct from per-student annotations.

## Priority 6: Real-Time Lesson Mode

### Screen Sharing During Lessons

During a video lesson (Zoom, FaceTime), teacher and student look at same score:
- Teacher marks up in real-time
- Student sees marks appear live
- Both see same page

Could use Cue-like sync or simpler screen-share annotation overlay.

### Lesson Recording Tied to Score

Record audio from a lesson. Later, scrub through recording and see which page/region was being discussed. Requires timestamp markers.

## Implementation Notes

### Annotations Are Server-First

Annotations live on the server, not just in SwiftData. This is fundamental to teacher-student workflows:
- Teacher creates annotations → synced to server → pushed to student
- Student adds their own annotations → synced to server → visible to teacher
- Cross-device access (teacher's iPad, teacher's Mac, student's iPhone)
- Annotations survive device replacement

Local SwiftData acts as a cache for offline access and fast rendering, but the server is the source of truth.

### Server Data Model

```python
# server/app/models.py

class Annotation(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    piece_id: UUID = Field(foreign_key="piece.id", index=True)
    author_id: int = Field(foreign_key="user.id", index=True)
    layer: str  # "teacher", "student", "shared"
    page_number: int
    type: str  # "drawing", "stamp", "region", "audio_note", "text"
    data: str  # JSON-serialized type-specific content
    s3_key: str | None = None  # for audio/video attachments
    created_at: datetime
    updated_at: datetime
```

### iOS Data Model (Cache)

```swift
// Cadenza/Models/Annotation.swift

@Model
final class Annotation {
    @Attribute(.unique) var id: UUID
    var pieceId: UUID
    var authorId: Int
    var layer: AnnotationLayer
    var pageNumber: Int
    var type: AnnotationType
    var data: Data  // JSON-encoded, mirrors server
    var localAudioPath: String?  // cached audio file
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus  // .synced, .pendingUpload, .pendingDownload
}
```

### Sync Strategy

1. **On piece open**: Fetch latest annotations from server, merge with local cache
2. **On annotation create/edit**: Save locally with `syncStatus = .pendingUpload`, then POST to server
3. **On server push**: Receive notification, fetch updated annotations, update local cache
4. **Offline support**: Queue changes locally, sync when connection restored
5. **Conflict resolution**: Server timestamp wins for same annotation; different annotations coexist

### Server Endpoints

```
GET    /pieces/{id}/annotations              # all annotations for a piece
POST   /pieces/{id}/annotations              # create annotation
PUT    /annotations/{id}                     # update annotation
DELETE /annotations/{id}                     # delete annotation
POST   /annotations/{id}/attachment          # upload audio/video (returns S3 presigned URL)
GET    /annotations/{id}/attachment          # download audio/video (returns S3 presigned URL)
GET    /pieces/{id}/annotations/since/{ts}   # delta sync since timestamp
```

### Push Notifications

When teacher updates annotations:
1. Server sends push notification to student's device
2. App wakes, fetches `/pieces/{id}/annotations/since/{lastSync}`
3. Merges new annotations into local cache
4. UI refreshes if piece is open

Use silent push for background sync; visible push only for significant events (new audio comment from teacher).

## Success Criteria

A teacher should be able to:
1. Mark up a piece with fingerings, bowings, and practice notes
2. Share the marked-up piece to a student with one tap
3. Assign specific regions for the student to practice this week
4. See where the student is struggling (student's flags + practice time data)
5. Leave audio/video feedback on specific passages
6. Update their annotations and have students see changes automatically

A student should be able to:
1. Open their assignment and immediately see what to practice
2. See teacher's markings as they practice
3. Add their own markings without affecting teacher's layer
4. Flag trouble spots for teacher review
5. Record themselves and share with teacher
6. Navigate efficiently through multi-piece routines
