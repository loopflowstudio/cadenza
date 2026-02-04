# upandrun: Local Dev & Dogfooding Infrastructure

## What to Build

Scripts and config to run the full Cadenza stack locally (server + iOS simulator) without Xcode IDE, with good logging and seed data for dogfooding.

## Current State

**What works:**
- `python dev.py server` — starts postgres + uvicorn
- `python dev.py simulator` — builds and launches iOS (but requires existing .xcodeproj)
- `/auth/dev-login` endpoint — email-based auth bypass
- DevSignInView — quick-fill buttons for test users
- 11 bundled PDFs in `Cadenza/Resources/`

**What's missing:**
- `project.yml` exists but `python dev.py generate` not wired up
- No rich seed data (only creates empty users, no routines/pieces/sessions)
- No structured logging (just `print()` statements)
- No way to reset/switch between app states

## Data Structures

### Seed Data Script

```python
# server/seed_scenario.py

@dataclass
class Scenario:
    name: str
    description: str
    setup: Callable[[Session], None]

SCENARIOS = {
    "empty": Scenario("Empty", "Fresh user, no data"),
    "teacher-with-students": Scenario(
        "Teacher with students",
        "Teacher with 2 students, routines, pieces"
    ),
    "student-with-assignment": Scenario(
        "Student with assignment",
        "Student with assigned routine, some practice history"
    ),
}
```

### project.yml (xcodegen)

Already exists at repo root. Includes Cadenza, CadenzaTests, CadenzaUITests targets.

## Key Functions

```python
# dev.py additions

def seed(args) -> None:
    """Seed database with a specific scenario."""
    # python dev.py seed --scenario teacher-with-students

def reset(args) -> None:
    """Reset database to clean state, optionally seed."""
    # python dev.py reset
    # python dev.py reset --scenario student-with-assignment

def logs(args) -> None:
    """Tail server logs with filtering."""
    # python dev.py logs --filter auth
    # python dev.py logs --filter "DB WRITE"

def generate(args) -> None:
    """Generate Xcode project from project.yml."""
    # python dev.py generate
```

```bash
# Full workflow example
python dev.py reset --scenario teacher-with-students
python dev.py server &
python dev.py generate
python dev.py simulator
```

## Constraints

- **No Xcode IDE** — all Swift builds via `xcodegen` + `xcodebuild` CLI
- **SPM for dependencies** — if we add any, they go in project.yml
- **Bundled PDFs only** — no S3 needed for dogfooding (use local/bundled pieces)
- **Single-command startup** — coding agents should be able to rebuild and run with one command

## Seed Scenarios

### 1. `empty`
- Single user (current email), no other data

### 2. `teacher-with-students`
- Teacher: teacher@example.com
- Students: student1@example.com, student2@example.com (linked to teacher)
- 3 pieces for teacher (from bundled PDFs)
- 1 routine with 2 exercises
- Student1 has routine assigned

### 3. `student-with-assignment`
- Student: student1@example.com
- Teacher: teacher@example.com
- Assigned routine with 3 exercises
- 2 completed practice sessions (for calendar gold stars)
- 1 in-progress session

## Observation Log Template

After running the app, capture friction in this format:

```markdown
## Session: [date]

### Flow: [what you tried]

- [ ] Worked as expected
- [ ] Broken: [description]
- [ ] Missing: [description]
- [ ] Friction: [description]

### Notes
[freeform observations]
```

## Done When

```bash
# 1. Generate project and build succeeds
python dev.py generate && python dev.py simulator --build-only
# Expected: BUILD SUCCEEDED

# 2. Seed data works
python dev.py reset --scenario teacher-with-students
curl -s http://localhost:8000/auth/dev-login?email=teacher@example.com | jq .user
# Expected: {"id": 1, "email": "teacher@example.com", ...}

curl -s -H "Authorization: Bearer dev_token_user_1" http://localhost:8000/routines | jq length
# Expected: 1

# 3. Full flow works
python dev.py server &
python dev.py simulator
# Expected: App launches, can sign in as teacher, see routine with pieces
```

## Open Questions

1. Do we need hot-reload for Swift, or is rebuild-on-save acceptable?
2. Should bundled PDFs be treated as "local pieces" or uploaded to local S3 (minio)?
3. What logging format? Structured JSON or human-readable with `[CATEGORY]` prefixes?
