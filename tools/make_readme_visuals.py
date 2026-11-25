#!/usr/bin/env python3
"""Build the README visuals from the project's own art (no external downloads).

Run from the repository root:

    python tools/make_readme_visuals.py

Inputs : assets/maps/kajla_osm.png, assets/fonts/NotoSans-Bold.ttf
Outputs: docs/images/banner.png, docs/images/map-overview.png,
         docs/images/wanted-poster.png

The images are decorative key art for the documentation. They are generated
locally so the repository stays self-contained and reproducible.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "images"
OUT.mkdir(parents=True, exist_ok=True)

MAP = ROOT / "assets" / "maps" / "kajla_osm.png"
FONT_LATIN = ROOT / "assets" / "fonts" / "NotoSans-Bold.ttf"

GOLD = (212, 171, 92)
TEAL = (106, 196, 184)
INK = (8, 14, 19)
CREAM = (238, 232, 215)


def font(size: int) -> ImageFont.FreeTypeFont:
    # Pillow without libraqm cannot shape Bengali conjuncts; keep image
    # typography Latin and put Bengali copy in the Markdown text instead.
    return ImageFont.truetype(str(FONT_LATIN), size)


def gradient(size: tuple[int, int], top=(10, 22, 28), bottom=(4, 8, 12)) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def map_layer(size: tuple[int, int], coverage: float = 1.35) -> Image.Image:
    """Desaturated, darkened crop of the real OSM raster."""
    src = Image.open(MAP).convert("RGB")
    w, h = size
    scale = max(w / src.width, h / src.height) * coverage
    src = src.resize((int(src.width * scale), int(src.height * scale)), Image.LANCZOS)
    left = (src.width - w) // 2
    top = (src.height - h) // 2
    src = src.crop((left, top, left + w, top + h))
    src = ImageEnhance.Color(src).enhance(0.25)
    src = ImageEnhance.Brightness(src).enhance(0.45)
    return src


def centered(draw: ImageDraw.ImageDraw, xy, text, fnt, fill, spacing=8):
    draw.text(xy, text, font=fnt, fill=fill, anchor="mm", spacing=spacing)


def banner() -> None:
    w, h = 1600, 620
    img = gradient((w, h), (12, 32, 38), (5, 9, 13)).convert("RGBA")
    back = map_layer((w, h))
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle((0, 0, w, h), fill=150)
    md.ellipse((w - 560, -260, w + 220, 520), fill=255)
    img.paste(back, (0, 0), mask)

    # All translucent shapes go on their own layer, then composite once.
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over, "RGBA")
    for i in range(0, w, 90):
        d.line((i - 260, h, i + 120, 0), fill=(90, 180, 170, 24), width=2)
    d.rectangle((0, h - 8, w, h), fill=GOLD + (255,))
    d.rectangle((56, 52, 66, h - 60), fill=GOLD + (255,))
    d.text((94, 96), "IGI 3", font=font(168), fill=CREAM + (255,))
    d.text((100, 268), "S O N T E K   K A J L A", font=font(50), fill=GOLD + (255,))
    d.line((100, 344, 700, 344), fill=GOLD + (190,), width=3)
    d.text((102, 376), "15 BENGALI MISSIONS  /  REAL DHAKA MAP  /  GODOT 4.3",
           font=font(30), fill=(201, 221, 219, 255))

    chips = ["WALK-IN CITY", "NEUTRAL FORCES", "BCS GATES", "SHOPS + ECONOMY"]
    x = 102
    for label in chips:
        tw = d.textbbox((0, 0), label, font=font(21))[2]
        d.rounded_rectangle((x, 470, x + tw + 38, 522), radius=8,
                            fill=(12, 28, 33, 225), outline=GOLD + (200,), width=2)
        d.text((x + 19, 496), label, font=font(21), fill=TEAL + (255,), anchor="lm")
        x += tw + 58
    img = Image.alpha_composite(img, over)

    # a small wanted-poster accent on the right (ours, with clean typography)
    p = Image.open(OUT / "wanted-poster.png").convert("RGBA")
    p.thumbnail((300, 420), Image.LANCZOS)
    px = (w - p.width - 90, 95)
    img.alpha_composite(p, px)
    frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rectangle(
        (px[0] - 6, px[1] - 6, px[0] + p.width + 6, px[1] + p.height + 6),
        outline=GOLD + (220,), width=3)
    img = Image.alpha_composite(img, frame)
    img.convert("RGB").save(OUT / "banner.png", optimize=True)


def map_overview() -> None:
    w, h = 1200, 760
    img = map_layer((w, h), coverage=1.0).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over, "RGBA")
    d.rectangle((0, 0, w, h), fill=(4, 12, 16, 55))
    d.rounded_rectangle((36, 34, 540, 158), radius=12, fill=(5, 13, 18, 230),
                        outline=GOLD + (220,), width=3)
    d.text((66, 76), "SONTEK KAJLA", font=font(52), fill=CREAM + (255,))
    d.text((68, 130), "REAL OPENSTREETMAP FOOTPRINTS  -  DHAKA",
           font=font(20), fill=TEAL + (255,))
    d.rectangle((0, h - 10, w, h), fill=GOLD + (255,))
    img = Image.alpha_composite(img, over)
    img.convert("RGB").save(OUT / "map-overview.png", optimize=True)


def wanted_poster() -> None:
    w, h = 900, 1200
    img = gradient((w, h), (24, 22, 18), (7, 8, 8)).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(0, w + h, 7):
        d.line((i, 0, i - h, h), fill=(255, 255, 255, 5), width=1)
    d.rectangle((34, 34, w - 34, h - 34), outline=GOLD + (255,), width=6)
    d.rectangle((52, 52, w - 52, h - 52), outline=GOLD + (130,), width=2)
    centered(d, (w // 2, 150), "WANTED", font(104), GOLD + (255,))
    centered(d, (w // 2, 222), "IGI 3  /  SONTEK KAJLA", font(26), TEAL + (255,))
    d.line((100, 264, w - 100, 264), fill=GOLD + (200,), width=3)

    # silhouette portrait built from simple shapes (fictional, no real person)
    box = (110, 310, w - 110, 800)
    d.rectangle(box, fill=(46, 44, 39, 255), outline=GOLD + (190,), width=3)
    cx = w // 2
    d.ellipse((cx - 118, 400, cx + 118, 636), fill=(18, 24, 27, 255))
    d.ellipse((cx - 210, 640, cx + 210, 1120), fill=(18, 24, 27, 255))
    d.polygon([(cx - 190, 706), (cx - 20, 640), (cx + 20, 640), (cx + 190, 706),
               (cx + 150, 820), (cx - 150, 820)], fill=(34, 42, 44, 255))
    d.rectangle((cx - 140, 742, cx + 140, 766), fill=GOLD + (110,))

    centered(d, (w // 2, 872), "S M NAZMUS SAKIB", font(40), CREAM + (255,))
    centered(d, (w // 2, 934), "FICTIONAL INTELLIGENCE TARGET", font(21), TEAL + (255,))
    d.line((140, 982, w - 140, 982), fill=GOLD + (150,), width=2)
    centered(d, (w // 2, 1032), "DEAD OR ALIVE  -  50,000 TAKA", font(27), GOLD + (255,))
    centered(d, (w // 2, 1100), "GAME ART  -  NOT A REAL PERSON", font(17), (170, 170, 165, 255))
    img.convert("RGB").save(OUT / "wanted-poster.png", optimize=True)


if __name__ == "__main__":
    wanted_poster()
    banner()
    map_overview()
    for p in sorted(OUT.glob("*.png")):
        print(f"{p.name}: {p.stat().st_size // 1024} KB")
