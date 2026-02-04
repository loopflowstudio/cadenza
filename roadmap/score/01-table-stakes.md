# Table Stakes: forScore Parity

Features needed to make Cadenza's sheet music experience competitive with forScore.

## Current State

Cadenza has basic PDF viewing via `SheetMusicView.swift` using PDFKit:
- Page navigation
- Zoom controls
- Basic display

Missing almost everything that makes forScore beloved.

## Priority 1: Core Viewing

### Crop & Margins
Scanned PDFs often have excessive whitespace. Musicians need to:
- Crop individual pages to focus on the music
- Adjust margins globally for a document
- De-skew crooked scans

forScore saves crop settings per-page without modifying the PDF.

### Half-Page Turns ✓
Picked → `scratch/score-half-page-turns.md`

### Performance Mode
Lock out most gestures during performance. Only page turns work. Prevents accidental menu triggers, annotation mode, etc.

### Reflow (Stretch Goal)
Detect music content regions and lay them out in a single horizontal scroll. Like a teleprompter. forScore's implementation doesn't parse notation—it uses visual detection to find "where music is" on the page.

## Priority 2: Page Turning

Musicians can't turn pages manually while playing. This is make-or-break.

### Bluetooth Pedals
Support AirTurn and similar Bluetooth pedals. Two modes:
1. **Keyboard mode**: Pedal sends arrow key events, app responds
2. **App-direct mode**: Pedal connects via Bluetooth LE, better battery life

forScore supports both. Keyboard mode is easier to implement initially.

### AirPods Head Gestures
iOS provides head-tracking data from AirPods Pro/Max/3. forScore 12.0.4 added this:
- Hold head still to establish baseline
- Quick lateral turn triggers page flip
- Works in the dark (no camera needed)
- Doesn't impede hearing (Transparency mode)

Free feature in forScore—we should match.

### Face Gestures (Lower Priority)
Camera-based: head turn, wink, mouth movement. forScore Pro feature. Less reliable than AirPods according to user reports. Consider as a later addition.

### Tap Zones ✓
Tap left/right edges (20% each) to turn pages. Implemented in `TapZoneOverlay` and `TapZone` components in `SheetMusicView.swift`. Brief chevron feedback on successful page turn.

## Priority 3: Annotation

### Apple Pencil Drawing
Enter annotation mode automatically when Pencil touches screen. Exit after inactivity. Draw naturally like on paper.

Key behaviors:
- Finger continues to pan/zoom while Pencil draws
- Multiple pen colors/widths as presets
- Eraser mode
- Undo/redo

### Stamps
Pre-built musical symbols: dynamics (p, f, mf), accidentals, fingerings, bowings, articulations. Tap to place, drag to position.

forScore has ~100 stamps; forScore Pro adds ~400 more. We need a solid core set covering:
- Dynamics (pp through ff, crescendo/decrescendo)
- Articulations (staccato, accent, tenuto, fermata)
- Fingerings (1-5 for piano/strings)
- Bowings (down-bow, up-bow)
- Breath marks, caesura

### Layers
Separate annotation layers that can be shown/hidden. Use cases:
- "Score study" layer hidden during performance
- Teacher's markings vs. student's markings
- Different interpretations of same passage

## Priority 4: Organization

### Metadata
Store per-piece: title, composer, genre, key, tags. Filter/search library by any field.

forScore's metadata approach is polarizing (no folders), but the dynamic filtering is powerful. Consider hybrid: metadata filtering + optional folder organization.

### Setlists
Ordered lists of pieces for a performance or practice session. Drag to reorder. Swipe through without returning to library.

For Cadenza, this maps naturally to Routines—but we should also support ad-hoc setlists independent of the assignment system.

### Bookmarks
Define a page range within a large PDF as a separate "piece" in the library. Essential for omnibus collections (Real Book, Suzuki volumes). The bookmark appears in the library alongside regular pieces.

## Priority 5: Metronome Integration

Cadenza already has MetronomeService. Enhancements needed:

### Per-Score Settings
Save BPM and time signature per piece. When you open a score, metronome defaults to saved values.

### Visual Beat
Flash screen border on beat (forScore's "visible" mode). Useful when audio would be distracting.

### Buttons in Score
Place tappable buttons on specific pages that set the metronome to a tempo. Useful for pieces with tempo changes—tap the button when you reach that section.

## Priority 6: Audio

### Linked Recordings
Attach audio files to a score. Sync playback position with page. Practice along with reference recordings.

### Practice Recording
Record yourself playing. Review later. Basic audio capture, not notation transcription.

### MIDI Playback
Link MIDI files to scores. Playback with tempo control. Lower priority than audio—MIDI is less commonly used for practice.

## Non-Goals (for now)

- **iCloud sync**: Complex, can defer. Device-local is fine initially.
- **Cue (ensemble sync)**: Multi-device coordination is a big lift.
- **Scan from camera**: iOS has document scanning built in; users can import PDFs.

## Implementation Notes

### SwiftUI + PDFKit
Current approach is sound. PDFKit handles rendering; SwiftUI handles UI. Annotation will need a custom drawing layer on top of PDFView.

### Annotations Are Server-Side

Even for "single user" table-stakes features, annotations should be server-first:
- Sync across user's devices (iPad for practice, iPhone on the go)
- Survive device replacement/reset
- Foundation for teacher-student sharing (Phase 2)
- Backup without relying on iCloud

Architecture:
1. User draws annotation → saved to SwiftData immediately (fast, offline-capable)
2. Background sync uploads to server
3. On other devices, pull from server and cache in SwiftData
4. Server is source of truth; SwiftData is cache

See `02-teacher-workflows.md` for full data model.

### What's Local-Only

Some settings can stay device-local (no server sync needed):
- Display preferences (brightness, sepia mode)
- Current page position (where user left off)
- Half-page turn toggle state

These are per-device preferences, not user data.

### What's Server-Side

Everything that represents user work or should persist:
- Annotations (drawings, stamps, text)
- Crop settings per page
- Piece metadata (tags, custom fields)
- Setlists
- Bookmarks
- Metronome settings per piece (BPM, time signature)

## Success Criteria

A professional musician should be able to:
1. Import a PDF of their repertoire
2. Crop out margins and straighten crooked scans
3. Annotate with pencil and stamps
4. Turn pages with a Bluetooth pedal during performance
5. Use half-page turns for awkward page breaks
6. Set metronome tempo per piece
7. Organize their library by composer/genre/tags
8. Create setlists for concerts

If they can do all that without thinking "I wish I had forScore," we've hit table stakes.
