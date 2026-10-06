#!/usr/bin/env python3
"""Make uncropped Phase 13 native/prototype pairs for manual visual review."""
import argparse
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw


ROWS = [
    ('47_community', '47_community', 'Contract league has five members rather than twelve and supplies its own tier/name/weekly XP. Invitation badge is actionable. Discover replaces Review (A-28).'),
    ('48_community_scrolled', '48_community_quests', 'Contract league is shorter; quests/friends use supplied titles/counts; the preview has two supplied friends rather than three. Scroll offset is chosen to expose the quests. No invented members or rewards.'),
    ('49_live_countdown', '49_challenge_countdown', 'Contract names/avatars replace prototype samples. Four-player group retains the 3-second countdown.'),
    ('50_live_question', '50_challenge_question', 'Supplied closed question is Arabic in either interface, has two choices, and uses the group preset 10-second deadline.'),
    ('51_live_reveal', '51_challenge_reveal', 'Supplied answer/explanation and actual points replace prototype samples; group reveal lasts 2200 ms.'),
    ('52_live_results', '52_challenge_results', 'Scores/ranks/XP are coordinator results; hero pose is naturally timed. Header review icon opens authoritative answer summaries.'),
    ('54_achievements', '54_achievements', 'Contract returns two achievements rather than eight. No missing badges are invented.'),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--captures', type=Path, default=Path('build/tour/phase13/community/en_motion'))
    p.add_argument('--output', type=Path, default=Path('build/phase13/comparison'))
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
    contact = Image.new('RGB', (804 * 2, 910 * ((len(thumbnails) + 1) // 2)), 'white')
    for i, thumb in enumerate(thumbnails): contact.paste(thumb, ((i % 2) * 804, (i // 2) * 910))
    contact.save(args.output / 'contact.jpg', quality=92)
    (args.output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    (args.output / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Qabas Phase 13 comparison</title><body style="font-family:system-ui;margin:24px"><h1>Phase 13: same-viewport comparison</h1><p>Full-size images are uncropped. Animation poses and server content differ; these pairs require manual inspection.</p>' + ''.join(links) + '</body>')
    print(f'Prepared {len(manifest)} uncropped comparisons at {args.output}')


if __name__ == '__main__':
    main()
