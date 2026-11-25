import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'world', 'KajlaMap.gd')
s = open(p, encoding='utf-8').read()
start = s.index('\t# ---------------- exact OSM building footprints ----------------')
end = s.index('\t# ---------------- real multi-storey Kajla houses ----------------')
new = '''\t# ---------------- exact OSM building footprints (dense Kajla) ----------------
\tvar rects: Array = []
\tvar sites: Array = []
\tvar all: Array = data.get("buildings", [])
\tvar step := maxi(1, int(float(all.size()) / 380.0))

\t# Reserve a few real OSM footprints for walk-in houses BEFORE drawing masses,
\t# otherwise a solid box is drawn on top of the accessible house and blocks it.
\tvar house_src := {}
\tvar house_centers: Array = []
\tvar scan := 0
\tfor bd in all:
\t\tscan += 1
\t\tvar pp: Array = bd["pts"]
\t\tif pp.size() < 4:
\t\t\tcontinue
\t\tvar lo0 := Vector2(INF, INF)
\t\tvar hi0 := Vector2(-INF, -INF)
\t\tfor q0 in pp:
\t\t\tvar v0 := Vector2(q0[0], q0[1])
\t\t\tlo0 = lo0.min(v0)
\t\t\thi0 = hi0.max(v0)
\t\tvar c0 := (lo0 + hi0) * 0.5
\t\tvar sz0 := hi0 - lo0
\t\tif sz0.x < 8.0 or sz0.y < 7.0 or sz0.x > 16.0 or sz0.y > 15.0:
\t\t\tcontinue
\t\tif absf(c0.x) > 330.0 or absf(c0.y) > 260.0:
\t\t\tcontinue
\t\tvar far := true
\t\tfor hc in house_centers:
\t\t\tif c0.distance_to(hc) < 75.0:
\t\t\t\tfar = false
\t\t\t\tbreak
\t\tif far:
\t\t\thouse_src[scan] = bd
\t\t\thouse_centers.append(c0)
\t\tif house_src.size() >= 6:
\t\t\tbreak

\tvar idx := 0
\tfor bd in all:
\t\tidx += 1
\t\tif idx % step != 0 or house_src.has(idx):
\t\t\tcontinue
\t\tvar pts: Array = bd["pts"]
\t\tvar lo := Vector2(INF, INF)
\t\tvar hi := Vector2(-INF, -INF)
\t\tfor p in pts:
\t\t\tvar v := Vector2(p[0], p[1])
\t\t\tlo = lo.min(v)
\t\t\thi = hi.max(v)
\t\tvar c := (lo + hi) * 0.5
\t\tvar sz := hi - lo
\t\tif sz.x < 2.2 or sz.y < 2.2 or sz.x > 70.0 or sz.y > 70.0:
\t\t\tcontinue
\t\tif absf(c.x) > 400.0 or absf(c.y) > 400.0:
\t\t\tcontinue
\t\tvar h := clampf(float(bd.get("h", 8.0)), 3.5, 22.0)
\t\tvar pick := (idx * 7 + mission * 3) % WALL_MATS.size()
\t\tvar wall: String = WALL_MATS[pick]
\t\tvar roof: String = ROOF_MATS[(idx + mission) % ROOF_MATS.size()]
\t\tb.box(Vector3(c.x, h * 0.5, c.y), Vector3(sz.x, h, sz.y), wall)
\t\tb.box(Vector3(c.x, h + 0.12, c.y), Vector3(sz.x + 0.35, 0.24, sz.y + 0.35), roof, false)
\t\t# windows only on every third mass: dense skyline without drowning the GPU
\t\tif idx % 3 == 0:
\t\t\tvar floors := maxi(1, int(h / 3.1))
\t\t\tfor fl in floors:
\t\t\t\tvar wy := 1.5 + float(fl) * 3.1
\t\t\t\tif wy > h - 0.4:
\t\t\t\t\tbreak
\t\t\t\tvar ww := maxf(1.0, sz.x - 1.8)
\t\t\t\tb.box(Vector3(c.x, wy, c.y - sz.y * 0.5 - 0.03), Vector3(ww, 0.72, 0.06), "office_blue", false)
\t\t\t\tb.box(Vector3(c.x, wy, c.y + sz.y * 0.5 + 0.03), Vector3(ww, 0.72, 0.06), "office_blue", false)
\t\trects.append([c, Vector2(sz.x * 0.5, sz.y * 0.5), 0.0, Color(0.45, 0.36, 0.3, 0.7)])
\t\tvar site := {"pos": Vector3(c.x, 0.0, c.y + sz.y * 0.5 + 1.6), "name": str(bd.get("name", "")), "h": h, "size": sz}
\t\tsites.append(site)

'''
s = s[:start] + new + s[end:]
# houses must use the reserved footprints
s = s.replace('''\tfor k in 6:
\t\tvar pick_site: Dictionary = named[k % named.size()] if not named.is_empty() else sites[(k * 13) % sites.size()]''',
'''\tvar house_bds: Array = house_src.values()
\tfor k in mini(6, house_bds.size()):
\t\tvar pick_bd: Dictionary = house_bds[k]
\t\tvar pp2: Array = pick_bd["pts"]
\t\tvar lo2 := Vector2(INF, INF)
\t\tvar hi2 := Vector2(-INF, -INF)
\t\tfor q2 in pp2:
\t\t\tvar v2 := Vector2(q2[0], q2[1])
\t\t\tlo2 = lo2.min(v2)
\t\t\thi2 = hi2.max(v2)
\t\tvar c2 := (lo2 + hi2) * 0.5
\t\tvar pick_site: Dictionary = {"pos": Vector3(c2.x, 0.0, c2.y + 4.0), "name": str(pick_bd.get("name", "")),
\t\t\t"h": float(pick_bd.get("h", 8.0)), "size": hi2 - lo2}''')
open(p, 'w', encoding='utf-8').write(s)
print('map density patched')
