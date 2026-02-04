# Notation Parsing: Toward Manipulable Music

Moving beyond PDF-as-image to understanding music structure. The long-term vision for Cadenza's sheet music.

## Why Parse Notation?

PDFs are just images. The app doesn't know:
- Where measures are
- What notes are on the page
- The rhythm, key, or tempo
- How long each section takes to play

With parsed notation, Cadenza could:
- Auto-scroll at the right tempo
- Play back the music
- Transpose on the fly
- Identify difficult passages algorithmically
- Generate practice exercises from the score
- Sync practice recordings with notation for analysis
- Provide "play along" with highlighted current position

## Current Technology Landscape

### OMR (Optical Music Recognition)

Like OCR but for music. Takes an image, outputs structured notation.

**State of the art:**
- Deep learning models (CNN + RNN) achieve good accuracy on clean printed scores
- Handwritten notation still challenging
- Complex layouts (multiple voices, piano grand staff) increase error rates
- No tool is 100% accurate—all require manual correction

**Notable projects:**
- [Audiveris](https://github.com/Audiveris/audiveris): Open source, outputs MusicXML
- [oemer](https://github.com/BreezeWhite/oemer): End-to-end OMR, handles phone photos
- [Newzik LiveScores](https://newzik.com/en/ai): Commercial AI OMR, converts PDFs to interactive scores
- [PlayScore 2](https://www.playscore.co/): Mobile app with real-time OMR
- [Soundslice](https://www.soundslice.com/sheet-music-scanner/): Browser-based OMR

### MusicXML

Standard interchange format for notation. Supported by Finale, Sibelius, MuseScore, Dorico.

Represents:
- Notes (pitch, duration, voice)
- Measures and barlines
- Clefs, key signatures, time signatures
- Articulations, dynamics, slurs
- Lyrics, chord symbols
- Multi-part scores

MusicXML is verbose but complete. Can round-trip through notation editors without loss.

### Alternative Formats

- **MEI (Music Encoding Initiative)**: Academic, more semantic than MusicXML
- **MIDI**: Timing/pitch only, loses notation details
- **ABC notation**: Text-based, limited expressiveness
- **LilyPond**: Text-based, powerful but steep learning curve

MusicXML is the pragmatic choice for interchange.

## Phased Approach

### Phase 3a: Import MusicXML

Support MusicXML files directly, alongside PDFs.

Benefits:
- Many scores available in MusicXML from MuseScore, IMSLP, publishers
- Perfect accuracy (no OMR errors)
- Immediate access to structured data

Required:
- MusicXML parser (Swift or use C library)
- Internal music model to represent parsed data
- Renderer to display notation (or convert to PDF for display)

Rendering is the hard part. Options:
1. **Convert MusicXML to PDF on import**: Use server-side tool (MuseScore CLI, LilyPond)
2. **Native notation rendering**: Build or use a rendering library
3. **Hybrid**: Store MusicXML, render to PDF for display, use structure for features

Option 1 is simplest for MVP. Option 2 enables real-time features (transposition, tempo sync).

### Phase 3b: Measure Detection (Lightweight OMR)

Don't parse every note—just find measure boundaries.

This gives us:
- Jump to measure N
- "Practice measures 17-24"
- Measure-level progress tracking
- Sync audio recording to measure positions

Measure/barline detection is easier than full OMR:
- High contrast vertical lines
- Regular spacing
- Well-studied problem

Could use:
- Classical computer vision (line detection, heuristics)
- Lightweight ML model trained on measure boundaries
- Hybrid: detect staves first, then barlines within

### Phase 3c: Full OMR Integration

Partner with or integrate existing OMR:
- Run OMR on PDF import
- Store resulting MusicXML alongside PDF
- User can correct errors
- Corrections improve future OMR (if we build/train our own)

User flow:
1. Import PDF
2. "Analyze score" (runs OMR, may take seconds to minutes)
3. Results appear: measures highlighted, notes recognized
4. User corrects any errors
5. Structured data now available for features

### Phase 3d: Interactive Features

With parsed notation:

**Auto-scroll / Follow Mode**
- Set tempo
- Cursor advances through score at tempo
- Camera/audio input adjusts for actual playing speed

**Transposition**
- Singer needs piece in different key
- One tap to transpose entire score
- Requires native rendering, not just PDF display

**Practice Generation**
- Extract difficult passage
- Generate variations (different rhythms, articulations)
- Slow practice version with simplified rhythm

**Smart Metronome**
- Reads tempo markings from score
- Adjusts for tempo changes (accel., rit.)
- Metronome follows the music, not vice versa

**Pitch Detection Feedback**
- Compare played notes to expected notes
- Highlight wrong notes in real-time
- "You played F# but the score has F natural"

This last one connects Cadenza's existing PitchService to notation data.

## Technical Considerations

### Music Data Model

```swift
struct Score {
    let id: UUID
    let parts: [Part]
    let metadata: ScoreMetadata
}

struct Part {
    let id: UUID
    let name: String  // "Violin I", "Piano RH"
    let measures: [Measure]
}

struct Measure {
    let number: Int
    let timeSignature: TimeSignature?  // nil if unchanged
    let keySignature: KeySignature?
    let events: [MusicEvent]
}

enum MusicEvent {
    case note(Note)
    case rest(Rest)
    case chord([Note])
    case direction(Direction)  // dynamics, tempo, etc.
}

struct Note {
    let pitch: Pitch  // reuse existing Pitch from PitchService
    let duration: Duration
    let voice: Int
    let articulations: [Articulation]
}
```

### Storage

- **MusicXML files**: Store in S3 alongside PDFs
- **Parsed model**: Could serialize to JSON or store in SQLite
- **PDF ↔ MusicXML mapping**: Track which PDF pages correspond to which measures

### Performance

OMR is CPU-intensive. Options:
1. **Server-side**: Upload PDF, server returns MusicXML
2. **On-device**: Use Core ML model, runs locally
3. **Hybrid**: Quick local analysis, detailed server processing

Server-side is simpler and can use better hardware. Privacy consideration: music PDFs may be copyrighted material, but we're not redistributing—just analyzing for the user.

## Competitive Moat

If Cadenza has:
- Good OMR (or MusicXML import)
- Teacher-student annotation workflows
- Pitch detection with notation comparison

Then we have something forScore can't offer: **intelligent practice feedback**.

"You spent 80% of your time on measures 17-24. Your pitch accuracy there improved from 73% to 91% this week. Here's the specific passage where you're still hitting B♭ instead of B♮."

That's the vision.

## Risks

- **OMR accuracy**: Errors frustrate users. May need "verified" scores (imported MusicXML) vs. "analyzed" scores (OMR'd PDFs) with different trust levels.
- **Scope creep**: Notation rendering is a rabbit hole. Consider using existing libraries rather than building from scratch.
- **Copyright**: Some publishers may object to OMR. We're not redistributing, just analyzing, but worth considering terms of service.

## Non-Goals (for now)

- **Notation editor**: Users don't compose in Cadenza; they practice existing music.
- **Score engraving quality**: Rendering doesn't need to match Finale/LilyPond; it needs to be readable.
- **Every notation feature**: Focus on common Western notation for classical/jazz education.

## Success Criteria

Phase 3a (MusicXML Import):
- User can import MusicXML file
- App displays the music (rendered or converted to PDF)
- Measure numbers are navigable

Phase 3b (Measure Detection):
- User imports PDF
- App detects measure boundaries with >90% accuracy
- User can jump to any measure
- Teacher can assign measure ranges

Phase 3c (Full OMR):
- User uploads PDF
- OMR extracts notes with >85% accuracy on clean printed scores
- User can correct errors
- Corrected data persists

Phase 3d (Interactive Features):
- Auto-scroll follows tempo
- Pitch detection compares played notes to score
- Practice report shows accuracy per measure
