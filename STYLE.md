# Style Guide

This is the governing document of the codebase. Humans and LLMs alike are expected to follow it.

This monorepo contains:
- `website/` — Loopflow marketing site (FastHTML, HTMX)
- `cadenza/` — Cadenza music practice app (iOS + server)

## Quick Reference

- SwiftUI only—no UIKit unless absolutely necessary
- `@Observable` over `ObservableObject` (iOS 17+)
- Python: use `uv`, type hints everywhere, SQLModel for database
- Design docs go in `<branch>.md` at repo root; delete them when the feature ships
- No AI attribution footers in commits

## File-Type Guidelines

When editing `*.swift` files:
- Put imports at the top: first-party, then third-party, alphabetically within each
- Use `// MARK: -` headers to organize sections
- Public API first, then private helpers grouped by category

When editing `*.py` files:
- Put imports at the top, not inline
- Use type hints on all functions
- One-line docstring if any; skip if the name and types are clear

When editing `*_test.py` or `test_*.py` files:
- Keep tests short and focused on one behavior
- Mock side effects (network, subprocess), but assert on results, not mock calls
- Delete flaky tests rather than adding retries

When editing Swift test files:
- UI tests for critical user workflows
- Unit tests for services (audio, network, data)
- View code gets Previews, not unit tests

When editing `<branch>.md` design docs:
- Focus on what's left to build, not what's done
- Delete the doc when the feature ships

# Goals

## Clarity

Design around data structures and public APIs. Aim for a 1:1 mapping between real-world concepts and their representation in code.

Write code that demonstrates its own correctness. If a feature exists, write a test that proves it works. Assume you won't finish everything you start—make it easy to see what's done and what's broken.

## Simplicity

Every line of code must earn its place. Readable code is not terse code; don't sacrifice clarity for brevity. But recognize that lines can be net-negative:

* Unused code
* Comments that restate the obvious
* Checks for impossible conditions

Start with minimal data structures and APIs. If the core is right, trimming excess at the edges is straightforward.

# LLM Collaboration

To begin most sessions or coding projects, start by asking a few clarifying technical design questions.

For substantial changes (new services, schema objects, major features): Start with design discussion.
For isolated features (leaf views, simple utilities): Jump straight to code.
Use judgment and be bold in both directions.

Avoid implementing "_v2" style files. You are working in a git branch and if things break the branch will simply be dropped or rolled back. Emphasize building in a way that leads to the cleanest code and always prioritize not leaving behind technical debt or old, rotting code.

Do not introduce new product features that were not explicitly specified.

# Code Organization

Keep one implementation. Avoid `v2_`, `_old`, `_new`, `_backup` prefixes and suffixes—look up old versions in git. If you're tempted to keep both old and new code around, delete the old version and commit. You can always get it back from git if needed.

Don't maintain backwards compatibility unless explicitly required. If a config format or API changes, migrate everything to the new format—don't write code that handles both old and new. Backwards compatibility is for production databases and published APIs with external users, not internal config files.

Keep information in one place. Version numbers, configuration, documentation—each piece of information should have a single source of truth.

Use header comments to group related code sections.

## Naming

Use verb-first names for action functions: `fetchPieces()`, `loadConfig()`, `createRoutine()`.

In Python, prefix private functions with underscore: `_should_ignore()`, `_load_file()`.

Name things after what they are, not what they're for: `Routine`, `Exercise`, `Session`—not `RoutineHelper`, `ExerciseResult`, `SessionHandler`.

In type names, avoid redundant namespacing. No `Foo.FooA.FooB`. Just `Foo.A.B`.

In file names, aim for global uniqueness. `practice_session_view.swift` instead of `view.swift`.

## Error Handling

Use a few broad error categories, not detailed taxonomies. Fail fast—assert clear expectations, don't suppress unexpected input. No generic catches that hide problems.

Return errors when the caller should handle them—invalid input, missing files, failed requests. Raise exceptions for bugs: violated invariants, impossible states, programming mistakes.

When in doubt: if you'd write an `assert`, raise an exception instead—it's easier for callers to catch.

# iOS App (cadenza/)

The iOS app uses SwiftUI and SwiftData, targeting iOS 17+.

## SwiftUI

Avoid UIKit at all costs. Just use SwiftUI.

If UIKit is absolutely necessary, use `UIViewRepresentable` and document why. Avoid `ViewController` types unless truly necessary.

Use modern patterns:
- `@Observable` instead of `ObservableObject` (iOS 17+)
- `async/await` for async code
- Combine for reactive streams where it makes sense

Avoid macros. If something isn't working about the current environment like an iPad/iPhone discrepancy or a missing package, ask for help debugging it, don't try to hammer around it.

## Good Swift Structure

```swift
import SwiftUI

import Combine

// MARK: - Public API

struct PracticeSessionView: View {
    var body: some View { ... }
    func startSession() { ... }
}

// MARK: - Timer Management

extension PracticeSessionView {
    private func startTimer() { ... }
    private func stopTimer() { ... }
}

// MARK: - Audio

extension PracticeSessionView {
    private func processAudio() { ... }
}
```

## Good Swift Error Handling

```swift
enum CadenzaError: LocalizedError {
    case audioPermissionDenied
    case networkUnavailable
    case invalidSession
}

// Fail fast
guard let session = audioSession else {
    preconditionFailure("Audio session must be available")
}
```

## SwiftData Models

Keep models simple. Mirror the server schema where possible so sync is straightforward.

```swift
@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var ownerId: Int
    var title: String
    var routineDescription: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var exercises: [Exercise] = []
}
```

## iOS Testing

We should maintain a few (~1-100, growing over time) UI tests for critical user workflows. Services (audio, network, data) should have unit tests. View code is not unit tested, but should have comprehensive Previews.

Prioritize having a centralized, modular PreviewContainer that drives all ViewPreviews as consistently as possible.

```swift
// Good: Preview with mock data
#Preview {
    PracticeSessionView(routine: .preview)
        .modelContainer(PreviewContainer.shared)
}
```

## iOS Services

Services live in `Cadenza/Services/`. Each service should:
- Have a protocol for mocking in tests and previews
- Use async/await for network calls
- Handle errors at the call site, not internally

```swift
// Good: Protocol + implementation
protocol PitchServiceProtocol {
    func startListening() async throws
    func stopListening()
    var currentPitch: Pitch? { get }
}

final class PitchService: PitchServiceProtocol {
    ...
}
```

# Website (website/)

The website uses FastHTML with inline CSS. It must be accessible and work across browsers.

## Accessibility Requirements (WCAG 2.1 AA)

These are not optional. Every UI change must satisfy:

**Interactive Elements**
- Buttons with only icons must have `aria-label`
- All interactive elements must have visible `:focus-visible` states
- Click handlers on non-button elements need `role`, `tabIndex`, and keyboard handlers

**Semantic HTML**
- Use `<nav>`, `<main>`, `<section>`, `<article>` appropriately
- Multiple `<nav>` elements must have distinct `aria-label` attributes
- Decorative elements (icons, dots) must have `aria-hidden="true"`

**Color & Contrast**
- Text must have 4.5:1 contrast ratio against background
- Don't convey information through color alone
- All states (hover, focus, active, disabled) must be visually distinct

**Links**
- External links (`target="_blank"`) must have visual indicator
- Links must be distinguishable from surrounding text

**Forms**
- All inputs must have associated labels
- Error states must be announced to screen readers

## CSS Patterns

```python
# Good: Button with accessible icon
Button(
    NotStr('<svg aria-hidden="true">...</svg>'),
    cls="icon-btn",
    **{"aria-label": "Close dialog"},
)

# Good: Multiple navs with labels
Nav(..., **{"aria-label": "Main navigation"})
Nav(..., **{"aria-label": "Documentation navigation"})

# Good: Focus states in CSS
.btn:focus-visible {
    outline: 2px solid var(--burgundy);
    outline-offset: 2px;
}
```

## Browser Testing

Before shipping website changes:
1. Test in Safari (our users skew Mac)
2. Test at mobile viewport (375px)
3. Run `/rams` for accessibility review

# Cadenza iOS App (cadenza/)

The iOS app uses SwiftUI and SwiftData, targeting iOS 17+.

## SwiftUI Accessibility

- Use semantic SwiftUI modifiers: `.accessibilityLabel()`, `.accessibilityHint()`
- Test with VoiceOver enabled
- Ensure touch targets are at least 44x44pt

# API Server (cadenza-server/)

The server is a FastAPI application with SQLModel for database models.

## Development Environment

Use `uv` for all package management. Never use pip directly.

```bash
cd cadenza-server
uv sync                       # Install dependencies
uv run pytest tests/          # Run tests
uv run uvicorn app.main:app   # Run server

# Or activate the venv
source .venv/bin/activate
pytest tests/
```

## Server Structure

```
cadenza-server/
├── app/
│   ├── main.py          # FastAPI app, route registration
│   ├── models.py        # SQLModel database models
│   ├── schemas.py       # Pydantic request/response schemas
│   ├── auth.py          # Authentication logic
│   ├── database.py      # Database connection
│   └── config.py        # Environment configuration
└── tests/
    ├── conftest.py      # Fixtures (test client, test db)
    └── test_*.py        # Test files
```

## SQLModel Models

Models go in `app/models.py`. Keep them simple and focused.

```python
from datetime import datetime
from uuid import UUID, uuid4

from sqlmodel import Field, SQLModel

class Routine(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    owner_id: int = Field(foreign_key="users.id", index=True)
    title: str
    description: str | None = None
    created_at: datetime
    updated_at: datetime
```

## API Endpoints

Endpoints go in `app/main.py` or are organized into routers. Use Pydantic schemas for request/response validation.

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

router = APIRouter(prefix="/routines", tags=["routines"])

@router.post("/", response_model=RoutineRead)
def create_routine(
    routine: RoutineCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Routine:
    db_routine = Routine(**routine.dict(), owner_id=current_user.id)
    session.add(db_routine)
    session.commit()
    session.refresh(db_routine)
    return db_routine
```

## Good Python Error Handling

```python
# Error: caller decides what to do
def find_config(path: Path) -> Config | None:
    if not path.exists():
        return None
    return load(path)

# Exception: this shouldn't happen
def get_routine(session: Session, id: UUID) -> Routine:
    routine = session.get(Routine, id)
    if routine is None:
        raise HTTPException(status_code=404, detail="Routine not found")
    return routine
```

## Server Testing

Tests use pytest with a test database. Each test gets a fresh database transaction that rolls back after.

```python
def test_create_routine(client: TestClient, auth_headers: dict):
    response = client.post(
        "/routines/",
        json={"title": "Scales Practice"},
        headers=auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["title"] == "Scales Practice"
```

# Documentation

The best documentation is simple code. Descriptive names, type hints, and clear APIs often suffice.

The worst documentation is wrong documentation. If it can drift from the code, it will. Update docs when you change code—or delete them.

Put documentation next to code. A few paragraphs at the top of a key file beats a separate doc that nobody maintains.

Skip obvious docstrings:

```python
# Bad
def start_session(routine_id: UUID) -> PracticeSession:
    """
    Start a practice session for the given routine.

    Args:
        routine_id: The ID of the routine to practice

    Returns:
        PracticeSession: The newly created session
    """
    ...

# Good
def start_session(routine_id: UUID) -> PracticeSession:
    ...
```

Start features with design docs in `<branch>.md` at repo root. Delete the design doc when implementation is complete—by then, the code and its README should speak for themselves.

# Testing

Test user behavior, not implementation details. A good test proves that something users care about actually works. Most tests don't meet that bar. Delete them.

Aim for a mix:
- **Smoke tests**: Does the system run without crashing?
- **Edge case tests**: What happens at boundaries?
- **Value tests**: Does this feature do what users expect?

## When to Mock

Mock to isolate your code from things that shouldn't be part of unit tests:
- **External systems**: Network calls, databases, file systems (when testing logic, not I/O)
- **Side effects**: Sending emails, writing logs, spawning processes
- **Slow operations**: Anything that would make tests take seconds instead of milliseconds

Don't mock to verify internal wiring. If a test's assertions are just "did we call the mock with the right args?"—that's testing implementation, not behavior. The test will break when you refactor, even if the feature still works.

```python
# Bad: testing that we called the mock correctly
def test_send_notification():
    with patch("app.email.send") as mock_send:
        notify_user(user)
        mock_send.assert_called_once_with(user.email, ANY)

# Good: mock the side effect, test the behavior
def test_notify_user_returns_success():
    with patch("app.email.send"):  # prevent actual email
        result = notify_user(user)
        assert result.success

# Better: if possible, test without mocking
def test_notification_message_format():
    msg = build_notification(user)
    assert user.name in msg.body
```

If a test requires elaborate mock setup, it's usually a sign that either:
1. The code under test does too much (refactor it)
2. You're testing implementation rather than behavior (test something else)
3. This should be an integration test, not a unit test (move it)

# Git

Commit messages are documentation. Explain what changed and why, not line-by-line what you did:

```
# Bad
Add startSession function
Add stopSession function
Update PracticeView to call new functions
Fix import statement

# Good
routines: add teacher assignment flow

Teachers can now assign routines to students. Assignment copies the
routine and auto-shares all referenced pieces.
```

Keep messages short—one sentence to one paragraph.

Do not add AI attribution footers like "Generated with Claude Code" or "Co-Authored-By: Claude" to commits. The git history should read the same whether written by a human or AI.

# Pre-Commit Checklist

Before committing, verify:

**Code Quality**
- [ ] No `Args:`/`Returns:` docstrings on functions with clear types
- [ ] No `v2_`, `_old`, `_new`, `_backup` etc.; keep one implementation, use git for history
- [ ] Mocks prevent side effects, not verify internal wiring
- [ ] Tests assert on results, not mock calls

**iOS**
- [ ] No UIKit unless documented why it's necessary
- [ ] Server and iOS models stay in sync where they overlap

**Website (if changed)**
- [ ] Run `/rams` and fix all critical/serious issues
- [ ] All buttons have visible focus states
- [ ] All icon-only buttons have `aria-label`
- [ ] Color contrast meets 4.5:1 ratio
- [ ] Tested in Safari at desktop and mobile widths
