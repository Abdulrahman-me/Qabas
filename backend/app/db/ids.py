"""Opaque identifiers (API §3.3): ``<prefix>_<26 chars>``.

The suffix is a ULID-style value: a 48-bit millisecond timestamp followed by 80 random bits, in
Crockford base32. That keeps new rows roughly time-ordered (good B-tree locality) while staying
unguessable. Clients must never parse IDs.
"""

from __future__ import annotations

import secrets
import time

CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
PREFIXES = frozenset({
    "usr", "unit", "les", "blk", "ex", "con", "term", "mis", "src", "ses", "conv", "msg", "att",
    "rchk", "duel", "run", "pair", "sen", "clm", "scn", "inv",
})


def _encode(value: int, length: int) -> str:
    chars = []
    for _ in range(length):
        value, rem = divmod(value, 32)
        chars.append(CROCKFORD[rem])
    return "".join(reversed(chars))


def new_id(prefix: str, *, now_ms: int | None = None) -> str:
    if prefix not in PREFIXES:
        raise ValueError(f"unknown id prefix: {prefix!r}")
    timestamp = now_ms if now_ms is not None else time.time_ns() // 1_000_000
    return f"{prefix}_{_encode(timestamp & (2**48 - 1), 10)}{_encode(secrets.randbits(80), 16)}"
