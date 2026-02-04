# PR Review: Teacher Video Response

## What was implemented
- Added submission-scoped messages so teachers and students can exchange text and video replies.
- Introduced message upload/playback flows with presigned S3 URLs for message videos and thumbnails.
- Wired iOS UI for message threads, recording, playback, and simple compose actions.
- Added server endpoints, model, and tests for message creation, listing, and video URL access.

## Key choices
- Messages are attached directly to a submission, not a separate conversation object, to keep the model simple and aligned with the roadmap.
- Video uploads follow the existing presigned URL pattern from submissions to avoid new infrastructure.
- Messages allow text-only, video-only, or mixed content to match real teacher feedback patterns.

## How it fits together
- The server stores `Message` rows keyed by `submission_id`, with optional video keys.
- iOS `MessageService` creates messages, persists them locally, and uploads media when needed.
- `VideoSubmissionDetailView` presents the submission video plus the message thread and compose controls.

## Risks and bottlenecks
- Message video uploads happen inline from the recording sheet; slow uploads will block dismissal.
- Message playback URLs are fetched per row, which may add request overhead for large threads.

## What's not included
- Push notifications or unread counts.
- Message editing/deletion or read receipts.
- Timestamped markers or score-linked references.
