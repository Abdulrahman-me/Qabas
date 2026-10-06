# Bounded hackathon pilot

This is a focused continuation after Phase 20, not Phase 21 completion or production acceptance.

The owner's preferred Factory and Raqeeb text model is `gpt-6.1-sol`. Set `OPENAI_API_KEY`,
`FACTORY_LLM_MODEL=gpt-6.1-sol` and `RAQEEB_LLM_MODEL=gpt-6.1-sol` locally. These explicit routes use
the shared Phase 11 prompt registry, untrusted-data framing, strict schemas, local validators and
usage/budget ledger. The Responses transport sends `store=false`; this is not a provider-retention
or data-processing approval. Existing Anthropic tiers remain available for compatibility.

Exact account access must pass before batch admission. From `backend/`:

```powershell
python -m scripts.check_hackathon_config --env-file PATH
python -m scripts.check_hackathon_config --env-file PATH --smoke
```

The second command makes a small structured-output call and optionally transcribes operator-supplied
neutral WAV files with `--ar-audio PATH --en-audio PATH`. It never prints credentials. A missing sample
is not a passed speech test. Run using the configured environment; pending production model/processing
gates are not bypassed. Neutral development connectivity checks do not authorize real learner uploads.

Hosted Raqeeb speech uses `STT_PROVIDER=openai`, `STT_BASE_URL=https://api.openai.com/v1/`,
`STT_MODEL=whisper-1` and `STT_API_KEY`. The same OpenAI key may be assigned explicitly to both key
fields. Local Quran recitation continues to use `tarteel-ai/whisper-base-ar-quran`; its expected text
comes from the canonical mushaf and its audio is not persisted. Raqeeb original uploads have the
separate seven-day private-retention policy; speech transcription does not promise immediate deletion.

Lesson visuals follow the owner's programmatic-scene direction. No external raster image provider is
required for vector-only scenes. `visuals` receives allowed kinds; `scene_author` refuses raster artwork
when no provider was selected. Style and code-output distribution rights are checked independently of
image-provider credentials. `scene_render` still requires the approved renderer, pinned scene grammar,
audit evidence, accessibility, immutable objects and valid fallback. Existing Canvas examples are
reference previews, not evidence of a normative Flutter capability release. Pending style/renderer/rights
gates remain pending. TTS narration/pronunciation are optional and are never Quran recitation.

Credentials alone cannot resolve scholarly content, English Quran translation, provider terms,
reviewer accreditation, source bindings, style/renderer releases or media rights. Use the existing bounded
Factory admission (one unit, limit 1–4, resumable runs), human Gate 1 and digest-bound Gate 2. Do not
automatically publish or launch all 93 slots before a successful pilot and confirmed budget.
