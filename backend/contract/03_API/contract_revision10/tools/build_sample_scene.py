"""Builds the sample agent-style scene used by the generated-scene fixtures.
In production the Animated Scene Author agent produces this manifest; this script only
creates a deterministic test artifact for contract/renderer verification."""
import json, hashlib, pathlib
OUT = pathlib.Path(__file__).resolve().parent.parent / "fixtures" / "scenes"
W, H = 1600, 1000
scene = {
  "schema_version": "qabas.scene/1",
  "scene_id": "scn_test_desert_well",
  "version": 2,
  "view_box": {"width": W, "height": H},
  "required_capabilities": ["scene/1", "shape.rect/1", "shape.ellipse/1", "shape.path/1", "paint.gradient/1", "track/1", "anchors/1", "fx.sparkles/1"],
  "palette": {"sky_night_top": "#0B1E3A", "sky_night_low": "#1E3A5F", "sky_dawn_top": "#F7C98B", "sky_dawn_low": "#F2A65E",
              "sand": "#C9A46A", "sand_dark": "#A8834E", "stone": "#7A6A58", "stone_dark": "#5B4E40", "water": "#2B6F8A",
              "trunk": "#6B4F2E", "leaf": "#2F6B4F", "glow": "#F6E3B4", "tent": "#8C5A3C", "tent_dark": "#6A402A", "star": "#FFFFFF"},
  "assets": [],
  "states": {"beat": {"type": "int", "min": 0, "max": 2, "default": 0},
             "focus": {"type": "int", "min": -1, "max": 2, "default": -1}},
  "layers": [
    {"id": "sky_dawn", "type": "rect", "x": 0, "y": 0, "w": W, "h": H,
     "fill": {"gradient": "linear", "from": [0, 0], "to": [0, 700], "stops": [{"at": 0, "color": "sky_dawn_top"}, {"at": 1, "color": "sky_dawn_low"}]}},
    {"id": "sky_night", "type": "rect", "x": 0, "y": 0, "w": W, "h": H, "opacity": 1,
     "fill": {"gradient": "linear", "from": [0, 0], "to": [0, 700], "stops": [{"at": 0, "color": "sky_night_top"}, {"at": 1, "color": "sky_night_low"}]},
     "state_rules": [{"when": {"beat": {"gte": 2}}, "set": {"opacity": 0}, "transition_ms": 1200, "easing": "ease_in_out"}]},
    {"id": "stars", "type": "sparkles", "x": 0, "y": 0, "w": W, "h": 520, "count": 32, "seed": 7, "fill": "star",
     "state_rules": [{"when": {"beat": {"gte": 2}}, "set": {"opacity": 0}, "transition_ms": 1000}]},
    {"id": "moon", "type": "ellipse", "x": 1300, "y": 170, "rx": 46, "ry": 46, "fill": "glow",
     "tracks": [{"property": "translate_y", "duration_ms": 8000, "easing": "ease_in_out", "loop": "ping_pong", "keyframes": [{"t": 0, "v": 0}, {"t": 1, "v": -10}]}],
     "state_rules": [{"when": {"beat": {"gte": 2}}, "set": {"opacity": 0}, "transition_ms": 1000}]},
    {"id": "dune_back", "type": "path", "fill": "sand_dark",
     "d": "M0 640 C 300 560 520 600 800 640 C 1080 680 1300 590 1600 620 L1600 1000 L0 1000 Z"},
    {"id": "dune_front", "type": "path", "fill": "sand",
     "d": "M0 760 C 260 700 600 720 900 760 C 1200 800 1400 740 1600 760 L1600 1000 L0 1000 Z"},
    {"id": "tent", "type": "group", "transform": {"x": 1180, "y": 600}, "children": [
      {"id": "tent_glow", "type": "ellipse", "x": 130, "y": 100, "rx": 170, "ry": 120, "fill": "glow", "opacity": 0,
       "state_rules": [{"when": {"focus": {"eq": 2}}, "set": {"opacity": 0.35}, "transition_ms": 400}]},
      {"id": "tent_body", "type": "path", "fill": "tent", "d": "M0 160 L130 0 L260 160 Z"},
      {"id": "tent_door", "type": "path", "fill": "tent_dark", "d": "M105 160 L130 70 L155 160 Z"}]},
    {"id": "palm", "type": "group", "transform": {"x": 300, "y": 470}, "children": [
      {"id": "palm_ring", "type": "ellipse", "x": 60, "y": 150, "rx": 170, "ry": 220, "fill": "glow", "opacity": 0,
       "state_rules": [{"when": {"focus": {"eq": 1}}, "set": {"opacity": 0.3}, "transition_ms": 400}]},
      {"id": "palm_trunk", "type": "path", "fill": "trunk", "d": "M40 330 C 50 220 30 120 60 0 L76 4 C 52 120 72 220 64 330 Z"},
      {"id": "palm_leaves", "type": "path", "fill": "leaf", "transform": {"origin_x": 68, "origin_y": 4},
       "d": "M68 4 C 10 -30 -60 0 -90 40 C -30 10 20 10 68 4 Z M68 4 C 120 -40 200 -20 230 30 C 170 0 120 0 68 4 Z M68 4 C 40 -70 80 -120 120 -130 C 90 -80 80 -40 68 4 Z",
       "tracks": [{"property": "rotation", "duration_ms": 5000, "easing": "ease_in_out", "loop": "ping_pong", "keyframes": [{"t": 0, "v": -3}, {"t": 1, "v": 3}]}]}]},
    {"id": "well", "type": "group", "transform": {"x": 760, "y": 640}, "children": [
      {"id": "well_glow", "type": "ellipse", "x": 0, "y": 40, "rx": 220, "ry": 150, "fill": "glow", "opacity": 0,
       "state_rules": [{"when": {"focus": {"eq": 0}}, "set": {"opacity": 0.45}, "transition_ms": 400},
                       {"when": {"beat": {"eq": 1}}, "set": {"opacity": 0.3}, "transition_ms": 600}],
       "tracks": [{"property": "scale", "duration_ms": 2400, "easing": "ease_in_out", "loop": "ping_pong", "keyframes": [{"t": 0, "v": 0.96}, {"t": 1, "v": 1.04}],
                   "active_when": {"focus": {"eq": 0}}}]},
      {"id": "well_body", "type": "rect", "x": -110, "y": 0, "w": 220, "h": 120, "corner": 10, "fill": "stone"},
      {"id": "well_rim", "type": "ellipse", "x": 0, "y": 0, "rx": 120, "ry": 34, "fill": "stone_dark"},
      {"id": "well_water", "type": "ellipse", "x": 0, "y": 2, "rx": 96, "ry": 22, "fill": "water", "opacity": 0.4,
       "state_rules": [{"when": {"beat": {"gte": 1}}, "set": {"opacity": 1}, "transition_ms": 800}],
       "tracks": [{"property": "opacity", "duration_ms": 3000, "easing": "ease_in_out", "loop": "ping_pong", "keyframes": [{"t": 0, "v": 0.85}, {"t": 1, "v": 1}],
                   "active_when": {"beat": {"gte": 1}}}]}]}
  ],
  "anchors": [{"anchor_id": "well", "layer_id": "well", "x": 760, "y": 660, "radius": 120},
              {"anchor_id": "palm", "layer_id": "palm", "x": 360, "y": 560, "radius": 110},
              {"anchor_id": "tent", "layer_id": "tent", "x": 1310, "y": 700, "radius": 110}],
  "reduced_motion": {"still_time_ms": 0},
  "preview": {"frames_ms": [0, 1500], "states": [{"beat": 0, "focus": -1}, {"beat": 1, "focus": 0}, {"beat": 2, "focus": 2}]}
}
OUT.mkdir(parents=True, exist_ok=True)
raw = json.dumps(scene, ensure_ascii=False, indent=1).encode()
p = OUT / "scn_test_desert_well.v2.scene.json"
p.write_bytes(raw)
print(p.name, len(raw), "bytes sha256", hashlib.sha256(raw).hexdigest())
