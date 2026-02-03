# Open Questions

## Video Submissions

- Offline flow: current implementation creates submissions on the server before upload; no local-only submission is created when offline (would require a pending local record + later create-on-reconnect). Is that acceptable for PR1?
- Teacher marking reviewed is available in VideoPlayerView without checking user type; should we gate the button by current user role?

## Score: Core Viewing Features

1. **Divider position sync**: Should half-page divider positions sync to server for teacher-shared scores? (Probably yes in Phase 2—a teacher setting optimal split points for students is valuable.)

2. **Variable page dimensions**: How do we handle documents with wildly different page dimensions? Current approach: normalize rendering to consistent aspect ratio. Per-page crop (Phase 2) handles edge cases.

3. **Per-page margin overrides**: Should margin adjustment have per-page overrides? For MVP, no—that's what the full crop editor (Phase 2) is for. Keep the margin slider simple.

4. **Auto-enable performance mode**: Should performance mode auto-enable when starting from a setlist/routine? Good UX for live performance, but adds coupling between features. Revisit after shipping the basics.

5. **Exit gesture alternatives**: Triple-tap works, but is it discoverable? Consider adding a brief tooltip on first use: "Triple-tap to exit performance mode". Or show a small hint after 30 seconds.

## Security

### COPPA compliance timeline

The app serves students who may be under 13. COPPA requires parental consent for collecting data from children. This is out of scope for this wave but needs a dedicated wave before public launch.

### Production infrastructure

The security hardening assumes:
- HTTPS termination at load balancer (not in FastAPI)
- Managed PostgreSQL with encryption at rest
- S3 with default encryption enabled

These are infrastructure decisions outside this codebase. Need confirmation this is the deployment model.

### Apple Client ID

The design requires `APPLE_CLIENT_ID` env var for token verification. This should match the bundle ID registered with Apple. Need to confirm the production value.
