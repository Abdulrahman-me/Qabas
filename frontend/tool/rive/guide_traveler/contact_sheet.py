#!/usr/bin/env python3
"""Renders headless frames of each companion state with the Rive CLI and tiles
them into one contact sheet per state, so motion can be reviewed at a glance.

    python3 contact_sheet.py idle greet celebrate --bg=dark
    python3 contact_sheet.py all --bg=light
"""
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
RIVE = os.path.expanduser("~/.rive/bin/rive")
SHOTS = HERE / "shots"

STATES = {
    # name: (data flags, frames to sample)
    "idle": ([], [1, 60, 120, 180]),
    "thinking": (["--data=mood=thinking"], [40, 70, 110, 160, 210]),
    "greet": (["--data=greet=1"], [10, 25, 40, 60, 80, 110, 130]),
    "encourage": (["--data=encourage=1"], [8, 20, 30, 40, 55, 80, 105]),
    "correct": (["--data=correct=1"], [6, 14, 22, 32, 40, 55, 75]),
    "celebrate": (["--data=celebrate=1"], [10, 22, 32, 44, 54, 70, 90, 120]),
    "retry": (["--data=retry=1"], [15, 30, 55, 80, 90, 105, 125]),
    "complete": (["--data=complete=1"], [12, 28, 45, 70, 100, 135, 160]),
    "streak": (["--data=streak=1"], [15, 35, 55, 80, 105, 135, 160]),
}


def render(state, bg):
    flags, frames = STATES[state]
    SHOTS.mkdir(exist_ok=True)
    subprocess.run([sys.executable, str(HERE / "generate.py"), f"--preview={bg}"], check=True, capture_output=True)
    tiles = []
    for f in frames:
        out = SHOTS / f"_{state}_{f}.png"
        # advance one frame so the machine starts, set data, then advance the rest
        cmd = [RIVE, str(HERE), f"--screenshot={out}", "--viewport=400x400", "--advance=1", *flags, f"--advance={f}"]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout[-800:], r.stderr[-800:])
            raise SystemExit(f"render failed for {state} @ {f}")
        tiles.append((f, Image.open(out).convert("RGB")))
    w, h = 400, 400
    sheet = Image.new("RGB", (w * len(tiles), h + 26), (20, 20, 20))
    d = ImageDraw.Draw(sheet)
    for i, (f, im) in enumerate(tiles):
        sheet.paste(im, (i * w, 26))
        d.text((i * w + 8, 6), f"{state} f{f} ({f / 60:.2f}s)", fill=(230, 230, 230))
    path = SHOTS / f"{state}_{bg}.png"
    sheet.save(path)
    for f, _ in tiles:
        (SHOTS / f"_{state}_{f}.png").unlink(missing_ok=True)
    return path


if __name__ == "__main__":
    bg = "dark"
    names = []
    for a in sys.argv[1:]:
        if a.startswith("--bg="):
            bg = a.split("=", 1)[1]
        else:
            names.append(a)
    if not names or names == ["all"]:
        names = list(STATES)
    for n in names:
        print(render(n, bg))
