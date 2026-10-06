#!/usr/bin/env python3
"""Drive the native completion tour; capture Android frames through adb.

Android 17's integration_test image conversion stalls with Rive textures. A
short test-only marker pauses the tour while this host captures its real surface.
iOS uses integration_test's normal screenshot callback. No app code is altered.
"""

import argparse
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--use-application-binary", help="Prepared simulator .app or Android APK")
    args = parser.parse_args()
    command = [
        "flutter", "drive", "--no-pub", "--keep-app-running",
        "--driver=test_driver/integration_test.dart",
        "--target=integration_test/phase8_completion_test.dart",
        "-d", args.device, "--dart-define-from-file=config/mock.json",
    ]
    if args.use_application_binary:
        command.append(f"--use-application-binary={args.use_application_binary}")
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captures = 0
    build_failed = False
    try:
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            if "Failed to build iOS app" in line or "Could not build the application" in line:
                build_failed = True
            if "Application failed to start on attempt:" in line:
                raise RuntimeError("Completion tour stopped after a build or launch failure")
            marker = re.search(r"PHASE8_CAPTURE:(phase8/[a-zA-Z0-9_]+)", line)
            if marker:
                image = subprocess.run(
                    ["adb", "-s", args.device, "exec-out", "screencap", "-p"],
                    capture_output=True, check=True, timeout=20,
                ).stdout
                if not image.startswith(b"\x89PNG\r\n\x1a\n"):
                    raise RuntimeError("adb did not return a PNG screenshot")
                target = Path("build/tour") / (marker.group(1) + ".png")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(image)
                captures += 1
    except BaseException:
        process.terminate()
        process.wait(timeout=30)
        raise
    result = process.wait()
    if build_failed:
        raise RuntimeError("Completion tour failed to build the requested application")
    if args.device.startswith("emulator-") and result == 0 and captures == 0:
        raise RuntimeError("Android completion tour passed without capture markers")
    return result


if __name__ == "__main__":
    sys.exit(main())
