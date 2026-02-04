# Video Practice Submissions Review

## What was implemented
- Added VideoSubmission model, API endpoints, and S3 helpers to create/list/review/play submissions.
- Built iOS recording flow with camera preview, upload service, and teacher review UI.
- Added mock API data for video submissions to support previews/UI tests.

## Key choices
- Two-phase submission (create metadata, then upload) to align with existing presigned S3 flow.
- Client-side duration extraction from recorded asset to keep server schema strict.
- Minimal playback UI (AVPlayer) with reviewed state, leaving richer feedback for later PRs.

## How it fits together
- iOS records video -> creates VideoSubmission via API -> uploads video/thumbnail to presigned S3 URLs.
- Server stores submission metadata and authorizes teacher access via student.teacher_id.
- Teacher views pending submissions, plays video, and marks reviewed via PATCH endpoint.

## Risks and bottlenecks
- Upload is performed synchronously in the recording sheet; large uploads may feel slow.
- Offline creation is not implemented; creating a submission requires connectivity.
- Playback/thumbnail URLs are fetched per row; large lists may incur extra requests.

## What's not included
- Teacher responses, timestamps, score linking, or progress timelines (PR2+).
- Background upload queueing or offline-first submission creation.
- Rich video controls or progress indicators.
