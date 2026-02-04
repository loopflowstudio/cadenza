# Open Questions

## Score: Core Viewing Features

1. **Divider position sync**: Should half-page divider positions sync to server for teacher-shared scores? (Probably yes in Phase 2—a teacher setting optimal split points for students is valuable.)

2. **Variable page dimensions**: How do we handle documents with wildly different page dimensions? Current approach: normalize rendering to consistent aspect ratio. Per-page crop (Phase 2) handles edge cases.

3. **Per-page margin overrides**: Should margin adjustment have per-page overrides? For MVP, no—that's what the full crop editor (Phase 2) is for. Keep the margin slider simple.

4. **Auto-enable performance mode**: Should performance mode auto-enable when starting from a setlist/routine? Good UX for live performance, but adds coupling between features. Revisit after shipping the basics.

5. **Exit gesture alternatives**: Triple-tap works, but is it discoverable? Consider adding a brief tooltip on first use: "Triple-tap to exit performance mode". Or show a small hint after 30 seconds.
