#!/usr/bin/env python3
"""Generates scene.rml — the Qabas companion character.

The companion is an original, faceless traveller in a hooded emerald cloak and a
flame-gold scarf, carrying the small ember (the qabas) that gives the product its
name. Following the brief's imagery rules the face is a blank, featureless shape:
every emotion is carried by pose, gesture, head orientation (where the face sits
inside the hood), cloth motion and the ember's light.

    python3 generate.py                 # production scene (transparent artboard)
    python3 generate.py --preview=dark  # adds a Deep Night Emerald backdrop
    python3 generate.py --preview=light # adds a Morning Mint backdrop

Then build with the Rive CLI:  rive . --once   (→ build/companion.riv)

Runtime contract (View Model `Companion`, bound to artboard `Companion`):
    mood       enum  idle | thinking      persistent looping state
    greet      trigger                    wave hello
    encourage  trigger                    "you can do it" fist pump
    celebrate  trigger                    jump with sparkles
    correct    trigger                    quick happy hop
    retry      trigger                    gentle "oops, let's try again"
    complete   trigger                    lesson complete, arms open, light rises
    streak     trigger                    raises the ember as it grows
One-shot reactions return to the current `mood` on their own.
"""

import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FPS = 60

# ----------------------------------------------------------------------------
# Brand palette (QABAS_PROJECT_BRIEF.md §6.1) plus character-only tones
# ----------------------------------------------------------------------------
NIGHT = "073C37"      # Deep Night Emerald
EMERALD = "0B5A52"    # Emerald
GOLD = "E0A526"       # Flame Gold
EMBER = "F6E3B4"      # Soft Ember
MINT = "EEF5F2"       # Morning Mint
INK = "16233A"        # Deep Ink

CLOAK_HI = "1E9180"
CLOAK = "13786B"
CLOAK_LO = "0E6157"
LINING = "08423C"
TUNIC_HI = "F4E8CF"
TUNIC = "E9D6AE"
SKIN_HI = "D8AB8A"
SKIN = "C39373"
SKIN_LO = "A97B5C"
TROUSER = "22324A"
SHOE = "3B2C24"
LEATHER = "8C5B37"
LEATHER_LO = "6E4428"
GOLD_LO = "C98A16"


def argb(hex6, alpha=0xFF):
    return f"{alpha:02X}{hex6}"


def rad(deg):
    return deg * math.pi / 180.0


# ----------------------------------------------------------------------------
# Tiny XML builder
# ----------------------------------------------------------------------------
class Ids:
    def __init__(self, start=10):
        self.n = start

    def __call__(self):
        self.n += 1
        return f"0:{self.n}"


nid = Ids()


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        s = f"{v:.4f}".rstrip("0").rstrip(".")
        return "0" if s in ("-0", "") else s
    return str(v).replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;")


class El:
    def __init__(self, tag, *children, **attrs):
        self.tag = tag
        self.children = [c for c in children if c is not None]
        self.attrs = {k: v for k, v in attrs.items() if v is not None}

    def add(self, *children):
        self.children.extend(c for c in children if c is not None)
        return self

    def render(self, ind=0):
        pad = "    " * ind
        keys = [k for k in self.attrs if k not in ("name", "id")] + [k for k in ("name", "id") if k in self.attrs]
        attrs = "".join(f' {k}="{fmt(self.attrs[k])}"' for k in keys)
        if not self.children:
            return f"{pad}<{self.tag}{attrs}/>"
        inner = "\n".join(c.render(ind + 1) if hasattr(c, "render") else f"{pad}    {c}" for c in self.children)
        return f"{pad}<{self.tag}{attrs}>\n{inner}\n{pad}</{self.tag}>"


class Comment:
    def __init__(self, text):
        self.text = text

    def render(self, ind=0):
        return "    " * ind + f"<!-- {self.text} -->"


# ----------------------------------------------------------------------------
# Scene registry: every animatable object gets a name → id, and its authored
# value becomes the rest pose.
# ----------------------------------------------------------------------------
T = {}       # target name -> id
REST = {}    # (target, prop) -> authored value
PROP_KEY = {"x": 13, "y": 14, "rot": 15, "sx": 16, "sy": 17, "op": 18,
            "w": 20, "h": 21, "vx": 24, "vy": 25, "color": 37, "stop": 38,
            "inner": 0}


def reg(name, **rest):
    if name in T:
        raise ValueError(f"duplicate target {name}")
    T[name] = nid()
    for k, v in rest.items():
        REST[(name, k)] = v
    return T[name]


def node(name, *children, x=0.0, y=0.0, rot=0.0, sx=1.0, sy=1.0, op=1.0):
    i = reg(name, x=x, y=y, rot=rot, sx=sx, sy=sy, op=op)
    return El("Node", *children, x=x, y=y, rotation=rot or None,
              scaleX=None if sx == 1 else sx, scaleY=None if sy == 1 else sy,
              opacity=None if op == 1 else op, name=name, id=i)


def shape(name, *children, x=0.0, y=0.0, rot=0.0, sx=1.0, sy=1.0, op=1.0, blend=None):
    i = reg(name, x=x, y=y, rot=rot, sx=sx, sy=sy, op=op)
    return El("Shape", *children, x=x, y=y, rotation=rot or None,
              scaleX=None if sx == 1 else sx, scaleY=None if sy == 1 else sy,
              opacity=None if op == 1 else op, blendModeValue=blend, name=name, id=i)


def ellipse(w, h, x=0.0, y=0.0, name="Path", key=None):
    i = reg(key, w=w, h=h) if key else None
    return El("Ellipse", x=x or None, y=y or None, width=w, height=h, name=name, id=i)


def rect(w, h, r=0.0, x=0.0, y=0.0, ox=0.5, oy=0.5, name="Path"):
    return El("Rectangle", x=x or None, y=y or None, width=w, height=h,
              originX=None if ox == 0.5 else ox, originY=None if oy == 0.5 else oy,
              cornerRadiusTL=r or None, name=name)


def solid(color, key=None):
    i = reg(key, color=color) if key else None
    return El("SolidColor", colorValue=color, name="Color", id=i)


def fill(paint, name="Fill"):
    return El("Fill", paint, name=name)


def stroke(paint, thickness, cap="round", join="round", name="Stroke"):
    return El("Stroke", paint, thickness=thickness, cap=cap, join=join, name=name)


def stop(color, pos):
    return El("GradientStop", colorValue=color, position=pos)


def linear(sx, sy, ex, ey, *stops):
    return El("LinearGradient", *stops, startX=sx, startY=sy, endX=ex, endY=ey, name="Gradient")


def radial(cx, cy, r, *stops):
    return El("RadialGradient", *stops, startX=cx, startY=cy, endX=cx + r, endY=cy, name="Gradient")


def smooth_path(points, closed=True, tension=1.0, keys=None, name="Path"):
    """Catmull-Rom spline through points, emitted as mirrored cubic vertices.

    points: (x, y) for a smooth point or (x, y, 'c', radius) for a corner.
    keys:   optional {index: target-name} to make vertices animatable.
    """
    n = len(points)
    verts = []
    for i, p in enumerate(points):
        x, y = p[0], p[1]
        vkey = (keys or {}).get(i)
        vid = reg(vkey, vx=x, vy=y) if vkey else None
        if len(p) > 2 and p[2] == "c":
            verts.append(El("StraightVertex", x=x, y=y, radius=p[3] if len(p) > 3 else None, id=vid))
            continue
        prev = points[(i - 1) % n] if (closed or i > 0) else p
        nxt = points[(i + 1) % n] if (closed or i < n - 1) else p
        dx, dy = nxt[0] - prev[0], nxt[1] - prev[1]
        dist = math.hypot(dx, dy) / 6.0 * tension
        verts.append(El("CubicMirroredVertex", x=x, y=y, rotation=math.atan2(dy, dx), distance=dist, id=vid))
    return El("PointsPath", *verts, isClosed=closed, name=name)


def polyline(points, name="Path"):
    return El("PointsPath", *[El("StraightVertex", x=x, y=y) for x, y in points], isClosed=False, name=name)


# ----------------------------------------------------------------------------
# Character geometry
# ----------------------------------------------------------------------------
SHOULDER = 34.0
SHOULDER_Y = -76.0
UPPER = 33.0
FORE = 31.0


OUTLINE = argb("06302B", 0x8C)


def limb(name, length, color, thickness):
    """A capsule limb with a soft dark edge so gestures read on any backdrop."""
    return shape(name, polyline([(0, 0), (0, length)]),
                 stroke(solid(OUTLINE), thickness + 3.0, name="Edge"),
                 stroke(color if isinstance(color, El) else solid(color), thickness, name="Stroke"))


def arm(side):
    """side: 'R' (viewer's right) or 'L'. Shoulder node → elbow node → hand.
    The emerald cloak sleeve covers the upper arm; the cream tunic sleeve shows
    on the forearm, which keeps every gesture legible against the cape."""
    s = 1 if side == "R" else -1
    hand = shape(f"Hand{side}Shape",
                 ellipse(19, 19),
                 stroke(solid(argb("7A5038", 0x80)), 1.6, name="Edge"),
                 fill(radial(-2 * s, -3, 12, stop(argb(SKIN_HI), 0), stop(argb(SKIN), 0.7), stop(argb(SKIN_LO), 1))))
    cuff = shape(f"Cuff{side}", polyline([(0, 23), (0, 27.5)]),
                 stroke(solid(argb(CLOAK)), 15.0, cap="butt"))
    forearm = limb(f"Forearm{side}", 27, linear(0, 0, 0, 27, stop(argb(TUNIC_HI), 0), stop(argb(TUNIC), 1)), 14.0)
    elbow = node(f"Elbow{side}", node(f"Hand{side}", hand, y=FORE), cuff, forearm, y=UPPER)
    upper = limb(f"Upper{side}", UPPER, linear(0, 0, 0, 33, stop(argb(CLOAK_HI), 0), stop(argb(CLOAK), 1)), 17.0)
    return node(f"Arm{side}", elbow, upper, x=s * SHOULDER, y=SHOULDER_Y)


def leg(side):
    s = 1 if side == "R" else -1
    shoe = shape(f"Shoe{side}", ellipse(25, 13),
                 fill(linear(0, -6, 0, 6, stop(argb("4A382E"), 0), stop(argb(SHOE), 1))),
                 x=s * 3.5, y=43)
    limb = shape(f"Shin{side}", polyline([(0, 0), (0, 40)]), stroke(solid(argb(TROUSER)), 16.5, cap="round"))
    return node(f"Leg{side}", shoe, limb, x=s * 12.5)


def head():
    face = shape("FaceShape",
                 ellipse(50, 55),
                 fill(radial(-6, -12, 40, stop(argb(SKIN_HI), 0), stop(argb(SKIN), 0.62), stop(argb(SKIN_LO), 1))),
                 # warm light from the ember below — no features, only light
                 fill(radial(0, 30, 34, stop(argb(GOLD, 0x66), 0), stop(argb(GOLD, 0x00), 1)), name="Ember Light"),
                 El("ClippingShape", sourceId="0:9", name="Hood Opening"))
    face_node = node("Face", face, y=6)
    mask = El("Shape", ellipse(66, 71), x=0, y=5, name="FaceMask", id="0:9")
    lining = shape("Lining", ellipse(66, 71),
                   fill(radial(0, 8, 40, stop(argb(LINING), 0.55), stop(argb("052E2A"), 1))),
                   stroke(solid(argb(CLOAK_HI)), 3.0), y=5)
    hood_pts = [(-36, 36), (-46, 6), (-42, -24), (-28, -44), (-14, -60), (2, -52), (24, -44),
                (42, -22), (46, 8), (36, 36), (0, 44)]
    hood = shape("Hood",
                 smooth_path(hood_pts, keys={4: "HoodPeak"}),
                 fill(linear(-20, -60, 20, 40, stop(argb(CLOAK_HI), 0), stop(argb(CLOAK), 0.55), stop(argb(CLOAK_LO), 1))))
    return node("Neck", node("Head", face_node, mask, lining, hood, y=-36), y=-84)


def torso():
    cape_pts = [(-19, -90), (-38, -80), (-47, -62), (-48, -50), (-26, -42), (0, -38), (26, -42),
                (48, -50), (47, -62), (38, -80), (19, -90)]
    cape = shape("Cape", smooth_path(cape_pts),
                 fill(linear(0, -90, 0, -40, stop(argb(CLOAK_HI), 0), stop(argb(CLOAK), 0.6), stop(argb(CLOAK_LO), 1))))
    tunic_pts = [(-18, -86), (-33, -76), (-38, -46), (-43, -12), (-46, 12, "c", 9), (0, 18),
                 (46, 12, "c", 9), (43, -12), (38, -46), (33, -76), (18, -86)]
    tunic = shape("Tunic",
                  smooth_path(tunic_pts, keys={4: "HemL", 6: "HemR"}),
                  fill(linear(-30, -80, 30, 18, stop(argb(TUNIC_HI), 0), stop(argb(TUNIC), 1))),
                  fill(linear(0, -20, 0, 18, stop(argb(EMERALD, 0x00), 0), stop(argb(EMERALD, 0x22), 1)), name="Shade"))
    belt = shape("Belt", polyline([(-41, -14), (41, -14)]), stroke(solid(argb(CLOAK_LO)), 5, cap="butt"))
    strap = shape("Strap", polyline([(-30, -82), (27, -10)]), stroke(solid(argb(LEATHER_LO)), 5.5, cap="round"))
    bag = node("Bag",
               shape("Clasp", ellipse(6, 6), fill(solid(argb(GOLD))), y=3),
               shape("Flap", rect(26, 11, 5, y=-3), fill(solid(argb(LEATHER_LO)))),
               shape("BagBody", rect(26, 22, 6, y=4), fill(linear(0, -6, 0, 14, stop(argb(LEATHER), 0), stop(argb(LEATHER_LO), 1)))),
               x=34, y=-6)
    scarf_knot = node("ScarfFront",
                      shape("ScarfDrop", smooth_path([(-4, 0), (4, 0), (6, 22), (0, 26), (-5, 21)], keys={3: "ScarfDropTip"}),
                            fill(linear(0, 0, 0, 26, stop(argb(GOLD), 0), stop(argb(GOLD_LO), 1)))),
                      shape("ScarfKnot", ellipse(13, 12), fill(solid(argb(GOLD_LO)))),
                      x=13, y=-78)
    scarf_wrap = shape("ScarfWrap", rect(58, 17, 8.5),
                       fill(linear(0, -8, 0, 8, stop(argb("EDBA45"), 0), stop(argb(GOLD), 0.5), stop(argb(GOLD_LO), 1))),
                       stroke(solid(argb(EMBER, 0x55)), 1.6), y=-84)
    # the long tail streams behind in a soft night breeze
    centre = [(0, 0), (-18, 6), (-38, 4), (-58, 12), (-76, 10)]
    half = [7.5, 7.0, 6.4, 5.8, 5.0]
    top = [(x, y - w) for (x, y), w in zip(centre, half)]
    bot = [(x, y + w) for (x, y), w in reversed(list(zip(centre, half)))]
    tail_pts = top + [(-83, 11)] + bot
    tail_keys = {3: "TailT3", 4: "TailT4", 5: "TailTip", 6: "TailB4", 7: "TailB3"}
    scarf_tail = node("ScarfTail",
                      shape("ScarfTailShape", smooth_path(tail_pts, keys=tail_keys, tension=0.9),
                            fill(linear(0, 0, -84, 10, stop(argb(GOLD), 0), stop(argb("EDBA45"), 0.6), stop(argb(GOLD_LO), 1))),
                            ),
                      x=-14, y=-82, rot=rad(24))
    return node("Torso", arm("R"), arm("L"), scarf_knot, scarf_wrap, head(), bag, cape, strap, belt, tunic, scarf_tail)


def ember():
    flame = [(0, 12), (-11, 3.5), (-9.5, -8.5), (0, -25), (9.5, -8.5), (11, 3.5)]
    core = [(0, 11), (-6, 5), (-5.4, -2.4), (0, -12), (5.4, -2.4), (6, 5)]
    return node("Ember",
                node("EmberFlicker",
                     shape("EmberCore", smooth_path(core, keys={3: "CoreTip"}),
                           fill(radial(0, 5, 11, stop(argb("FFFDF5"), 0), stop(argb(EMBER), 1)))),
                     shape("EmberFlame", smooth_path(flame, keys={3: "FlameTip"}),
                           fill(linear(0, -25, 0, 12, stop(argb("F2BF45"), 0), stop(argb(GOLD), 0.6), stop(argb("D7901C"), 1)))),
                     y=0),
                shape("EmberGlow", ellipse(124, 124),
                      fill(radial(0, 0, 62, stop(argb(GOLD, 0x7A), 0), stop(argb(GOLD, 0x30), 0.45), stop(argb(GOLD, 0x00), 1)))),
                y=-104)


SPARKLES = [(-74, -206), (76, -196), (-98, -128), (100, -118), (-42, -250), (50, -244), (-104, -60), (108, -58)]
RISERS = [(-34, -70), (22, -52), (44, -96), (-52, -36), (6, -126), (-12, -90)]


def fx_front():
    kids = []
    for i, (x, y) in enumerate(SPARKLES):
        size = 16 if i % 2 == 0 else 12
        kids.append(shape(f"Spark{i}",
                          El("Star", width=size, height=size, points=4, innerRadius=0.32, cornerRadius=1.5, name="Path"),
                          fill(solid(argb("FFF1C9"))),
                          x=x, y=y, sx=0.0, sy=0.0, op=0.0))
    for i, (x, y) in enumerate(RISERS):
        kids.append(shape(f"Riser{i}", ellipse(7 if i % 2 else 5, 7 if i % 2 else 5),
                          fill(solid(argb("F3C556"))), x=x, y=y, op=0.0))
    kids.append(shape("Ripple", ellipse(34, 34), stroke(solid(argb(EMBER)), 2.5),
                      x=0, y=-104, sx=0.4, sy=0.4, op=0.0))
    return node("FxFront", *kids)


def fx_back():
    rays = shape("Rays",
                 El("Star", width=330, height=330, points=12, innerRadius=0.42, cornerRadius=10, name="Path"),
                 fill(radial(0, 0, 165, stop(argb(GOLD, 0x55), 0), stop(argb(GOLD, 0x1C), 0.55), stop(argb(GOLD, 0x00), 1))),
                 op=0.0, sx=0.6, sy=0.6)
    aura = shape("Aura", ellipse(320, 320),
                 fill(radial(0, 0, 160, stop(argb(GOLD, 0x5A), 0), stop(argb(GOLD, 0x18), 0.5), stop(argb(GOLD, 0x00), 1))),
                 op=0.0)
    return node("FxBack", aura, rays, y=-140)


def body():
    hips = node("Hips", node("Breath", torso()), leg("R"), leg("L"), y=-46)
    return node("Body", hips)


# ----------------------------------------------------------------------------
# Posing: IK for the arms, everything else by hand
# ----------------------------------------------------------------------------
def ik(side, hx, hy, elbow="out"):
    """Hand target in torso space → shoulder & elbow rotations (rest = arm hanging down)."""
    s = 1 if side == "R" else -1
    sx, sy = s * SHOULDER, SHOULDER_Y
    vx, vy = hx - sx, hy - sy
    d = max(abs(UPPER - FORE) + 0.5, min(UPPER + FORE - 0.05, math.hypot(vx, vy)))
    base = math.atan2(vy, vx)
    a = math.acos(max(-1.0, min(1.0, (UPPER ** 2 + d ** 2 - FORE ** 2) / (2 * UPPER * d))))
    best = None
    for sign in (1, -1):
        ua = base + sign * a
        ex, ey = sx + UPPER * math.cos(ua), sy + UPPER * math.sin(ua)
        score = s * ex if elbow == "out" else (ey if elbow == "down" else -s * ex)
        if best is None or score > best[0]:
            tx, ty = sx + d * math.cos(base), sy + d * math.sin(base)
            fa = math.atan2(ty - ey, tx - ex)
            best = (score, ua, fa)
    _, ua, fa = best
    shoulder = ua - math.pi / 2
    bend = fa - ua
    bend = (bend + math.pi) % (2 * math.pi) - math.pi
    shoulder = (shoulder + math.pi) % (2 * math.pi) - math.pi
    return {(f"Arm{side}", "rot"): shoulder, (f"Elbow{side}", "rot"): bend}


def arms(r, l, er="out", el="out"):
    p = {}
    p.update(ik("R", *r, elbow=er))
    p.update(ik("L", *l, elbow=el))
    return p


def P(*parts, **kw):
    out = {}
    for part in parts:
        out.update(part)
    for k, v in kw.items():
        tgt, prop = k.split("__")
        out[(tgt, prop)] = v
    return out


def look(fx=0.0, fy=0.0, tilt=0.0, hy=0.0):
    return {("Face", "x"): fx, ("Face", "y"): 6 + fy, ("Head", "rot"): tilt, ("Head", "y"): -36 + hy}


def ember_at(x, y, s=1.0, op=1.0):
    return {("Ember", "x"): x, ("Ember", "y"): y, ("Ember", "sx"): s, ("Ember", "sy"): s, ("Ember", "op"): op}


def spark(i, s, op=None, rot=0.0):
    return {(f"Spark{i}", "sx"): s, (f"Spark{i}", "sy"): s, (f"Spark{i}", "op"): (1.0 if s > 0 else 0.0) if op is None else op,
            (f"Spark{i}", "rot"): rot}


CUP = arms((9, -38), (-9, -38))
HANG = arms((40, -10), (-40, -10))
IDLE = P(CUP, look(0, 2, 0.0), ember_at(0, -104))


# ----------------------------------------------------------------------------
# Animation builder
# ----------------------------------------------------------------------------
EASE = {
    "inout": (0.42, 0.0, 0.58, 1.0),
    "sine": (0.37, 0.0, 0.63, 1.0),
    "out": (0.22, 0.61, 0.36, 1.0),
    "in": (0.55, 0.06, 0.68, 0.19),
    "sinein": (0.12, 0.0, 0.39, 0.0),
    "sineout": (0.61, 1.0, 0.88, 1.0),
    "back": (0.34, 1.45, 0.64, 1.0),
    "snap": (0.2, 0.9, 0.3, 1.0),
}


def keyframe(frame, value, ease, color=False):
    tag = "KeyFrameColor" if color else "KeyFrameDouble"
    if ease in (None, "linear", "hold"):
        return El(tag, value=value, frame=frame, interpolationType=ease or "linear")
    x1, y1, x2, y2 = EASE[ease]
    return El(tag, El("CubicEaseInterpolator", x1=x1, y1=y1, x2=x2, y2=y2),
              value=value, frame=frame, interpolationType="cubic")


class Track:
    """Keyframes for one (target, prop), authored in seconds."""

    def __init__(self):
        self.keys = []  # (seconds, value, ease)

    def frames(self):
        return [(round(t * FPS), v, e) for t, v, e in self.keys]


def build_animation(name, seconds, loop, poses, props, extra_tracks=None):
    """poses: [(t, pose_dict, ease)] where each pose is complete relative to REST.

    Every prop in `props` is keyed so a state never inherits stray values from
    the state it blended out of.
    """
    tracks = {}
    for p in props:
        tr = Track()
        values = [pose.get(p, REST[p]) for _, pose, _ in poses]
        if all(abs(v - values[0]) < 1e-6 for v in values):
            tr.keys.append((0.0, values[0], "hold"))
        else:
            for (t, pose, ease), v in zip(poses, values):
                tr.keys.append((t, v, ease))
        tracks[p] = tr
    for p, keys in (extra_tracks or {}).items():
        tr = Track()
        tr.keys = keys
        tracks[p] = tr

    anim_id = nid()
    anim = El("LinearAnimation", loopValue=loop, fps=FPS, duration=round(seconds * FPS), name=name, id=anim_id)
    by_target = {}
    for (tgt, prop), tr in tracks.items():
        by_target.setdefault(tgt, []).append((prop, tr))
    for tgt, plist in by_target.items():
        ko = El("KeyedObject", objectId=T[tgt])
        for prop, tr in sorted(plist, key=lambda x: PROP_KEY[x[0]]):
            kp = El("KeyedProperty", propertyKey=PROP_KEY[prop])
            fr = tr.frames()
            for i, (f, v, e) in enumerate(fr):
                kp.add(keyframe(f, v, e if i < len(fr) - 1 else "linear"))
            ko.add(kp)
        anim.add(ko)
    return anim, anim_id


def seq(*steps):
    """steps: (t, pose, ease) with poses merged onto IDLE-relative REST values."""
    return list(steps)


# ----------------------------------------------------------------------------
# The mood animations
# ----------------------------------------------------------------------------
def mood_poses():
    A = {}

    # Idle: cradling the ember, breathing, glancing between the light and you.
    A["idle"] = (4.0, "loop", [
        (0.0, IDLE, "sine"),
        (1.0, P(IDLE, look(1.5, 3.5, 0.05), ember_at(0, -109), Torso__rot=0.012), "sine"),
        (2.0, IDLE, "sine"),
        (3.0, P(IDLE, look(-2.5, -2.0, -0.045), ember_at(0, -108), Torso__rot=-0.01), "sine"),
        (4.0, IDLE, "sine"),
    ])

    # Thinking: hand to the hood's chin, gaze up, the ember orbits above.
    think_base = P(arms((-12, -50), (-3, -86), el="down"), look(5, -5, 0.1), Torso__rot=0.02)
    A["thinking"] = (3.2, "loop", [
        (0.0, P(think_base, ember_at(48, -238, 0.9)), "sinein"),
        (0.8, P(think_base, look(4, -4, 0.08), ember_at(0, -224, 1.0)), "sineout"),
        (1.6, P(think_base, ember_at(-48, -238, 0.9)), "sinein"),
        (2.4, P(think_base, look(6, -6, 0.11), ember_at(0, -252, 0.78)), "sineout"),
        (3.2, P(think_base, ember_at(48, -238, 0.9)), "sinein"),
    ])

    # Greet: a warm wave with the free hand; the ember gives a small hop.
    wave_base = arms((8, -40), (-62, -128))
    wave_hi = P(wave_base, look(-3, -3, -0.11), ember_at(2, -104), Torso__rot=-0.035,
                ElbowL__rot=wave_base[("ElbowL", "rot")] + 0.42)
    wave_lo = P(wave_base, look(-3, -3, -0.08), ember_at(2, -104), Torso__rot=-0.03,
                ElbowL__rot=wave_base[("ElbowL", "rot")] - 0.32)
    A["greet"] = (2.1, "oneShot", [
        (0.0, IDLE, "out"),
        (0.28, P(wave_hi, ember_at(2, -116)), "sine"),
        (0.48, wave_lo, "sine"),
        (0.68, wave_hi, "sine"),
        (0.88, wave_lo, "sine"),
        (1.08, wave_hi, "sine"),
        (1.3, wave_lo, "inout"),
        (1.75, P(IDLE, look(0, 0, 0.03)), "inout"),
        (2.1, IDLE, "linear"),
    ])

    # Encourage: dip, then a confident fist up and a nod — "you've got this".
    dip = P(IDLE, look(0, 3, 0), Body__sy=0.95, Body__sx=1.03)
    pump = P(arms((50, -122), (-8, -40), er="down"), look(1, -4, 0.04), ember_at(-4, -110, 1.3),
             Body__y=-8, Torso__rot=0.03)
    pump2 = P(arms((48, -110), (-8, -40), er="down"), look(1, 0, 0.02), ember_at(-4, -106, 1.15),
              Body__y=0, Torso__rot=0.02)
    A["encourage"] = (1.7, "oneShot", [
        (0.0, IDLE, "inout"),
        (0.16, dip, "out"),
        (0.38, P(pump, spark(2, 0.0), spark(3, 0.0)), "inout"),
        (0.6, P(pump2, spark(2, 1.0, rot=0.6), spark(3, 0.8, rot=-0.5)), "inout"),
        (0.82, P(pump, spark(2, 0.0, rot=1.2), spark(3, 0.0, rot=-1.0)), "inout"),
        (1.3, P(IDLE, look(0, 1, 0)), "inout"),
        (1.7, IDLE, "linear"),
    ])

    # Correct: a quick happy hop and a small flash of light.
    hop_up = P(arms((9, -42), (-52, -128)), look(-1, -5, -0.05), ember_at(0, -116, 1.35),
               Body__y=-18, Body__sy=1.04, Body__sx=0.97)
    A["correct"] = (1.25, "oneShot", [
        (0.0, IDLE, "out"),
        (0.1, P(IDLE, Body__sy=0.94, Body__sx=1.04), "out"),
        (0.32, P(hop_up, spark(0, 0.0), spark(1, 0.0), spark(5, 0.0)), "in"),
        (0.52, P(hop_up, Body__y=0, Body__sy=0.95, Body__sx=1.04), "out"),
        (0.62, P(hop_up, spark(0, 1.0, rot=0.5), spark(1, 0.8, rot=-0.4), spark(5, 0.9, rot=0.4), Body__y=0), "inout"),
        (0.95, P(IDLE, spark(0, 0.0, rot=1.0), spark(1, 0.0, rot=-0.9), spark(5, 0.0, rot=0.9)), "inout"),
        (1.25, IDLE, "linear"),
    ])

    # Celebrate: anticipation, a big jump with arms up, sparkles, soft landing.
    crouch = P(arms((20, -30), (-20, -30)), look(0, 5, 0), ember_at(0, -98, 0.9),
               Body__sy=0.88, Body__sx=1.07, Hips__y=-44)
    air = P(arms((54, -134), (-54, -134)), look(0, -7, 0), ember_at(0, -282, 1.35),
            Body__y=-52, Body__sy=1.07, Body__sx=0.95, LegR__rot=-0.32, LegL__rot=0.32, ScarfTail__rot=rad(-12))
    land = P(arms((58, -128), (-58, -128)), look(0, -5, 0), ember_at(0, -262, 1.6),
             Body__y=0, Body__sy=0.9, Body__sx=1.07)
    cheer_a = P(arms((60, -126), (-50, -138)), look(-2, -5, -0.06), ember_at(0, -252, 1.25))
    cheer_b = P(arms((50, -138), (-60, -126)), look(2, -5, 0.06), ember_at(0, -256, 1.25))
    burst = {}
    for i in range(8):
        burst.update(spark(i, 1.0 if i % 2 == 0 else 0.85, rot=0.7))
    fade = {}
    for i in range(8):
        fade.update(spark(i, 0.0, rot=1.5))
    A["celebrate"] = (2.4, "oneShot", [
        (0.0, IDLE, "inout"),
        (0.2, crouch, "out"),
        (0.48, air, "in"),
        (0.7, P(land, Ripple__op=1.0, Ripple__sx=0.4, Ripple__sy=0.4, Ripple__y=-262), "out"),
        (0.86, P(cheer_a, burst, Ripple__op=0.0, Ripple__sx=3.2, Ripple__sy=3.2, Ripple__y=-262,
                 Aura__op=0.8), "sine"),
        (1.12, P(cheer_b, fade, Aura__op=0.6), "sine"),
        (1.38, P(cheer_a, Aura__op=0.4), "inout"),
        (1.95, P(IDLE, ember_at(0, -112, 1.05)), "inout"),
        (2.4, IDLE, "linear"),
    ])

    # Retry: the light dims a little, a sheepish hand to the hood, then a nod
    # and the ember rekindles. Gentle — never harsh.
    slump = P(arms((12, -32), (-12, -32)), look(0, 6, -0.07, hy=2), ember_at(0, -96, 0.72, 0.5),
              Hips__y=-43, Torso__rot=0.0)
    sheepish = P(arms((12, -32), (-44, -132)), look(-3, 3, -0.16, hy=2), ember_at(0, -96, 0.7, 0.45),
                 Hips__y=-43)
    lift = P(arms((10, -36), (-12, -40)), look(0, -2, 0.0), ember_at(0, -104, 1.0, 1.0))
    A["retry"] = (2.4, "oneShot", [
        (0.0, IDLE, "inout"),
        (0.35, slump, "inout"),
        (0.85, sheepish, "inout"),
        (1.3, P(lift, Ripple__op=0.0, Ripple__sx=0.5, Ripple__sy=0.5), "out"),
        (1.42, P(lift, ember_at(0, -106, 1.2), Ripple__op=0.9, Ripple__sx=0.5, Ripple__sy=0.5), "out"),
        (1.75, P(lift, look(0, 3, 0, hy=3), ember_at(0, -104, 1.05), Ripple__op=0.0, Ripple__sx=2.4, Ripple__sy=2.4), "inout"),
        (2.0, P(lift, look(0, -1, 0)), "inout"),
        (2.4, IDLE, "linear"),
    ])

    # Complete: arms open in welcome, the light rises and blooms.
    open_arms = P(arms((80, -86), (-80, -86)), look(0, -6, 0), ember_at(0, -250, 1.7),
                  Body__y=-6, Aura__op=1.0, Rays__op=0.9, Rays__sx=1.0, Rays__sy=1.0)
    A["complete"] = (2.8, "oneShot", [
        (0.0, P(IDLE, Rays__rot=0.0), "inout"),
        (0.25, P(crouch, Body__sy=0.93, Body__sx=1.04, Hips__y=-45, Rays__rot=0.0), "out"),
        (0.7, P(open_arms, burst, Rays__rot=0.25), "sine"),
        (1.25, P(open_arms, fade, ember_at(0, -244, 1.6), Rays__rot=0.5), "sine"),
        (1.85, P(open_arms, ember_at(0, -250, 1.7), Rays__rot=0.75, Aura__op=0.8), "inout"),
        (2.35, P(IDLE, ember_at(0, -112, 1.1), Rays__rot=0.95, Rays__op=0.0, Rays__sx=0.6, Rays__sy=0.6), "inout"),
        (2.8, P(IDLE, Rays__rot=1.0), "linear"),
    ])

    # Streak: raises the ember, which grows into a fuller (still gentle) flame.
    raise_ = P(arms((50, -132), (-50, -132)), look(0, -7, 0), ember_at(0, -238, 2.1),
               Body__y=-4, Aura__op=1.0)
    rise = {}
    rise_top = {}
    for i, (x, y) in enumerate(RISERS):
        rise[(f"Riser{i}", "op")] = 0.0
        rise[(f"Riser{i}", "y")] = y
        rise_top[(f"Riser{i}", "op")] = 0.0
        rise_top[(f"Riser{i}", "y")] = y - 150
    rise_mid = {}
    for i, (x, y) in enumerate(RISERS):
        rise_mid[(f"Riser{i}", "op")] = 1.0
        rise_mid[(f"Riser{i}", "y")] = y - 70
    A["streak"] = (2.8, "oneShot", [
        (0.0, P(IDLE, rise), "inout"),
        (0.3, P(crouch, rise), "out"),
        (0.8, P(raise_, rise_mid, Ripple__op=0.0, Ripple__y=-238), "sine"),
        (1.3, P(raise_, rise_top, ember_at(0, -242, 2.25), Ripple__op=0.9, Ripple__sx=0.6, Ripple__sy=0.6, Ripple__y=-238), "sine"),
        (1.8, P(raise_, ember_at(0, -238, 2.1), Ripple__op=0.0, Ripple__sx=3.0, Ripple__sy=3.0, Ripple__y=-238, Aura__op=0.85), "inout"),
        (2.35, P(IDLE, ember_at(0, -112, 1.15)), "inout"),
        (2.8, IDLE, "linear"),
    ])
    return A


def ambient_animation():
    """Always-on life: breathing, cloth in the breeze and a flickering flame.
    Only touches objects the mood layer never keys."""
    props = {}

    def tr(target, prop, keys):
        props[(target, prop)] = keys

    tr("Breath", "sy", [(0.0, 1.0, "sine"), (1.6, 1.018, "sine"), (3.2, 1.0, "linear")])
    # scarf ribbon: a travelling wave toward the tip
    wave = [(0.0, 0, "sine"), (0.4, 1, "sine"), (0.8, 0, "sine"), (1.2, -1, "sine"), (1.6, 0, "linear")]

    def tail(name, amp, lag):
        base = REST[(name, "vy")]
        keys = []
        for t, w, e in wave:
            keys.append((t, base + amp * math.sin((t / 1.6) * 2 * math.pi - lag), "sine"))
        keys[-1] = (1.6, keys[0][1], "linear")
        tr(name, "vy", keys)

    tail("TailT3", 2.2, 0.6)
    tail("TailB3", 2.2, 0.6)
    tail("TailT4", 3.4, 1.2)
    tail("TailB4", 3.4, 1.2)
    tail("TailTip", 4.6, 1.8)
    tr("ScarfDropTip", "vx", [(0.0, REST[("ScarfDropTip", "vx")], "sine"), (0.8, REST[("ScarfDropTip", "vx")] - 1.6, "sine"),
                              (1.6, REST[("ScarfDropTip", "vx")], "linear")])
    tr("HemL", "vx", [(0.0, -46, "sine"), (1.6, -47.2, "sine"), (3.2, -46, "linear")])
    tr("HemR", "vx", [(0.0, 46, "sine"), (1.6, 46.8, "sine"), (3.2, 46, "linear")])
    # flame flicker: irregular, small, warm
    tr("FlameTip", "vx", [(0.0, 0, "sine"), (0.22, 2.0, "sine"), (0.5, -1.5, "sine"), (0.8, 1.0, "sine"),
                          (1.1, -2.0, "sine"), (1.4, 0.6, "sine"), (1.6, 0, "linear")])
    tr("FlameTip", "vy", [(0.0, -25, "sine"), (0.3, -28, "sine"), (0.6, -24, "sine"), (0.95, -27.5, "sine"),
                          (1.3, -24.5, "sine"), (1.6, -25, "linear")])
    tr("CoreTip", "vy", [(0.0, -12, "sine"), (0.4, -14.4, "sine"), (0.8, -11.4, "sine"), (1.2, -13.8, "sine"), (1.6, -12, "linear")])
    tr("EmberFlicker", "sx", [(0.0, 1.0, "sine"), (0.4, 1.04, "sine"), (0.8, 0.98, "sine"), (1.2, 1.03, "sine"), (1.6, 1.0, "linear")])
    tr("EmberGlow", "op", [(0.0, 0.85, "sine"), (0.5, 1.0, "sine"), (0.9, 0.8, "sine"), (1.3, 0.95, "sine"), (1.6, 0.85, "linear")])
    tr("EmberGlow", "sx", [(0.0, 1.0, "sine"), (0.8, 1.06, "sine"), (1.6, 1.0, "linear")])
    tr("EmberGlow", "sy", [(0.0, 1.0, "sine"), (0.8, 1.06, "sine"), (1.6, 1.0, "linear")])
    # Breath is 3.2s and the rest 1.6s: author once at 3.2s, repeating the short cycles
    full = {}
    for k, keys in props.items():
        if keys[-1][0] < 3.2 - 1e-6:
            span = keys[-1][0]
            rep = [kk for kk in keys[:-1]] + [(t + span, v, e) for t, v, e in keys]
            full[k] = rep
        else:
            full[k] = keys
    return build_animation("Ambient", 3.2, "loop", [(0.0, {}, "hold")], [], extra_tracks=full)


# ----------------------------------------------------------------------------
# View model + state machine
# ----------------------------------------------------------------------------
TRIGGERS = ["greet", "encourage", "celebrate", "correct", "retry", "complete", "streak"]


def view_model():
    enum_id = "0:900"
    vm_id, inst_id = "0:910", "0:911"
    enum = El("DataEnumCustom",
              El("DataEnumValue", key="idle", value="Idle", id="0:901"),
              El("DataEnumValue", key="thinking", value="Thinking", id="0:902"),
              name="CompanionMood", id=enum_id)
    props = [El("ViewModelPropertyEnumCustom", enumId=enum_id, name="mood", id="0:912")]
    values = [El("ViewModelInstanceEnum", propertyValue="0:901", viewModelPropertyId="0:912")]
    for i, t in enumerate(TRIGGERS):
        pid = f"0:{920 + i}"
        props.append(El("ViewModelPropertyTrigger", name=t, id=pid))
        values.append(El("ViewModelInstanceTrigger", viewModelPropertyId=pid))
    vm = El("ViewModel", *props, El("ViewModelInstance", *values, exports=True, name="Default", id=inst_id),
            defaultInstanceId=inst_id, name="Companion", id=vm_id)
    return enum, vm


def mood_is(value_id):
    return El("TransitionViewModelCondition",
              El("TransitionPropertyViewModelComparator",
                 El("BindablePropertyEnum", El("DataBindContext", sourcePathIds="0:910-0:912", propertyKey=637))),
              El("TransitionValueEnumComparator", value=value_id))


def fired(trigger):
    pid = f"0:{920 + TRIGGERS.index(trigger)}"
    return El("TransitionViewModelCondition",
              El("TransitionPropertyViewModelComparator",
                 El("BindablePropertyTrigger", El("DataBindContext", sourcePathIds=f"0:910-{pid}", propertyKey=686))),
              El("TransitionValueTriggerComparator"))


def blend(ms, ease="inout"):
    x1, y1, x2, y2 = EASE[ease]
    return dict(duration=ms, interpolationType="cubic"), El("CubicEaseInterpolator", x1=x1, y1=y1, x2=x2, y2=y2)


def transition(to, ms, *conds, exit_full=False, ease="inout"):
    attrs, interp = blend(ms, ease)
    if exit_full:
        attrs.update(enableExitTime=True, exitTimeIsPercetange=True, exitTime=100)
    return El("StateTransition", interp, *conds, stateToId=to, **attrs)


def state_machine(anim_ids, ambient_id):
    sid = {k: nid() for k in ["idle", "thinking"] + TRIGGERS}
    any_state = El("AnyState", *[transition(sid[t], 160, fired(t), ease="out") for t in TRIGGERS], x=40, y=-160)
    idle = El("AnimationState", transition(sid["thinking"], 380, mood_is("0:902")),
              animationId=anim_ids["idle"], stateName="Idle", x=40, y=40, id=sid["idle"])
    thinking = El("AnimationState", transition(sid["idle"], 380, mood_is("0:901")),
                  animationId=anim_ids["thinking"], stateName="Thinking", x=40, y=200, id=sid["thinking"])
    reactions = []
    for i, t in enumerate(TRIGGERS):
        reactions.append(El("AnimationState", transition(sid["idle"], 260, exit_full=True),
                            animationId=anim_ids[t], stateName=t.capitalize(), reset=True,
                            x=320, y=-200 + i * 80, id=sid[t]))
    mood_layer = El("StateMachineLayer", any_state, El("ExitState", x=600, y=40),
                    El("EntryState", El("StateTransition", stateToId=sid["idle"]), x=-200, y=40),
                    idle, thinking, *reactions, name="Mood", id=nid())
    amb_state = nid()
    ambient_layer = El("StateMachineLayer", El("AnyState", x=40, y=-160), El("ExitState", x=600, y=40),
                       El("EntryState", El("StateTransition", stateToId=amb_state), x=-200, y=40),
                       El("AnimationState", animationId=ambient_id, stateName="Breathe", x=200, y=40, id=amb_state),
                       name="Ambient", id=nid())
    return El("StateMachine", mood_layer, ambient_layer, name="Companion", id="0:800")


# ----------------------------------------------------------------------------
def main():
    preview = None
    for a in sys.argv[1:]:
        if a.startswith("--preview="):
            preview = a.split("=", 1)[1]

    root = node("Companion",
                fx_front(),
                ember(),
                body(),
                fx_back(),
                shape("Shadow", ellipse(116, 15), fill(radial(0, 0, 58, stop(argb("000000", 0x30), 0),
                                                                stop(argb("000000", 0x00), 1))), y=3),
                x=200, y=368, sx=1.1, sy=1.1)

    poses = mood_poses()
    mood_props = set()
    for _, _, steps in poses.values():
        for _, pose, _ in steps:
            mood_props.update(pose.keys())
    mood_props = sorted(mood_props)
    anims, anim_ids = [], {}
    for name, (secs, loop, steps) in poses.items():
        el, aid = build_animation(name.capitalize(), secs, loop, steps, mood_props)
        anims.append(el)
        anim_ids[name] = aid
    ambient, ambient_id = ambient_animation()
    anims.append(ambient)

    sm = state_machine(anim_ids, ambient_id)
    enum, vm = view_model()

    art = El("Artboard", El("LayoutComponentStyle", name="Artboard Style", id="0:5"),
             defaultStateMachineId="0:800", viewModelId="0:910", viewModelInstanceId="0:911",
             styleId="0:5", width=400, height=400, name="Companion", id="0:2")
    if preview:
        bg = {"dark": NIGHT, "light": MINT}[preview]
        art.add(El("Fill", solid(argb(bg)), name="Preview Backdrop"))
    art.add(root, sm, *anims)

    doc = El("Rive", Comment("Generated by generate.py — edit the generator, not this file."),
             art, enum, vm, version=1, kind="fragment")
    (HERE / "scene.rml").write_text(doc.render() + "\n", encoding="utf-8")
    n_keys = sum(1 for _ in doc.render().split("<KeyFrame")) - 1
    print(f"scene.rml written: {len(T)} animatable targets, {len(mood_props)} mood props, {n_keys} keyframes")


if __name__ == "__main__":
    main()
