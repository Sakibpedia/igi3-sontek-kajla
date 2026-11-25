"""Download real OpenStreetMap raster tiles for Kajla, Dhaka and stitch them.

The resulting PNG is used as the in-game minimap background and as an optional
ground map texture, so the layout really is the map, not an approximation.
Tiles © OpenStreetMap contributors, ODbL 1.0 / tile usage policy.
"""
import io, math, os, requests
from PIL import Image, ImageDraw

LAT, LON, Z = 23.71116, 90.4435, 17
N = 2 ** Z
tx = int((LON + 180.0) / 360.0 * N)
ty = int((1.0 - math.asinh(math.tan(math.radians(LAT))) / math.pi) / 2.0 * N)
SPAN = 8  # 8 x 8 tiles ~ 2.2 km across at this latitude
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'maps', 'kajla_osm.png')
HEADERS = {'User-Agent': 'IGI-Sontek-Kajla-map-builder/1.0 (educational project)'}

canvas = Image.new('RGB', (SPAN * 256, SPAN * 256), (240, 238, 230))
for j, y in enumerate(range(ty - SPAN // 2, ty + SPAN // 2)):
    for i, x in enumerate(range(tx - SPAN // 2, tx + SPAN // 2)):
        url = f'https://tile.openstreetmap.org/{Z}/{x}/{y}.png'
        try:
            r = requests.get(url, headers=HEADERS, timeout=30)
            r.raise_for_status()
            tile = Image.open(io.BytesIO(r.content)).convert('RGB')
            canvas.paste(tile, (i * 256, j * 256))
        except Exception as e:
            print('tile failed', x, y, e)
d = ImageDraw.Draw(canvas)
d.rectangle((0, canvas.height - 18, canvas.width, canvas.height), fill=(255, 255, 255))
d.text((6, canvas.height - 16), 'Map data (c) OpenStreetMap contributors, ODbL 1.0 - Kajla, Dhaka', fill=(40, 40, 40))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
canvas.save(OUT)
print('saved', OUT, canvas.size, os.path.getsize(OUT), 'bytes')
print('tile origin', tx - SPAN // 2, ty - SPAN // 2, 'zoom', Z)
