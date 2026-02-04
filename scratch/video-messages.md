# video-messages: PR 1 Implementation

This branch implements Practice Video Submissions—the first PR in the [video feedback roadmap](../roadmap/video/00-overview.md).

## What to Build

Students can record a practice video and submit it for teacher review. Teachers see pending videos in their student dashboard and can mark them as reviewed.

## Data Structures

### Server: VideoSubmission

```python
class VideoSubmission(SQLModel, table=True):
    __tablename__ = "video_submissions"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)

    # Context
    exercise_id: UUID | None = Field(foreign_key="exercises.id")
    piece_id: UUID | None = Field(foreign_key="pieces.id")
    session_id: UUID | None = Field(foreign_key="practice_sessions.id")

    # Video
    s3_key: str
    thumbnail_s3_key: str | None = None
    duration_seconds: int
    notes: str | None = None

    # Review
    reviewed_at: datetime | None = None
    reviewed_by_id: int | None = Field(foreign_key="users.id")

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
```

### iOS: VideoSubmission

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
    var uploadStatus: String  // "pending", "uploading", "uploaded", "failed"
}
```

## Key Functions

### Server Endpoints

```python
POST /video-submissions
# Create submission, returns { id, upload_url, thumbnail_upload_url }

GET /video-submissions
# Student's own submissions

GET /students/{id}/video-submissions
# Teacher views student's submissions (requires teacher relationship)

GET /video-submissions/{id}/upload-url
# Get fresh upload URLs if needed

GET /video-submissions/{id}/video-url
# Presigned URL to watch video

PATCH /video-submissions/{id}/reviewed
# Teacher marks as reviewed
```

### iOS Service

```swift
protocol VideoSubmissionServiceProtocol {
    func createSubmission(exerciseId: UUID?, pieceId: UUID?, notes: String?) async throws -> VideoSubmission
    func uploadVideo(localURL: URL, for submission: VideoSubmission) async throws
    func getMySubmissions() async throws -> [VideoSubmission]
    func getStudentSubmissions(studentId: Int) async throws -> [VideoSubmission]
    func markReviewed(submissionId: UUID) async throws
}
```

### iOS Views

```swift
// Recording
VideoRecordingSheet  // camera, record, preview, submit

// Display
VideoSubmissionList  // thumbnails in list
VideoPlayerView  // plays video with controls
PendingReviewBadge  // count indicator for teacher
```

## Constraints

- Max duration: 3 minutes (180 seconds)
- Format: H.264/AAC in MP4
- Resolution: 720p max
- S3 path: `cadenza/videos/{user_id}/{submission_id}.mp4`

## Done When

```bash
# Server tests pass
cd server && python dev.py test

# Verify flow manually:
# 1. Student creates submission → gets upload URL
# 2. Upload video to S3
# 3. Teacher lists student submissions → sees video
# 4. Teacher gets video-url → can play
# 5. Teacher marks reviewed → reviewed_at set
```

## Implementation Order

1. **Server model + endpoints** (this PR)
   - VideoSubmission model
   - S3 helpers for video upload/download
   - CRUD endpoints
   - Tests

2. **iOS model + service** (this PR or next)
   - VideoSubmission SwiftData model
   - VideoSubmissionService
   - API integration

3. **iOS recording UI** (this PR or next)
   - VideoRecordingSheet with AVFoundation
   - Thumbnail generation
   - Upload queue

4. **iOS display UI** (this PR or next)
   - VideoSubmissionList
   - VideoPlayerView
   - Teacher dashboard integration

## Open Questions

- Should we support audio-only submissions? (Probably yes, simpler for some feedback)
- Offline recording queue: how long to retain before giving up? (7 days?)
