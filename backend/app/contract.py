"""Access point for the vendored revision 10 contract (``backend/contract/03_API/contract_revision10``).

The contract modules import each other as top-level modules (``import qabas_contract as C``)
and must stay byte-identical to the handoff, so their directory is put on ``sys.path`` here
instead of being repackaged. Every other module imports the contract through this one.
"""

from __future__ import annotations

import json
import sys
from functools import cache
from pathlib import Path
from typing import Any

VENDOR_ROOT = Path(__file__).resolve().parents[1] / "contract"
CONTRACT_ROOT = VENDOR_ROOT / "03_API" / "contract_revision10"
CONTRACT_DIR = CONTRACT_ROOT / "contract"
TOOLS_DIR = CONTRACT_ROOT / "tools"
FIXTURES_DIR = CONTRACT_ROOT / "fixtures"
SCHEMA_PATH = CONTRACT_DIR / "qabas_contract.schema.json"

CONTRACT_REVISION = 10

if str(CONTRACT_DIR) not in sys.path:
    sys.path.insert(0, str(CONTRACT_DIR))

import qabas_contract as models  # noqa: E402

__all__ = ["CONTRACT_REVISION", "SCHEMA_PATH", "exported_schema", "models"]


@cache
def exported_schema() -> dict[str, Any]:
    """The custom-exported schema: root name -> standalone JSON Schema (99 roots)."""
    data: dict[str, Any] = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    return data
