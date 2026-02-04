# Sheet Music UX Roadmap

Vision for Cadenza's sheet music experience, informed by forScore's gold standard and Cadenza's unique teacher-student model.

## Competitive Landscape

### forScore (Gold Standard)

[forScore](https://forscore.co/) is the #3 top paid iPad app, considered the gold standard for digital sheet music. One-time $19.99 purchase, Apple-only.

**What musicians love:**
- PDF viewing with crop, margins, zoom, Reflow (horizontal teleprompter)
- Rich annotation: Apple Pencil drawing, stamps (musical symbols), layers
- Metadata-based organization (no folders, but dynamic filtering by composer/genre/tags)
- Setlists with drag-and-drop ordering
- Page turning: Bluetooth pedals (AirTurn), AirPods head gestures, face gestures (Pro), tap/swipe
- Per-score metronome settings (BPM, time signature saved per piece)
- Audio playback linked to scores, recording practice sessions
- MIDI file playback
- Cue: synchronized page turns across multiple devices for ensembles
- Half-page turns, performance mode (gesture lockdown)
- Links and buttons embedded in scores
- Bookmarks that define page ranges within larger compilations
- iCloud sync across devices
- Scan: camera-based PDF creation from paper music

**forScore's limitations:**
- Apple-only ecosystem
- No MusicXML support (PDF-only, no notation understanding)
- No true OMR/parsing—Reflow uses visual detection, not music comprehension
- No folder hierarchy (polarizing—some love metadata approach, others hate it)
- Face gestures unreliable for actual performance
- Learning curve for advanced features (layers, buttons, links)

### Newzik

Cloud-based collaboration focus. Free tier + $4.99/mo premium.

**Unique strengths:**
- MusicXML native support
- LiveScores: AI-powered OMR converts PDFs to interactive sheet music
- Real-time collaboration (conductor can push annotations to ensemble)
- Cloud-first with sync
- Projects with shared annotations across members

**Weaknesses:**
- Subscription model
- Less mature than forScore for individual use

### Piascore

Free with $5 unlock. Lower-cost alternative.

**Unique strengths:**
- Vertical scrolling (unique among competitors)
- IMSLP integration (free public domain scores)
- Lower price point

**Weaknesses:**
- No annotation layers
- Less powerful organization
- Fewer automation features

### Practice Tracking Apps (Tonara, Better Practice)

These focus on teacher-student workflows but have weaker sheet music UX:

**Tonara:**
- Listens to students play and tracks practice
- Teacher dashboard with student progress at a glance
- Assignment system with multimedia chat

**Better Practice:**
- Assignment management
- Recording sharing with teacher feedback
- Progress reports

## Cadenza's Position

Cadenza already has the teacher-student core that practice apps focus on:
- User model with teacher/student types
- Routine/exercise structure for assignments
- Practice session tracking with reflections
- Piece sharing from teacher to student
- Real-time pitch detection (tuner)

What Cadenza lacks is the sheet music UX polish that forScore provides.

## Strategic Direction

### Core Principle: Server-First Annotations

Unlike forScore (local-only), Cadenza's annotations are server-side from day one:
- Sync across devices
- Enable teacher-student sharing
- Survive device replacement
- SwiftData is a cache for offline access; server is source of truth

This is more complex upfront but essential for the teacher-student workflows that differentiate Cadenza.

### Phase 1: Table Stakes
Get PDF viewing and annotation to a level where musicians don't miss forScore. See `01-table-stakes.md`.

### Phase 2: Teacher-Student Workflows
Build sheet music features that leverage Cadenza's unique teacher-student relationship—things forScore can't do because it's single-user focused. See `02-teacher-workflows.md`.

### Phase 3: Notation Parsing
Move beyond PDF-as-image to understanding music structure. Parse notation into a manipulable format (MusicXML, custom AST). Enable features impossible with static PDFs. See `03-notation-parsing.md`.

## Research Sources

- [forScore Documentation](https://forscore.co/documentation/)
- [forScore Review 2025](https://trombonegeek.com/forscore-review/)
- [Scoring Notes: Best iPad Score Reader](https://www.scoringnotes.com/reviews/the-best-ipad-score-reader-for-most-people/)
- [nkoda: Best Sheet Music Apps Comparison](https://www.nkoda.com/blog/best-sheet-music-apps)
- [Tonara](https://www.tonara.com/)
- [Better Practice](https://betterpracticeapp.com/)
- [Newzik LiveScores](https://newzik.com/en/ai)
- [OMR Research - oemer](https://github.com/BreezeWhite/oemer)
