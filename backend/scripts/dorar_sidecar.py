"""Install or run the Dorar sidecar natively (handoff §12; pinned in content/sources/providers.yaml).

    uv run python scripts/dorar_sidecar.py install [--git-ssl-backend schannel]   # clone the pinned revision, npm ci
    uv run python scripts/dorar_sidecar.py run                                  # foreground, on DORAR_BASE_URL's port

Needs git and Node (22 LTS verified). The checkout lives in DORAR_SIDECAR_DIR (default backend/var/sidecars/dorar,
git-ignored). Only the pinned revision is accepted; updating it is a reviewed change to providers.yaml.
"""

from __future__ import annotations

import argparse
import asyncio
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings
from app.sources.policy import policy
from app.sources.sidecar import REVISION_FILE, DorarSidecar, pinned_revision


def install(directory: Path, ssl_backend: str | None) -> int:
    sidecar = policy("dorar").extra("sidecar") or {}
    revision = pinned_revision()
    git = ["git"] + (["-c", f"http.sslBackend={ssl_backend}"] if ssl_backend else [])
    if directory.exists():
        shutil.rmtree(directory)
    directory.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([*git, "clone", "--quiet", sidecar["repository"], str(directory)], check=True)
    subprocess.run(["git", "-C", str(directory), "checkout", "--quiet", revision], check=True)
    head = subprocess.run(["git", "-C", str(directory), "rev-parse", "HEAD"], check=True, capture_output=True,
                          text=True).stdout.strip()
    if head != revision:
        print(f"checked out {head}, expected {revision}", file=sys.stderr)
        return 1
    npm = shutil.which("npm") or "npm"
    subprocess.run([npm, "ci", "--omit=dev", "--no-audit", "--no-fund"], cwd=directory, check=True)
    (directory / REVISION_FILE).write_text(revision + "\n", encoding="utf-8")
    print(f"Dorar sidecar {revision[:12]} installed in {directory}")
    return 0


async def run(directory: Path, base_url: str) -> int:
    sidecar = DorarSidecar(directory, base_url)
    await sidecar.start()
    print(f"Dorar sidecar listening on {base_url} (Ctrl+C to stop)")
    try:
        assert sidecar.process is not None
        return await sidecar.process.wait()
    finally:
        await sidecar.stop()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    inst = commands.add_parser("install")
    inst.add_argument("--git-ssl-backend", help="e.g. schannel on Windows hosts with a TLS-inspecting proxy")
    commands.add_parser("run")
    args = parser.parse_args()
    settings = get_settings()
    if args.command == "install":
        return install(settings.dorar_sidecar_dir, args.git_ssl_backend)
    return asyncio.run(run(settings.dorar_sidecar_dir, settings.dorar_base_url))


if __name__ == "__main__":
    sys.exit(main())
