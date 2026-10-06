#!/usr/bin/env python3
"""Draws Qabas' app icon and launch art from the same flame geometry the app
uses (lib/widgets/brand.dart → flamePath): a gold flame on deep emerald —
"a warm light seen from a distance" (brief §7, concept 4)."""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
NIGHT950, NIGHT, EMERALD = (3, 38, 36), (7, 60, 55), (11, 90, 82)
GOLD, EMBER = (224, 165, 38), (246, 227, 180)

# flamePath() control points, normalised to a w x h box
SEGMENTS = [
    ((0.23, 1.0), (0.07, 0.82), (0.09, 0.6)),
    ((0.11, 0.41), (0.28, 0.31), (0.41, 0.15)),
    ((0.47, 0.08), (0.52, 0.03), (0.57, 0.0)),
    ((0.62, 0.11), (0.67, 0.2), (0.75, 0.31)),
    ((0.85, 0.45), (0.93, 0.56), (0.91, 0.68)),
    ((0.89, 0.88), (0.73, 1.0), (0.5, 1.0)),
]


def flame_points(x0, y0, w, h, steps=40):
    pts = [(x0 + 0.5 * w, y0 + h)]
    p0 = (0.5, 1.0)
    for c1, c2, p3 in SEGMENTS:
        for i in range(1, steps + 1):
            t = i / steps
            x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * c1[0] + 3 * (1 - t) * t ** 2 * c2[0] + t ** 3 * p3[0]
            y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * c1[1] + 3 * (1 - t) * t ** 2 * c2[1] + t ** 3 * p3[1]
            pts.append((x0 + x * w, y0 + y * h))
        p0 = p3
    return pts


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, stops):
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                d.line([(0, y), (w, y)], fill=lerp(c0, c1, (t - p0) / max(1e-6, p1 - p0)))
                break
    return img


def radial_glow(size, center, radius, color, alpha):
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for r in range(int(radius), 0, -4):
        a = int(alpha * (1 - r / radius) ** 1.8)
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (a,))
    return glow.filter(ImageFilter.GaussianBlur(radius / 12))


def draw_flame(canvas, cx, base_y, fw, fh):
    """Outer gold flame with a soft ember core, like FlameMark."""
    w, h = canvas.size
    x0, y0 = cx - fw / 2, base_y - fh
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(flame_points(x0, y0, fw, fh), fill=255)
    outer = vertical_gradient((w, h), [(0, lerp(GOLD, (255, 255, 255), 0.22)), (max(0, y0 / h), lerp(GOLD, (255, 255, 255), 0.22)),
                                       (min(1, (y0 + fh * 0.55) / h), GOLD), (min(1, base_y / h), lerp(GOLD, (184, 116, 15), 0.5)), (1, lerp(GOLD, (184, 116, 15), 0.5))])
    canvas.paste(outer, (0, 0), mask)
    cw, ch = fw * 0.46, fh * 0.5
    cmask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(cmask).polygon(flame_points(cx - cw / 2, base_y - fh * 0.03 - ch, cw, ch), fill=255)
    core = vertical_gradient((w, h), [(0, (255, 253, 246)), (min(1, (base_y - ch) / h), (255, 253, 246)), (min(1, base_y / h), EMBER), (1, EMBER)])
    canvas.paste(core, (0, 0), cmask)


def icon(size=1024, ss=3, rounded=False):
    S = size * ss
    img = vertical_gradient((S, S), [(0, NIGHT950), (0.55, NIGHT), (1, EMERALD)]).convert("RGBA")
    cx, base = S / 2, S * 0.73
    fw, fh = S * 0.34, S * 0.53
    img.alpha_composite(radial_glow((S, S), (cx, base - fh * 0.38), S * 0.46, GOLD, 120))
    draw_flame(img, cx, base, fw, fh)
    img = img.resize((size, size), Image.LANCZOS)
    if rounded:
        m = Image.new("L", (size * 4, size * 4), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=size * 4 * 0.22, fill=255)
        img.putalpha(m.resize((size, size), Image.LANCZOS))
    return img


if __name__ == "__main__":
    master = icon(1024).convert("RGB")
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios / "Contents.json").read_text())
    for entry in contents["images"]:
        pts = float(entry["size"].split("x")[0])
        px = round(pts * int(entry["scale"].rstrip("x")))
        master.resize((px, px), Image.LANCZOS).save(ios / entry["filename"])
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        icon(px * 2, rounded=True).resize((px, px), Image.LANCZOS).save(ROOT / f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")
    web = ROOT / "web"
    for px in (192, 512):
        icon(px).convert("RGB").save(web / f"icons/Icon-{px}.png")
        icon(px).convert("RGB").save(web / f"icons/Icon-maskable-{px}.png")
    icon(64, rounded=True).save(web / "favicon.png")
    # The native launch screen is plain night emerald: the Flutter splash then
    # draws the path and kindles the flame, so nothing appears twice.
    li = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        Image.new("RGBA", (scale, scale), (0, 0, 0, 0)).save(li / name)
    master.save(ROOT / "docs/brand/app_icon_1024.png")
    print("icons written")
