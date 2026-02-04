# Video Practice Submissions

## Problem

Music teachers can't see how students actually practice between lessons. Students describe problems verbally, but teachers need to observe technique, posture, and timing directly. The existing text-based reflection field in ExerciseSession captures thoughts but not the physical act of playing.

Students need a way to record themselves practicing and get direct feedback. Teachers need to review videos efficiently and mark them as addressed.

## Approach

Ship a minimal video submission flow: record, upload, review. No messaging, no timestamps, no threading—that's PR2+.

**Server**: New `VideoSubmission` model with S3 storage. Presigned URLs for upload (student) and playback (both). Teacher-only mark-as-reviewed endpoint.

**iOS**: Recording UI via AVFoundation. Local persistence with background upload. Teacher sees pending videos in student detail view.

## Alternatives considered

| Approach | Tradeoff | Why not |
|----------|----------|---------|
| Direct file upload (server receives bytes) | Simpler server code | Videos are large (50MB). Presigned URLs let clients upload directly to S3, avoiding server memory pressure and timeouts. |
| No thumbnail | Fewer moving parts | Thumbnails make video lists scannable. Teachers reviewing 10+ submissions need visual context. Worth the complexity. |
| Upload video immediately, create submission on success | Atomic operation | Poor offline experience. Students practice where WiFi is spotty. Record now, upload later is essential. |
| Store videos in app Documents directory forever | Simple | Storage bloat. Videos should be deleted after successful upload + server confirmation. |

## Key decisions

**1. Two-phase submission: create metadata, then upload**

Client creates submission (gets presigned URLs), uploads video, confirms upload. Server stores `s3_key` immediately—it doesn't verify the file exists until playback. If upload fails, client retries with same presigned URL or requests new ones.

This matches the Piece upload pattern already in the codebase (`server/app/s3.py:86` - `generate_upload_url`).

**2. Local upload status tracking, not server sync**

`uploadStatus` is iOS-only (`@Transient` equivalent—not persisted to server). Server doesn't know or care if upload is pending; it just stores the s3_key. iOS tracks `.pending`, `.uploading`, `.uploaded`, `.failed` locally.

Why: Simplicity. Server doesn't need to track client state. If student's phone dies mid-upload, they can retry from the local video file.

**3. No duration_seconds on create—set after upload**

Original spec requires `duration_seconds` at creation time. But we don't know duration until the video is recorded. Options:
- Require duration at creation → client must read video metadata first
- Make duration optional → complicates queries ("show videos over 1 minute")
- Set duration after upload → extra endpoint

Decision: Require duration at creation. AVFoundation provides `CMTime` duration immediately after recording. Client reads metadata before API call. This keeps the model clean and enables future filtering.

**4. Teacher authorization via student.teacher_id check**

Teacher can view/review a student's videos iff `student.teacher_id == current_user.id`. Same pattern as existing `/students/{id}/pieces` endpoint.

**5. 3-minute max, 720p, ~50MB limit**

Per roadmap spec. Enforced client-side during recording. Server doesn't validate file size (S3 handles large uploads fine), but iOS shows countdown and stops at 180 seconds.

**6. Recording entry point: after exercise completion**

Students record after marking an exercise complete, not during. ExerciseCompletionView (new) shows "Record Video" button. This keeps the practice flow uninterrupted—play first, reflect/record second.

Alternative considered: record button always visible during exercise. Rejected because it encourages recording while playing, which is awkward and produces worse videos.

## Scope

**In scope:**
- VideoSubmission model with all fields from roadmap spec
- S3 upload/download URLs for video and thumbnail
- CRUD endpoints: create, list own, list student's (teacher), mark reviewed, get playback URL
- iOS recording UI with AVFoundation
- iOS local persistence with upload status tracking
- Background upload when connectivity returns
- Teacher's pending videos view
- Basic video playback (AVPlayer, no custom controls)

**Out of scope (PR2+):**
- Teacher responses (that's messaging, PR2)
- Timestamped markers (PR3)
- Push notifications (PR2)
- Score linking (PR4)
- Progress timeline (PR5)
- Video editing/trimming
- Multiple recordings per submission
- Re-recording after submission

## Server implementation

### Model

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

### S3 helpers

```python
def get_video_s3_key(user_id: int, submission_id: UUID) -> str:
    return f"{_get_path_prefix()}cadenza/videos/{user_id}/{submission_id}.mp4"

def get_video_thumbnail_s3_key(user_id: int, submission_id: UUID) -> str:
    return f"{_get_path_prefix()}cadenza/videos/{user_id}/{submission_id}_thumb.jpg"

def generate_video_upload_url(user_id: int, submission_id: UUID) -> dict:
    # Same pattern as generate_upload_url for pieces
    s3_key = get_video_s3_key(user_id, submission_id)
    presigned_url = s3_client.generate_presigned_url(
        "put_object",
        Params={"Bucket": bucket, "Key": s3_key, "ContentType": "video/mp4"},
        ExpiresIn=3600,
    )
    return {"url": presigned_url, "s3_key": s3_key, "expires_in": 3600}
```

### Endpoints

```python
# Create submission and get upload URLs
POST /video-submissions
Body: { exercise_id?, piece_id?, session_id?, duration_seconds, notes? }
Returns: { submission, upload_url, thumbnail_upload_url }

# Get fresh upload URLs (for retry)
GET /video-submissions/{id}/upload-url
Returns: { upload_url, thumbnail_upload_url }

# List own submissions
GET /video-submissions
Query: ?exercise_id=...&piece_id=...

# Teacher: list student's submissions
GET /students/{id}/video-submissions
Query: ?pending_review=true

# Teacher: mark as reviewed
PATCH /video-submissions/{id}/reviewed
Sets: reviewed_at = now, reviewed_by_id = current_user.id

# Get playback URL (any authorized viewer)
GET /video-submissions/{id}/video-url
Returns: { video_url, thumbnail_url, expires_in }
```

## iOS implementation

### Model

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

    // Local-only (not synced to server)
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

### Recording flow

1. ExerciseCompletionView shows "Record Video" button
2. Tap opens VideoRecordingSheet (full-screen camera)
3. AVCaptureSession captures video + audio
4. Countdown shows time remaining (3:00 max)
5. Stop → show preview with playback
6. Optional notes field
7. Submit → save video locally, create submission via API, begin background upload
8. Sheet dismisses, exercise completion continues

### VideoRecordingSheet

```swift
struct VideoRecordingSheet: View {
    let exerciseId: UUID?
    let pieceId: UUID?
    let sessionId: UUID?
    let onSubmit: (VideoSubmission) -> Void

    @State private var isRecording = false
    @State private var recordedVideoURL: URL?
    @State private var elapsedSeconds = 0
    @State private var notes = ""

    // AVFoundation state
    @StateObject private var cameraManager = CameraManager()
}
```

### Upload service

```swift
class VideoUploadService {
    func uploadPendingSubmissions() async {
        // Called on app foreground and network reachability change
        let pending = fetchPendingSubmissions()
        for submission in pending {
            await uploadSubmission(submission)
        }
    }

    private func uploadSubmission(_ submission: VideoSubmission) async {
        guard let localPath = submission.localVideoPath,
              let localURL = URL(string: localPath),
              FileManager.default.fileExists(atPath: localURL.path) else {
            return
        }

        submission.uploadStatus = .uploading

        do {
            // Get presigned URL
            let urls = try await apiClient.getVideoUploadUrl(submissionId: submission.id, token: token)

            // Upload video
            try await uploadFile(localURL, to: urls.uploadUrl)

            // Upload thumbnail if exists
            if let thumbPath = submission.localThumbnailPath,
               let thumbURL = URL(string: thumbPath) {
                try await uploadFile(thumbURL, to: urls.thumbnailUploadUrl)
            }

            // Clean up local files
            try? FileManager.default.removeItem(at: localURL)

            submission.uploadStatus = .uploaded
            submission.localVideoPath = nil
            submission.localThumbnailPath = nil
        } catch {
            submission.uploadStatus = .failed
        }
    }
}
```

### Teacher view

In StudentDetailView, add section:

```swift
struct PendingVideosSection: View {
    let studentId: Int
    @State private var submissions: [VideoSubmission] = []

    var body: some View {
        Section("Pending Videos") {
            ForEach(submissions.filter { $0.reviewedAt == nil }) { submission in
                VideoSubmissionRow(submission: submission)
            }
        }
    }
}

struct VideoSubmissionRow: View {
    let submission: VideoSubmission

    var body: some View {
        NavigationLink {
            VideoPlayerView(submission: submission)
        } label: {
            HStack {
                AsyncImage(url: thumbnailURL) { ... }
                VStack(alignment: .leading) {
                    Text(exerciseTitle)
                    Text(submission.createdAt, style: .relative)
                        .font(.caption)
                }
            }
        }
    }
}
```

## Test plan

### Server tests

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

### iOS previews

```swift
#Preview("Recording Sheet") {
    VideoRecordingSheet(
        exerciseId: UUID(),
        pieceId: nil,
        sessionId: nil,
        onSubmit: { _ in }
    )
}

#Preview("Pending Videos") {
    PendingVideosSection(studentId: 1)
        .modelContainer(PreviewContainer.shared)
}

#Preview("Video Player") {
    VideoPlayerView(submission: .preview)
}
```

## Done when

1. `python dev.py test --server` passes with new video submission tests
2. Student completes exercise → sees "Record Video" button
3. Student records 30-second video, adds note, submits
4. Video uploads to S3 (verify in AWS console or via presigned URL)
5. Teacher opens student detail → sees video in "Pending Videos"
6. Teacher taps video → plays in VideoPlayerView
7. Teacher marks as reviewed → video no longer shows as pending
8. Student's submission shows "Reviewed" status

## Migration notes

New table `video_submissions`. No existing data to migrate. SQLModel creates table on startup.

## Future considerations (not this PR)

- **Push notifications**: Teacher gets notified of new submission. Requires APNs setup.
- **Compression**: Client-side compression before upload. Currently relying on AVFoundation's built-in H.264 encoding.
- **Resumable uploads**: For very large files or spotty connections. S3 multipart upload is an option.
- **Playback caching**: Cache recently viewed videos locally. Low priority—presigned URLs work fine.
