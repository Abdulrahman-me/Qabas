"""Scene manifest checks (schema + semantics + limits) and a NON-NORMATIVE SVG preview.

The normative renderer is the Flutter package `qabas_scene` (contract §5.5e). This script is
what the backend validator runs before rendering, plus a quick SVG preview for humans.
Revision 10 adds the static rules of 07_ANIMATION/SCENE_RENDERER_SEMANTICS.md §9
(`semantic_rule_errors`). The SVG preview below predates those semantics: it skips tracks in
reduced motion, uses Python's PRNG for sparkles and omits transitions, clips, strokes and assets.
"""
import hashlib, io, json, math, re, sys, pathlib
import xml.etree.ElementTree as ET
from PIL import Image
import jsonschema

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEMA = json.loads((ROOT / "contract/scene.schema.json").read_text())
REG = json.loads((ROOT / "contract/scene_capabilities.json").read_text())
PATH_TOKEN = re.compile(r"[MLHVCQZmlhvcqz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
TYPE_CAP = {"rect": "shape.rect/1", "ellipse": "shape.ellipse/1", "path": "shape.path/1", "sparkles": "fx.sparkles/1", "group": "scene/1"}


def walk(layers):
    for l in layers:
        yield l
        yield from walk(l.get("children", []))


def path_commands(data):
    """Parse the supported path grammar, counting implicit repeated commands."""
    tokens, end = [], 0
    for match in PATH_TOKEN.finditer(data):
        if data[end:match.start()].strip(' \t\r\n,'):
            raise ValueError('unsupported path token/command')
        tokens.append(match.group()); end = match.end()
    if data[end:].strip(' \t\r\n') or ',,' in data or re.search(r'[A-Za-z]\s*,|,\s*[A-Za-z]', data):
        raise ValueError('invalid path separator/token')
    if not tokens or tokens[0].upper() != 'M':
        raise ValueError('path must start with M')
    arity = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'Q': 4, 'Z': 0}
    i, count = 0, 0
    while i < len(tokens):
        command = tokens[i]
        if command.upper() not in arity:
            raise ValueError('path command required')
        i += 1
        n, argc = arity[command.upper()], 0
        while i < len(tokens) and tokens[i].upper() not in arity:
            if not math.isfinite(float(tokens[i])):
                raise ValueError('non-finite coordinate')
            argc += 1; i += 1
        if n == 0:
            if argc:
                raise ValueError('Z has no arguments')
            count += 1
        else:
            if not argc or argc % n:
                raise ValueError(f'{command} requires groups of {n} numbers')
            count += argc // n
    return count


def asset_errors(m, asset_files):
    errors = []
    if m['assets'] and asset_files is None:
        return ['asset bytes must be resolved and verified before acceptance']
    for asset in m['assets']:
        path = (asset_files or {}).get(asset['url'])
        if path is None:
            errors.append(f"{asset['asset_id']}: missing asset bytes"); continue
        try:
            raw = pathlib.Path(path).read_bytes()
        except OSError as e:
            errors.append(f"{asset['asset_id']}: cannot read asset bytes: {e}"); continue
        if len(raw) != asset['bytes'] or hashlib.sha256(raw).hexdigest() != asset['sha256']:
            errors.append(f"{asset['asset_id']}: bytes/checksum mismatch")
        try:
            if asset['mime_type'] == 'image/svg+xml':
                if b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
                    raise ValueError('SVG document/entity declarations prohibited')
                root = ET.fromstring(raw)
                if root.tag.split('}')[-1] != 'svg':
                    raise ValueError('asset is not SVG')
                allowed = {'svg', 'g', 'defs', 'path', 'rect', 'circle', 'ellipse', 'polygon', 'polyline', 'line', 'linearGradient', 'radialGradient', 'stop', 'clipPath'}
                for node in root.iter():
                    if node.tag.split('}')[-1] not in allowed:
                        raise ValueError('unsupported/script/text SVG element')
                    for key, value in node.attrib.items():
                        if key.split('}')[-1].lower().startswith('on') or key.split('}')[-1] == 'style':
                            raise ValueError('SVG handlers/styles prohibited')
                        if key.split('}')[-1] == 'href' and not value.startswith('#'):
                            raise ValueError('external SVG reference prohibited')
                        if 'url(' in value and not re.fullmatch(r'url\(#[A-Za-z0-9_-]+\)', value):
                            raise ValueError('external SVG paint reference prohibited')
                box = [float(x) for x in root.attrib.get('viewBox', '').replace(',', ' ').split()]
                if len(box) != 4 or box[2:] != [asset['width'], asset['height']]:
                    raise ValueError('SVG viewBox dimensions mismatch')
            else:
                with Image.open(io.BytesIO(raw)) as image:
                    actual = {'WEBP': 'image/webp', 'PNG': 'image/png', 'JPEG': 'image/jpeg'}.get(image.format)
                    if actual != asset['mime_type'] or image.size != (asset['width'], asset['height']):
                        raise ValueError('asset MIME/dimensions mismatch')
                    image.verify()
        except (ValueError, ET.ParseError, OSError) as e:
            errors.append(f"{asset['asset_id']}: {e}")
    return errors


def check(m, raw_bytes=None, *, asset_files=None, publication=False, registry=None, token_table=None):
    errs = [f"schema: {e.message} at {list(e.path)}" for e in jsonschema.Draft202012Validator(SCHEMA).iter_errors(m)]
    if errs:
        return errs
    reg = REG if registry is None else registry
    lim = reg["limits"]
    released = {c["id"] for c in reg["capabilities"] if c["status"] == "released"}
    if publication and reg.get('environment') != 'production':
        errs.append('publication requires a production registry with release evidence')
    if publication:
        for c in reg['capabilities']:
            if c['id'] in m['required_capabilities'] and not c.get('release_evidence'):
                errs.append(f"capability lacks app build/release evidence: {c['id']}")
    declared = set(m["required_capabilities"])
    for c in declared - released:
        errs.append(f"capability not released: {c}")
    layers = list(walk(m["layers"]))
    ids = [l["id"] for l in layers]
    if len(ids) != len(set(ids)):
        errs.append("duplicate layer ids")
    used = {"scene/1"}
    for l in layers:
        if l["type"] == "asset":
            used.add("asset.svg/1" if any(a["asset_id"] == l.get("asset_id") and a["mime_type"] == "image/svg+xml" for a in m["assets"]) else "asset.raster/1")
        else:
            used.add(TYPE_CAP[l["type"]])
        if isinstance(l.get("fill"), dict):
            used.add("paint.gradient/1")
        if l.get("tracks"):
            used.add("track/1")
        if l.get("clip"):
            used.add("clip/1")
    if m["anchors"]:
        used.add("anchors/1")
    for c in used - declared:
        errs.append(f"capability used but not declared: {c}")
    for c in declared - used:
        errs.append(f"capability declared but not used: {c}")
    if len(layers) > lim["layers"]:
        errs.append(f"too many layers {len(layers)}")
    tracks = [t for l in layers for t in l.get("tracks", [])]
    if len(tracks) > lim["tracks"]:
        errs.append("too many tracks")
    cmds = 0
    for l in layers:
        if l['type'] == 'path':
            try:
                count = path_commands(l['d']); cmds += count
                if count > 400:
                    errs.append(f"{l['id']}: path exceeds 400 commands")
            except ValueError as e:
                errs.append(f"{l['id']}: {e}")
    if cmds > lim["path_commands_total"]:
        errs.append(f"too many path commands {cmds}")
    if raw_bytes is not None and len(raw_bytes) > lim["manifest_bytes"]:
        errs.append("manifest too large")
    if sum(a["bytes"] for a in m["assets"]) > lim["asset_bytes_total"]:
        errs.append("assets too large")
    if len({a['asset_id'] for a in m['assets']}) != len(m['assets']):
        errs.append('duplicate asset IDs')
    errs += asset_errors(m, asset_files)
    pal = set(m["palette"])
    def color_ok(c):
        return c in pal
    for l in layers:
        f = l.get("fill")
        if isinstance(f, str) and not color_ok(f):
            errs.append(f"{l['id']}: unknown palette {f}")
        if isinstance(f, dict):
            for s in f["stops"]:
                if not color_ok(s["color"]):
                    errs.append(f"{l['id']}: unknown palette {s['color']}")
        if l.get('stroke') and not color_ok(l['stroke']):
            errs.append(f"{l['id']}: unknown stroke palette")
        if l["type"] == "asset" and not any(a["asset_id"] == l.get("asset_id") for a in m["assets"]):
            errs.append(f"{l['id']}: unknown asset")
        if l.get("clip") and l["clip"] not in ids:
            errs.append(f"{l['id']}: unknown clip")
        elif l.get('clip') and next(x for x in layers if x['id'] == l['clip'])['type'] not in ('rect', 'ellipse', 'path'):
            errs.append(f"{l['id']}: clip must reference a rect, ellipse, or path")
        for t in l.get("tracks", []):
            ks = [k["t"] for k in t["keyframes"]]
            if ks != sorted(ks) or len(set(ks)) != len(ks) or ks[0] != 0 or ks[-1] != 1:
                errs.append(f"{l['id']}: keyframes must run 0..1 ascending")
            if "active_when" in t:
                errs += cond_errs(m, t["active_when"], l["id"])
        for r in l.get("state_rules", []):
            errs += cond_errs(m, r["when"], l["id"])
            if "fill" in r["set"] and not color_ok(r["set"]["fill"]):
                errs.append(f"{l['id']}: unknown palette in rule")
    for st in m["preview"]["states"]:
        errs += state_errs(m, st, "preview")
    for key, state in m['states'].items():
        if state['type'] == 'int' and ('min' not in state or 'max' not in state or state['min'] > state['max']):
            errs.append(f'{key}: invalid integer state declaration')
        elif state['type'] == 'enum' and (not state.get('values') or len(set(state['values'])) != len(state['values'])):
            errs.append(f'{key}: invalid enum state declaration')
        else:
            errs += state_errs(m, {key: state['default']}, 'default')
    vb = m["view_box"]
    for a in m["anchors"]:
        if not (0 <= a["x"] <= vb["width"] and 0 <= a["y"] <= vb["height"]):
            errs.append(f"anchor {a['anchor_id']} outside view box")
    errs += anchor_stability_errors(m)
    errs += semantic_rule_errors(m, token_table)
    return errs


def semantic_rule_errors(m, token_table=None):
    """Rev 10 rules from 07_ANIMATION/SCENE_RENDERER_SEMANTICS.md §9 (static part)."""
    errs = []
    layers = list(walk(m["layers"]))
    clip_sources = {l["clip"] for l in layers if l.get("clip")}
    anchored = {a["layer_id"] for a in m["anchors"]}
    assets = {a["asset_id"]: a for a in m["assets"]}
    for l in layers:
        for r in l.get("state_rules", []):
            if "scale" in r["set"] and not r["set"]["scale"] > 0:
                errs.append(f"{l['id']}: state rule scale must be > 0")
        for t in l.get("tracks", []):
            if t["property"] == "scale" and not all(k["v"] > 0 for k in t["keyframes"]):
                errs.append(f"{l['id']}: scale keyframes must be > 0")
        if l["id"] in clip_sources and (l.get("state_rules") or l.get("tracks") or l["id"] in anchored):
            errs.append(f"{l['id']}: clip sources are definitions only (no rules, tracks or anchors)")
        if l["type"] == "sparkles" and not isinstance(l.get("fill"), str):
            errs.append(f"{l['id']}: sparkles need a solid palette fill")
        if l["type"] == "asset" and l.get("asset_id") in assets:
            a = assets[l["asset_id"]]
            if abs((l["w"] / l["h"]) / (a["width"] / a["height"]) - 1) > 0.01:
                errs.append(f"{l['id']}: asset box proportion differs from the asset by more than 1%")
    if token_table is not None:
        for name, value in m["palette"].items():
            if value.startswith("token:") and value[6:] not in token_table:
                errs.append(f"palette {name}: unknown theme token {value[6:]}")
    return errs


POS_PROPS = {"x", "y", "rotation", "scale"}
POS_TRACKS = {"translate_x", "translate_y", "rotation", "scale"}


def _paths(layers, chain=()):
    for l in layers:
        yield l, chain
        yield from _paths(l.get("children", []), chain + (l,))


def anchor_stability_errors(m):
    """Graded hotspots must stay under their anchors in every state and at every animation time.
    Anchored layer + ancestors: no position-changing tracks/state rules. Descendants: bounded motion only."""
    lim = REG["limits"]["anchor_motion"]; vb = m["view_box"]; errs = []
    index = {l["id"]: (l, chain) for l, chain in _paths(m["layers"])}
    for a in m["anchors"]:
        if a["layer_id"] not in index:
            errs.append(f"anchor {a['anchor_id']}: unknown layer {a['layer_id']}"); continue
        layer, chain = index[a["layer_id"]]
        for node in chain + (layer,):
            for r in node.get("state_rules", []):
                if POS_PROPS & set(r["set"]):
                    errs.append(f"anchor {a['anchor_id']}: {node['id']} changes position by state")
            for t in node.get("tracks", []):
                if t["property"] in POS_TRACKS:
                    errs.append(f"anchor {a['anchor_id']}: {node['id']} has a {t['property']} track")
        for d, _ in _paths(layer.get("children", [])):
            for t in d.get("tracks", []):
                vals = [k["v"] for k in t["keyframes"]]
                p = t["property"]
                if p in ("translate_x", "translate_y"):
                    span = vb["width" if p == "translate_x" else "height"] * lim["translate_max_pct_of_view_box"] / 100
                    if max(abs(v) for v in vals) > span: errs.append(f"anchor {a['anchor_id']}: {d['id']} translates beyond the decorative limit")
                elif p == "rotation" and max(abs(v) for v in vals) > lim["rotation_max_deg"]:
                    errs.append(f"anchor {a['anchor_id']}: {d['id']} rotates beyond the decorative limit")
                elif p == "scale" and not all(lim["scale_min"] <= v <= lim["scale_max"] for v in vals):
                    errs.append(f"anchor {a['anchor_id']}: {d['id']} scales beyond the decorative limit")
            for r in d.get("state_rules", []):
                if {"x", "y"} & set(r["set"]):
                    errs.append(f"anchor {a['anchor_id']}: {d['id']} moves by state")
                if abs(r['set'].get('rotation', 0)) > lim['rotation_max_deg']:
                    errs.append(f"anchor {a['anchor_id']}: {d['id']} rotates beyond the decorative limit by state")
                if not lim['scale_min'] <= r['set'].get('scale', 1) <= lim['scale_max']:
                    errs.append(f"anchor {a['anchor_id']}: {d['id']} scales beyond the decorative limit by state")
    return errs


def pin_alignment_errors(m, pins):
    """Each scene hotspot pin must reference an anchor and sit inside that anchor's radius (view-box coordinates)."""
    vb = m["view_box"]; anchors = {a["anchor_id"]: a for a in m["anchors"]}; errs = []
    for p in pins:
        a = anchors.get(p.get("anchor_id"))
        if a is None:
            errs.append(f"pin {p['pin_id']}: unknown anchor {p.get('anchor_id')}"); continue
        x = p["x_pct"] * vb["width"] / 100; y = p["y_pct"] * vb["height"] / 100
        if math.hypot(x - a["x"], y - a["y"]) > a["radius"]:
            errs.append(f"pin {p['pin_id']}: not over anchor {a['anchor_id']} (off by {math.hypot(x - a['x'], y - a['y']):.0f} units)")
    return errs


def state_values_errors(m, values, where):
    return state_errs(m, values, where)


def state_errs(m, values, where):
    errs = []
    for k, v in values.items():
        s = m["states"].get(k)
        if s is None:
            errs.append(f"{where}: unknown state {k}")
        elif s["type"] == "int" and not (type(v) is int and s.get("min", math.inf) <= v <= s.get("max", -math.inf)):
            errs.append(f"{where}: {k}={v} out of range")
        elif s["type"] == "bool" and not isinstance(v, bool):
            errs.append(f"{where}: {k} must be bool")
        elif s["type"] == "enum" and v not in s["values"]:
            errs.append(f"{where}: {k}={v} not in enum")
    return errs


def cond_errs(m, cond, lid):
    errs = []
    for k, ops in cond.items():
        if k not in m["states"]:
            errs.append(f"{lid}: condition on unknown state {k}")
            continue
        for op, v in ops.items():
            if op in ('gte', 'lte') and m['states'][k]['type'] != 'int':
                errs.append(f'{lid}: ordered conditions require an integer state')
            for x in (v if op == "in" else [v]):
                errs += state_errs(m, {k: x}, f"{lid} condition")
    return errs


# ---------------- non-normative SVG preview ----------------
def holds(cond, st):
    for k, ops in cond.items():
        v = st[k]
        for op, x in ops.items():
            if op == "eq" and v != x: return False
            if op == "gte" and v < x: return False
            if op == "lte" and v > x: return False
            if op == "in" and v not in x: return False
    return True


def ease(e, p):
    return {"linear": p, "ease_in": p * p, "ease_out": 1 - (1 - p) ** 2, "ease_in_out": 0.5 - 0.5 * math.cos(math.pi * p)}[e]


def track_value(t, ms):
    d = t["duration_ms"]; x = max(0, ms - t.get("delay_ms", 0)) / d
    if t["loop"] == "none": x = min(x, 1)
    elif t["loop"] == "repeat": x = x % 1
    else: x = x % 2; x = 2 - x if x > 1 else x
    p = ease(t["easing"], x); ks = t["keyframes"]
    for a, b in zip(ks, ks[1:]):
        if a["t"] <= p <= b["t"]:
            f = 0 if b["t"] == a["t"] else (p - a["t"]) / (b["t"] - a["t"])
            return a["v"] + f * (b["v"] - a["v"])
    return ks[-1]["v"]


def render_svg(m, state, ms, reduced=False):
    st = {k: s["default"] for k, s in m["states"].items()}; st.update(state)
    if reduced: ms = m["reduced_motion"]["still_time_ms"]
    pal = m["palette"]; defs = []; vb = m["view_box"]

    def paint(f, lid):
        if isinstance(f, str): return pal[f]
        gid = f"g_{lid}"
        stops = "".join(f'<stop offset="{s["at"]}" stop-color="{pal[s["color"]]}"/>' for s in f["stops"])
        if f["gradient"] == "linear":
            (x1, y1), (x2, y2) = f["from"], f["to"]
            defs.append(f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>')
        else:
            cx, cy = f["center"]; defs.append(f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{f["radius"]}">{stops}</radialGradient>')
        return f"url(#{gid})"

    def node(l):
        props = {"opacity": l.get("opacity", 1), **{k: l.get("transform", {}).get(k, d) for k, d in [("x", 0), ("y", 0), ("rotation", 0), ("scale", 1)]}}
        fill = l.get("fill")
        for r in l.get("state_rules", []):
            if holds(r["when"], st):
                for k, v in r["set"].items():
                    if k == "fill": fill = v
                    else: props[k] = v
        if not reduced:
            for t in l.get("tracks", []):
                if "active_when" in t and not holds(t["active_when"], st): continue
                v = track_value(t, ms); p = t["property"]
                if p == "translate_x": props["x"] += v
                elif p == "translate_y": props["y"] += v
                elif p == "rotation": props["rotation"] += v
                elif p == "scale": props["scale"] *= v
                elif p == "opacity": props["opacity"] *= v
        ox = l.get("transform", {}).get("origin_x", 0); oy = l.get("transform", {}).get("origin_y", 0)
        tr = f'translate({props["x"]},{props["y"]}) translate({ox},{oy}) rotate({props["rotation"]}) scale({props["scale"]}) translate({-ox},{-oy})'
        fl = paint(fill, l["id"]) if fill else "none"; t = l["type"]
        if t == "group": inner = "".join(node(c) for c in l.get("children", []))
        elif t == "rect": inner = f'<rect x="{l["x"]}" y="{l["y"]}" width="{l["w"]}" height="{l["h"]}" rx="{l.get("corner",0)}" fill="{fl}"/>'
        elif t == "ellipse": inner = f'<ellipse cx="{l["x"]}" cy="{l["y"]}" rx="{l["rx"]}" ry="{l["ry"]}" fill="{fl}"/>'
        elif t == "path": inner = f'<path d="{l["d"]}" fill="{fl}"/>'
        elif t == "sparkles":
            import random; rnd = random.Random(l["seed"]); pts = []
            for i in range(l["count"]):
                x = l["x"] + rnd.random() * l["w"]; y = l["y"] + rnd.random() * l["h"]; ph = rnd.random()
                a = 0.4 + 0.6 * abs(math.sin(math.pi * (ms / 2000 + ph))) if not reduced else 0.8
                pts.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{2 + 2 * ph:.1f}" fill="{fl}" opacity="{a:.2f}"/>')
            inner = "".join(pts)
        else: inner = ""
        return f'<g transform="{tr}" opacity="{props["opacity"]}">{inner}</g>'

    body = "".join(node(l) for l in m["layers"])
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vb["width"]} {vb["height"]}" width="{vb["width"]//2}" height="{vb["height"]//2}"><defs>{"".join(defs)}</defs>{body}</svg>'


if __name__ == "__main__":
    for f in sys.argv[1:]:
        raw = pathlib.Path(f).read_bytes(); m = json.loads(raw)
        e = check(m, raw)
        print(f, "OK" if not e else e)
