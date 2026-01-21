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
    python dev.py open            # Open Xcode project
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).parent
SERVER_DIR = ROOT / "server"
PROJECT = ROOT / "Cadenza.xcodeproj"
CACHE_PATH = ROOT / "build" / "simulator_device_cache.json"


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=cwd, check=check)


def server(args: argparse.Namespace) -> None:
    """Start the Cadenza API server."""
    os.chdir(SERVER_DIR)

    # Start database if using docker
    if args.docker:
        run(["docker-compose", "up"])
    else:
        # Check if db is running
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=cadenza-server-db", "--format", "{{.Names}}"],
            capture_output=True, text=True
        )
        if "cadenza-server-db" not in result.stdout:
            print("Starting PostgreSQL...")
            run(["docker-compose", "up", "-d", "db"])
            time.sleep(2)

        print("\nStarting server on http://localhost:8000")
        print("API docs: http://localhost:8000/docs\n")
        run(["uv", "run", "uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000"])


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

    # Boot simulator
    subprocess.run(["xcrun", "simctl", "boot", device_id], capture_output=True)
    subprocess.run(["open", "-a", "Simulator"])

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
    test_parser.add_argument("--device", default="iPhone 16", help="iOS Simulator device")
    test_parser.add_argument("-k", "--pattern", help="Test name pattern filter")
    test_parser.set_defaults(func=test)

    # simulator
    sim_parser = subparsers.add_parser("simulator", help="Build and launch iOS simulator")
    sim_parser.add_argument("--device", default="iPhone 16", help="Simulator device name")
    sim_parser.add_argument("--mock-api", action="store_true", help="Launch with mock API data")
    sim_parser.set_defaults(func=simulator)

    # open
    open_parser = subparsers.add_parser("open", help="Open Xcode project")
    open_parser.set_defaults(func=open_xcode)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
