"""Render reference pages from G:\GTA\Downloads\Image.pdf into game textures.

Pages 1-5 are Google-Map screenshots of Kajla main road; pages 6+ are real
interior photos of a Dhaka home (rooms, grilled windows, balconies, stairs).
"""
import os, pymupdf
from PIL import Image

PDF = r'G:\GTA\Downloads\Image.pdf'
ROOT = os.path.join(os.path.dirname(__file__), '..')
TEX = os.path.join(ROOT, 'assets', 'textures', 'ref')
MAPS = os.path.join(ROOT, 'assets', 'maps')
os.makedirs(TEX, exist_ok=True)
os.makedirs(MAPS, exist_ok=True)
doc = pymupdf.open(PDF)

# map screenshots (pages are 1-indexed for humans)
for p in [2, 3, 4]:
    pix = doc[p - 1].get_pixmap(matrix=pymupdf.Matrix(1.6, 1.6), alpha=False)
    im = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
    im.save(os.path.join(MAPS, 'kajla_road_ref_%d.jpg' % p), quality=82)

# interior photos used as wall / floor reference panels
select = {
    7: 'doorway', 8: 'window', 9: 'grill_window', 11: 'room_a', 16: 'room_b',
    17: 'living', 28: 'balcony_a', 29: 'balcony_b', 37: 'bed_a', 38: 'bed_b',
    47: 'room_c', 49: 'room_d', 54: 'stair_hall', 55: 'wood_door',
}
for page, name in select.items():
    pix = doc[page - 1].get_pixmap(matrix=pymupdf.Matrix(1.1, 1.1), alpha=False)
    im = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
    im.thumbnail((768, 768))
    im.save(os.path.join(TEX, 'ref_%s.jpg' % name), quality=80)
    print('page', page, '->', name, im.size)
print('done')
