#!/usr/bin/env python3
"""Make uncropped Phase 12 native/prototype pairs for manual visual review."""
import argparse
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw


ROWS = [
    ('40_review_card', '40_review_front', 'Supplied card front is Arabic in either interface language; wording stays verbatim.'),
    ('41_review_card_flipped', '41_review_back', 'Supplied back is verbatim; interval hints are omitted under A-05 because the contract has no intervals.'),
    ('42_review_done', '42_review_complete', 'XP and next step come from the server result; no prototype reward is synthesized.'),
    ('57_unit_guide', '57_unit_guide', 'Supplied Arabic guide uses the matching First Step unit title/art from the demo journey. The Guide contract has no reviewed_by; no reviewer badge is invented.'),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--captures', type=Path, default=Path('build/tour/phase12/learning/en_motion'))
    p.add_argument('--output', type=Path, default=Path('build/phase12/comparison'))
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest, thumbnails, links = [], [], []
    for reference, capture, note in ROWS:
        left = Image.open(Path('docs/prototype/screens') / f'{reference}.png').convert('RGB')
        right = Image.open(args.captures / f'{capture}.png').convert('RGB')
        if left.size != right.size:
            raise SystemExit(f'{reference}: viewport mismatch {left.size} != {right.size}')
        pair = Image.new('RGB', (left.width * 2, left.height), 'white')
        pair.paste(left, (0, 0)); pair.paste(right, (left.width, 0))
        output = args.output / f'{reference}_pair.png'
        pair.save(output)
        thumb = pair.copy(); thumb.thumbnail((804, 874))
        frame = Image.new('RGB', (804, 910), 'white'); frame.paste(thumb, (0, 36))
        ImageDraw.Draw(frame).text((12, 10), f'{reference}: prototype / production', fill='black')
        thumbnails.append(frame)
        manifest.append({'reference': reference, 'capture': capture, 'pixels': left.size, 'intentional_difference': note})
        links.append(f'<h2>{html.escape(reference)}</h2><p>{html.escape(note)}</p><a href="{output.name}"><img src="{output.name}" style="width:100%;max-width:1206px"></a>')
    contact = Image.new('RGB', (804 * 2, 910 * 2), 'white')
    for i, thumb in enumerate(thumbnails): contact.paste(thumb, ((i % 2) * 804, (i // 2) * 910))
    contact.save(args.output / 'contact.jpg', quality=92)
    (args.output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    (args.output / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Qabas Phase 12 comparison</title><body style="font-family:system-ui;margin:24px"><h1>Phase 12: same-viewport comparison</h1><p>Full-size images are uncropped. Animation poses and server content differ; these pairs require manual inspection.</p>' + ''.join(links) + '</body>')
    print(f'Prepared {len(manifest)} uncropped comparisons at {args.output}')


if __name__ == '__main__':
    main()
