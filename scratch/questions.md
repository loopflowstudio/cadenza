# Open Questions

## Video Submissions

- Offline flow: current implementation creates submissions on the server before upload; no local-only submission is created when offline (would require a pending local record + later create-on-reconnect). Is that acceptable for PR1?
- Teacher marking reviewed is available in VideoPlayerView without checking user type; should we gate the button by current user role?

## Score: Core Viewing Features

1. **Auto-crop detection**: Should we auto-suggest crop regions based on content detection? Not MVP, but could be a nice enhancement. forScore doesn't do this, but it would differentiate us.

2. **Variable page dimensions**: How do we handle documents where pages have wildly different content areas (e.g., title page vs. music pages)? Per-page crop handles this, but bulk operations get awkward. Consider: a "copy crop to similar pages" option that detects pages with similar layouts?

3. **Performance mode + half-page persistence**: Current design preserves half-page position when toggling performance mode. Is this the right behavior, or should entering performance mode reset to a full-page view?
