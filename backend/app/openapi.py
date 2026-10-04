"""OpenAPI document whose components come only from the contract's custom export.

FastAPI's own schema generation is used for *paths* only. Its generated component schemas
(generic dictionaries for tagged unions) are discarded and replaced with the 99-root custom
export (AD-16), flattened into ``components/schemas``. Building fails if a route references a
schema that the contract doesn't define, so no hand-written public DTO can reach the document.
"""

from __future__ import annotations

import copy
from typing import Any

from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

from app.contract import CONTRACT_REVISION, exported_schema

DEFS_PREFIX = "#/$defs/"
COMPONENTS_PREFIX = "#/components/schemas/"


class ContractSchemaError(RuntimeError):
    pass


def _rewrite_refs(node: Any) -> Any:
    if isinstance(node, dict):
        out: dict[str, Any] = {}
        for key, value in node.items():
            if key == "$schema":
                continue
            if key == "$ref" and isinstance(value, str) and value.startswith(DEFS_PREFIX):
                out[key] = COMPONENTS_PREFIX + value[len(DEFS_PREFIX):]
            elif key == "mapping" and isinstance(value, dict):
                out[key] = {k: COMPONENTS_PREFIX + v[len(DEFS_PREFIX):] if v.startswith(DEFS_PREFIX) else v
                            for k, v in value.items()}
            else:
                out[key] = _rewrite_refs(value)
        return out
    if isinstance(node, list):
        return [_rewrite_refs(v) for v in node]
    return node


def contract_components() -> dict[str, Any]:
    """Flatten every root and its ``$defs`` into one component map.

    A name defined differently by two roots is an error, except the four tagged-union bases,
    whose root copy only adds a ``title``; the root copy wins.
    """
    roots = exported_schema()
    merged: dict[str, Any] = {}
    for name, root in roots.items():
        for def_name, definition in root.get("$defs", {}).items():
            if def_name in roots:
                continue  # roots are taken from their own top-level schema below
            if def_name in merged and merged[def_name] != definition:
                raise ContractSchemaError(f"conflicting definitions for {def_name}")
            merged.setdefault(def_name, definition)
        body = {k: v for k, v in root.items() if k not in ("$defs", "$schema")}
        merged[name] = body
    for name, root in roots.items():
        for def_name, definition in root.get("$defs", {}).items():
            if def_name in roots and def_name != name:
                strip = {k: v for k, v in merged[def_name].items() if k != "title"}
                other = {k: v for k, v in definition.items() if k != "title"}
                if strip != other:
                    raise ContractSchemaError(f"root {def_name} differs from its copy inside {name}")
    return _rewrite_refs(copy.deepcopy(merged))  # type: ignore[no-any-return]


def _collect_refs(node: Any, found: set[str]) -> None:
    if isinstance(node, dict):
        ref = node.get("$ref")
        if isinstance(ref, str) and ref.startswith(COMPONENTS_PREFIX):
            found.add(ref[len(COMPONENTS_PREFIX):])
        for value in node.values():
            _collect_refs(value, found)
    elif isinstance(node, list):
        for value in node:
            _collect_refs(value, found)


ERROR_RESPONSE = {
    "description": "Error envelope (API §3.4)",
    "content": {"application/json": {"schema": {"$ref": COMPONENTS_PREFIX + "ErrorEnvelope"}}},
}


def build_openapi(app: FastAPI) -> dict[str, Any]:
    generated = get_openapi(title=app.title, version=app.version, routes=app.routes,
                            description=app.description, separate_input_output_schemas=False)
    components = contract_components()
    paths: dict[str, Any] = generated.get("paths", {})
    for operations in paths.values():
        for operation in operations.values():
            responses = operation.setdefault("responses", {})
            responses.pop("422", None)  # validation failures are 400 envelopes
            responses["default"] = ERROR_RESPONSE
            operation.setdefault("security", [{"bearer": []}])
    referenced: set[str] = set()
    _collect_refs(paths, referenced)
    unknown = sorted(referenced - components.keys())
    if unknown:
        raise ContractSchemaError(f"routes reference schemas outside the contract: {unknown}")
    return {
        "openapi": "3.1.0",
        "info": {**generated["info"], "x-qabas-contract": CONTRACT_REVISION},
        "servers": [{"url": "/"}],
        "paths": paths,
        "components": {
            "schemas": components,
            "securitySchemes": {"bearer": {"type": "http", "scheme": "bearer"}},
        },
    }


def install_openapi(app: FastAPI) -> None:
    def _openapi() -> dict[str, Any]:
        if app.openapi_schema is None:
            app.openapi_schema = build_openapi(app)
        return app.openapi_schema

    app.openapi = _openapi  # type: ignore[method-assign]
