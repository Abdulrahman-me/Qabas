# Qabas contract — revision 10 candidate

The **active canonical machine contract** for both teams, pending approval under [O-01](../../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md). Human-readable rules are in [API requirements](../API_REQUIREMENTS.md). Differences from the received revision 9, plus compatibility and migration notes, are in [CHANGES.md](CHANGES.md).

| Artifact | Use |
|---|---|
| [contract/qabas_contract.py](contract/qabas_contract.py) | Canonical Pydantic v2 request/response/event models; source for backend DTOs |
| [contract/qabas_contract.schema.json](contract/qabas_contract.schema.json) | 99 exported roots with typed tagged unions; source for OpenAPI components and Dart models |
| [contract/dispatch_map.json](contract/dispatch_map.json) | Discriminators, answer/details model per exercise type, context-only rules |
| [contract/contextual.py](contract/contextual.py) | Served-context validation, deterministic grading, six-decimal mastery, composition checks (unchanged from revision 9) |
| [contract/review.py](contract/review.py) | Reviewer gate digest (canonical JSON + SHA-256) |
| [contract/display_fields.py](contract/display_fields.py) | Stored glossary → `TermCard` projection (unchanged) |
| [contract/scene.schema.json](contract/scene.schema.json), [scene_capabilities.production.json](contract/scene_capabilities.production.json), [scene_capabilities.json](contract/scene_capabilities.json) | Scene manifest grammar, production (nothing released) and simulation registries (unchanged); runtime meaning in [scene renderer semantics](../../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md) |
| [contract/exercise_art_registry.json](contract/exercise_art_registry.json), [registries.template.json](contract/registries.template.json) | Compiled category art; template for the production registries still to be completed |
| [fixtures/](fixtures/MANIFEST.json) | 392 model fixtures, coverage matrix, roles and private evaluation context (unchanged; private files stay out of learner bundles) |
| [tools/](tools/) | `validate.py` (examples + fixtures + semantics + negatives, writes report/checksums/schema), `regression.py` (615 checks), `rev10_checks.py` (170 checks), `export_schema.py`, `scene_check.py`, `recovery.py`, fixture generators |
| [VALIDATION_REPORT.md](VALIDATION_REPORT.md), [REGRESSION_REPORT.json](REGRESSION_REPORT.json), [REV10_CHECKS.json](REV10_CHECKS.json), [SHA256SUMS](SHA256SUMS) | Results of the last run and the folder identity (`SHA256SUMS` excludes itself and `VALIDATION_REPORT.md`) |

## Reproduce

Work in a disposable copy of this folder together with its sibling `../API_REQUIREMENTS.md`, because `validate.py` rewrites the schema, reports and checksums:

```sh
PKG=$(pwd)                       # run from the package root
work=$(mktemp -d) && mkdir "$work/03_API"
cp -R 03_API/contract_revision10 03_API/API_REQUIREMENTS.md "$work/03_API/"
python3 -m venv "$work/.venv"
"$work/.venv/bin/python" -m pip install -r "$PKG/10_REFERENCE/engineer_delivery/reply8/requirements.lock.txt"
cd "$work/03_API/contract_revision10"
PYTHONDONTWRITEBYTECODE=1 "$work/.venv/bin/python" tools/regression.py
PYTHONDONTWRITEBYTECODE=1 "$work/.venv/bin/python" tools/rev10_checks.py
PYTHONDONTWRITEBYTECODE=1 "$work/.venv/bin/python" tools/validate.py
```

The received lock file pins Pydantic 2.12.5, jsonschema 4.25.1 and Pillow 12.0.0. Expected: 615/615, 170/170, then 105/105 examples, 392/392 fixtures and `Result: PASS`. A changed schema digest after a rerun means the models changed. Record the new digest in `PACKAGE_METADATA.json` and the approval record.

Production CI must run these checks with Python 3.12 (the service runtime) as well; that run has not been performed yet.
