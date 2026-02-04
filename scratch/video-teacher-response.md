# PR 2: Teacher Video Response

Teachers can respond to student video submissions with their own videos and text.

## Problem

After PR1, students can submit practice videos—but there's no way for teachers to respond. The submission flow ends at "reviewed" status, a binary flag that tells students nothing about what they did well or what to fix.

Music teaching is fundamentally about dialogue: student plays, teacher responds with specific feedback, student adjusts. Video captures the playing; now we need to capture the feedback.

**Who benefits:**
- Teachers: can provide async feedback with the same precision as in-person lessons
- Students: get actionable, specific feedback instead of a checkmark

**Why now:** PR1 infrastructure is in place. Adding messages is a natural extension that unlocks the core value proposition of video-based teaching.

## Approach

Add a `Message` model that attaches to submissions. Each message can contain text, video, or both. Messages form a thread—student submits, teacher responds, student can ask follow-up questions.

**No push notifications in this PR.** Notifications add significant complexity (APNs setup, device tokens, notification service) that would triple the scope. Students and teachers can check the app for new messages; push notifications become PR2.5 once the core flow works.

**No unread counts in this PR.** Unread state requires tracking per-user-per-message read status, which is straightforward but adds scope. Focus first on the ability to send and receive messages at all. Unread indicators become PR2.5 alongside notifications.

## Alternatives Considered

| Approach | Tradeoff | Why Not |
|----------|----------|---------|
| Single response field on VideoSubmission | Simpler model, no new table | Can't have back-and-forth dialogue; teacher can only respond once |
| Full messaging system (inbox, contacts) | Generic, reusable | Over-engineered; we specifically need submission-attached feedback, not arbitrary messaging |
| Video-only responses (no text) | Simpler UI | Teachers often want to leave quick text notes without recording video |
| Push notifications in this PR | Better UX for message awareness | Significantly more infrastructure (APNs, device tokens, notification service); can layer on after core flow works |

## Key Decisions

### Messages belong to submissions, not conversations

The roadmap spec shows `submission_id` as the foreign key, and that's correct. Each video submission is its own conversation. There's no need for a separate "conversation" or "thread" entity—the submission itself is the thread anchor.

This follows the wave principle of building toward timestamped markers (PR3), which will attach to messages. The hierarchy is: Submission → Message → Marker.

### Teacher or student can send messages

Authorization: you can send a message if you're either:
1. The student who created the submission, or
2. The teacher of that student

This enables the back-and-forth dialogue that makes video feedback useful. A student asks "what am I doing wrong at 0:45?" and the teacher can respond.

### Video messages use same S3 pattern as submissions

Reuse the presigned URL flow from PR1:
- Client requests message creation with `include_video: true`
- Server returns message ID + presigned upload URLs
- Client uploads video directly to S3
- S3 path: `cadenza/videos/{user_id}/messages/{message_id}.mp4`

This keeps video handling consistent and avoids building new upload infrastructure.

### Text and video can coexist in one message

A teacher might record a video demonstrating technique AND write "Notice how I keep my wrist relaxed" as text. These belong together as one message, not two separate messages.

The schema allows `text` and `video_s3_key` to both be set. At least one must be non-null.

### No read receipts or unread counts yet

The spec mentions unread indicators, but implementing them properly requires:
- Tracking which user has read which message
- Aggregating unread counts across submissions
- Updating UI badges in real-time

This is valuable but adds complexity. Ship the core send/receive flow first, then add read tracking as a fast follow.

## Scope

**In scope:**
- Message model with text and/or video content
- Create message endpoint with optional video upload
- List messages for a submission
- Get video playback URL for message videos
- iOS Message model and service
- VideoSubmissionDetailView with message thread
- ComposeBar for sending text/video replies

**Out of scope (PR2.5 or later):**
- Push notifications
- Unread counts and badges
- Read receipt tracking (`read_at` field exists but isn't used yet)
- Message editing or deletion
- Rich text formatting

## Data Model

### Server

```python
class Message(SQLModel, table=True):
    __tablename__ = "messages"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    submission_id: UUID = Field(foreign_key="video_submissions.id", index=True)
    sender_id: int = Field(foreign_key="users.id")

    # Content (at least one required)
    text: Optional[str] = None
    video_s3_key: Optional[str] = None
    video_duration_seconds: Optional[int] = None
    thumbnail_s3_key: Optional[str] = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_serializer("created_at")
    def serialize_datetime(self, dt: datetime, _info):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

    @field_serializer("id", "submission_id")
    def serialize_uuid(self, val: UUID, _info):
        return str(val)
```

### iOS

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

    // Local-only upload state
    var localVideoPath: String?
    var localThumbnailPath: String?
    @Transient var uploadStatus: UploadStatus = .pending
}
```

## API Endpoints

```python
# List messages for a submission
GET /video-submissions/{submission_id}/messages
Returns: [MessageDTO]
Auth: submission owner OR their teacher

# Create a message
POST /video-submissions/{submission_id}/messages
Body: { text?: str, include_video?: bool, video_duration_seconds?: int }
Returns: MessageCreateResponse (includes upload URLs if include_video=true)
Auth: submission owner OR their teacher
Validation: at least one of text or include_video must be provided

# Get video playback URL for a message
GET /messages/{message_id}/video-url
Returns: { video_url: str, thumbnail_url: str?, expires_in: int }
Auth: participant in the submission thread
```

## S3 Structure

```
cadenza/videos/{user_id}/messages/{message_id}.mp4
cadenza/videos/{user_id}/messages/{message_id}_thumb.jpg
```

Separate from submission videos to keep paths clean and allow different retention policies if needed.

## iOS Views

```
VideoSubmissionDetailView
├── VideoPlayerSection (student's original submission)
├── SubmissionInfoSection (notes, exercise context)
├── MessageList
│   └── MessageRow (text bubble and/or video thumbnail)
└── ComposeBar
    ├── TextField for text
    ├── Video record button
    └── Send button

VideoRecordingSheet (reuse from PR1)
```

## Test Plan

### Server Tests

```python
def test_create_text_message():
    # Teacher sends text-only message
    # Message appears in GET /video-submissions/{id}/messages

def test_create_video_message():
    # Teacher sends video message
    # Returns presigned upload URLs
    # video_s3_key is set after creation

def test_create_combined_message():
    # Teacher sends text + video in one message
    # Both fields populated

def test_student_can_reply():
    # Student sends message on their own submission
    # Message appears in thread

def test_non_participant_cannot_message():
    # Random user cannot send message to submission
    # 403 Forbidden

def test_list_messages_authorization():
    # Owner can list messages
    # Teacher can list messages
    # Random user gets 403

def test_message_video_url():
    # Participant can get video playback URL
    # Non-participant gets 403

def test_message_requires_content():
    # Empty message (no text, no video) returns 422
```

### iOS Previews

```swift
#Preview("Message Thread") {
    VideoSubmissionDetailView(submission: .previewWithMessages)
}

#Preview("Compose Bar") {
    ComposeBar(onSend: { _, _ in })
}

#Preview("Text Message") {
    MessageRow(message: .previewText)
}

#Preview("Video Message") {
    MessageRow(message: .previewVideo)
}
```

## Done When

1. `python dev.py test --server` passes with new message tests
2. Teacher opens student submission in VideoSubmissionDetailView
3. Teacher taps text field, types "Great progress on the rhythm!"
4. Teacher taps send → message appears in thread
5. Teacher taps video button → VideoRecordingSheet opens
6. Teacher records 15-second video demonstrating fingering
7. Teacher sends → video uploads, message with thumbnail appears in thread
8. Student opens same submission → sees teacher's messages
9. Student types follow-up question, sends → appears in thread
10. Both users can tap video thumbnail to play teacher's video

## Migration

Add `messages` table:

```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY,
    submission_id UUID NOT NULL REFERENCES video_submissions(id),
    sender_id INTEGER NOT NULL REFERENCES users(id),
    text TEXT,
    video_s3_key TEXT,
    video_duration_seconds INTEGER,
    thumbnail_s3_key TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_messages_submission_id ON messages(submission_id);
```
