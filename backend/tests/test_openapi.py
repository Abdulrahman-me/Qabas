"""The served OpenAPI document uses only the contract's custom-exported schemas (AD-16)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from fastapi import APIRouter, FastAPI
from fastapi.testclient import TestClient
from pydantic import BaseModel

from app.contract import exported_schema, models
from app.openapi import COMPONENTS_PREFIX, ContractSchemaError, build_openapi, contract_components

DOCS_OPENAPI = Path(__file__).resolve().parents[1] / "docs" / "openapi.json"


def _refs(node: Any) -> set[str]:
    found: set[str] = set()
    stack = [node]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            ref = item.get("$ref")
            if isinstance(ref, str):
                found.add(ref)
            stack.extend(item.values())
        elif isinstance(item, list):
            stack.extend(item)
    return found


def test_components_contain_every_root_and_resolve() -> None:
    components = contract_components()
    assert set(exported_schema()) <= set(components)
    for ref in _refs(components):
        assert ref.startswith(COMPONENTS_PREFIX), ref
        assert ref[len(COMPONENTS_PREFIX):] in components, ref


def test_components_equal_contract_roots() -> None:
    """Each root, with refs rewritten, is exactly the custom export (title aside for tagged bases)."""
    components = contract_components()
    for name, root in exported_schema().items():
        expected = json.loads(json.dumps({k: v for k, v in root.items() if k not in ("$defs", "$schema")})
                              .replace('"#/$defs/', f'"{COMPONENTS_PREFIX}'))
        assert components[name] == expected, name


def test_tagged_unions_keep_discriminators() -> None:
    components = contract_components()
    for base in ("Exercise", "ReviewerExercise", "WsEvent", "WsClientMessage"):
        schema = components[base]
        assert schema["discriminator"]["propertyName"] == "type"
        for target in schema["discriminator"]["mapping"].values():
            assert target.startswith(COMPONENTS_PREFIX)


def test_served_document_has_no_fastapi_generated_schemas(client: TestClient) -> None:
    document = client.get("/openapi.json").json()
    assert document["openapi"] == "3.1.0"
    schemas = document["components"]["schemas"]
    assert "HTTPValidationError" not in schemas
    assert "ValidationError" not in schemas
    assert schemas == contract_components()


def test_routes_using_contract_models_are_accepted() -> None:
    app = FastAPI()
    router = APIRouter(prefix="/v1")

    @router.get("/probe", response_model=models.ErrorEnvelope)
    def probe() -> Any:
        raise NotImplementedError

    app.include_router(router)
    document = build_openapi(app)
    operation = document["paths"]["/v1/probe"]["get"]
    assert "422" not in operation["responses"]
    assert operation["responses"]["default"]["content"]["application/json"]["schema"]["$ref"].endswith(
        "/ErrorEnvelope")


def test_routes_with_hand_written_models_are_rejected() -> None:
    class HandWritten(BaseModel):
        value: int

    app = FastAPI()

    @app.get("/v1/bad", response_model=HandWritten)
    def bad() -> Any:
        raise NotImplementedError

    with pytest.raises(ContractSchemaError, match="HandWritten"):
        build_openapi(app)


def test_exported_docs_openapi_is_current(app: FastAPI) -> None:
    rendered = json.dumps(app.openapi(), indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    assert DOCS_OPENAPI.read_text(encoding="utf-8") == rendered, "run scripts/export_openapi.py"
