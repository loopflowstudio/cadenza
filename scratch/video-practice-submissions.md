# PR 1: Practice Video Submissions

Students can record a video of themselves practicing and submit it for teacher review.

## User Stories

**Student**: "I just finished practicing this passage. I want my teacher to see what I'm doing wrong."

**Teacher**: "I want to see how my students are actually practicing between lessons, not just hear about it."

## What Ships

### Server

New model: `VideoSubmission`

```python
class VideoSubmission(SQLModel, table=True):
    __tablename__ = "video_submissions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)

    # What this video is about
    exercise_id: UUID | None = Field(foreign_key="exercises.id")
    piece_id: UUID | None = Field(foreign_key="pieces.id")  # standalone, not via exercise
    session_id: UUID | None = Field(foreign_key="practice_sessions.id")

    # Video file
    s3_key: str
    thumbnail_s3_key: str | None = None
    duration_seconds: int

    # Optional context from student
    notes: str | None = None  # "I'm having trouble with the fingering here"

    # Review status
    reviewed_at: datetime | None = None
    reviewed_by_id: int | None = Field(foreign_key="users.id")

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
```

New endpoints:

```python
# Student uploads video
POST /video-submissions
Body: { exercise_id?, piece_id?, notes? }
Returns: { id, upload_url, thumbnail_upload_url }

# Get upload URLs (if video needs re-upload)
GET /video-submissions/{id}/upload-url

# Student's own submissions
GET /video-submissions
Query: ?piece_id=...&exercise_id=...

# Teacher views student's submissions
GET /students/{id}/video-submissions
Query: ?piece_id=...&pending_review=true

# Mark as reviewed
PATCH /video-submissions/{id}/reviewed

# Get video playback URL
GET /video-submissions/{id}/video-url
```

### iOS

New model: `VideoSubmission`

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
    var uploadStatus: UploadStatus  // .pending, .uploading, .uploaded, .failed
}
```

New service: `VideoSubmissionService`

```swift
protocol VideoSubmissionServiceProtocol {
    func createSubmission(
        exerciseId: UUID?,
        pieceId: UUID?,
        notes: String?
    ) async throws -> VideoSubmission

    func uploadVideo(
        localURL: URL,
        for submission: VideoSubmission
    ) async throws

    func getMySubmissions(
        pieceId: UUID?,
        exerciseId: UUID?
    ) async throws -> [VideoSubmission]

    func getStudentSubmissions(
        studentId: Int,
        pendingReviewOnly: Bool
    ) async throws -> [VideoSubmission]

    func markReviewed(submissionId: UUID) async throws
}
```

New views:

```swift
// After exercise completion, option to record video
ExerciseCompletionView
  └── VideoRecordingSheet  // camera UI, record button, preview

// In teacher's student list
StudentDetailView
  └── PendingVideosSection  // thumbnails of unreviewed videos

// Video player
VideoPlayerView  // plays video with basic controls
```

### Recording UI

Simple camera interface:
- Portrait or landscape based on device orientation
- Start/stop button
- 3-minute max (show countdown)
- Preview before submitting
- Optional notes field
- Submit button

Use AVFoundation for recording. Generate thumbnail from first frame.

## S3 Structure

```
cadenza/videos/{user_id}/{submission_id}.mp4
cadenza/videos/{user_id}/{submission_id}_thumb.jpg
```

Same presigned URL pattern as pieces.

## Offline Support

1. Recording works offline (saved to Documents directory)
2. Submission created locally with `uploadStatus = .pending`
3. When online, upload video and thumbnail
4. On success, update `uploadStatus = .uploaded`
5. SwiftData syncs submission metadata to server

## Constraints

- **Max duration**: 3 minutes (180 seconds)
- **Format**: H.264/AAC in MP4
- **Resolution**: 720p max
- **File size**: ~50MB max for 3 min at 720p

## Done When

1. Student completes exercise, sees "Record Video" option
2. Student records 30-second video, adds note, submits
3. Video uploads to S3
4. Teacher sees video in student's profile with thumbnail
5. Teacher plays video
6. Teacher marks as reviewed
7. Student sees "Reviewed by Teacher" status

## Test Plan

Server:
```python
def test_create_video_submission():
    # Authenticated student can create submission
    # Returns presigned upload URLs
    # Submission appears in GET /video-submissions

def test_teacher_views_student_submissions():
    # Teacher can see student's submissions
    # Non-teacher cannot see other user's submissions

def test_mark_reviewed():
    # Teacher can mark submission as reviewed
    # reviewed_at and reviewed_by_id are set
```

iOS:
- Preview: VideoRecordingSheet with mock camera
- Preview: PendingVideosSection with sample thumbnails
- Preview: VideoPlayerView with sample video
