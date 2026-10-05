"""Reviewer console and Gate 2 (Phase 13): the API surface, digest binding, approval = publication of exactly the
reviewed draft, blockers that keep a draft unpublishable, request_changes / reject, races and replays, version
pinning for learners, and the shared approval rule of factory and gold content.

Real factory drafts carry placeholder media until Phase 14, so a successful publication here first applies
``install_media``: a test-only stand-in for the Phase 14 media stages (audited https images in place of the
placeholders, a new draft, a new digest). Without it the same draft is refused, as production would refuse it.
"""

from __future__ import annotations

import asyncio
import copy
import json
import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text
from sqlalchemy.exc import DBAPIError, IntegrityError

from app.api import admin_factory
from app.config import Settings
from app.content.package import LessonPackage
from app.content.store import Approval, FixtureApproval, publish
from app.content.validation import ContentValidationError
from app.contract import models as C
from app.errors import ApiError
from app.factory.gate2 import ScriptureAuthority, decide_gate2
from app.factory.orchestrator import gate_digest
from app.models import FactoryRun, Lesson, LessonVersion, ReviewDecision, SentenceRecord, Source
from app.runtime import Resources
from tests.factory import pipeline_support as P
from tests.factory.support import SLOT, drive, reviewer
from tests.factory.test_pipeline import Harness, harness, sequence
from tests.learning.conftest import learner, user_id

pytestmark = pytest.mark.integration
CDN = "https://cdn.qabas.app/media/"
PASSWORD = "a long passphrase"


@pytest.fixture
def console(fresh_curriculum: tuple[TestClient, Settings]) -> Iterator[tuple[TestClient, Settings]]:
    yield fresh_curriculum
    fresh_curriculum[0].app.dependency_overrides.clear()  # type: ignore[attr-defined]


@pytest.fixture
async def resources(console: tuple[TestClient, Settings]) -> Any:
    created = Resources.create(console[1])
    yield created
    await created.close()


def wire(client: TestClient, h: Harness, tmp_path: Path) -> None:
    """The console uses the test's dispatcher and the synthetic scripture authority (never the real mushaf)."""
    overrides = client.app.dependency_overrides  # type: ignore[attr-defined]
    overrides[admin_factory.get_dispatcher] = lambda: h.dispatcher
    overrides[admin_factory.get_scripture_authority] = lambda: authority(tmp_path)


def authority(tmp_path: Path) -> ScriptureAuthority:
    return ScriptureAuthority(mushaf=P.synthetic.mushaf(), translations=P.manifest(tmp_path))


def login(client: TestClient, email: str = "usr_factory_reviewer@example.test") -> dict[str, str]:
    response = client.post("/v1/auth/reviewer", json={"email": email, "password": PASSWORD})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def install_media(resources: Resources, run_id: str) -> str:
    """TEST ONLY — stands in for the Phase 14 media stages: the draft's placeholder images become audited https
    images, which is a new draft with a new review digest (exactly what a regeneration produces)."""
    async with resources.sessionmaker() as db, db.begin():
        run = await db.get(FactoryRun, run_id, with_for_update=True)
        assert run is not None and run.status == "awaiting_gate2"
        artifacts = copy.deepcopy(run.artifacts)
        output = artifacts["qa"]["output"]
        output["package"] = json.loads(json.dumps(output["package"]).replace("mock-asset://factory/", CDN))
        output["package_digest"] = LessonPackage.model_validate(output["package"]).digest()
        output["draft"] = json.loads(json.dumps(output["draft"]).replace("mock-asset://factory/", CDN))
        for visual in output["draft"]["visuals"]:
            visual.update(audit={"passed": True, "issues": []}, attempts=1)
        run.artifacts = artifacts
        run.qa_report = {"issues": [i for i in run.qa_report["issues"] if i["kind"] != "validation"]}
        run.review_digest = gate_digest("awaiting_gate2", run)
        return run.review_digest


def gate2(client: TestClient, headers: dict[str, str], run_id: str, digest: str, decision: str = "approve",
          **fields: Any) -> Any:
    body = {"decision": decision, "sentence_edits": [], "exercise_removals": [], "reason": None,
            "review_digest": digest} | fields
    return client.post(f"/v1/admin/factory/runs/{run_id}/gate2", json=body, headers=headers)


async def complete(resources: Resources, uid: str, lesson_id: str) -> None:
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("INSERT INTO learner_lessons (user_id, lesson_id, completed_at) VALUES (:u, :l, now())"),
                         {"u": uid, "l": lesson_id})


async def counts(resources: Resources, run_id: str) -> tuple[int, int]:
    async with resources.sessionmaker() as db:
        decisions = await db.scalar(select(func.count()).select_from(ReviewDecision).where(
            ReviewDecision.run_id == run_id, ReviewDecision.gate == 2))
        versions = await db.scalar(select(func.count()).select_from(LessonVersion).where(
            LessonVersion.lesson_id == SLOT))
        return int(decisions or 0), int(versions or 0)


# ------------------------------------------------------------------------------------------- the API surface

async def test_every_console_route_needs_an_active_reviewer(console: tuple[TestClient, Settings],
                                                           resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    assert client.get("/v1/admin/factory/runs").status_code == 401
    learner_headers = learner(client)
    for method, path in (("GET", "/v1/admin/factory/runs"), ("GET", "/v1/admin/factory/runs/run_x"),
                         ("POST", "/v1/admin/factory/runs/run_x/gate2")):
        response = client.request(method, path, headers=learner_headers, json={})
        assert response.status_code == 403 and response.json()["error"]["code"] == "forbidden"


async def test_runs_are_created_listed_and_read_as_contract_shapes(console: tuple[TestClient, Settings],
                                                                    resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    await reviewer(resources)
    headers = login(client)
    body = {"unit_id": "unit_test_2", "lesson_type": "concept", "brief": "Plan this slot.", "position_index": 1}
    key = str(uuid.uuid4())
    first = client.post("/v1/admin/factory/runs", json=body, headers=headers | {"Idempotency-Key": key})
    again = client.post("/v1/admin/factory/runs", json=body, headers=headers | {"Idempotency-Key": key})
    assert first.status_code == again.status_code == 201 and first.json() == again.json()
    run = C.FactoryRun.model_validate(first.json())
    assert (run.status, run.stage, run.review_digest, run.draft) == ("running", "plan", None, None)
    assert h.dispatcher.queue == [(run.run_id, "plan", 1)]                    # one run, one dispatch
    conflict = client.post("/v1/admin/factory/runs", json=body | {"brief": "Other."},
                           headers=headers | {"Idempotency-Key": key})
    assert conflict.status_code == 409 and conflict.json()["error"]["code"] == "idempotency_conflict"
    assert client.post("/v1/admin/factory/runs", json=body | {"position_index": 40},
                       headers=headers).status_code == 400
    await drive(h.orchestrator, h.dispatcher)
    page = client.get("/v1/admin/factory/runs?status=awaiting_gate1", headers=headers | {"Accept-Language": "en"})
    assert page.status_code == 200
    rows = C.EXPORTED["RunPage"].model_validate(page.json()).items
    assert [(r.run_id, r.title) for r in rows] == [(run.run_id, "Synthetic title")]
    current = client.get(f"/v1/admin/factory/runs/{run.run_id}", headers=headers).json()
    assert current["status"] == "awaiting_gate1" and len(current["review_digest"]) == 64
    decided = client.post(f"/v1/admin/factory/runs/{run.run_id}/gate1", headers=headers,
                          json={"decision": "approve", "plan": None, "reason": None,
                                "review_digest": current["review_digest"]})
    assert decided.status_code == 200 and decided.json()["stage"] == "decompose"
    replay = client.post(f"/v1/admin/factory/runs/{run.run_id}/gate1", headers=headers,
                         json={"decision": "approve", "plan": None, "reason": None,
                               "review_digest": current["review_digest"]})
    assert replay.status_code == 409 and replay.json()["error"]["code"] == "run_not_at_gate"


async def test_the_review_digest_is_the_contract_digest(resources: Resources, tmp_path: Path) -> None:
    from app.contract import review
    from app.factory.runs import to_contract
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    run = await h.load(run_id)
    projected = to_contract(run)
    assert run.review_digest == review.review_digest(projected)               # API §6.11: contract review.py


# ------------------------------------------------------------------------------------------- approval

async def test_a_draft_with_placeholder_media_is_never_approved(console: tuple[TestClient, Settings],
                                                                resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    before = await h.load(run_id)
    response = gate2(client, login(client), run_id, before.review_digest)
    assert response.status_code == 400 and response.json()["error"]["code"] == "validation_error"
    issues = response.json()["error"]["details"]["issues"]
    assert all(i["severity"] == "blocker" for i in issues)
    assert any("placeholder" in i["message"] for i in issues)
    assert {i["location"]["scene_id"] for i in issues if "readiness" in i["message"]} == {
        "b_hook", "b_story.beat1", "b_story.beat2"}
    after = await h.load(run_id)
    assert (after.status, after.review_digest) == ("awaiting_gate2", before.review_digest)
    assert await counts(resources, run_id) == (0, 1)        # no decision, no new version (only the fixture's v1)


async def test_approval_publishes_exactly_the_reviewed_draft(console: tuple[TestClient, Settings],
                                                             resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = await install_media(resources, run_id)
    # A learner already inside the current (v1) lesson stays on it.
    early = learner(client)
    await complete(resources, user_id(client, early), "les_t2_0")
    pinned = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": SLOT}, headers=early)
    assert pinned.status_code == 201, pinned.text
    headers = login(client)
    viewed = client.get(f"/v1/admin/factory/runs/{run_id}", headers=headers).json()
    assert viewed["review_digest"] == digest and (await h.load(run_id)).review_started_at is not None
    edits = [{"sentence_id": "s_t1", "language": "ar", "variant": "explorer", "new_text": "جملة مراجعة"},
             {"sentence_id": "s_t1", "language": "en", "variant": "explorer", "new_text": "A reviewed sentence."}]
    response = gate2(client, headers, run_id, digest, sentence_edits=edits)
    assert response.status_code == 200, response.text
    run = C.FactoryRun.model_validate(response.json())
    assert run.status == "published" and run.review_digest is None
    assert run.published is not None and (run.published.lesson_id, run.published.version) == (SLOT, 2)
    async with resources.sessionmaker() as db:
        version = (await db.execute(select(LessonVersion).where(LessonVersion.lesson_id == SLOT,
                                                                LessonVersion.version == 2))).scalar_one()
        decision = (await db.execute(select(ReviewDecision).where(ReviewDecision.run_id == run_id,
                                                                  ReviewDecision.gate == 2))).scalar_one()
        assert (version.origin, version.run_id, version.published_at is not None) == ("factory", run_id, True)
        assert decision.lesson_version_id == version.id and decision.reviewed_digest == digest
        assert decision.published_digest == version.content_sha256 and decision.decision == "approve"
        assert decision.edits["sentence_edits"][0]["before"] == "جملة تجريبية تدعمها الأدلة"
        lesson = await db.get(Lesson, SLOT)
        assert lesson is not None and lesson.current_version == 2 and lesson.is_gold is False
        edited = {(s.lang, s.variant) for s in (await db.execute(select(SentenceRecord).where(
            SentenceRecord.lesson_version_id == version.id, SentenceRecord.edited_by_reviewer))).scalars()}
        assert edited == {("ar", "explorer"), ("en", "explorer")}
        # Every cited source is stored once, with the provenance (raw request/response) it was verified from.
        package = LessonPackage.model_validate((await h.load(run_id)).artifacts["qa"]["output"]["package"])
        for cited in package.sources:
            row = await db.get(Source, cited.source_id)
            assert row is not None and row.raw["schema"] == "qabas.source_raw/1"
    # Learners: the pinned session is untouched; a new one gets v2 with the edit and without any key.
    assert client.get(f"/v1/sessions/{pinned.json()['session_id']}", headers=early).json() == pinned.json()
    late = learner(client)
    await complete(resources, user_id(client, late), "les_t2_0")
    fresh = client.post("/v1/sessions", json={"kind": "lesson", "lesson_id": SLOT}, headers=late).json()
    assert fresh["lesson_version"] == 2 and "جملة مراجعة" in json.dumps(fresh, ensure_ascii=False)
    assert "answer_key" not in json.dumps(fresh) and "option_misconceptions" not in json.dumps(fresh)
    # The published factory version is immutable like any other (database triggers, Phase 1).
    async with resources.sessionmaker() as db:
        with pytest.raises(DBAPIError):
            async with db.begin():
                await db.execute(text("UPDATE lesson_versions SET plan = '{}'::jsonb WHERE run_id = :r"),
                                 {"r": run_id})
    # A double click or a network retry after success changes nothing.
    replay = gate2(client, headers, run_id, digest, sentence_edits=edits)
    assert replay.status_code == 409 and replay.json()["error"]["code"] == "run_not_at_gate"
    assert await counts(resources, run_id) == (1, 2)


async def test_a_stale_digest_never_authorizes_a_changed_draft(console: tuple[TestClient, Settings],
                                                               resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    seen = (await h.load(run_id)).review_digest
    await install_media(resources, run_id)                    # the draft changed after the reviewer loaded it
    response = gate2(client, login(client), run_id, seen)
    assert response.status_code == 409 and response.json()["error"]["code"] == "review_stale"
    assert await counts(resources, run_id) == (0, 1)


async def test_model_blockers_clear_only_by_editing_what_they_flag(console: tuple[TestClient, Settings],
                                                                   resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    flagged = {"issues": [{"severity": "blocker", "kind": "unsupported_sentence", "sentence_id": "s_t2",
                           "exercise_id": None, "message": "asserts more than c2"}]}
    h = harness(resources, tmp_path, factory_qa=flagged)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = await install_media(resources, run_id)
    headers = login(client)
    english_only = [{"sentence_id": "s_t2", "language": "en", "variant": "explorer", "new_text": "Polished."}]
    blocked = gate2(client, headers, run_id, digest, sentence_edits=english_only)
    assert blocked.status_code == 400
    assert [i["kind"] for i in blocked.json()["error"]["details"]["issues"]] == ["unsupported_sentence"]
    unpaired = gate2(client, headers, run_id, digest, sentence_edits=[
        {"sentence_id": "s_t2", "language": "ar", "variant": "explorer", "new_text": "جملة"}])
    assert unpaired.status_code == 400                         # an Arabic edit needs its English localization
    edits = [{"sentence_id": "s_t2", "language": lang, "variant": variant, "new_text": text}
             for variant in ("explorer", "new_muslim")
             for lang, text in (("ar", f"جملة أضيق عن {P.TERM_AR}"), ("en", "A narrower sentence."))]
    published = gate2(client, headers, run_id, digest, sentence_edits=edits)
    assert published.status_code == 200, published.text
    # The edited Arabic sentence keeps its term link (deterministic linker on edited text).
    async with resources.sessionmaker() as db:
        version = (await db.execute(select(LessonVersion).where(LessonVersion.run_id == run_id))).scalar_one()
        blocks = version.content["variants"]["ar"]["explorer"]["blocks"]
        point = next(b for b in blocks if b["block_id"] == "b_teach")["points"][1]["sentence"]
        assert [s["type"] for s in point["spans"]] == ["text", "term"]


async def test_removals_and_edits_rerun_every_validator(console: tuple[TestClient, Settings],
                                                        resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = await install_media(resources, run_id)
    package = (await h.load(run_id)).artifacts["qa"]["output"]["package"]
    pretest = next(e["exercise_id"] for e in package["exercises"] if e["purpose"] == "pretest")
    headers = login(client)
    response = gate2(client, headers, run_id, digest, exercise_removals=[pretest])
    assert response.status_code == 400
    assert any("pretest" in i["message"] for i in response.json()["error"]["details"]["issues"])
    unknown = gate2(client, headers, run_id, digest, exercise_removals=["ex_nope"],
                    sentence_edits=[{"sentence_id": "s_nope", "language": "en", "variant": "explorer",
                                     "new_text": "x"}])
    assert unknown.status_code == 400 and len(unknown.json()["error"]["details"]["issues"]) == 2
    assert await counts(resources, run_id) == (0, 1)


async def test_a_failure_inside_publication_rolls_everything_back(console: tuple[TestClient, Settings],
                                                                  resources: Resources, tmp_path: Path,
                                                                  monkeypatch: pytest.MonkeyPatch) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = await install_media(resources, run_id)
    from app.content import store

    async def crash(db: Any) -> dict[str, bool]:
        raise RuntimeError("storage outage after the lesson rows were written")

    async with resources.sessionmaker() as db:
        sources_before = await db.scalar(select(func.count()).select_from(Source))
    monkeypatch.setattr(store, "refresh_unit_availability", crash)
    response = gate2(client, login(client), run_id, digest)
    assert response.status_code == 500
    run = await h.load(run_id)
    assert (run.status, run.review_digest) == ("awaiting_gate2", digest)
    assert await counts(resources, run_id) == (0, 1)
    async with resources.sessionmaker() as db:
        lesson = await db.get(Lesson, SLOT)
        assert lesson is not None and lesson.current_version == 1
        assert await db.scalar(select(func.count()).select_from(Source)) == sources_before
    monkeypatch.undo()
    assert gate2(client, login(client), run_id, digest).status_code == 200   # the same decision then succeeds


# ------------------------------------------------------------------------------------------- other decisions

async def test_request_changes_regenerates_from_write_with_the_reason(console: tuple[TestClient, Settings],
                                                                      resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    def revised(data: dict[str, Any]) -> dict[str, Any]:
        draft = P.write(data)
        for variant in draft["variants"]:
            variant["blocks"][0]["situation"] = "موقف أقصر"
        return draft

    writer = sequence(P.write, revised)
    h = harness(resources, tmp_path, factory_write=writer)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    first = (await h.load(run_id)).review_digest
    headers = login(client)
    missing = gate2(client, headers, run_id, first, decision="request_changes")
    assert missing.status_code == 400                          # request_changes needs a reason
    sent = gate2(client, headers, run_id, first, decision="request_changes", reason="Shorten the hook.")
    assert sent.status_code == 200 and sent.json()["status"] == "running" and sent.json()["stage"] == "write"
    assert sent.json()["draft"] is None and sent.json()["qa_report"] is None
    assert h.dispatcher.queue == [(run_id, "write", 1)]
    outcomes = await drive(h.orchestrator, h.dispatcher)
    assert outcomes[-1] == "gate"
    run = await h.load(run_id)
    assert run.status == "awaiting_gate2" and run.review_digest is not None
    assert writer.seen[-1]["reviewer_change_requests"] == ["Shorten the hook."]
    revision = run.artifacts["revisions"][0]
    assert revision["reviewed_digest"] == first and revision["artifacts"]["qa"]["output"]["draft"]
    stale = gate2(client, headers, run_id, first)
    assert stale.status_code == 409 and stale.json()["error"]["code"] == "review_stale"
    async with resources.sessionmaker() as db:
        rows = list((await db.execute(select(ReviewDecision.decision).where(ReviewDecision.run_id == run_id,
                                                                            ReviewDecision.gate == 2))).scalars())
        assert rows == ["request_changes"]


async def test_reject_is_final_and_recorded_once(console: tuple[TestClient, Settings], resources: Resources,
                                                 tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = (await h.load(run_id)).review_digest
    headers = login(client)
    rejected = gate2(client, headers, run_id, digest, decision="reject", reason="Off-outcome.")
    assert rejected.status_code == 200 and rejected.json()["status"] == "rejected"
    assert gate2(client, headers, run_id, digest).json()["error"]["code"] == "run_not_at_gate"
    async with resources.sessionmaker() as db:
        db.add(ReviewDecision(run_id=run_id, gate=2, decision="approve", reviewer_id="usr_factory_reviewer",
                              reviewed_digest=digest, published_digest=digest))
        with pytest.raises(IntegrityError):                    # the database refuses a second final decision
            await db.commit()


async def test_simultaneous_approve_and_reject_have_one_winner(resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = await install_media(resources, run_id)
    await reviewer(resources, user_id="usr_second_reviewer")

    async def decide(decision: str, who: str) -> str:
        body = C.Gate2(decision=decision, sentence_edits=[], exercise_removals=[], reason="race",  # type: ignore[arg-type]
                       review_digest=digest)
        try:
            result = await decide_gate2(resources.sessionmaker, resources.settings, h.dispatcher, run_id=run_id,
                                        reviewer_id=who, body=body, authority=authority(tmp_path))
            return str(result["status"])
        except ApiError as exc:
            return exc.code.value

    outcomes = await asyncio.gather(decide("approve", "usr_factory_reviewer"), decide("reject", "usr_second_reviewer"),
                                    decide("approve", "usr_second_reviewer"))
    assert sorted(outcomes).count("run_not_at_gate") == 2
    winner = next(o for o in outcomes if o != "run_not_at_gate")
    assert winner in ("published", "rejected")
    async with resources.sessionmaker() as db:
        final = list((await db.execute(select(ReviewDecision).where(ReviewDecision.run_id == run_id,
                                                                    ReviewDecision.gate == 2))).scalars())
        assert len(final) == 1
        published = await db.scalar(select(func.count()).select_from(LessonVersion).where(
            LessonVersion.lesson_id == SLOT, LessonVersion.published_at.is_not(None)))
        assert published == (2 if winner == "published" else 1)


async def test_an_inactive_reviewer_cannot_decide(resources: Resources, tmp_path: Path) -> None:
    h = harness(resources, tmp_path)
    run_id, _ = await h.to_gate2()
    await reviewer(resources, user_id="usr_gone_reviewer", active=False)
    body = C.Gate2(decision="reject", sentence_edits=[], exercise_removals=[], reason=None,
                   review_digest=(await h.load(run_id)).review_digest)
    with pytest.raises(ApiError) as error:
        await decide_gate2(resources.sessionmaker, resources.settings, h.dispatcher, run_id=run_id,
                           reviewer_id="usr_gone_reviewer", body=body)
    assert error.value.code.value == "forbidden"


# ------------------------------------------------------------------------------------------- one approval path

async def test_an_approval_authorizes_only_its_own_version_and_origin(console: tuple[TestClient, Settings],
                                                                      resources: Resources, tmp_path: Path) -> None:
    client, _ = console
    h = harness(resources, tmp_path)
    wire(client, h, tmp_path)
    run_id, _ = await h.to_gate2()
    digest = await install_media(resources, run_id)
    assert gate2(client, login(client), run_id, digest).status_code == 200
    async with resources.sessionmaker() as db:
        decision = (await db.execute(select(ReviewDecision).where(ReviewDecision.run_id == run_id,
                                                                  ReviewDecision.gate == 2))).scalar_one()
        package = LessonPackage.model_validate((await h.load(run_id)).artifacts["qa"]["output"]["package"])
    # A gold import of the same slot (new content -> v3) is not authorized by the factory decision, and test-fixture
    # allowances never apply to reviewed origins.
    data = package.model_dump(mode="json")
    data["variants"]["ar"]["explorer"]["title"] += " (gold)"
    from app.content.store import import_package
    async with resources.sessionmaker() as db, db.begin():
        gold = await import_package(db, LessonPackage.model_validate(data), origin="gold_import")
    for approval in (Approval(decision.id), FixtureApproval()):
        async with resources.sessionmaker() as db:
            with pytest.raises(ContentValidationError):
                async with db.begin():
                    await publish(db, resources.settings, gold.lesson_version_id, approval)
