# Curriculum and learning design

**Purpose:** own the learner tracks, the Unit 0–10 curriculum structure, onboarding by curiosity, Roadmap and Discover, the difference between curriculum position and prerequisites, Soft Lock, lesson types and composition, lesson completeness and depth (including duration) and the learning-design principles. Public fields are owned by the [API requirements](../03_API/API_REQUIREMENTS.md), access and planner algorithms by the [backend handoff](../05_BACKEND/BACKEND_HANDOFF.md), and lesson production (LessonPlan, Lesson Arc, claims, localization, pedagogical QA) by the [factory handoff](../06_CONTENT/FACTORY_AND_REVIEWER_HANDOFF.md).

**Status:** owner-confirmed product and content architecture (2026-10-03). The curriculum below is the structure engineers build for. Unit/lesson wording, Arabic titles, prerequisite analysis, standalone eligibility and every lesson's religious content still need scholarly review before approval ([O-12](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md)).

## Learning-design principles

1. The Explorer is not asked to accept a claim before the foundations needed to evaluate it have been established.
2. The foundation must not feel like a philosophy course. Simplify the interface and the teaching experience, not the integrity of the reasoning.
3. We do not ask who the learner is religiously. We ask what they are curious about.
4. Entry point does not change curriculum order. It gives the learner a reason to care about the curriculum.
5. Roadmap answers "What should I learn next?"
6. Discover answers "What can I explore now?"
7. Discover exposes the exact same canonical published lesson, not a Discover-specific version.
8. Curriculum position is not prerequisite dependency.
9. One lesson equals one coherent primary learning outcome, taught completely: the learner leaves with a useful understanding of the lesson's central question, not one isolated fact or definition (refined 2026-10-03).
10. Lesson Arc is not a universal template. It is a lesson-specific pedagogical journey.
11. AI may be creative in non-assertive pedagogical framing, while every factual or religious assertion stays strictly evidence-backed.
12. Arabic Explorer and Arabic New Muslim are authored semantic variants.
13. English is constrained, meaning-preserving localization of the corresponding Arabic variant, not an independently authored semantic lesson.
14. Explorer exercises measure understanding of an argument, never personal acceptance of it.
15. Religious correctness alone is insufficient; lesson quality also requires pedagogical QA.
16. The goal is not an Islamic encyclopedia inside a Duolingo-like interface. It is a carefully sequenced, interactive journey where each step has a clear conceptual purpose and a manageable daily size.
17. Increase depth, not repetition: a lesson is complete, not maximal.
18. The first lessons must show the value of the platform. Unit 0 and Unit 1 lessons should leave the learner thinking "I learned something meaningful", never "that was obvious" (added 2026-10-03).

## Learner tracks

| Track | Who | Starts at | Assumptions |
|---|---|---|---|
| `explorer` | Someone interested in Islam | Unit 0 | Must not be assumed to accept Allah, the Qur'an as revelation, Muhammad ﷺ as a prophet, or claims about the unseen. Content attributes ("The Qur'an describes…", "Muslims believe…") instead of presupposing. |
| `new_muslim` | Someone who has already accepted Islam | Unit 1 | Direct, warm, personal address ("Allah tells us…"). |

- Unit 0 is Explorer-only. After Unit 0 both tracks use the **same canonical curriculum**: Units 1–10, the same lessons and the same lesson IDs. There is no second curriculum.
- A shared lesson has an Arabic Explorer variant and an Arabic New Muslim variant of the **same canonical lesson** (one plan, outcome, arc, claim and evidence set). English variants are localized from them. Exercises have one wording per language that serves both tracks.
- Completion belongs to the canonical lesson. If an Explorer becomes Muslim and switches to the New Muslim track, every completed shared lesson stays completed; Unit 0 leaves their roadmap (its records are kept). The track changes only when the learner chooses it; it is never inferred from behavior.

## Onboarding by curiosity

Onboarding never asks for or records the learner's religion or worldview and never classifies learners (Christian, atheist, Jewish, Hindu, …). It does not infer religious identity from behavior. The learner-type page only chooses the track: "I'm exploring Islam", "I'm a new Muslim", or "Prefer not to say" (→ Explorer).

A curiosity page asks **"What would you most like to understand?"** The initial choices (keys in the shared `goal_anchors` registry) are: Does God exist? · Who is God in Islam? · What makes the Qur'an special? · Who was Muhammad ﷺ? · What do Muslims actually believe? · Why do Muslims pray? The learner may skip it.

The choice creates a **Goal Anchor** (`User.goal_anchor`). It is not a branch: the start unit, curriculum order and recommendations are unchanged. The learner then sees a short **onboarding bridge** that explains why the foundation will help answer their question. Example for "Who was Muhammad ﷺ?" (Explorer):

> Muhammad ﷺ claimed to bring a message from the Creator. To examine that claim fairly, we will first explore whether there is a Creator and whether revelation makes sense. Then we will return to Muhammad ﷺ.

Bridges are onboarding content, not lessons: one per goal anchor × track × language, written and specialist-reviewed by humans, bundled with the onboarding copy, and never generated by the lesson factory.

## Roadmap and Discover

| Surface | Question | Contents |
|---|---|---|
| **Roadmap** (journey, S3) | What should I learn next? | The recommended ordered path of the learner's track, the `current` pointer and next step. |
| **Discover** (S22) | What can I explore now? | Lessons marked `standalone_eligible`, i.e. understandable without mandatory prerequisites. |

Discover is only another access surface. A lesson opened there is exactly the published lesson and version that sits at its Roadmap position for that track: no Discover wording, adaptation, exercise set or record. A lesson completed through Discover is already completed when the learner reaches it on the Roadmap. Discover may show one general page notice that some lessons normally come later and that earlier units can make them easier; individual lesson content never depends on the entry surface.

## Curriculum position versus prerequisites

- **Curriculum position** (unit and `index`): where a lesson ideally sits in the recommended journey. It drives Roadmap order and the planner.
- **Prerequisites** (`prerequisite_concept_ids`, approved at Gate 1): the concepts the learner must already understand. They are the only input to lesson access. A Unit 7 lesson does not require Units 1–6 unless its prerequisites say so.
- A concept is introduced by exactly one lesson. A prerequisite is satisfied when that lesson is completed (from any surface) or when its unit was passed through the unit test. Prerequisites always point to earlier curriculum positions and must be satisfiable inside every track that serves the lesson (a shared lesson cannot depend on an Explorer-only Unit 0 concept).
- **Standalone eligibility** is a separate, reviewed decision: it requires no mandatory prerequisites, but having none does not make a lesson standalone. Story lessons are not standalone merely because they are stories; prophet stories in Unit 7 qualify only after prerequisite analysis.

**Soft Lock.** Roadmap progression stays structured. A lesson with an unmet prerequisite is not opened, and there is no generic "skip lesson" action, but it is never an unexplained lock either: the learner sees why the earlier idea matters and a button to the lesson to take first (conceptually: "You're almost there. One idea first will make this much easier to understand."). Exact copy is a frontend/product detail. The existing unit placement test ("Skip unit") remains: passing it demonstrates understanding of the unit; it is not a lesson skip.

## Unit 0: the Explorer foundation

Unit 0 builds the conceptual foundation needed before revelation, prophethood and unseen claims are presented as things to evaluate. Its underlying logic is:

knowledge/evidence → Creator → one Creator → need for guidance → revelation → evaluating revelation → prophethood → Muhammad ﷺ → Islam

It must not feel like an academic course. Lessons are framed as concrete, accessible questions with everyday examples; avoid framing such as "epistemology", "contingency argument", "metaphysics" or "philosophy of religion". Reasoning tools (observation, inference, testimony, …) are introduced only when a lesson needs them: lesson 0.1 introduces that knowledge can come from direct observation, evidence/inference and reliable testimony (a trusted person reporting something they can see and you cannot; a trace such as a parcel at the door showing that someone brought it), and later lessons add tools just in time (see the 0.1 reference design below).

Unit 0 keeps "Islam says X" apart from "reasoning you can follow before accepting Islam". Scripture may be shown as "This is how the Qur'an frames this question", but reasoning that establishes the foundation must be understandable without first accepting the Qur'an's authority. The argument "the Qur'an is true because the Qur'an says so" is never made (factory §13.2, QA `circular_reasoning`).

**Stories and scenarios in Explorer lessons.** Do not use an Islamic story merely to make a lesson "Islamic". Ask whether the story actually needs Islamic authority to teach the outcome; if not, prefer an accessible everyday scenario (travel, family and neighbours, home, markets, libraries and museums, food, health, sport, nature, physical traces, online information, ordinary historical claims, trusted and untrusted sources). Weather, school, the workplace, footprints and social-media rumours are fine occasionally but are habitual defaults: a lesson must not lean on them and a unit must not keep returning to them. A story is a small narrative with progression, not an example with a character attached; it may be invented (asserting nothing) or sourced (verified), and its characters are light roles such as a traveller, a neighbour or a shop owner (factory §13.2). Religious material appears when it is the subject being learned, when it meaningfully advances the curriculum, or when it has a clear pedagogical reason. In Unit 0 this means foundations are taught through ordinary situations; Qur'an, revelation and Muhammad ﷺ arrive when the curriculum reaches them (0.7–0.12 and the shared units). Neutral does not mean empty: Explorer lessons still need personality, curiosity, memorable examples, visual storytelling, small surprises and meaningful choices.

**Examples teach how to reason, so they must be epistemically clean.** Prefer examples whose intended conclusion clearly follows and whose obvious alternative explanations do not undermine the lesson; match the strength of the conclusion to the evidence; phrase uncertain conclusions as uncertain ("the wet ground suggests it may have rained", never "proves"). "I saw my neighbour's car, so I know they are back" and "the ground is wet, so it rained" are weak: choose clearer examples. Keep apart what is observed, what is inferred and how strong the inference is, and never write the conclusion into the description of what was seen ("a half-eaten sandwich" already says someone ate it). Simplify the presentation, never the integrity of the reasoning; later Explorer lessons build on these foundations.

### Reference design: lesson 0.1 "Do You Have to See It to Know It?"

One canonical lesson, `lesson_type: concept`, depth profile **foundational**. **Central question:** do I have to see something myself to know it? **Primary outcome:** the learner understands that direct sight is not the only reasonable basis for knowledge, and can tell how something is known and how much that route can establish. Supporting understandings, each taught through situations rather than terms:
- knowledge reaches us by several routes: **direct observation** with any sense (learner-facing "الملاحظة المباشرة" or a reviewer-approved phrase, not only sight even though the title asks about seeing), **inference from evidence or traces**, and **reports**;
- what I observe is different from what I conclude from it;
- an inference may claim only as much as its evidence shows (a parcel at the door tells you someone brought it, not who or when);
- not all evidence is equally strong, and the wording should match the strength ("you know" versus "probably");
- reports can give knowledge, but they vary: is the source truthful, and is it in a position to know rather than guessing;
- not every report needs the same checking: an ordinary report from someone who knows is normally enough, while a surprising, important or unsourced one deserves more.

Testimony is never taught as "someone said it, so it is knowledge", nor as "every single report must be rejected until several people confirm it". No academic vocabulary; deeper treatment of testimony and historical evidence comes later when needed.

A strong arc (one possibility, not a template), about 8–10 minutes with frequent interaction:

| Arc step | Technique | What the learner experiences |
|---|---|---|
| Hook | scenario | A grandmother calls from her village: the apricot tree you planted has fruit at last; you are far away and cannot see it. |
| Predict | prediction (ungraded) | "هل يمكن أن تعرف شيئاً لم تره بعينيك؟" |
| A box at the door | example | A parcel with your name at the door, nobody seen: what you observed (a box and a label) versus what you concluded (someone brought it, a strong inference), a weaker inference (it is the order you expect) and what the box cannot tell you (who, when). |
| Fit the evidence | practice | A library table with an open book and a still-warm cup of tea: choose the conclusion that claims no more than the traces show (someone was here a short while ago). |
| Discovery | explanation | Name the three routes after the learner has met them, in simple words. |
| Quick application | practice | Classify a few clear examples, including observation by taste and by smell. Not many near-identical items. |
| Short scenario | scenario | The last bus: a passenger confidently passes on a cancellation he overheard; the traveller notices he is relaying, asks at the ticket window, and the clerk, who can see the departures screen, says it is only late. (fictional, a small narrative with a doubt and a resolution) |
| Who would know? | practice | Why was the clerk's answer the one to rely on (he was placed to know), not because the latest report is always right or because the passenger lied? |
| Which would you check? | reflection (ungraded poll) | A neighbour on when the bakery opens versus a stranger warning that the tap water is unsafe today. |
| Not every report needs the same checking | explanation | Ordinary reports from someone who knows are normally enough; surprising, important or unsourced ones deserve more. |
| Transfer | practice | A clip in which an unnamed man says a herbal drink can replace diabetes medication, then a judgement on "one person's report can never be known". |
| Takeaway | takeaway | Several routes to knowledge, each with limits. |

These contexts are one clean and varied choice, not a prescription: the planner chooses its own against the unit context. The previous version used weather, school, messages and footprints, and had three reasoning slips ("half-eaten" put the conclusion inside the observation; a timetable was treated as knowing whether a bus had left; a friend relaying his brother was called a source who would know), recorded as review log L-22. The hadith of Dhul-Yadayn, or any Seerah or Qur'anic story, is unnecessary here: it would presuppose prophethood and hadith authority the Explorer has not yet examined. Two earlier tests shaped this design: separate concept, story and practice lessons for the outcome were each too thin (and concatenating them would only repeat), and a first composed version (~5 minutes) named the three routes but stopped before the learner could judge how far each route reaches. The richer arc above adds depth (limits of inference, sources who know versus sources who guess, proportionate checking), not repetition.

## Lesson types and composition

`lesson_type` (`concept`, `story`, `practice`) is the lesson's **primary pedagogical mode**: what it is mainly trying to do. It never restricts which techniques or blocks the lesson may use.

| Type | Primary purpose | May also contain |
|---|---|---|
| Concept | Help the learner understand or discover an idea ("Could Something Create Itself?") | hook, prediction, examples, a short story or scenario, visual explanation, comparison, exercises, guided application |
| Story | Learn through a narrative that itself carries the outcome: a prophetic or Islamic historical story when appropriate, a verified historical narrative, or a deliberately fictional teaching scenario | predictions, reflection, concept explanation, exercises, application |
| Practice | Build or rehearse a practical skill (performing wudu, sequencing the prayer, pronunciation, recognising a type of evidence, applying a decision process) | brief explanation, demonstration, scenarios, feedback, repeated attempts |

- **One learning outcome, one lesson.** One canonical outcome normally produces one canonical lesson, and a curriculum slot holds one lesson. The Curriculum Architect distinguishes genuinely different outcomes (separate lessons, defined by the curriculum) from different ways of teaching the same outcome (one lesson whose arc combines them). A concept lesson is never followed by automatic "story" and "practice" versions of the same outcome; a separate story or practice lesson exists only when the curriculum defines a distinct outcome for it.
- **Merge selectively, never concatenate.** When several techniques serve one outcome, the arc picks the strongest piece for each step. Not every lesson needs a story, practice, a prediction, a comparison, a visual or an evidence card; every block has a pedagogical purpose and none is added to satisfy a template.
- **Rhythm.** A lesson unfolds as stimulus → learner action → feedback or reveal → new stimulus → action → synthesis, not as a run of cards followed by a run of questions. Interactions are meaningful (predict, notice, classify, compare, choose evidence, apply a rule, correct a misconception, sequence a skill, interpret a scenario), never added only for frequency.
- **Arc families, not templates.** Discovery, investigation, contrast, misconception, progressive reveal, narrative discovery, thought experiment and evidence evaluation are useful names for the `lesson_arc.pattern` label and for variety, never fixed step sequences. A pattern is chosen because it fits the outcome; two lessons with the same pattern can and should unfold differently. The reference designs and test lessons illustrate the bar and must not become a hidden template.
- **Unit-level variety.** Before planning a lesson the Curriculum Architect sees the unit's recent lessons: their arc patterns, technique sequences, openings, story settings and characters, exercise families and visual kinds. It avoids the same pattern twice in a row, the same opening three times, the same exercise mix, and settings that keep returning; QA flags unit monotony (factory §13.5).
- **Experience before definition.** Prefer experience → question → discovery → naming the idea ("ترى آثار أقدام على الرمل. لم ترَ أحداً يمر. فماذا تعرف من هذه الآثار؟") over definition → explanation → example. This is a preference, not a fixed template.

## Lesson completeness and depth

**One primary outcome is not one fact.** A lesson keeps one coherent primary learning outcome, which answers one **central learner question** (for example "What does Islam actually mean?"). It may include several **supporting understandings** when the learner needs them to genuinely understand that outcome: they complete the main idea and do not become separate lessons. A lesson ends when the learner's understanding of the central question is complete enough to be useful, not when the central term has been defined. The test for every plan and draft: *if this were the learner's only exposure to this idea today, would they leave with a coherent and useful mental model?*

**Completeness dimensions.** When relevant, a lesson gives enough of: intuition, meaning, context, boundaries (what the idea is not), important nuance, misconception correction, implications, concrete examples, application and transfer to a new situation. These are dimensions the planner weighs, not required blocks; there is no template.

**Depth, not padding.** Length is earned through meaningful explanation, useful nuance, another angle on the same idea, misconception correction, stronger examples, learner reasoning, application, relevant story or context and conceptual connection. It is never earned through repeated definitions, near-identical exercises, redundant examples, unnecessary storytelling, filler transitions, restated conclusions, extra source cards or repetition disguised as practice. Greater depth also never means teaching later lessons early: **establish the map now, explore each region later** (a lesson on what Islam means mentions that submission involves worship and following guidance; it does not teach the Shahadah, Salah, the pillars, halal and haram or detailed rulings).

**Depth profile** (`LessonPlan.depth_profile`, chosen by the Curriculum Architect and reviewed at Gate 1; it is not difficulty, and foundational lessons can use very simple language):

| Profile | Use when | Normally needs |
|---|---|---|
| foundational | Later lessons will build on this concept (all of Unit 0 and Unit 1, and other cornerstone ideas) | A rich mental model, important boundaries, the relevant beginner misconceptions, meaningful application and enough context for future learning |
| standard | The idea needs to be understood well enough for normal progression | Sufficient development of the outcome with its key supporting understandings |
| focused | A genuinely narrow objective | Little development beyond the objective itself |

**Units 0 and 1 carry a higher bar.** They shape the learner's whole mental model and form the first impression of the platform. They must not feel obvious, shallow, like a dictionary card or a short FAQ: they need conceptual completeness, clarity, memorable explanation, meaningful interaction, strong examples, misconception handling, useful insight and coherent progression, without artificial complexity. Unit 0 lessons in particular are never "one clever example → one definition → three questions → done": the learner is building the reasoning tools that later support thinking about a Creator, revelation, historical knowledge, Qur'anic claims, prophethood and unseen claims, taught through situations, comparisons, choices and examples rather than terminology. Unit 1 lessons are the first shared foundation of both tracks and must not feel like a glossary.

**Duration guidance** for the whole composed lesson (guidance ranges, not constants; a genuinely simple lesson may be shorter, and no lesson is padded to reach a target):

| Lesson | Usual duration | Graded exercises |
|---|---|---|
| Foundational concept (especially Units 0 and 1) | about 8–10 min when the content warrants it | about 3–5 |
| Other concept | about 6–10 min | about 3–5 |
| Story | about 6–10 min | about 2–4 |
| Practice | about 6–10 min | about 3–5 checks, plus ungraded attempts |

A ten-minute interactive lesson is acceptable, and seven minutes is not inherently long: a nine-minute lesson with frequent meaningful interaction can feel lighter than four minutes of passive cards. When a lesson is likely to run well beyond about 10–12 minutes, the Curriculum Architect **reviews** whether it holds more than one genuine outcome; nothing splits automatically at a time threshold. Longer lessons do not mean more questions: interactions (predictions, polls, comparisons, choices, reflection, transfer) are not the same as graded exercises, and a richer lesson keeps roughly 3–5 graded items depending on need (structural limit 2–6). Flashcards, pretests, unit tests and challenge items exist separately. A supporting story or scenario inside a concept or practice lesson stays short relative to the lesson (normally up to about two minutes); a full multi-beat story belongs to a lesson whose primary type is story.

**When to split.** Split by a change in learning purpose, not by every change in subtopic.
- *Keep together* when the sections answer the same central learner question, the sub-concepts depend on one another, removing one would leave the main idea incomplete or misleading, the learner is building one coherent mental model, and the whole experience fits a reasonable interactive session.
- *Consider splitting* when there are two independently useful outcomes, one part introduces a new skill rather than deepening the same idea, the lesson moves from understanding what and why into a substantial how-to skill, the second part needs its own prerequisites, each half would be a meaningful lesson on its own, or the lesson cannot stay coherent within roughly 10–12 minutes without rushing.

Duration alone is not a reason to split, and neither are topic headings: a textbook chapter's definition, importance, purpose, examples, misconception and implications may be six parts of one lesson rather than six lessons. As an illustration only (not a curriculum template): "what Salah is, its importance, why Muslims pray and the five daily prayers" can together answer one question ("What is this daily worship called Salah, and why is it central to Muslim life?"), while "How is Salah structured?" is a genuinely different purpose.

## Curriculum: Units 0–10

English working titles; Arabic titles are authored as the semantic source and reviewed with the content (O-12). Track-specific framing applies to unit titles, subtitles and guides as well as lesson variants.

**Unit 0 — Start With a Question** (Explorer only). Goal: build the foundation required before revelation, prophethood and unseen claims are presented for evaluation. Explorers then enter Unit 1.

| # | Lesson | Focus |
|---|---|---|
| 0.1 | Do You Have to See It to Know It? | Observation, evidence/inference and reliable testimony through simple examples |
| 0.2 | Could Something Come From Nothing? | The existence question without abstract vocabulary |
| 0.3 | Could Something Create Itself? | An intuitive example that exposes the self-creation problem |
| 0.4 | What Would a Creator Be Like? | Independence, non-dependence, Creator versus creation |
| 0.5 | One Creator or Many? | An accessible introduction to divine oneness |
| 0.6 | If There Is a Creator, Would We Need Guidance? | Why reason alone does not answer every question about purpose, worship and the afterlife |
| 0.7 | How Could Guidance Reach Us? | Revelation and messengers |
| 0.8 | How Would We Test a Claim of Revelation? | A claimed revelation is examined, not automatically accepted |
| 0.9 | The Qur'an's Claim | What the Qur'an claims about itself, without assuming the claim is accepted |
| 0.10 | How Would We Recognize a Messenger? | Questions relevant to a prophethood claim |
| 0.11 | Muhammad ﷺ and His Claim | The earlier foundations brought together around his claim |
| 0.12 | So What Is Islam? | Creator → One God → Guidance → Revelation → Messenger → Islam |

**Unit 1 — The First Step** (shared). Explorer framing: *Understanding the First Step into Islam*; New Muslim framing: *Your First Steps with Allah*. Explorers understand the meaning of the transition; New Muslims understand what entering Islam means personally.

*Reference design: lesson 1.1 "What Does Islam Mean?"* (`concept`, **foundational**). The central question is the learner's real one, "What does Islam actually mean?", not "What is the dictionary origin of the word?". **Primary outcome:** the learner can explain, at beginner level, that Islam means willing submission to Allah, a relationship that shapes worship, obedience, trust and the direction of a person's whole life. Supporting understandings, each subject to retrieval, verification and scholarly approval (the wording here is not final religious copy): the linguistic root (*aslama*: to submit and yield) as the starting point rather than the whole answer; that submission is willing; that Islam is not an ethnic, national or inherited identity, not merely a label or phrase without lived meaning and not merely a checklist of prohibitions; that it is a whole orientation of the person toward Allah in which worship, obedience, trust and following His guidance belong together. The lesson must not set worship against "living Islam": prayer and the other acts of worship belong inside this orientation, not beside or against it, so no hook, option or summary may imply that rituals are secondary; that a Muslim is one who submits to Allah; and that the Qur'an presents this submission as the way of earlier prophets (Ibrahim's answer stays when the architect judges it advances the outcome). It establishes the map that later lessons fill in and does not teach the Shahadah, Salah, the pillars, halal and haram or detailed rulings. The Explorer variant speaks of what Muslims mean by Islam and how it differs from common assumptions, without assuming acceptance; the New Muslim variant may personalise the same meaning (the step they have taken, learning to live it step by step) without adding religious claims. Target about 8–10 interactive minutes. Every verse used is checked against the exact sentence it supports (factory §13.1 semantic review): for example, Al-An'am 6:162 is a declaration the Prophet ﷺ is told to make and is generalised only with that said, Al-Baqarah 2:256 concerns compulsion into the religion, and Al-Baqarah 2:130–132 concern Ibrahim and Yaqub rather than all prophets. The test lesson records these as flags for the specialist rather than silently rewording religious content.
1.1 What Does Islam Mean? · 1.2 What Does Worship Really Mean? · 1.3 La ilaha illa Allah · 1.4 Muhammad Rasul Allah · 1.5 What Changes When Someone Becomes Muslim? · 1.6 Mercy, Forgiveness, and a New Beginning

**Unit 2 — Knowing Allah** (shared).
2.1 Who Is Allah? · 2.2 One and Unique · 2.3 The Creator and Sustainer · 2.4 Allah's Mercy · 2.5 Knowing Allah Through His Names · 2.6 Love, Hope, and Trust · 2.7 Du'a: Speaking to Allah

**Unit 3 — Prayer: Your Daily Connection** (shared). Explorers learn what prayer is and how Muslims practise it; the New Muslim variant increasingly supports actual performance.
3.1 Why Do Muslims Pray? · 3.2 Five Times a Day · 3.3 Getting Ready for Prayer · 3.4 Wudu: Step by Step · 3.5 Facing the Qiblah · 3.6 The Movements of Salah · 3.7 What Do We Say in Prayer? · 3.8 Al-Fatihah · 3.9 A Guided Prayer

**Unit 4 — Living the Five Pillars** (shared).
4.1 The Five Pillars · 4.2 Shahadah Revisited · 4.3 Salah Revisited · 4.4 Zakah · 4.5 Ramadan and Fasting · 4.6 Hajj · 4.7 One Life, Five Pillars

**Unit 5 — What Muslims Believe** (shared). Divine Decree stays introductory, without advanced theological complexity at this stage.
5.1 What Is Iman? · 5.2 Belief in Allah · 5.3 Angels · 5.4 Revealed Books · 5.5 Messengers · 5.6 The Last Day · 5.7 Divine Decree · 5.8 How Belief Changes Life

**Unit 6 — The Qur'an** (shared).
6.1 What Is the Qur'an? · 6.2 How Revelation Came · 6.3 From Revelation to Mushaf · 6.4 Surah, Ayah, Juz' · 6.5 What Does the Qur'an Talk About? · 6.6 Reading and Listening to the Qur'an · 6.7 Understanding Before Memorizing · 6.8 Living With the Qur'an

**Unit 7 — One Message, Many Prophets** (shared). Several prophet-story lessons may become standalone-eligible and appear in Discover, but only after their actual prerequisites are analysed.
7.1 Why Prophets? · 7.2 Adam · 7.3 Nuh · 7.4 Ibrahim · 7.5 Musa · 7.6 Isa · 7.7 One Message · 7.8 The Final Messenger

**Unit 8 — The Life of Muhammad ﷺ** (shared). The Seerah is not reduced to a chronological list of battles.
8.1 Arabia Before the Message · 8.2 Muhammad Before Prophethood · 8.3 The First Revelation · 8.4 The First Muslims · 8.5 Opposition and Patience · 8.6 The Hijrah · 8.7 Building Madinah · 8.8 Major Turning Points · 8.9 The Character of Muhammad ﷺ · 8.10 The Final Years

**Unit 9 — Islam in Everyday Life** (shared).
9.1 Intention · 9.2 Honesty and Trust · 9.3 Parents and Family · 9.4 Neighbours and Society · 9.5 Food and Everyday Choices · 9.6 Money, Giving, and Responsibility · 9.7 Good Character · 9.8 What Happens When I Make a Mistake?

**Unit 10 — Beyond the Basics** (shared). It intentionally holds topics that would be epistemically premature early in the Explorer journey. Al-Isra' wal-Mi'raj is the clearest example: by this point the learner has met the framework of God, revelation, prophethood, the Qur'an, Muhammad ﷺ and the unseen.
10.1 Life as a Test · 10.2 The Seen and the Unseen · 10.3 Miracles · 10.4 Al-Isra' wal-Mi'raj · 10.5 Death and What Comes After · 10.6 Patience and Trust During Hardship · 10.7 Questions, Doubts, and Seeking Knowledge · 10.8 Scholars and Reliable Sources · 10.9 Building a Sustainable Journey · 10.10 Where Do You Go From Here?

## Responsibility boundaries

| Role | Decides |
|---|---|
| Curriculum (this document, curriculum team) | What should be learned and in what conceptual order: units, lesson slots, concepts |
| Curriculum Architect (factory stage `plan`, Gate 1) | The central learner question and primary outcome, the supporting understandings needed to make it complete, the depth profile, the primary lesson type, prerequisites, introduced concepts, standalone eligibility, required reasoning tools, the lesson arc with the techniques it actually needs (story? practice? prediction? evidence? which interactions are essential and which would only repeat?) and whether the whole experience fits the budget |
| Retrieve + Verify | Which factual and religious assertions can be used safely and accurately. AI never quotes Qur'an or hadith from memory; exact text is inserted by code from verified sources |
| Writer | Composes the one lesson: implements each approved arc step with existing blocks, develops each idea completely in simple words (simple language is not minimal information), may write short fictional teaching scenarios that assert nothing, and never appends parallel story or practice versions, invents curriculum or redefines the objective |
| Localizer | Produces each English variant from its Arabic variant without changing meaning |
| Exercise Designer | Tests the approved outcome along the arc's progression; may draft a larger candidate pool, of which only the strongest non-duplicated subset enters the lesson (the rest can feed flashcards, pretests, unit tests and challenges); never tests religious belief |
| QA + reviewers | Religious/factual correctness **and** pedagogical quality: understandable, short, interactive, coherent, non-mechanical and aligned with the approved arc |

## Reference lesson placement

The Flutter prototype's Salah lesson remains the binding UI/interaction reference (frontend Appendix A). Its frozen fixture identity is `les_u1_l3`/`unit_1`; in this curriculum it is the gold candidate for lesson 3.2 "Five Times a Day". Its size (14 steps, 6 scored exercises, about 7 minutes) is within the duration guidance; its scope (what Salah is, why Muslims pray, the five daily prayers) matches the introductory-Salah grouping in the illustration above, which spans the current slots 3.1 and 3.2. Whether it publishes at 3.2 as-is, is adapted, or the two slots are merged is product decision [P-07](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md) together with curriculum review [O-12](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md).
