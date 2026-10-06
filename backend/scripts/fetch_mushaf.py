"""Install the canonical mushaf dataset pinned in ``content/sources/mushaf.yaml`` (D-88).

    uv run python scripts/fetch_mushaf.py                 # download, verify both digests, install
    uv run python scripts/fetch_mushaf.py --archive FILE  # install from an archive obtained separately

The archive and the extracted member must both match their pinned SHA-256; anything else is refused and nothing
is installed. The file lands in ``MUSHAF_DIR`` (default ``backend/var/sources/mushaf/``, git-ignored): its
redistribution terms are unconfirmed (O-03), so it is fetched per environment rather than committed.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx

from app.config import get_settings
from app.sources.mushaf import Mushaf, load_manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--archive", type=Path, help="use this local archive instead of downloading")
    parser.add_argument("--dataset", help="dataset id (default: the manifest's canonical dataset)")
    parser.add_argument("--if-missing", action="store_true", help="validate and reuse an installed dataset")
    args = parser.parse_args()
    canonical, specs = load_manifest()
    spec = specs[args.dataset or canonical]
    target = get_settings().mushaf_dir / f"{spec.id}.json"
    if args.if_missing and target.is_file():
        Mushaf.load(target, spec)
        print(f"validated installed {spec.id}")
        return 0
    if spec.url is None or spec.archive_sha256 is None:
        print(f"{spec.id} has no download source", file=sys.stderr)
        return 1
    if args.archive:
        archive = args.archive.read_bytes()
    else:
        print(f"downloading {spec.url}", flush=True)
        # Cold deployments may encounter a slow or transiently unreachable origin.
        # Retry connection failures, keeping TLS verification and both pinned digests.
        transport = httpx.HTTPTransport(retries=2)
        try:
            with httpx.Client(transport=transport, timeout=httpx.Timeout(120, connect=30),
                              follow_redirects=True) as client:
                response = client.get(spec.url)
                response.raise_for_status()
                archive = response.content
        except httpx.HTTPError as exc:
            print(f"canonical dataset download failed ({type(exc).__name__}); "
                  "the download origin must be reachable, or use --archive FILE with the pinned archive",
                  file=sys.stderr, flush=True)
            return 1
    digest = hashlib.sha256(archive).hexdigest()
    if digest != spec.archive_sha256:
        print(f"archive SHA-256 {digest} does not match the pinned {spec.archive_sha256}; nothing installed",
              file=sys.stderr)
        return 1
    member = zipfile.ZipFile(io.BytesIO(archive)).read(spec.member)
    digest = hashlib.sha256(member).hexdigest()
    if digest != spec.member_sha256:
        print(f"{spec.member} SHA-256 {digest} does not match the pinned {spec.member_sha256}; nothing installed",
              file=sys.stderr)
        return 1
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(member)
    mushaf = Mushaf.load(target, spec)  # parses and validates the whole text
    words = sum(len(a.words) for s in mushaf.surahs for a in s.ayahs)
    print(f"installed {spec.id} ({len(mushaf.surahs)} surahs, {spec.ayah_count} ayahs, {words} words) at {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
