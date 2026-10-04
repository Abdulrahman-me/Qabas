"""Record provider responses for the offline adapter tests (Phase 9: CI never calls a provider).

    uv run python scripts/record_sources.py [--provider NAME ...] [--system-ca] [--dorar URL]

Each named request below is sent once to the live provider and saved verbatim (status, content type, parsed body)
under ``tests/sources/recordings/<provider>/<name>.json`` with the URL it came from and the recording date. The
tests replay them through an in-memory transport. Dorar is recorded through a locally running sidecar
(``--dorar``, see scripts/install_dorar_sidecar.py). The IslamHouse key is read from ISLAMHOUSE_API_KEY and is
replaced by ``{key}`` in what is saved. Providers that need credentials (Quran Foundation's OAuth API, the Tafsir
Center MCP server) are recorded only where a public endpoint with the same schema exists; everything else is
covered by documented-shape fixtures written by the tests themselves, and the live gate stays closed (O-03).
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx

RECORDINGS = Path(__file__).resolve().parents[1] / "tests" / "sources" / "recordings"
QURAN_VERSE = {"words": "true", "word_fields": "text_qpc_hafs", "fields": "text_qpc_hafs", "audio": "7"}

# provider -> (base URL, [(name, path, query)])
REQUESTS: dict[str, tuple[str, list[tuple[str, str, dict[str, str]]]]] = {
    # The public Quran.com v4 API serves the same Content API v4 schema as Quran Foundation's OAuth endpoint.
    "quran_com": ("https://api.quran.com/api/v4", [
        ("verse_4_103", "/verses/by_key/4:103", QURAN_VERSE),
        ("verse_112_1", "/verses/by_key/112:1", QURAN_VERSE),
        ("recitations_ar", "/resources/recitations", {"language": "ar"}),
        ("search_aqimu", "/search", {"q": "أقيموا الصلاة", "size": "5", "language": "ar"}),
    ]),
    "quranenc": ("https://quranenc.com/api/v1", [
        ("translations_en", "/translations/list/en", {}),
        ("aya_english_saheeh_4_103", "/translation/aya/english_saheeh/4/103", {}),
        ("aya_english_rwwad_112_1", "/translation/aya/english_rwwad/112/1", {}),
        ("aya_unknown_key", "/translation/aya/english_unknown/4/103", {}),
    ]),
    "hadeethenc": ("https://hadeethenc.com/api/v1", [
        ("one_2962_ar", "/hadeeths/one/", {"language": "ar", "id": "2962"}),
        ("one_2962_en", "/hadeeths/one/", {"language": "en", "id": "2962"}),
        ("one_missing_ar", "/hadeeths/one/", {"language": "ar", "id": "99999999"}),
    ]),
    "islamhouse": ("https://api3.islamhouse.com/v3/{key}", [
        ("item_2839210_ar", "/main/get-item/2839210/ar/json", {}),
        ("item_missing_ar", "/main/get-item/999999999/ar/json", {}),
    ]),
    "dorar": ("{dorar}", [
        ("search_innama", "/v1/site/hadith/search", {"value": "إنما الأعمال بالنيات", "removehtml": "true",
                                                     "specialist": "false", "page": "1"}),
        ("hadith_JIDbtVSz", "/v1/site/hadith/JIDbtVSz", {}),
        ("sharh_74201", "/v1/site/sharh/74201", {}),
        ("alternate_m5AGKRFc", "/v1/site/hadith/alternate/m5AGKRFc", {}),
        ("search_sin", "/v1/site/hadith/search", {"value": "اطلبوا العلم ولو بالصين", "removehtml": "true",
                                                  "specialist": "false", "page": "1"}),
    ]),
}


def record(provider: str, client: httpx.Client, base: str, requests: list[tuple[str, str, dict[str, str]]],
           secret: str | None) -> None:
    out = RECORDINGS / provider
    out.mkdir(parents=True, exist_ok=True)
    for name, path, query in requests:
        response = client.get(base + path, params=query)
        content_type = response.headers.get("content-type", "")
        body: Any
        try:
            body = response.json()
        except ValueError:
            body = response.text
        url = str(response.request.url)
        if secret:
            url = url.replace(secret, "{key}")
        saved = {"recorded_from": url, "recorded_at": datetime.now(UTC).date().isoformat(),
                 "request": {"method": "GET", "path": path, "query": query},
                 "response": {"status": response.status_code, "content_type": content_type.split(";")[0],
                              "body": body}}
        (out / f"{name}.json").write_text(json.dumps(saved, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"{provider}/{name}: HTTP {response.status_code}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--provider", action="append", choices=sorted(REQUESTS))
    parser.add_argument("--system-ca", action="store_true", help="verify TLS with the OS certificate store")
    parser.add_argument("--dorar", default="http://127.0.0.1:5000", help="running Dorar sidecar base URL")
    args = parser.parse_args()
    verify: ssl.SSLContext | bool = ssl.create_default_context() if args.system_ca else True
    with httpx.Client(timeout=httpx.Timeout(30, connect=10), verify=verify,
                      headers={"User-Agent": "Qabas source recorder"}) as client:
        for provider in args.provider or sorted(REQUESTS):
            base, requests = REQUESTS[provider]
            secret = None
            if provider == "islamhouse":
                secret = os.environ.get("ISLAMHOUSE_API_KEY")
                if not secret:
                    print("islamhouse: ISLAMHOUSE_API_KEY not set; skipped", file=sys.stderr)
                    continue
                base = base.replace("{key}", secret)
            base = base.replace("{dorar}", args.dorar.rstrip("/"))
            record(provider, client, base, requests, secret)
    return 0


if __name__ == "__main__":
    sys.exit(main())
