#!/usr/bin/env python3
"""Drive the native scene tour; capture Android frames through adb.

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
    parser.add_argument("--tour", choices=["all", "flow", "benchmark"], default="all")
    parser.add_argument("--profile", action="store_true", help="Measure an AOT profile build on a supported device")
    args = parser.parse_args()
    command = [
        "flutter", "drive", "--no-pub", "--keep-app-running",
        "--driver=test_driver/phase7_scenes.dart",
        "--target=integration_test/phase7_scenes_test.dart",
        "-d", args.device, "--dart-define-from-file=config/mock.json",
        f"--dart-define=PHASE7_TOUR={args.tour}",
    ]
    if args.profile:
        command.append("--profile")
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captures = 0
    try:
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            marker = re.search(r"PHASE7_CAPTURE:(phase7/[a-zA-Z0-9_]+)", line)
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
    if args.tour != "benchmark" and args.device.startswith("emulator-") and result == 0 and captures == 0:
        raise RuntimeError("Android scene tour passed without capture markers")
    return result


if __name__ == "__main__":
    sys.exit(main())
