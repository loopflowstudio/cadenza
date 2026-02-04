# PR 1: Practice Video Submissions

Students can record a video of themselves practicing and submit it for teacher review.

## Problem

Music teachers can’t see how students practice between lessons. Text reflections help, but teachers need to observe technique, posture, and timing. A minimal video submission flow closes that gap.

## User Stories

**Student**: "I just finished practicing this passage. I want my teacher to see what I’m doing wrong."

**Teacher**: "I want to see how my students are actually practicing between lessons, not just hear about it."

## Approach

Ship a minimal record → upload → review flow. No messaging, timestamps, or threading (PR2+).

## What Ships

### Server

New model: `VideoSubmission`

```python
class VideoSubmission(SQLModel, table=True):
    __tablename__ = "video_submissions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)

    # Context (all optional, but at least one should be set)
    exercise_id: UUID | None = Field(default=None, foreign_key="exercises.id")
    piece_id: UUID | None = Field(default=None, foreign_key="pieces.id")
    session_id: UUID | None = Field(default=None, foreign_key="practice_sessions.id")

    # Video
    s3_key: str
    thumbnail_s3_key: str | None = None
    duration_seconds: int

    # Student notes
    notes: str | None = None

    # Review tracking
    reviewed_at: datetime | None = None
    reviewed_by_id: int | None = Field(default=None, foreign_key="users.id")

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
```

Endpoints:

```python
# Create submission + upload URLs
POST /video-submissions
Body: { exercise_id?, piece_id?, session_id?, duration_seconds, notes? }
Returns: { submission, upload_url, thumbnail_upload_url }

# Fresh upload URLs (retry)
GET /video-submissions/{id}/upload-url

# List own submissions
GET /video-submissions
Query: ?exercise_id=...&piece_id=...

# Teacher: list student submissions
GET /students/{id}/video-submissions
Query: ?pending_review=true

# Teacher: mark reviewed
PATCH /video-submissions/{id}/reviewed

# Playback URL
GET /video-submissions/{id}/video-url
```

### iOS

Model:

```swift
@Model
final class VideoSubmission: Identifiable {
    @Attribute(.unique) var id: UUID
    var userId: Int
    var exerciseId: UUID?
    var pieceId: UUID?
    var sessionId: UUID?

    var s3Key: String
    var thumbnailS3Key: String?
    var durationSeconds: Int

    var notes: String?
    var reviewedAt: Date?
    var reviewedById: Int?

    var createdAt: Date

    // Local-only
    var localVideoPath: String?
    var localThumbnailPath: String?
    @Transient var uploadStatus: UploadStatus = .pending
}

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case uploaded
    case failed
}
```

Service:

```swift
protocol VideoSubmissionServiceProtocol {
    func createSubmission(
        exerciseId: UUID?,
        pieceId: UUID?,
        sessionId: UUID?,
        durationSeconds: Int,
        notes: String?,
        localVideoURL: URL?,
        localThumbnailURL: URL?
    ) async throws -> VideoSubmission

    func uploadVideo(
        localURL: URL,
        thumbnailURL: URL?,
        for submission: VideoSubmission
    ) async throws

    func getMySubmissions(pieceId: UUID?, exerciseId: UUID?) async throws -> [VideoSubmissionDTO]
    func getStudentSubmissions(studentId: Int, pendingReviewOnly: Bool, pieceId: UUID?, exerciseId: UUID?) async throws -> [VideoSubmissionDTO]
    func markReviewed(submissionId: UUID) async throws -> VideoSubmissionDTO
    func getPlaybackUrls(submissionId: UUID) async throws -> VideoSubmissionVideoUrlResponse
}
```

Views:

```swift
ExerciseCompletionView
  └── VideoRecordingSheet

StudentDetailView
  └── PendingVideosSection

VideoPlayerView
```

### Recording UI

- Start/stop button
- 3-minute max with countdown
- Preview before submitting
- Optional notes field
- Generates thumbnail from first frame

## S3 Structure

```
cadenza/videos/{user_id}/{submission_id}.mp4
cadenza/videos/{user_id}/{submission_id}_thumb.jpg
```

## Key Decisions

1. **Two-phase submission**: create metadata → upload via presigned URLs.
2. **Local upload status only**: server doesn’t track pending state.
3. **Duration required at creation**: client reads asset duration immediately after recording.
4. **Teacher auth**: teacher can view/review iff `student.teacher_id == current_user.id`.
5. **3-minute max, 720p**: enforced client-side.
6. **Entry point after exercise completion**: no recording during active practice.

## What Was Implemented

- VideoSubmission model, endpoints, and S3 helpers for create/list/review/playback.
- iOS recording flow with camera preview, upload service, and teacher review UI.
- Mock API data for video submissions to support previews/UI tests.

## Risks and Bottlenecks

- Upload runs in the recording sheet; large uploads may feel slow.
- Offline creation is not implemented; create requires connectivity.
- Thumbnail/playback URLs fetched per row may add request overhead on large lists.

## Out of Scope (PR2+)

- Teacher responses and messaging
- Timestamped markers
- Score linking
- Progress timeline
- Push notifications
- Editing/trimming

## Test Plan

Server:
```python
def test_create_video_submission():
    # Student can create submission
    # Returns presigned upload URLs
    # Submission appears in GET /video-submissions

def test_create_submission_requires_duration():
    # 422 if duration_seconds missing

def test_teacher_views_student_submissions():
    # Teacher can see their student's submissions
    # Returns submissions for that student only

def test_non_teacher_cannot_view_other_submissions():
    # 403 if requesting user is not student's teacher

def test_mark_reviewed():
    # Teacher can mark submission as reviewed
    # reviewed_at and reviewed_by_id are set
    # Student cannot mark their own as reviewed

def test_get_playback_url():
    # Owner can get playback URL
    # Teacher can get student's playback URL
    # Random user cannot get playback URL
```

iOS Previews:
```swift
#Preview("Recording Sheet") { ... }
#Preview("Pending Videos") { ... }
#Preview("Video Player") { ... }
```

## Done When

1. `python dev.py test --server` passes with new video submission tests
2. Student completes exercise → sees “Record Video” button
3. Student records 30-second video, adds note, submits
4. Video uploads to S3
5. Teacher sees video in student profile with thumbnail
6. Teacher plays video
7. Teacher marks as reviewed
8. Student sees “Reviewed by Teacher” status
