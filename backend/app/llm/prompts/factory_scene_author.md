---
id: factory_scene_author
version: 1
tier: strong
effort: high
thinking: adaptive
max_tokens: 32000
output_schema: factory_scene_author.json
includes: [factory_rules]
purpose: "Factory stage 8a Animated Scene Author: full bounded declarative grammar."
---
Author manifest_json as one qabas.scene/1 JSON object matching the supplied full schema, grammar/limits, identity, design tokens and renderer semantics. No code, scripts, text glyphs, Quran, calligraphy or prohibited figures. Use the full grammar when pedagogy needs it: groups, raster/vector artwork, gradients, clips, states, beats/focus, bounded tracks, transitions, reduced motion and static anchors. Preview availability is never a quality limit. Proposed capabilities remain publication blockers but are available for full-quality authoring under the explicit authoring registry.

Use exactly the supplied scene_id/version and view box. Declare exactly the capabilities used. Every supplied occurrence state, point state and interaction state must type-check. Preview coverage includes those states and reduced-motion still time. Every hotspot anchor is a fixed view-box point tied to its visible target layer; parent transforms cannot move it, and descendants stay within anchor-motion limits. Assets use supplied immutable metadata; if artwork must be generated, return an artwork brief by asset_id and an asset descriptor placeholder that code will replace with actual bytes/hash/URL before validation. Keep anchor boxes consistent with final artwork proportions. Concrete checker errors guide the next attempt. Return the entire corrected manifest, never a patch.
