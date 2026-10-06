# Content and brand policy

**Purpose:** own editorial tone, source approval and visual-asset constraints. Rendering algorithms and asset transport are in the animation/API documents.

## Editorial and source policy

Use short, clear, respectful explanations for explorers and new Muslims. Preserve learner privacy, explain unfamiliar terms, and meet mistakes warmly. Explorers receive attributed wording that does not presuppose acceptance (“The Qur'an describes Jesus as a messenger of God.”); new Muslims receive direct, reassuring wording (“Allah tells us that Jesus ﷺ was one of His messengers.”). Both are variants of one canonical lesson with the same claims, evidence and outcome. Never ask, record or infer a learner's religion, and never grade whether a learner personally believes or agrees with a claim. Raqeeb attributes views, abstains or refers according to its routing class.

Short fictional teaching scenarios and stories (a grandmother's phone call, a parcel at the door, a library table, a delayed bus, a market price) are welcome when they are recognisably fictional and assert nothing about real people, events, science or religion. Sourced religious stories come from the Qur'an and authentic Sunnah only and are used when the source itself matters to the lesson, not merely to make a lesson "Islamic"; early Explorer lessons prefer everyday scenarios, chosen for the concept and varied across a unit rather than drawn from habitual defaults (weather, school, the workplace, footprints, social-media rumours); characters are light roles (traveller, neighbour, shop owner, student) rather than generic "a person" or "a friend" (factory §13.2). Every factual, historical, theological or religious assertion needs verified support. Pedagogical framing that asserts nothing (clearly marked hypotheticals such as “Imagine finding footprints in the sand”, instructions, curiosity questions, transitions) needs no scriptural evidence. It may never disguise an assertion, and a hypothetical never puts words or deeds in the mouths of prophets, companions or scripture. For Explorers, foundation reasoning (Unit 0) must be understandable without first accepting the Qur'an's authority: scripture can show how the Qur'an frames a question, never prove itself. Arabic is the semantic source of authored lessons; English is a faithful localization that adds, removes or reinterprets nothing. Onboarding bridges are a small human-written, specialist-reviewed set. Details: [curriculum and learning design](CURRICULUM_AND_LEARNING_DESIGN.md) and the [factory handoff](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md) §13.2.

Exact Quran text, hadith text and authenticity grades come from verified source adapters/code, rather than model memory. Preserve attributable quotation, excerpt/translation labels and provenance. Religious rulings and authenticity grades are not authored by the model. Specialist review is mandatory before learner publication. The reference scripture/attributions still need renewed verification; the prototype's reviewer labels are not an approval record.

Lesson content uses at most three distinct displayed **content** sources, plus declared **activity** sources for recitation. Preserve claim-to-source support internally even when UI content combines claims. Definitions, explanations, narrations, exercise keys and English localizations undergo the same content pipeline; translations of Quran and hadith come from verified sources, never from the model. Verified playback audio must be licensed for the intended distribution; Quran recitation is never TTS-generated.

## Imagery rules

- No depiction of God, prophets, historical companions, angels, paradise or hell. Prohibited figures include faces, bodies, silhouettes and symbolic human shapes representing them.
- A referenced prophet/historical companion can use a separately approved human-authored calligraphic-name medallion. Generated artwork does not produce that calligraphy.
- Ordinary modern characters in content use blank featureless faces and are absent from historical scenes of the Prophet's era.
- Generated images contain no letters, names, calligraphy or scripture. Flutter text and approved overlays are separate.
- Quran text uses verified Uthmani content and the designated Quran font; do not stylize it as an illustration.
- Scenes favor places, light, doors, water, palms, landscapes, books, lanterns and architecture. Use calm compositions and consistent colors. The flame guides; it is not aggressive fire.
- **Illustration style** (made explicit from the direction above and the compiled reference scenes): flat illustration with solid fills and soft linear or radial gradients for sky and light; no photorealism, 3D rendering, heavy outlines or texture noise; the design-identity palette anchors every scene (emerald for primary objects, Flame Gold and Soft Ember for light and attention, Deep Ink for night skies, Morning Mint for calm backgrounds) with natural neutrals; one clear subject per scene.
- **Composition for phones:** scenes are 16:10 (1600×1000 view box); the key subject sits inside the central area, nothing essential lies in the outer edge, and every highlighted element stays legible at about 360 px wide. Scenes are never mirrored for right-to-left text.
- **Attention cues** are soft Flame Gold glows on the relevant object, never arrows, labels or text in the image.
- **Consistency:** within a lesson, a story keeps one setting, time of day and palette across its beats, and a recurring modern character keeps the same faceless appearance and modest everyday clothing, defined by a character reference sheet.
- **Gap:** the factory's `content/style_guide.md` and the character reference sheet are referenced but not yet written. They must be produced from these rules and reviewed before any image provider is used (open decision O-13).

The modern UI companion is Flutter-owned and replaceable by any character within the product's approved visual policy. Its current Rive implementation is not a server/content requirement.

## Design identity

| Role | Color |
|---|---|
| Deep Night Emerald | `#073C37` |
| Emerald | `#0B5A52` |
| Flame Gold | `#E0A526` |
| Soft Ember | `#F6E3B4` |
| Morning Mint | `#EEF5F2` |
| Deep Ink | `#16233A` |
| Slate | `#566476` |

Use the [compiled theme tokens](../10_REFERENCE/engineer_delivery/reply8/flutter_reference/lib/core/theme/tokens.dart) and bundled fonts as the implementation reference: Figtree/IBM Plex Sans Arabic UI, Fraunces/Amiri special moments and Amiri Quran scripture. Keep rounded surfaces, raised answer controls, generous spacing, subtle patterns, a winding journey path and restrained light/glow. Avoid aggressive fire, neon, mystical effects, generic religious-logo clichés or loud gamification.

The original brand brief, including historical logo exploration ideas, is preserved in the history archive. Those ideas do not authorize redesigning the current Flutter reference or adding launch deliverables. Content approval workflow is owned by [the factory/reviewer handoff](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md).
