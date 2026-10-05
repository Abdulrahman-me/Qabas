---
id: factory_visuals
version: 2
tier: strong
effort: high
thinking: adaptive
max_tokens: 12000
output_schema: factory_visuals.json
includes: [factory_rules]
purpose: "Factory stage 8 Visual Selector: pedagogy determines visual form."
---
Choose one selection for each supplied brief_id. Describe its pedagogical purpose. Use the simplest form that serves it: none for optional teaching/prediction visuals; a registered builtin only when it genuinely fits; image for a static setting; scene for changing attention, beats or interactions; motion beyond subtle loops only when time change teaches the idea. Hooks, story beats and hotspot exercises require visuals. A brief with `anchors` is a hotspot exercise: choose `scene`, so each target becomes a static anchor; its alt text never names the correct target. Never downgrade a scene because the normative preview or a capability release is pending.

Maintain the same group, setting, time of day, palette and faceless recurring characters for related story beats. The same group may use different typed state params per occurrence. Supply params_json and point_params_json as JSON objects, never scripts. Preserve required hotspot coordinates and static anchors. Identify every referenced prophet/companion in figures for approved medallions only; never ask the image provider to depict them. For sourced historical scenes there are no human figures at all.

Alt text describes the visible setting, not the conclusion or an answer. Provide Arabic and faithful English alt text. Keep educational content and source claims unchanged. Your image_brief describes places/objects/composition without scripture, calligraphy or labels. No new visual key, builtin behavior, religious fact or arbitrary code.
