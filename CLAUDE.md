# Claude Code Instructions

## Python Commands

This repo uses `uv` for Python dependency management. Always prefix Python commands with `uv run`:

```bash
uv run python script.py
uv run pytest tests/
uv run uvicorn app.main:app
```

## Project Structure

- `Cadenza/` - iOS app (SwiftUI, SwiftData, iOS 17+)
- `server/` - FastAPI backend
- `dev.py` - Development CLI

## Development CLI

The `dev.py` CLI handles `uv run` internally:

```bash
python dev.py server      # Start server
python dev.py test        # All tests
python dev.py test --server  # Server only
python dev.py test --ios     # iOS only
```

## Running Tests

```bash
python dev.py test           # All tests
python dev.py test --server  # Server only
python dev.py test --ios     # iOS only
```
