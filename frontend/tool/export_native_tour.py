#!/usr/bin/env python3
"""Recover completed native captures from an iOS simulator's app cache."""
import argparse
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Booted simulator UUID')
    parser.add_argument('--output', type=Path, default=Path('build/tour/phase11'))
    parser.add_argument('--phase', default='phase11')
    args = parser.parse_args()
    container = subprocess.check_output([
        'xcrun', 'simctl', 'get_app_container', args.device, 'com.rw.qabas', 'data',
    ], text=True).strip()
    if not args.phase.replace('_', '').isalnum():
        raise SystemExit('Invalid phase folder')
    source = Path(container) / 'tmp/qabas_tour' / args.phase
    if not source.exists():
        raise SystemExit(f'No saved {args.phase} captures in this simulator app.')
    count = 0
    for capture in sorted(source.rglob('*.png')):
        output = args.output / capture.relative_to(source)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(capture, output)
        count += 1
    print(f'Exported {count} completed captures to {args.output}')


if __name__ == '__main__':
    main()
