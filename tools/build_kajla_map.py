"""Convert the downloaded OpenStreetMap XML for Kajla, Dhaka into a compact
Godot-ready JSON map (local metres, relative to Kajla centre).

Source: https://api.openstreetmap.org/api/0.6/map?bbox=90.440,23.706,90.447,23.716
Attribution: © OpenStreetMap contributors, ODbL 1.0
"""
import json, math, os, xml.etree.ElementTree as ET

SRC = r"C:\Users\sakib\AppData\Local\Temp\opencode\kajla_big.osm"
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'maps', 'kajla.json')
LAT0, LON0 = 23.71116, 90.44350
MX = 111320.0 * math.cos(math.radians(LAT0))
MZ = 111320.0


def local(lat, lon):
    return [round((lon - LON0) * MX, 2), round(-(lat - LAT0) * MZ, 2)]


root = ET.parse(SRC).getroot()
nodes = {n.get('id'): (float(n.get('lat')), float(n.get('lon'))) for n in root.findall('node')}

buildings, roads, amenities = [], [], []
ROAD_W = {'motorway': 18, 'trunk': 14, 'primary': 12, 'secondary': 10, 'tertiary': 8,
          'residential': 6, 'living_street': 4, 'service': 4, 'unclassified': 5,
          'pedestrian': 4, 'footway': 2, 'path': 2, 'cycleway': 2}

for w in root.findall('way'):
    tags = {t.get('k'): t.get('v') for t in w.findall('tag')}
    refs = [nd.get('ref') for nd in w.findall('nd')]
    pts = [local(*nodes[r]) for r in refs if r in nodes]
    if len(pts) < 2:
        continue
    # keep only the compact playable area
    if max(abs(p[0]) for p in pts) > 900 or max(abs(p[1]) for p in pts) > 900:
        continue
    if 'building' in tags and len(pts) >= 4:
        if pts[0] != pts[-1]:
            pts.append(pts[0])
        levels = tags.get('building:levels', '')
        try:
            h = float(levels) * 3.1
        except (ValueError, TypeError):
            h = 6.5 if tags.get('building') in ('house', 'residential') else 9.0
        buildings.append({'pts': pts, 'h': round(max(3.0, min(h, 24.0)), 1),
                          'kind': tags.get('building', 'yes'),
                          'name': tags.get('name', '')})
    elif 'highway' in tags and tags['highway'] not in ('traffic_signals', 'bus_stop', 'crossing'):
        roads.append({'pts': pts, 'w': ROAD_W.get(tags['highway'], 5),
                      'kind': tags['highway'], 'name': tags.get('name', '')})
    elif any(k in tags for k in ('amenity', 'shop', 'office')):
        amenities.append({'pts': pts, 'name': tags.get('name', ''),
                          'kind': tags.get('amenity', tags.get('shop', tags.get('office', '')))})

os.makedirs(os.path.dirname(OUT), exist_ok=True)
data = {'attribution': 'OpenStreetMap contributors (ODbL 1.0)',
        'center': [LAT0, LON0], 'buildings': buildings, 'roads': roads, 'amenities': amenities}
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
print('buildings', len(buildings), 'roads', len(roads), 'amenities', len(amenities))
print('wrote', OUT, os.path.getsize(OUT), 'bytes')
