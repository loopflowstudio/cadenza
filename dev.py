#!/usr/bin/env python3
"""
Cadenza development CLI.

Usage:
    python dev.py server          # Start the API server
    python dev.py test            # Run all tests
    python dev.py test --server   # Run server tests only
    python dev.py test --ios      # Run iOS tests only
    python dev.py simulator       # Build and launch iOS simulator
    python dev.py simulator --mock-api  # Launch with mock API data
    python dev.py simulator --build-only  # Build without launching
    python dev.py open            # Open Xcode project
    python dev.py generate        # Generate Xcode project from project.yml
    python dev.py reset           # Reset database to clean state
    python dev.py seed            # Seed database with scenario data
    python dev.py research        # Run UX research: screenshots + Claude analysis
    python dev.py fetch-bundles   # Download PDFs from Dropbox
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent
SERVER_DIR = ROOT / "server"
PROJECT = ROOT / "Cadenza.xcodeproj"
CACHE_PATH = ROOT / "build" / "simulator_device_cache.json"


def _get_branch_name() -> str:
    """Get current git branch name."""
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True, text=True, cwd=ROOT
    )
    return result.stdout.strip() if result.returncode == 0 else "main"


def _get_db_port() -> int:
    """Get a deterministic port for this branch (5433-5532 range)."""
    branch = _get_branch_name()
    hash_val = int(hashlib.md5(branch.encode()).hexdigest()[:8], 16)
    return 5433 + (hash_val % 100)


def _get_compose_project() -> str:
    """Get docker-compose project name for this branch."""
    branch = _get_branch_name()
    # Sanitize branch name for docker
    safe = branch.replace("/", "-").replace("_", "-").lower()
    return f"cadenza-{safe}"


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=cwd, check=check)


def server(args: argparse.Namespace) -> None:
    """Start the Cadenza API server."""
    port = _get_db_port()
    project = _get_compose_project()
    db_url = f"postgresql://cadenza:cadenza_dev@localhost:{port}/cadenza"

    print(f"Branch: {_get_branch_name()}")
    print(f"DB port: {port}")
    print(f"Project: {project}\n")

    # Set environment for docker-compose
    compose_env = {
        **os.environ,
        "COMPOSE_PROJECT_NAME": project,
        "CADENZA_DB_PORT": str(port),
    }

    # Start database if using docker
    if args.docker:
        subprocess.run(["docker-compose", "up"], cwd=SERVER_DIR, env=compose_env)
    else:
        # Check if our specific db container is running
        container_name = f"{project}-db-1"
        result = subprocess.run(
            ["docker", "ps", "--filter", f"name={container_name}", "--format", "{{.Names}}"],
            capture_output=True, text=True
        )
        if container_name not in result.stdout:
            print("Starting PostgreSQL...")
            subprocess.run(
                ["docker-compose", "up", "-d", "db"],
                cwd=SERVER_DIR, env=compose_env
            )
            time.sleep(2)

        print(f"\nStarting server on http://localhost:8000")
        print(f"API docs: http://localhost:8000/docs\n")

        server_env = {**os.environ, "DATABASE_URL": db_url}
        subprocess.run(
            ["uv", "run", "uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000"],
            cwd=SERVER_DIR, env=server_env
        )


def test(args: argparse.Namespace) -> None:
    """Run tests."""
    if args.server or not args.ios:
        print("=== Server Tests ===\n")
        cmd = ["uv", "run", "pytest", "tests/", "-v"]
        if args.pattern:
            cmd.extend(["-k", args.pattern])
        run(cmd, cwd=SERVER_DIR, check=False)

    if args.ios or not args.server:
        print("\n=== iOS Tests ===\n")
        if not _has_xcode():
            print("Skipping iOS tests (Xcode not configured)")
            print("Run from Xcode: Cmd+U")
            return

        cmd = [
            "xcodebuild", "test",
            "-project", str(PROJECT),
            "-scheme", "Cadenza",
            "-destination", f"platform=iOS Simulator,name={args.device}",
            "-only-testing:CadenzaTests",
        ]
        run(cmd, check=False)


def simulator(args: argparse.Namespace) -> None:
    """Build and launch the iOS app in simulator."""
    if not _has_xcode():
        print("Error: Xcode not configured. Run: sudo xcode-select -s /Applications/Xcode.app")
        sys.exit(1)

    device = args.device
    print(f"Building Cadenza for {device}...")

    # Get device ID
    devices = _load_simctl_devices()
    device_id = None
    if devices:
        for runtime, device_list in devices.get("devices", {}).items():
            if "iOS" in runtime:
                for d in device_list:
                    if device in d["name"] and d["isAvailable"]:
                        device_id = d["udid"]
                        break
    elif _looks_like_udid(device):
        device_id = device

    if not device_id:
        cached_id = _load_cached_device_id(device)
        if cached_id:
            device_id = cached_id

    if not device_id:
        print(f"Error: Device '{device}' not found")
        subprocess.run(["xcrun", "simctl", "list", "devices", "available"])
        sys.exit(1)
    if devices and device_id and not _looks_like_udid(device):
        _cache_device_id(device, device_id)

    # Build
    build_dir = ROOT / "build"
    run([
        "xcodebuild",
        "-project", str(PROJECT),
        "-scheme", "Cadenza",
        "-destination", f"platform=iOS Simulator,id={device_id}",
        "-derivedDataPath", str(build_dir),
        "build"
    ])

    if args.build_only:
        print("\nBuild succeeded")
        return

    # Boot simulator
    subprocess.run(["xcrun", "simctl", "boot", device_id], capture_output=True)
    subprocess.run(["open", "-a", "Simulator"])

    # Find and install app
    app_path = None
    for path in build_dir.rglob("Cadenza.app"):
        if "Debug-iphonesimulator" in str(path):
            app_path = path
            break

    if app_path:
        try:
            run(["xcrun", "simctl", "install", device_id, str(app_path)])
        except subprocess.CalledProcessError:
            print("Simulator install failed. Check simulator availability and try again.")
            return

        launch_cmd = ["xcrun", "simctl", "launch", device_id, "com.cadenza.Cadenza"]
        if args.mock_api:
            launch_cmd.extend(["--args", "--mock-api"])
        launch_result = subprocess.run(launch_cmd)
        if launch_result.returncode != 0:
            print("Simulator launch failed. Retrying after reset...")
            _reset_simulator(device_id)
            launch_retry = subprocess.run(launch_cmd)
            if launch_retry.returncode != 0:
                print("Simulator launch failed after reset. Open Simulator or run from Xcode.")
                return
        print(f"\nApp launched on {device}")
    else:
        print("\nBuild succeeded. Open Xcode to run.")


def open_xcode(args: argparse.Namespace) -> None:
    """Open the Xcode project."""
    subprocess.run(["open", str(PROJECT)])


def generate(args: argparse.Namespace) -> None:
    """Generate Xcode project from project.yml using xcodegen."""
    project_yml = ROOT / "project.yml"
    if not project_yml.exists():
        print("Error: project.yml not found")
        sys.exit(1)

    result = subprocess.run(["which", "xcodegen"], capture_output=True)
    if result.returncode != 0:
        print("Error: xcodegen not installed")
        print("Install with: brew install xcodegen")
        sys.exit(1)

    run(["xcodegen", "generate"])
    print("\nXcode project generated successfully")


def reset(args: argparse.Namespace) -> None:
    """Reset database to clean state, optionally seed with scenario."""
    port = _get_db_port()
    db_url = f"postgresql://cadenza:cadenza_dev@localhost:{port}/cadenza"
    env = {**os.environ, "DATABASE_URL": db_url}

    print(f"Branch: {_get_branch_name()}, DB port: {port}\n")

    scenario = args.scenario or "empty"
    subprocess.run(
        ["uv", "run", "python", "seed_scenario.py", "--scenario", scenario],
        cwd=SERVER_DIR, env=env, check=True
    )


def seed(args: argparse.Namespace) -> None:
    """Seed database with a specific scenario."""
    port = _get_db_port()
    db_url = f"postgresql://cadenza:cadenza_dev@localhost:{port}/cadenza"
    env = {**os.environ, "DATABASE_URL": db_url}

    if not args.list:
        print(f"Branch: {_get_branch_name()}, DB port: {port}\n")

    cmd = ["uv", "run", "python", "seed_scenario.py"]
    if args.list:
        cmd.append("--list")
    elif args.scenario:
        cmd.extend(["--scenario", args.scenario])
    else:
        cmd.append("--list")

    subprocess.run(cmd, cwd=SERVER_DIR, env=env)


def research(args: argparse.Namespace) -> None:
    """Run UX research: capture screenshots and analyze with Claude."""
    import base64

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = ROOT / "scratch" / "research" / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)

    scenarios = args.scenarios.split(",") if args.scenarios else ["teacher-assigns-routine"]

    print(f"Running UX research")
    print(f"Scenarios: {scenarios}")
    print(f"Output: {output_dir}\n")

    # Run each scenario and capture screenshots
    all_screenshots = []
    config_path = Path("/tmp/cadenza-research-config.json")

    for scenario in scenarios:
        scenario_dir = output_dir / scenario
        scenario_dir.mkdir(exist_ok=True)

        # Write config file for test to read
        config = {"scenario": scenario, "outputDir": str(scenario_dir)}
        config_path.write_text(json.dumps(config))

        print(f"Running scenario: {scenario}")
        result = subprocess.run([
            "xcodebuild", "test",
            "-project", str(PROJECT),
            "-scheme", "Cadenza",
            "-destination", f"platform=iOS Simulator,name={args.device}",
            "-only-testing:CadenzaUITests/ScreenshotPipelineTests/testCaptureScenario",
        ], capture_output=True, text=True)

        if result.returncode != 0:
            print(f"  Warning: scenario failed")
            if args.verbose:
                print(result.stderr[-500:] if len(result.stderr) > 500 else result.stderr)

        screenshots = list(scenario_dir.glob("*.png"))
        all_screenshots.extend(screenshots)
        print(f"  Captured {len(screenshots)} screenshots")

    if not all_screenshots:
        print("\nNo screenshots captured. Skipping analysis.")
        return

    # Analyze with Claude
    print(f"\nAnalyzing {len(all_screenshots)} screenshots with Claude...")

    try:
        import anthropic
    except ImportError:
        print("Error: anthropic package not installed")
        print("Run: uv pip install anthropic")
        return

    client = anthropic.Anthropic()

    # Build message with images
    content = [{
        "type": "text",
        "text": """You are reviewing screenshots from a music practice app (Cadenza) used by:
- Teachers: assign routines to students, track progress
- Students: practice assigned routines, view sheet music
- Self-taught: manage their own learning

For each screenshot sequence, identify:
1. Confusing UI elements or unclear affordances
2. Missing information a user would need
3. Friction points in the workflow
4. What works well

Be specific. Reference exact UI elements visible in the screenshots.
Format as markdown with ## headers for each issue found."""
    }]

    for screenshot in all_screenshots:
        with open(screenshot, "rb") as f:
            image_data = base64.standard_b64encode(f.read()).decode("utf-8")
        content.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": image_data,
            }
        })
        content.append({
            "type": "text",
            "text": f"Screenshot: {screenshot.parent.name}/{screenshot.name}"
        })

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        messages=[{"role": "user", "content": content}]
    )

    analysis = response.content[0].text

    # Write analysis to scratch/research/
    report_file = output_dir / "analysis.md"
    report_file.write_text(analysis)

    print(f"\nAnalysis written to {report_file}")
    print("\n" + "=" * 60)
    print(analysis)


def fetch_bundles(args: argparse.Namespace) -> None:
    """Download bundled PDFs from Dropbox."""
    import urllib.request
    import zipfile

    config_path = ROOT / ".cadenza-local.json"
    resources_dir = ROOT / "Cadenza" / "Resources"

    # Load or create config
    if config_path.exists():
        config = json.loads(config_path.read_text())
    else:
        config = {}

    # Get Dropbox link from config or args
    dropbox_url = args.url or config.get("dropbox_bundles_url")

    if not dropbox_url:
        print("No Dropbox URL configured.")
        print("\nTo set up, either:")
        print("  1. Run: python dev.py fetch-bundles --url 'https://dropbox.com/...'")
        print("  2. Create .cadenza-local.json with: {\"dropbox_bundles_url\": \"...\"}")
        print("\nThe URL should be a shared folder link. Add ?dl=1 to force download.")
        return

    # Save URL to config for future use
    if args.url:
        config["dropbox_bundles_url"] = args.url
        config_path.write_text(json.dumps(config, indent=2))
        print(f"Saved Dropbox URL to {config_path}")

    # Ensure dl=1 for direct download
    if "dl=0" in dropbox_url:
        dropbox_url = dropbox_url.replace("dl=0", "dl=1")
    elif "dl=1" not in dropbox_url:
        dropbox_url += "&dl=1" if "?" in dropbox_url else "?dl=1"

    print(f"Downloading from Dropbox...")

    # Download to temp file
    zip_path = Path("/tmp/cadenza-bundles.zip")
    try:
        urllib.request.urlretrieve(dropbox_url, zip_path)
    except Exception as e:
        print(f"Download failed: {e}")
        return

    # Extract PDFs
    resources_dir.mkdir(parents=True, exist_ok=True)
    pdf_count = 0

    try:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            for name in zf.namelist():
                if name.endswith('.pdf'):
                    # Extract just the filename, not the folder path
                    filename = Path(name).name
                    target = resources_dir / filename
                    with zf.open(name) as src, open(target, 'wb') as dst:
                        dst.write(src.read())
                    pdf_count += 1
                    print(f"  Extracted: {filename}")
    except zipfile.BadZipFile:
        # Might be a single PDF, not a zip
        if zip_path.stat().st_size > 0:
            # Check if it's actually a PDF
            with open(zip_path, 'rb') as f:
                header = f.read(4)
            if header == b'%PDF':
                target = resources_dir / "downloaded.pdf"
                zip_path.rename(target)
                print(f"  Downloaded single PDF: {target.name}")
                pdf_count = 1
            else:
                print("Downloaded file is not a valid zip or PDF")
                return

    zip_path.unlink(missing_ok=True)
    print(f"\nDownloaded {pdf_count} PDFs to {resources_dir}")


def _load_simctl_devices() -> dict | None:
    for _ in range(3):
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                pass
        _restart_simulator_service(result.stderr)
        time.sleep(2)

    print("Warning: Failed to read simulator device list.")
    if result.stderr:
        print(result.stderr.strip())
    return None


def _restart_simulator_service(stderr: str) -> None:
    if stderr:
        print(stderr.strip())
    user_id = str(os.getuid())
    subprocess.run(
        ["launchctl", "kickstart", "-k", f"gui/{user_id}/com.apple.CoreSimulator.CoreSimulatorService"],
        capture_output=True
    )
    subprocess.run(["open", "-a", "Simulator"], capture_output=True)


def _reset_simulator(device_id: str) -> None:
    subprocess.run(["xcrun", "simctl", "terminate", device_id, "com.cadenza.Cadenza"], capture_output=True)
    subprocess.run(["xcrun", "simctl", "shutdown", device_id], capture_output=True)
    subprocess.run(["xcrun", "simctl", "boot", device_id], capture_output=True)
    subprocess.run(["open", "-a", "Simulator"], capture_output=True)


def _looks_like_udid(value: str) -> bool:
    if len(value) != 36:
        return False
    parts = value.split("-")
    if len(parts) != 5:
        return False
    return all(part and all(ch in "0123456789abcdefABCDEF" for ch in part) for part in parts)


def _load_cached_device_id(device: str) -> str | None:
    if not CACHE_PATH.exists():
        return None
    try:
        data = json.loads(CACHE_PATH.read_text())
    except json.JSONDecodeError:
        return None
    cached_id = data.get(device)
    if cached_id and _looks_like_udid(cached_id):
        print(f"Using cached simulator ID for {device}: {cached_id}")
        return cached_id
    return None


def _cache_device_id(device: str, device_id: str) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if CACHE_PATH.exists():
        try:
            data = json.loads(CACHE_PATH.read_text())
        except json.JSONDecodeError:
            data = {}
    data[device] = device_id
    CACHE_PATH.write_text(json.dumps(data, indent=2))


def _has_xcode() -> bool:
    """Check if Xcode is properly configured."""
    result = subprocess.run(
        ["xcode-select", "-p"],
        capture_output=True, text=True
    )
    return "Xcode.app" in result.stdout


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Cadenza development CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # server
    server_parser = subparsers.add_parser("server", help="Start the API server")
    server_parser.add_argument("--docker", action="store_true", help="Run everything in Docker")
    server_parser.set_defaults(func=server)

    # test
    test_parser = subparsers.add_parser("test", help="Run tests")
    test_parser.add_argument("--server", action="store_true", help="Server tests only")
    test_parser.add_argument("--ios", action="store_true", help="iOS tests only")
    test_parser.add_argument("--device", default="iPhone 17", help="iOS Simulator device")
    test_parser.add_argument("-k", "--pattern", help="Test name pattern filter")
    test_parser.set_defaults(func=test)

    # simulator
    sim_parser = subparsers.add_parser("simulator", help="Build and launch iOS simulator")
    sim_parser.add_argument("--device", default="iPhone 17", help="Simulator device name")
    sim_parser.add_argument("--mock-api", action="store_true", help="Launch with mock API data")
    sim_parser.add_argument("--build-only", action="store_true", help="Build without launching")
    sim_parser.set_defaults(func=simulator)

    # open
    open_parser = subparsers.add_parser("open", help="Open Xcode project")
    open_parser.set_defaults(func=open_xcode)

    # generate
    gen_parser = subparsers.add_parser("generate", help="Generate Xcode project from project.yml")
    gen_parser.set_defaults(func=generate)

    # reset
    reset_parser = subparsers.add_parser("reset", help="Reset database to clean state")
    reset_parser.add_argument("--scenario", "-s", help="Scenario to seed after reset")
    reset_parser.set_defaults(func=reset)

    # seed
    seed_parser = subparsers.add_parser("seed", help="Seed database with scenario data")
    seed_parser.add_argument("--scenario", "-s", help="Scenario name")
    seed_parser.add_argument("--list", "-l", action="store_true", help="List available scenarios")
    seed_parser.set_defaults(func=seed)

    # research
    research_parser = subparsers.add_parser("research", help="Run UX research: screenshots + Claude analysis")
    research_parser.add_argument("--scenarios", "-s", help="Comma-separated scenario names")
    research_parser.add_argument("--device", default="iPhone 17", help="Simulator device")
    research_parser.add_argument("--verbose", "-v", action="store_true", help="Show xcodebuild output")
    research_parser.set_defaults(func=research)

    # fetch-bundles
    fetch_parser = subparsers.add_parser("fetch-bundles", help="Download PDFs from Dropbox")
    fetch_parser.add_argument("--url", help="Dropbox shared folder URL")
    fetch_parser.set_defaults(func=fetch_bundles)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
