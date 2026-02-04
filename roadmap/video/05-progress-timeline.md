# PR 5: Progress Timeline

View all videos for a piece/exercise chronologically to see improvement over time.

## User Stories

**Teacher**: "Show me how this student's Bach Prelude has evolved over the past month."

**Student**: "I want to see my progress—how much better am I now than when I started?"

## Builds On

PR4: Score-Linked Video

## Why This Matters

Music practice is slow, incremental improvement. Day-to-day progress is invisible. But week-over-week and month-over-month, the difference is dramatic.

Video timeline makes this visible:
- Week 1: Struggling with rhythm, lots of wrong notes
- Week 4: Rhythm solid, working on dynamics
- Week 8: Performance ready

This is motivating for students and useful for teachers assessing growth.

## What Ships

### Server

New endpoint:

```python
# Get all videos for a piece/exercise, chronologically
GET /pieces/{id}/video-timeline
GET /exercises/{id}/video-timeline
Query: ?user_id=...  # for teacher viewing student

Returns:
{
    "timeline": [
        {
            "date": "2024-01-15",
            "submissions": [
                { submission data with page_number }
            ]
        },
        ...
    ],
    "mastery_markers": [
        { "date": "2024-02-01", "type": "teacher_marked_mastered" }
    ]
}
```

Extended model:

```python
# VideoSubmission: add mastery field
is_mastered: bool = False  # teacher can mark as mastered
mastered_at: datetime | None = None
```

New endpoint:

```python
PATCH /video-submissions/{id}/mastery
Body: { is_mastered: true }
```

### iOS

New views:

```swift
// Timeline view for a piece
ProgressTimelineView
  ├── TimelineHeader  // piece title, date range
  ├── MasteryBadge  // shows if mastered
  └── TimelineList
        ├── TimelineDay
        │     ├── DateLabel
        │     └── VideoThumbnailRow
        └── ...

// Side-by-side comparison
VideoComparisonView
  ├── EarlyVideo  // first submission
  ├── RecentVideo  // latest submission
  └── SplitControls  // play both, toggle
```

### Mastery Marking

Teacher can mark any submission as "mastered":
- Appears as gold star badge on that video
- Piece shows "Mastered on [date]" in student's library
- Timeline shows mastery marker

### Side-by-Side Comparison

Student or teacher can select two videos:
1. Tap video 1 → "Compare"
2. Tap video 2 → opens comparison view
3. Videos play side by side (or A/B toggle)
4. Visual proof of improvement

### Entry Points

- From piece detail → "View Progress" button
- From exercise completion → "See your journey" link
- From teacher's student view → per-piece progress

## Done When

1. Student has 8 video submissions for "Bach Prelude" over 2 months
2. Student opens piece → taps "Progress Timeline"
3. Timeline shows all 8 videos grouped by date
4. Student selects earliest and latest videos
5. Comparison view shows both side by side
6. Visible improvement in posture and accuracy
7. Teacher opens student's Bach Prelude timeline
8. Teacher marks latest submission as "mastered"
9. Student's piece shows mastery badge
10. Timeline shows gold mastery marker on that date

## Test Plan

```python
def test_piece_timeline():
    # Returns submissions for piece, grouped by date
    # Ordered chronologically

def test_exercise_timeline():
    # Returns submissions for exercise
    # Filtered by user_id for teacher view

def test_mark_mastered():
    # Teacher can mark submission as mastered
    # is_mastered = True, mastered_at set

def test_timeline_with_mastery():
    # Timeline includes mastery markers
```

iOS:
- Preview: ProgressTimelineView with sample data
- Preview: VideoComparisonView with two videos
