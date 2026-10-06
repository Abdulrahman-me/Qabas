"""Creates the files behind every mock-asset:// URL used by the fixtures and writes
fixtures/mock_assets/mock_assets.json (url -> path, mime_type, width, height, bytes, sha256).

TEST MEDIA ONLY:
  * scene fallbacks are rendered with the NON-NORMATIVE preview in tools/scene_check.py at each
    fallback_params state (production fallbacks come from the Flutter renderer's tools/scene_preview);
  * maps and lesson images are abstract placeholders without text;
  * audio is a synthetic test tone with test timings — not a Quran recitation. Licensed reciter
    audio for the reference lesson is still pending.
"""
import asyncio, hashlib, io, json, pathlib, re, subprocess, sys
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import scene_check  # noqa: E402

FX = ROOT / "fixtures"; MA = FX / "mock_assets"
urls = set()
scene_states = {}
def walk(o):
    if isinstance(o, dict):
        if o.get("kind") == "scene" and o.get("fallback_image"):
            scene_states[o["fallback_image"]["url"]] = (o["scene"], o["fallback_params"], o["fallback_image"])
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
    elif isinstance(o, str) and o.startswith("mock-asset://"):
        urls.add(o)
for f in json.loads((FX / "MANIFEST.json").read_text()):
    walk(json.loads((FX / f["file"]).read_text()))

def path_of(url): return MA / url[len("mock-asset://"):]
meta = {}
def record(url, mime, w=None, h=None):
    p = path_of(url); b = p.read_bytes()
    meta[url] = {"path": str(p.relative_to(FX)), "mime_type": mime, "width": w, "height": h, "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}

async def render(svgs):
    from playwright.async_api import async_playwright
    async with async_playwright() as p:
        b = await p.chromium.launch(); pg = await b.new_page(viewport={"width": 1600, "height": 1000})
        out = {}
        for k, (svg, w, h) in svgs.items():
            await pg.set_viewport_size({"width": w, "height": h})
            await pg.set_content(f"<html><body style='margin:0'>{svg.replace('width=\"800\" height=\"500\"', f'width=\"{w}\" height=\"{h}\"')}</body></html>")
            out[k] = await pg.screenshot()
        await b.close(); return out

svgs = {}
for url in sorted(urls):
    p = path_of(url); p.parent.mkdir(parents=True, exist_ok=True)
    if url.endswith("scene.json"):
        m = re.search(r"scenes/(scn_[a-z0-9_]+)/v(\d+)/", url)
        src = FX / "scenes" / f"{m.group(1)}.v{m.group(2)}.scene.json"
        p.write_bytes(src.read_bytes()); record(url, "application/json")
    elif url in scene_states:
        ref, params, img = scene_states[url]
        man = json.loads(path_of(ref["url"]).read_bytes() if path_of(ref["url"]).exists() else (FX / "scenes" / f"{ref['scene_id']}.v{ref['version']}.scene.json").read_bytes())
        svgs[url] = (scene_check.render_svg(man, params, 0, reduced=True), img["width"], img["height"])
    elif url.endswith(".webp"):
        w, h = (1600, 1200) if "maps/" in url else (1600, 1000)
        im = Image.new("RGB", (w, h), (238, 245, 242)); d = ImageDraw.Draw(im)
        seed = int(hashlib.sha256(url.encode()).hexdigest()[:6], 16)
        for i in range(6):
            x = (seed >> i) % (w - 300); y = (seed >> (i + 3)) % (h - 300)
            d.ellipse([x, y, x + 260, y + 200], fill=(11 + i * 20, 90, 82 + i * 10))
        im.save(p, "WEBP", quality=80); record(url, "image/webp", w, h)
    elif url.endswith(".mp3"):
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=2.9", "-b:a", "64k", str(p)], check=True)
        record(url, "audio/mpeg")
if svgs:
    pngs = asyncio.run(render(svgs))
    for url, png in pngs.items():
        im = Image.open(io.BytesIO(png)).convert("RGB"); im.save(path_of(url), "WEBP", quality=82)
        record(url, "image/webp", im.width, im.height)
(MA / "mock_assets.json").write_text(json.dumps(meta, indent=1))
print(len(meta), "mock assets")
