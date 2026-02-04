# Video Feedback Roadmap

Vision: Asynchronous video exchange between teachers and students, with timestamped feedback tied to specific musical passages.

## The Core Loop

In-person music lessons work because of a tight feedback loop:
1. Student plays passage
2. Teacher points at specific moment: "right there, you're rushing"
3. Teacher demonstrates correct approach
4. Student tries again
5. Repeat until mastered

Video feedback recreates this loop asynchronously. Each PR below adds one capability that makes this loop tighter.

## PR Sequence

| PR | Name | Adds |
|----|------|------|
| 1 | [Practice Submissions](01-practice-submissions.md) | Student records and uploads practice video |
| 2 | [Teacher Response](02-teacher-response.md) | Teacher replies with video/text |
| 3 | [Timestamped Markers](03-timestamped-markers.md) | Feedback at specific moments |
| 4 | [Score-Linked](04-score-linked.md) | Videos reference pages/measures |
| 5 | [Progress Timeline](05-progress-timeline.md) | See improvement over time |

Each PR is independently useful. Details in linked specs.

## Technical Foundation

Each PR builds on the same core infrastructure:

### S3 Storage Pattern

```
cadenza/videos/{user_id}/{video_id}.mp4
cadenza/videos/{user_id}/{video_id}_thumb.jpg
```

Same pattern as pieces: presigned URLs for upload/download.

### Data Model Growth

```
PR1: VideoSubmission (exercise_id, user_id, s3_key)
PR2: Message (conversation_id, sender_id, text?, video_s3_key?)
PR3: VideoMarker (message_id, timestamp_ms, text)
PR4: Add page_number, measure_number to VideoSubmission, Message, VideoMarker
PR5: No new models, just new queries/views
```

### iOS View Hierarchy

```
PR1: ExerciseCompletionView → VideoRecordingSheet
PR2: VideoSubmissionView → MessageThreadView
PR3: VideoPlayerView → MarkerOverlay
PR4: SheetMusicView → VideoSidebarView
PR5: PieceDetailView → ProgressTimelineView
```

## Dependencies

```
PR1 ──► PR2 ──► PR3
          │
          └──► PR4 ──► PR5
```

PR3 and PR4 can proceed in parallel after PR2.

## What We're NOT Building (Yet)

- **Real-time video calls**: Async is the differentiator. Live calls can use FaceTime/Zoom.
- **AI analysis**: Audio analysis from video is future work (see notation-parsing roadmap).
- **Group lessons**: 1:1 teacher-student first. Group dynamics are different.
- **Public sharing**: All videos are private between teacher and student.
- **Video editing**: Record, send, done. No trimming, filters, etc.

## Success Metrics

After PR5 ships, we should see:
- Students submitting 2+ videos per week per assigned routine
- Teachers responding to 80%+ of submissions within 48 hours
- Average 3+ markers per video from teachers
- Students viewing progress timeline at least weekly
