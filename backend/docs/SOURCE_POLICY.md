# Source policy: authority, capability and provenance

**Scope.** The rules the source layer (`app/sources/`, Phase 9) follows for every piece of Islamic evidence Qabas retrieves, verifies, inserts or cites. They implement SOURCE_ADAPTERS §12/§12.1, the operations timeouts, and the hackathon organizers' scientific reference package (*المرجعية والحزمة العلمية والبيانات*, 20/3/1448). Machine-readable counterparts: [`content/sources/providers.yaml`](../content/sources/providers.yaml), [`mushaf.yaml`](../content/sources/mushaf.yaml) and [`translations.yaml`](../content/sources/translations.yaml). Decisions are D-88 to D-97 in `IMPLEMENTATION_PHASES.md`.

## 1. Principles

1. **Authority and capability are separate roles.**
   - An *authority* is the source whose text or ruling Qabas presents as the evidence.
   - A *capability provider* supplies technical data that Qabas needs (search hits, audio, word timings, metadata) without being cited for the text.
   - One provider may hold both roles for different data. Neither role is inferred from convenience.
2. **Capability data is validated mechanically against the authority before use**: verse identity, normalized text, word counts. On disagreement the authority's data stands. The capability data for that item is dropped, never "fixed", and the disagreement is recorded.
3. **No scripture or hadith text is produced from memory or by engineering.**
   - Qur'an text comes only from the digest-pinned canonical mushaf, by reference.
   - Hadith text comes only from the provider record it is cited from.
4. **Fail safe.**
   - A provider outage yields `upstream_unavailable`, or an abstention upstream. It never yields an answer without sources.
   - "No match" and "provider down" are different outcomes: an outage is never reported as `not_found`, and `not_found` is never reported as "fabricated".
5. **No invented precedence.**
   - Where two authorities disagree (e.g. two hadith grades), the item becomes `needs_specialist` and both statements are kept with their attribution.
   - Engineering does not rank scholars or sources beyond what the handoff and the organizers' package state.
6. **Returned text is data**: never instructions, never executed.

## 2. Matrix

| Evidence | Preferred authority | Capability providers | Accepted from each | Cross-checks | Fallback order | Provenance stored | Licence / cache | Disagreement |
|---|---|---|---|---|---|---|---|---|
| **Qur'an text** | King Fahd Complex Uthmani Hafs v3.0 dataset (organizers: "طبعة مجمع الملك فهد"; handoff: local Uthmani mushaf), digest-pinned (D-88) | None for text. Quran.com and QuranEnc also return Arabic text; it is used only to validate their own records | Complex: the text, surah/ayah numbering, imlāʾī rendering (matching only) | The loader checks the SHA-256 and the 6,236-ayah structure. Any provider verse text must equal the canonical text after normalization | None. If the dataset is missing or altered, insertion and verification refuse | dataset id, version, publisher, file SHA-256, reference, word range, `text_sha256` | Redistribution unconfirmed (O-03): fetched per environment by digest, not committed. Held in memory, no cache | Canonical text stands; the provider record is rejected (`capability_mismatch`) |
| **Qur'an translation** | QuranEnc approved translations (association, three-stage review per the organizers' package); per-language choice in `translations.yaml`, **pending specialist** (D-93) | None (another translation is a different text, never a fallback) | translation text, footnotes, translation key + version | QuranEnc's sura/aya and its Arabic text must match the canonical verse | None: outage → `upstream_unavailable`; unselected language → `translation_unselected` | `quranenc` record id `{key}:{s}:{a}`, translation version, response SHA-256 | Terms pending (O-03) → not cached | Record rejected if its Arabic text disagrees with the canonical verse |
| **Qur'an audio** | Recitation licence holder (O-06); no audio is cited as text | Quran Foundation recitations (handoff §12). MP3Quran (organizers' package) is a recorded follow-up, ayah-level only (D-95) | audio URL, reciter id | Verse key must equal the requested verse | None automatic; no audio → contract `audio: null` | provider, reciter id, verse key, URL, response SHA-256 | URL reference only; storing or serving a clip needs a licence (O-06). Not cached while terms are pending | Mismatched verse → audio dropped |
| **Word / ayah timing** | — (capability only) | Quran Foundation word segments | `[word, start_ms, end_ms]` per word | Segment count equals the canonical word count; positions contiguous from 1; times monotonic and non-negative | None; timings that fail the checks become `words: null` (the contract's "play whole clip, no highlighting") | as for audio, plus the segment checks passed | as for audio | Timings dropped, never re-aligned by guesswork |
| **Tafsir** | Tafsir Center (organizers' package: tafsir.net; handoff: Mukhtasar first, then Sa'di, etc.). The organizers also accept dorar.net/tafseer and early-centuries sources (follow-up) | Tafsir Center MCP (stdio) delivers it | tafsir text, book id, verse key | Verse key equals the request; tafsir is stored as kind `tafsir`, never merged into Qur'an text | Book order is the caller's strategy (Raqeeb §9.3), not a silent substitution | `tafsir_center` record `{book}:{s}:{a}`, server/tool version, SHA-256 | Server, tool names and terms undelivered (O-03) → mock only | n/a (single authority per book) |
| **Hadith text** | Dorar hadith encyclopedia (organizers: Sahihayn first, then verified sunnah books via dorar.net/hadith or Shamela; handoff: Dorar sidecar) | Dorar Node sidecar (pinned MIT repository) | hadith text verbatim, narrator, muhaddith, book, number/page, takhrij | Text inserted only from the cited record; `excerpt=true` slices must be verbatim substrings | None: Dorar down → `upstream_unavailable`; no Dorar match → `not_found` (never "fabricated") | `dorar` hadith id, request, response SHA-256, `text_sha256` | Sidecar MIT; Dorar's automated-access terms unconfirmed (O-03) → not cached | — |
| **Hadith grading / source metadata** | The muhaddith's verbatim ruling as recorded by Dorar (grade label, grader, book, reference) | — | grade label verbatim; category only via the conservative exact table (D-94) | Category `authentic`/`acceptable` only for an exact standard ruling; anything else is `other` → specialist | — | as above, plus the classification rule used | as above | HadeethEnc's grade is kept as HadeethEnc's own statement. If it differs from Dorar's → `needs_specialist`, both kept |
| **Hadith translation / explanation** | HadeethEnc (association; display verbatim, credit the source) | — | translation, explanation, hints, words' meanings | Joined to its Arabic record by id (the Arabic record carries the reference/grade fields the translations lack). Attached to a Dorar hadith only if HadeethEnc's Arabic text matches Dorar's after normalization | None | `hadeethenc` id + language, both responses' SHA-256 | Terms pending → not cached | Mismatch → not attached |
| **Islamic explanatory content** (articles, fatwas, books) | IslamHouse (association). The organizers also list Bayan al-Islam, IslamEnc, dawa.center *Bayyinat* and the Kuwaiti encyclopedia (follow-ups) | — | item metadata, title, description, attachments, author/source, languages | Item id and language echo the request | None | `islamhouse` item id + language, response SHA-256 | Public documented key; terms pending → not cached | — |
| **Terminology / translation of terms** | Organizers: the Jamhara dictionary (islamic-content.com), the Encyclopedia of Islamic Terms (terminologyenc.com), preferred over automatic translation | — | — | — | — | — | Not used by Phase 9: glossary terms are authored content. The Localizer (Phase 11) must prefer these (follow-up, D-97) | — |

## 3. Search capability (D-96)

The handoff names `hadeethenc.search` and `islamhouse.search`. Neither provider's documented REST API offers text search. HadeethEnc v1 offers languages, categories and list/one; IslamHouse v3 offers listing by type, category or author, and item details. These adapters therefore raise `OperationUnsupported`, so the caller abstains rather than guessing.

The organizers' package names the association's MCP server (`mcp.islamiccontent.org`, Streamable HTTP, 11 read-only tools including a unified `search`, `get_hadith`, `get_quran_verses` and `get_library_item`). It is the planned search capability: hits from it are re-fetched from the authority REST record before use. It is not integrated in Phase 9, for two reasons:
- its tool argument schemas could not be retrieved or recorded from the build environment;
- its terms are unconfirmed (O-03).

## 4. Resilience and cache

These rules are common to all adapters (operations §19).

- **Timeouts and retries:**
  - 5 s connect, 15 s read.
  - Two retries with full jitter, on transport errors, 429 and 5xx only. A 4xx other than 429 is not retried.
  - A malformed response is not retried; it counts as a failure.
- **Circuit breaker, per provider and per process:**
  - It opens after 5 consecutive failures, for 60 s.
  - One half-open trial follows: success closes it, failure re-opens it.
  - While open, calls fail immediately with `upstream_unavailable`.
- **Cache:**
  - Redis, keyed by `tool + adapter version + SHA-256 of the normalized arguments`.
  - The TTL comes from `providers.yaml`, and only when that provider's terms are `confirmed`. Today all are `pending`, so nothing is cached.
  - Published or cited content is never served from the cache. It is persisted in `sources` (below), and the digest is the reference for re-verification.

## 5. Provenance (`sources.raw`)

Every persisted source row records the following.

**Row fields:**
- `provider`;
- `provider_record_id`;
- `retrieved_at`;
- `adapter_version`;
- `text_sha256`: the SHA-256 of the exact text that is cited.

**`raw` contents:**
- `schema: qabas.source_raw/1`;
- `request`: tool, operation and arguments;
- `response_sha256`: the SHA-256 of the provider payload;
- `response`: the payload itself;
- `parts`: one entry per contributing provider, each with its `role` (`text_authority`, `translation`, `audio`, `timing`, `grade`, …), provider, record id, version and digest, plus the checks that passed.

For Qur'an rows the contract's `Provider` enum (rev 10) has no value for the mushaf publisher. These rows therefore carry `provider: quran_com`, the value every contract fixture uses, with the quran.com link. `parts[text_authority]` records the canonical dataset, so the stored attribution is never collapsed (D-89).

A stored row is immutable. If a provider returns different text for the same record id, nothing is overwritten. The adapter raises `SourceChanged`, and a reviewer decides through re-verification.

## 6. Open items

| Item | Owner | Gate |
|---|---|---|
| Credentials, live approval and cache terms for each provider | Backend/platform + content reviewer | O-03 |
| Redistribution terms of the King Fahd Complex dataset | Content/legal | O-03 |
| English (and any further) translation choice | Content specialist | D-93 |
| Tafsir Center MCP server package, tool names and arguments | Backend + provider | O-03 |
| Dorar automated-access terms | Content/legal | O-03 |
| Recitation clip licence and timings | Media/content | O-06 |
| Association MCP (search) schemas and terms | Backend + provider | O-03, D-96 |
| Hadith grade phrases beyond the exact table | Content specialist | D-94 |
| Binding of hadith citations ("Bukhari 4770") to provider record ids | Content team | D-92 |
