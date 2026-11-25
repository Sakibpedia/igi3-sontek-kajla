"""IGI-2 style wanted posters and leaflets for the campaign target.

Uses the project's Noto Sans Bengali font.  If the player drops a photo at
user://posters/sakib.png the game will paste it onto the poster automatically;
otherwise this generated stylised portrait is used.
"""
import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets', 'textures')
FONT_PATH = os.path.join(ROOT, 'assets', 'fonts', 'NotoSansBengali-Regular.ttf')
os.makedirs(OUT, exist_ok=True)


def font(sz):
    try:
        return ImageFont.truetype(FONT_PATH, sz)
    except Exception:
        return ImageFont.load_default()


def make_poster():
    w, h = 512, 768
    img = Image.new('RGB', (w, h), (28, 26, 24))
    d = ImageDraw.Draw(img)
    # printed-paper mottling
    for i in range(5000):
        x = (i * 73) % w
        y = (i * 131 + i // 7) % h
        d.point((x, y), fill=(40 + (i * 7) % 25, 36 + (i * 11) % 22, 30 + (i * 13) % 20))
    # border
    d.rectangle((12, 12, w - 13, h - 13), outline=(196, 162, 92), width=5)
    d.rectangle((20, 20, w - 21, h - 21), outline=(120, 96, 52), width=2)
    # header
    d.text((w // 2, 44), "WANTED", font=font(62), fill=(226, 196, 118), anchor='ma')
    d.text((w // 2, 108), "অপরাধী — জীবিত অথবা মৃত", font=font(27), fill=(226, 206, 160), anchor='ma')
    d.line((40, 150, w - 40, 150), fill=(160, 130, 70), width=3)
    # portrait frame (stylised silhouette placeholder)
    px0, py0, px1, py1 = 70, 172, w - 70, 500
    d.rectangle((px0, py0, px1, py1), fill=(96, 92, 80), outline=(180, 150, 90), width=3)
    cx, cy = (px0 + px1) // 2, py0 + 130
    d.ellipse((cx - 62, cy - 72, cx + 62, cy + 72), fill=(54, 48, 42))
    d.ellipse((cx - 110, cy + 90, cx + 110, cy + 300), fill=(54, 48, 42))
    d.text((w // 2, py1 + 16), "[ photo: user://posters/sakib.png ]", font=font(15), fill=(150, 140, 120), anchor='ma')
    # name
    d.text((w // 2, 552), "S M NAZMUZ SAKIB", font=font(33), fill=(238, 220, 170), anchor='ma')
    d.text((w // 2, 602), "এস এম নাজমুজ সাকিব", font=font(31), fill=(232, 210, 160), anchor='ma')
    d.text((w // 2, 656), "SONTEK KAJLA OPERATION — DHAKA", font=font(18), fill=(190, 176, 140), anchor='ma')
    d.text((w // 2, 700), "পুরস্কার — ৳ ৫০,০০০", font=font(26), fill=(226, 196, 118), anchor='ma')
    img.save(os.path.join(OUT, 'poster_sakib.png'))
    print('wrote poster_sakib.png')


def make_leaflet():
    w, h = 512, 384
    img = Image.new('RGB', (w, h), (222, 212, 186))
    d = ImageDraw.Draw(img)
    d.rectangle((8, 8, w - 9, h - 9), outline=(110, 86, 45), width=3)
    d.text((w // 2, 36), "নিরাপত্তা সতর্কতা", font=font(38), fill=(120, 30, 24), anchor='ma')
    d.text((w // 2, 84), "SECURITY BULLETIN — KAJLA", font=font(20), fill=(70, 50, 30), anchor='ma')
    d.line((30, 116, w - 30, 116), fill=(130, 100, 60), width=2)
    lines = [
        "• সন্দেহজনক ব্যক্তির ছবি প্রচার করা হয়েছে।",
        "• কাজলা বাস স্টপ ও পার্কে কড়া নজরদারি।",
        "• কোনো অজ্ঞাত বস্তু দেখলে অ্যালার্ম বাজান।",
        "• অপারেশন: SONTEK KAJLA / R110 SECTOR",
    ]
    y = 142
    for line in lines:
        d.text((32, y), line, font=font(20), fill=(46, 38, 30))
        y += 48
    d.text((w // 2, h - 40), "S M NAZMUZ SAKIB — WANTED", font=font(18), fill=(120, 30, 24), anchor='ma')
    img.save(os.path.join(OUT, 'leaflet_kajla.png'))
    print('wrote leaflet_kajla.png')


make_poster()
make_leaflet()
