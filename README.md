# Cadenza

Music practice app for teachers and students.

## Overview

Cadenza helps music teachers create structured practice routines for their students, track progress, and provide feedback.

- **iOS App**: SwiftUI app for students to practice with real-time pitch detection and metronome
- **Server**: FastAPI backend for teacher/student management, practice tracking, and PDF storage

## Quick Start

### Server

```bash
cd server
docker-compose up  # Starts PostgreSQL + API
```

Or for local development:

```bash
docker-compose up db  # Just PostgreSQL
uv run uvicorn app.main:app --reload
```

### iOS App

Open `Cadenza.xcodeproj` in Xcode and run on simulator or device.

## Development

Use the `dev.py` CLI for common tasks:

```bash
python dev.py server      # Start server
python dev.py test        # Run all tests
python dev.py test --server  # Server tests only
python dev.py test --ios     # iOS tests only
```

## License

Apache 2.0
