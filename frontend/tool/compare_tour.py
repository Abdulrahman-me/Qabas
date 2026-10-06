#!/usr/bin/env python3
"""Pair the Phase 11 tour with read-only prototype captures; make a review index.

No image is cropped, recolored or aligned to disguise differences. Full-size
pairs retain the actual viewport. Contact sheets are only navigation previews.
Pixel differences include authored animation poses and contract-backed data;
this tool deliberately does not certify visual fidelity automatically.
"""
import argparse
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw

TIER_A = list(range(1, 40)) + list(range(43, 47)) + [53, 55, 56]


def differences(index):
    if index == 7:
        return 'Private profile starts enabled in the production flow; reminder choices persist and Arabic uses Arabic-Indic digits. Other geometry and wording follow the prototype.'
    if index <= 8:
        return 'Explorer chosen for the required demo script; extra undisclosed choice, contract preview titles and responsive wrapping.'
    if index in (9, 10, 38):
        return 'Revision 10 Unit 0 curriculum, server progress and next step; Discover replaces Review in navigation.'
    if index in (30, 31, 32):
        return 'Unavailable reciter/checker and explicit skip; no simulated playback or successful recitation.'
    if index == 20:
        return 'Contract grading adds the typed correct answer and supplied misconception/remediation card; warm clay feedback stays scrollable.'
    if index in (18, 22, 23, 24, 25, 27, 28, 34, 35):
        return 'Accessible 44 px targets, retained ghost-token geometry and stable praise variants; server payload wording and source control.'
    if index == 11:
        return 'Verbatim server reviewed_by status (unreviewed reference export); authenticated source count and source control. Salah remains developer-only.'
    if index in (19, 21, 26):
        return 'Verbatim evidence/provider/reference/honorific fields, including unverified adapter text; all-sources control and API term state.'
    if index in (36, 37):
        return 'Server reward, streak/date and returned mastery/terms; counts never synthesized by the client.'
    if index == 39:
        return 'Your words moved to Profile; Review entry moved to Journey by owner instruction; full review and glossary deferred to Phase 12.'
    if index == 45:
        return 'Supplied Arabic fixture B has a fabricated verdict rather than the prototype\'s authentic example; verbatim grade/grader, related authentic text and source controls.'
    if index == 46:
        return 'Supplied Arabic fixture C has an external specialist referral and rating controls; no invented private inbox or promised reply.'
    if 43 <= index <= 44:
        return 'Verbatim Arabic fixture A in both UI languages; contract classification/stages, source and feedback controls; Discover navigation.'
    if index == 53:
        return 'Server profile/statistics, supplied badges, Your words preview and developer avatar gesture.'
    if index == 55:
        return 'Required Characters preference, persisted reminder choices; curiosity disabled in demo.'
    if index == 56:
        return 'Full verified verse is tappable; AI/content notes remain available below the prototype section.'
    return 'Server payload wording, term/source state and contract progress counts; all-sources control; stable praise variants; unmirrored artwork.'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--captures', type=Path, default=Path('build/tour/phase11/spine/en_motion'))
    p.add_argument('--output', type=Path, default=Path('build/compare'))
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows, thumbs = [], []
    references = sorted(Path('docs/prototype/screens').glob('*.png'))
    references = [ref for ref in references if int(ref.name[:2]) in TIER_A]
    if {int(ref.name[:2]) for ref in references} != set(TIER_A):
        raise SystemExit('The prototype baseline must contain all 46 Tier A screens.')
    for ref in references:
        capture = args.captures / ref.name
        if not capture.exists():
            raise SystemExit(f'Missing Tier A capture: {capture}')
        with Image.open(ref) as a, Image.open(capture) as b:
            if a.size != b.size:
                raise SystemExit(f'Viewport mismatch: {ref}: {a.size}, {capture}: {b.size}')
    for ref in references:
        index = int(ref.name[:2])
        capture = args.captures / ref.name
        with Image.open(ref) as a, Image.open(capture) as b:
            a, b = a.convert('RGB'), b.convert('RGB')
            w, h = a.size
            pair = Image.new('RGB', (w * 2, h + 66), '#eee8da')
            pair.paste(a, (0, 66))
            pair.paste(b, (w, 66))
            draw = ImageDraw.Draw(pair)
            draw.text((18, 15), f'{ref.stem} | PROTOTYPE', fill='#0c3328', font_size=27)
            draw.text((w + 18, 15), 'PRODUCTION | config/demo.json', fill='#0c3328', font_size=27)
            pair.save(args.output / ref.name)
            pair.thumbnail((604, 690))
            thumbs.append(pair.copy())
            rows.append({'screen': ref.stem, 'prototype': str(ref), 'capture': str(capture),
                         'viewport_px': [w, h], 'baseline_language': 'en', 'capture_language': 'ar' if args.captures.name.startswith('ar_') else 'en', 'motion_pose': 'Naturally timed companion, sky and particle poses can differ between captures.', 'intentional_differences': differences(index)})
    for offset in range(0, len(thumbs), 6):
        group = thumbs[offset:offset + 6]
        sheet = Image.new('RGB', (604 * 3, 690 * 2), '#eee8da')
        for i, thumb in enumerate(group):
            sheet.paste(thumb, ((i % 3) * 604, (i // 3) * 690))
        sheet.save(args.output / f'contact_{offset // 6 + 1:02}.jpg', quality=92)
    additions = sorted(p for p in args.captures.glob('*.png') if p.name not in {r['screen'] + '.png' for r in rows})
    for offset in range(0, len(additions), 12):
        sheet = Image.new('RGB', (804, 1386), '#eee8da')
        draw = ImageDraw.Draw(sheet)
        for i, path in enumerate(additions[offset:offset + 12]):
            with Image.open(path) as frame:
                thumb = frame.convert('RGB')
                thumb.thumbnail((201, 437))
                x, y = (i % 4) * 201, (i // 4) * 462
                sheet.paste(thumb, (x, y + 25))
                draw.text((x + 3, y + 3), path.stem, fill='#0c3328', font_size=10)
        sheet.save(args.output / f'additions_{offset // 12 + 1:02}.jpg', quality=94)
    (args.output / 'manifest.json').write_text(json.dumps(rows, indent=2) + '\n')
    items = ''.join(f'<article><h2>{html.escape(r["screen"])}</h2><p>{html.escape(r["intentional_differences"])}</p><a href="{r["screen"]}.png"><img src="{r["screen"]}.png" loading="lazy"></a></article>' for r in rows)
    contacts = ''.join(f'<li><a href="{path.name}">{path.stem}</a></li>' for path in sorted(args.output.glob('contact_*.jpg')))
    extras = ''.join(f'<li><a href="{path.name}">{path.stem}</a></li>' for path in sorted(args.output.glob('additions_*.jpg')))
    language = rows[0]['capture_language']
    (args.output / 'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Qabas Phase 11 comparison</title><style>body{background:#eee8da;color:#0c3328;font:16px system-ui;margin:32px}article{max-width:1200px;margin:36px auto}img{width:100%}</style><h1>Prototype / production: Tier A</h1>'
        + f'<p>English prototype baseline; {language.upper()} production captures. Arabic captures support RTL review against the source; an Arabic pixel baseline is not supplied.</p>'
        + '<p>Full viewport pairs. Listed data and product differences require human review; pixel equality is not asserted. Naturally timed companion, sky and particle poses can differ.</p>'
        + '<h2>Pair contacts</h2><ul>' + contacts + '</ul><h2>Unit 0 and demo additions</h2><ul>' + extras + '</ul>' + items + '</html>')
    print(f'{len(rows)} Tier A pairs; {len(range(0, len(thumbs), 6))} contact sheets; {args.output}/index.html')


if __name__ == '__main__':
    main()
