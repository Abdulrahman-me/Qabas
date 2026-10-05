# Source policy: authority, capability and provenance

**Scope.** The rules the source layer (`app/sources/`, Phase 9) follows for every piece of Islamic evidence Qabas retrieves, verifies, inserts or cites. They implement SOURCE_ADAPTERS §12/§12.1, the operations timeouts, and the hackathon organizers' scientific reference package (*المرجعية والحزمة العلمية والبيانات*, 20/3/1448). Machine-readable counterparts: [`content/sources/providers.yaml`](../content/sources/providers.yaml), [`mushaf.yaml`](../content/sources/mushaf.yaml) and [`translations.yaml`](../content/sources/translations.yaml). Decisions are D-88 onward in `IMPLEMENTATION_PHASES.md`.

The complete 15-page organizers' package was re-read directly during continuation. Pages 3–4 permit King Fahd text/translations or Quranpedia and specify topic-dependent religious references; pages 8–11 explain the association's reviewed translations and prefer those or Risala al-Haramain; pages 12–15 list Tafsir Center, MP3Quran, the King Fahd developer data, Dorar and Shamela. QuranEnc is Qabas's explicit project choice, not an exclusive requirement of that PDF. Listing an approved website does not establish its API availability, redistribution licence or cache terms.

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
| **Word / ayah timing** | — (capability only) | Quran Foundation word segments | `[zero_based_index, one_based_position, start_ms, end_ms]` per recorded word | Segment count equals the canonical word count; positions contiguous from 1; times monotonic and non-negative; canonical word text | None; timings that fail the checks become `words: null` (the contract's "play whole clip, no highlighting") | as for audio, plus the segment checks passed | as for audio | Timings dropped, never re-aligned by guesswork |
| **Tafsir** | **Pending specialist confirmation (D-107).** The organizers' rule (p. 3) names Islamic sources of the first three centuries or dorar.net/tafseer, keeping the commentator's words distinct from the Qur'anic text; they list Tafsir Center (tafsir.net) among recommended external platforms (pp. 11–12) without vouching for it. The handoff's order (Mukhtasar first, then Sa'di, …) names later works, so which books are acceptable is a specialist decision, not engineering's | Tafsir Center MCP (stdio) delivers it | tafsir text, book id, verse key | Verse key equals the request; tafsir is stored as kind `tafsir`, never merged into Qur'an text | Book order is the caller's strategy (Raqeeb §9.3), not a silent substitution | `tafsir_center` record `{book}:{s}:{a}`, server/tool version, SHA-256 | Server, tool names and terms undelivered (O-03) → mock only | n/a (single authority per book) |
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
  - Quran Foundation alone may refresh an OAuth token after one HTTP 401 and repeat that request once; a second 401 fails. No 403 retry. This follows its official token-management flow (D-99), rather than treating authorization errors as general transient failures.
- **Circuit breaker, per provider and per process:**
  - It opens after 5 consecutive failures, for 60 s.
  - One half-open trial follows: success closes it, failure re-opens it.
  - While open, calls fail immediately with `upstream_unavailable`.
- **Cache:**
  - Redis, keyed by `tool + adapter version + SHA-256 of the normalized arguments`.
  - The TTL comes from `providers.yaml`, and only when that provider's terms are `confirmed`. Today all are `pending`, so nothing is cached.
  - Published or cited content is never served from the cache. It is persisted in `sources` (below), and the digest is the reference for re-verification.
  - Dorar's NodeCache is disabled by a Qabas preload hook. `CACHE_EACH=0` would mean unlimited retention, not disabled caching. The original access-rate limit remains in place; the sidecar receives no ambient database/provider credentials. The marker, actual Git HEAD and tracked-file cleanliness are checked before launch.

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

For Qur'an rows the contract's `Provider` enum (rev 10) has no value for the mushaf publisher. These rows therefore carry `provider: quran_com` for contract compatibility. The learner-facing title names the surah and the canonical edition (`سورة … — مصحف المدينة النبوية، مجمع الملك فهد (رواية حفص)`), the reference is `surah name: ayahs`, and the link is a verse reading page, never a dataset download (D-105). `parts[text_authority]` records the canonical dataset and digest, so the stored attribution is never collapsed (D-89).

**Only authority records become `sources` rows (D-106).** `store.persist` refuses any record from a capability-only provider (Quran Foundation verse text, search hits, audio, timings), and any record claiming the mushaf text-authority part that was not produced by canonical insertion. Capability snapshots that support a citation stay embedded in the authority row's `raw`; gold import verifies them but does not store them as citable rows.

A stored row is immutable through the persistence service. The existing PostgreSQL primary key and unique provider/record index arbitrate concurrent inserts; replay preserves original retrieval metadata. If a provider returns different text for the same record id, nothing is overwritten. `store.persist` raises `SourceChanged`, and a reviewer decides through re-verification. The caller's transaction includes all cited-source and lesson writes.

Changed citation/critical attribution metadata (grade, grader, narrator, collection/reference, translation key/version) also requires re-verification; unchanged text cannot authorize a new religious ruling against an older snapshot. Provider version migrations after `SourceChanged` remain a reviewed operation, not an automatic overwrite.

## 6. Insertion and import

`scripture.insert` accepts explicit references, never fuzzy results. Canonical Arabic and word ranges come only from the pinned mushaf. Each supplied translation must match the specialist-approved key/version and the canonical ayah's Arabic. Whole-ayah translation is not presented as the meaning of a word segment; that needs a separately approved excerpt. Multi-ayah audio is not fabricated from separate clips.

Pass the same complete translation/audio bundle for all language variants. Its fingerprint determines one source identity shared by Arabic and English; different verified bindings get a new identity. Each provider remains a separate provenance part. Audio requires canonical word identity; count/position/time disagreements disable highlighting with `words: null` and retain the rejection reason. Wrong verse/word identity rejects the capability record.

Gold files can carry `source_records`, typed private adapter snapshots keyed by source ID. `import_gold` mechanically checks every Quran evidence body, embedded exercise evidence, recitation text and word range against the mushaf before writing, verifies the public source metadata and translation/audio provenance, then persists snapshots and the unpublished lesson in the same transaction. English Quran evidence requires a selected translation. Older files without the required provenance must be re-verified. Existing specialist approval/publication rules remain mandatory.

Hadith bodies/source rows likewise require a verified Dorar binding. Text/excerpts, narrator, grade label/category/source and collection reference are checked against the recorded entry; sharh cannot substitute for it. A translation needs a separately attributed HadeethEnc record with matching Arabic. A single entry cannot authorize an invented collection list or a composite “agreed upon” ruling; such composites need reviewed multi-record bindings (D-104). The Unit 0 collection-number placeholders remain blocked until the content team supplies these bindings.

The Unit 0 converter accepts a verified resolver; its CLI uses the locally installed canonical dataset for Arabic placeholders. English stays blocked until a specialist selects a translation and the resolver supplies its verified records. Hadith collection-number bindings, source claims and sourced stories still require content-team selections. This phase does not fabricate those bindings or publish drafts.

## 7. Integrations and operational approval

Quran Foundation supports verse metadata, reciter catalogue, audio/word segments and current Search API discovery. Content and search tokens are separately scoped, memory-only and omitted from provenance. Its OAuth/current Search API are mock-tested; the recorded public v4 bodies validate content formats. See the official [OAuth quickstart](https://api-docs.quran.foundation/docs/quickstart/) and [Search API](https://api-docs.quran.foundation/docs/search_apis_versioned/1.0.0/search-controller-search/). Translation requests are explicitly delegated to QuranEnc by policy, not fulfilled with an unapproved alternative.

IslamHouse supports item metadata, descriptions and attachment links. It never treats a book description as the book's full text. Documented missing-item responses become `RecordNotFound`; unknown error bodies remain outages. Structured list fields may use safe `ast.literal_eval`, never execution. Credential-bearing URLs are redacted in responses and HTTP diagnostics; the original response digest is retained.

Tafsir MCP supports the six handoff books and asbab via confirmed mappings. `TAFSIR_MCP_COMMAND` is a JSON argv array, with no shell expansion. The stdio client initializes, checks the protocol/tool catalogue and JSON Schema arguments, rejects mismatched identities and treats all returned prose as data. Actual server package, tool names, response normalization schema and restricted native network-egress deployment remain O-03 gates. Fake-server CI coverage is not a live verification claim. The host must isolate provider subprocesses before production approval; this phase does not claim to install a Windows firewall policy.

## 8. Open items

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
