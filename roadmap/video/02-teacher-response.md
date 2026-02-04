# PR 2: Teacher Video Response

Teachers can respond to student video submissions with their own videos and text.

## User Stories

**Teacher**: "I watched my student's video. I want to record a quick response showing the correct fingering."

**Student**: "I submitted my video. I want to see my teacher's feedback."

## Builds On

PR1: Practice Video Submissions

## What Ships

### Server

New model: `Message`

```python
class Message(SQLModel, table=True):
    __tablename__ = "messages"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    submission_id: UUID = Field(foreign_key="video_submissions.id", index=True)
    sender_id: int = Field(foreign_key="users.id")

    # Content (at least one required)
    text: str | None = None
    video_s3_key: str | None = None
    video_duration_seconds: int | None = None
    thumbnail_s3_key: str | None = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    read_at: datetime | None = None
```

New endpoints:

```python
# Get messages for a submission
GET /video-submissions/{id}/messages

# Send a message (teacher or student)
POST /video-submissions/{id}/messages
Body: { text?, video?: bool }  # if video=true, returns upload URL

# Mark message as read
PATCH /messages/{id}/read

# Get video playback URL for message
GET /messages/{id}/video-url
```

Push notifications:
- Student submits video → notify teacher
- Teacher responds → notify student
- Student responds → notify teacher

### iOS

New model: `Message`

```swift
@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID
    var submissionId: UUID
    var senderId: Int

    var text: String?
    var videoS3Key: String?
    var videoDurationSeconds: Int?
    var thumbnailS3Key: String?

    var createdAt: Date
    var readAt: Date?

    // Local-only
    var localVideoPath: String?
    var uploadStatus: UploadStatus
}
```

Updated views:

```swift
// Video submission now shows message thread
VideoSubmissionDetailView
  ├── OriginalVideoSection  // student's submitted video
  ├── MessageList  // all responses
  │     ├── MessageBubble  // text or video thumbnail
  │     └── ...
  └── ComposeBar  // text input + video button

// Compose includes video option
ComposeBar
  └── VideoRecordingSheet  // reuse from PR1
```

### Notification Flow

1. Student submits video → server creates submission
2. Server sends push to teacher: "New video from [Student] - [Exercise Name]"
3. Teacher opens, watches, records response
4. Server sends push to student: "Feedback from [Teacher]"
5. Student opens, watches response
6. Optionally student responds with follow-up video

### Unread Indicator

- Badge on teacher's "Students" tab showing count of unread submissions
- Badge on student's inbox showing count of unread messages
- Messages marked read when opened (not just listed)

## Done When

1. Teacher opens student submission
2. Teacher taps "Reply", records 15-second video explaining fingering
3. Teacher adds text: "Notice how I keep my wrist relaxed"
4. Teacher sends response
5. Student receives push notification
6. Student opens submission, sees teacher's video and text
7. Student marks as read (badge clears)
8. Student can reply with follow-up question/video

## Test Plan

Server:
```python
def test_send_text_message():
    # Teacher can send text reply to submission
    # Message appears in GET /video-submissions/{id}/messages

def test_send_video_message():
    # Teacher can send video reply
    # Returns upload URL
    # After upload, video_s3_key is set

def test_student_can_reply():
    # Student can reply to their own submission thread
    # Non-participant cannot send messages

def test_mark_read():
    # Recipient can mark message as read
    # read_at is set
```

iOS:
- Preview: VideoSubmissionDetailView with sample thread
- Preview: ComposeBar with text input
