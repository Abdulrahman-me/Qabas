"""Expose SDK-compiled Material shaders to Flutter's Chrome test asset handler.

The harness serves paths from test/, while its bundle builder puts assets under
build/unit_test_assets and compiles native shader format. Compile web format into
build/ and temporarily link just that shader directory beside each suite,
since the browser resolves asset URLs relative to its nested suite page.
Never modify the SDK.
"""
import argparse
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/chrome_test_assets/shaders'
LINKS = sorted({test.parent / 'assets/shaders' for test in (ROOT / 'test').rglob('*_test.dart')})


def clean():
    for link in LINKS:
        if link.is_symlink() and link.resolve() == OUTPUT:
            link.unlink()
            if not any(link.parent.iterdir()):
                link.parent.rmdir()


def prepare():
    for link in LINKS:
        if link.exists() or link.is_symlink():
            if not link.is_symlink() or link.resolve() != OUTPUT:
                raise SystemExit(f'{link.relative_to(ROOT)} already exists; refusing to replace it')
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter is required on PATH')
    sdk = Path(flutter).resolve().parents[1]
    os_name = 'darwin' if sys.platform == 'darwin' else 'linux'
    arch = 'arm64' if platform.machine() in ('arm64', 'aarch64') else 'x64'
    compiler = sdk / f'bin/cache/artifacts/engine/{os_name}-{arch}/impellerc'
    if not compiler.exists():
        compiler = sdk / f'bin/cache/artifacts/engine/{os_name}-x64/impellerc'
    source = sdk / 'packages/flutter/lib/src/material/shaders'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in ('ink_sparkle.frag', 'stretch_effect.frag'):
        output = OUTPUT / name
        subprocess.run([
            str(compiler), '--sksl', '--iplr', '--json',
            f'--sl={output}', f'--spirv={output}.spirv',
            f'--input={source / name}', '--input-type=frag',
            f'--include={source}', f'--include={compiler.parent / "shader_lib"}',
        ], check=True)
        Path(f'{output}.spirv').unlink(missing_ok=True)
    for link in LINKS:
        link.parent.mkdir(exist_ok=True)
        if not link.is_symlink():
            link.symlink_to(OUTPUT, target_is_directory=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--clean', action='store_true')
    args = parser.parse_args()
    clean() if args.clean else prepare()
