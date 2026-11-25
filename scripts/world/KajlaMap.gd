extends RefCounted
## Real-world Kajla, Dhaka from OpenStreetMap footprints + the stitched OSM
## raster tile image.  Buildings are extruded at OSM heights with Dhaka-style
## brick / plaster / tin facades; several are fully walk-in with doorways and
## interior floors so guards can patrol inside them.

const LevelBuilder := preload("res://scripts/world/LevelBuilder.gd")

const WALL_MATS := ["brick", "brick_old", "plaster_cream", "plaster_blue", "plaster_green",
	"plaster_yellow", "plaster_white", "kahn", "office", "concrete"]
const ROOF_MATS := ["tin_rust", "tin", "concrete", "tin_blue"]
## Each mission is a different tactical sector of the same real Kajla map.
const ZONES := {
	"north":   {"c": Vector2(-185, -10), "r": 240.0, "spawn": Vector3(-330, 0.2, 78), "extract": Vector3(-250, 0.2, 110)},
	"south":   {"c": Vector2(-60, -190), "r": 260.0, "spawn": Vector3(-235, 0.2, 78), "extract": Vector3(85, 0.2, -255)},
	"park":    {"c": Vector2(210, -120), "r": 250.0, "spawn": Vector3(120, 0.2, 76), "extract": Vector3(330, 0.2, -60)},
	"highway": {"c": Vector2(60, 90), "r": 230.0, "spawn": Vector3(-175, 0.2, 78), "extract": Vector3(310, 0.2, 78)},
	"full":    {"c": Vector2(0, 0), "r": 420.0, "spawn": Vector3(-44, 0.2, 78), "extract": Vector3(250, 0.2, 76)},
	"rooftops": {"c": Vector2(120, -80), "r": 220.0, "spawn": Vector3(60, 0.2, 76), "extract": Vector3(250, 0.2, 40)},
	## The three Sontek colonies. Each is a dense block with its own shops.
	"sontek_north": {"c": Vector2(-185, -10), "r": 240.0, "spawn": Vector3(-330, 0.2, 78), "extract": Vector3(-250, 0.2, 110)},
	"sontek_south": {"c": Vector2(-60, -190), "r": 260.0, "spawn": Vector3(-235, 0.2, 78), "extract": Vector3(85, 0.2, -255)},
	"sontek_main":  {"c": Vector2(60, 90), "r": 230.0, "spawn": Vector3(-175, 0.2, 78), "extract": Vector3(310, 0.2, 78)},
}

## Colony names, in build order of the reserved walk-in houses.
const COLONIES := [
	{"name": "সনটেক উত্তর / Sontek North", "en": "Sontek North", "c": Vector2(-185, -10)},
	{"name": "সনটেক দক্ষিণ / Sontek South", "en": "Sontek South", "c": Vector2(-60, -190)},
	{"name": "সনটেক মূল সড়ক / Sontek Main Road", "en": "Sontek Main Road", "c": Vector2(60, 90)},
]
## 15-, 10-, 5-, 12- and 8-storey walk-in houses, repeated across the three colonies.
const HOUSE_FLOORS := [15, 12, 5, 10, 8, 6]
## Varied ground-floor businesses in the three colonies.
const SHOP_TYPES := ["pharmacy", "pharmacy", "arms", "grocery", "general", "clinic",
	"mobile", "arms", "pharmacy", "tea", "hardware", "general", "clinic", "grocery",
	"arms", "pharmacy", "mobile", "general", "tea", "hardware", "clinic", "grocery",
	"arms", "pharmacy", "general", "mobile", "clinic", "tea", "hardware", "pharmacy"]
## The only open ground in Sontek: the pond and the playing field.
const POND_CENTER := Vector2(-150.0, -330.0)
const POND_RADIUS := 44.0
const FIELD_CENTER := Vector2(225.0, -300.0)
const FIELD_HALF := Vector2(48.0, 34.0)


static func build(b, mission: int) -> Dictionary:
	var f := FileAccess.open("res://assets/maps/kajla.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	b.rng.seed = 4400 + mission
	b.bounds = Rect2(-420, -420, 840, 840)
	b.beach_style = false
	b.ground(Rect2(-420, -420, 840, 840), -0.06, "pavement")

	# ---------------- exact OSM roads ----------------
	for r in data.get("roads", []):
		var pts: Array = r["pts"]
		var width: float = float(r["w"])
		var road_mat := "asphalt" if str(r["kind"]).begins_with("primary") or str(r["kind"]) == "trunk" else "pavement"
		for i in range(pts.size() - 1):
			var a: Array = pts[i]
			var c: Array = pts[i + 1]
			var d := Vector2(c[0] - a[0], c[1] - a[1])
			var len := d.length()
			if len < 0.5:
				continue
			var mid := Vector2((a[0] + c[0]) * 0.5, (a[1] + c[1]) * 0.5)
			b.box(Vector3(mid.x, 0.015, mid.y), Vector3(width, 0.05, len + 0.4), road_mat, false, atan2(d.x, d.y))
		if str(r.get("name", "")) != "" and pts.size() > 1:
			var p0: Array = pts[pts.size() / 2]
			b.label(Vector3(p0[0], 4.4, p0[1]), 0.0, str(r["name"]), 30, Color(0.95, 0.9, 0.65), 0.006)

	# ---------------- Sontek roads ----------------
	# Main road: 9 m (four to five cars). Colony dividers: 3.6 m (two cars).
	# Internal lanes: 1.6 m - only a single car can squeeze through.
	b.box(Vector3(0.0, 0.02, 76.0), Vector3(820.0, 0.05, 9.0), "asphalt", false)
	for dx in [-110.0, 110.0]:
		b.box(Vector3(dx, 0.02, -70.0), Vector3(3.6, 0.05, 540.0), "asphalt", false)
	for ax in [-360.0, -330.0, -300.0, -270.0, -240.0, -210.0, -180.0, -150.0, -120.0, -90.0, -60.0, -30.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]:
		b.box(Vector3(ax, 0.02, -120.0), Vector3(1.6, 0.05, 390.0), "pavement", false)
	for az in [-270.0, -240.0, -210.0, -180.0, -150.0, -120.0, -90.0, -60.0, -30.0, 0.0, 30.0]:
		b.box(Vector3(0.0, 0.02, az), Vector3(820.0, 0.05, 1.6), "pavement", false)
	var fly_y := 8.5
	b.box(Vector3(0.0, fly_y, 76.0), Vector3(560.0, 0.9, 11.0), "concrete", true)
	b.ramp(Vector3(-350.0, 0.0, 76.0), Vector3(-280.0, fly_y, 76.0), 11.0, "concrete", 0.4)
	b.ramp(Vector3(280.0, fly_y, 76.0), Vector3(350.0, 0.0, 76.0), 11.0, "concrete", 0.4)
	for i in 23:
		var px := -275.0 + float(i) * 25.0
		b.box(Vector3(px, fly_y * 0.5, 76.0), Vector3(1.3, fly_y, 1.3), "concrete", true)
	for zz in [72.0, 80.0]:
		b.box(Vector3(0.0, fly_y + 0.52, zz), Vector3(550.0, 0.03, 0.16), "white", false)
	b.sign_board(Vector3(-60.0, fly_y + 3.2, 76.0), 0.0, "জাত্রাবাড়ি রোড flyover", 6.0, 1.0, "sign_green")
	b.sign_board(Vector3(190.0, 0.0, 66.0), PI, "আজিমপুর — কাজলা বাস স্টপ", 6.0, 1.0, "sign_blue")

	# ---------------- the two open spaces: Sontek pond and playing field ----------------
	b.box(Vector3(POND_CENTER.x, -0.02, POND_CENTER.y), Vector3(POND_RADIUS * 2.0, 0.08, POND_RADIUS * 2.0), "water", false)
	for i in 18:
		var a := float(i) / 18.0 * TAU
		b.box(Vector3(POND_CENTER.x + cos(a) * POND_RADIUS, 0.12, POND_CENTER.y + sin(a) * POND_RADIUS),
			Vector3(3.0, 0.24, 3.0), "brick", false)
	b.box(Vector3(FIELD_CENTER.x, 0.0, FIELD_CENTER.y), Vector3(FIELD_HALF.x * 2.0, 0.06, FIELD_HALF.y * 2.0), "grass", false)
	b.sign_board(Vector3(POND_CENTER.x, 0.0, POND_CENTER.y - POND_RADIUS - 3.0), 0.0,
		"সনটেক পুকুর  |  Sontek Pond", 5.0, 1.0, "sign_blue")
	b.sign_board(Vector3(FIELD_CENTER.x, 0.0, FIELD_CENTER.y - FIELD_HALF.y - 3.0), 0.0,
		"সনটেক মাঠ  |  Sontek Field", 5.0, 1.0, "sign_green")

	# ---------------- markets in every colony ----------------
	for m in COLONIES:
		var mc: Dictionary = m
		var ctr: Vector2 = mc.get("c", Vector2.ZERO)
		for s in 7:
			var sx := ctr.x - 18.0 + float(s) * 6.0
			var sz := ctr.y + 26.0 + float(s % 2) * 3.0
			b.stall(Vector3(sx, 0.0, sz), float(s) * 0.35)
		b.sign_board(Vector3(ctr.x, 0.0, ctr.y + 34.0), 0.0,
			"মার্কেট — " + str(mc.get("en", "Sontek")), 5.0, 1.0, "sign_blue")

	# ---------------- three Sontek colonies, separated by wider roads ----------------
	b.sign_board(Vector3(-250.0, 0.0, -30.0), 0.0, "সনটেক উত্তর  |  Sontek North", 7.0, 1.2, "sign_green")
	b.sign_board(Vector3(-30.0, 0.0, -205.0), 0.0, "সনটেক দক্ষিণ  |  Sontek South", 7.0, 1.2, "sign_blue")
	b.sign_board(Vector3(120.0, 0.0, 88.0), PI, "সনটেক মূল সড়ক  |  Sontek Main Road", 7.0, 1.2, "sign_green")
	# Narrow colony lanes: 1.7 m wide - two cars cannot pass side by side.
	for lx in [-330.0, -300.0, -270.0, -240.0, -210.0]:
		b.box(Vector3(lx, 0.025, -70.0), Vector3(1.7, 0.05, 210.0), "pavement", false)
	for lz in [-250.0, -220.0, -190.0, -160.0]:
		b.box(Vector3(-120.0, 0.025, lz), Vector3(330.0, 0.05, 1.7), "pavement", false)
	for mx in [-60.0, -10.0, 40.0, 90.0, 140.0]:
		b.box(Vector3(mx, 0.025, 62.0), Vector3(1.7, 0.05, 26.0), "pavement", false)

	# ---------------- exact OSM building footprints (dense Kajla) ----------------
	var rects: Array = []
	var sites: Array = []
	var all: Array = data.get("buildings", [])
	# Sontek is built solid: every real OSM footprint becomes a building except
	# the pond, the playing field and the roads.
	var step := 1

	# Reserve a few real OSM footprints for walk-in houses BEFORE drawing masses,
	# otherwise a solid box is drawn on top of the accessible house and blocks it.
	var house_src := {}
	var house_centers: Array = []
	var scan := 0
	for bd in all:
		scan += 1
		var pp: Array = bd["pts"]
		if pp.size() < 4:
			continue
		var lo0 := Vector2(INF, INF)
		var hi0 := Vector2(-INF, -INF)
		for q0 in pp:
			var v0 := Vector2(q0[0], q0[1])
			lo0 = lo0.min(v0)
			hi0 = hi0.max(v0)
		var c0 := (lo0 + hi0) * 0.5
		var sz0 := hi0 - lo0
		if sz0.x < 8.0 or sz0.y < 7.0 or sz0.x > 16.0 or sz0.y > 15.0:
			continue
		if absf(c0.x) > 330.0 or absf(c0.y) > 260.0:
			continue
		var far := true
		for hc in house_centers:
			if c0.distance_to(hc) < 28.0:
				far = false
				break
		if far:
			house_src[scan] = bd
			house_centers.append(c0)
		if house_src.size() >= 6:
			break

	var idx := 0
	var mass_walkins: Array = []
	var mass_boxes: Array = []
	var mass_wall_cols := [Color(0.55, 0.36, 0.3), Color(0.72, 0.68, 0.6), Color(0.4, 0.55, 0.65),
		Color(0.6, 0.55, 0.4), Color(0.5, 0.58, 0.45), Color(0.68, 0.65, 0.58)]
	var mass_roof_cols := [Color(0.3, 0.28, 0.26), Color(0.35, 0.34, 0.32), Color(0.28, 0.32, 0.32)]
	# Mass colony colliders use the vehicle layer: the hero collides with them,
	# but the navigation bake only processes the 30 detailed feature towers.
	b.collider_layer = Game.L_VEHICLE
	b.bodies.clear()
	for bd in all:
		if OS.get_environment("SKIP_MASS") == "1":
			break
		idx += 1
		if idx % step != 0 or house_src.has(idx):
			continue
		var pts: Array = bd["pts"]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in pts:
			var v := Vector2(p[0], p[1])
			lo = lo.min(v)
			hi = hi.max(v)
		var c := (lo + hi) * 0.5
		var sz := hi - lo
		if sz.x < 2.2 or sz.y < 2.2 or sz.x > 70.0 or sz.y > 70.0:
			continue
		if absf(c.x) > 400.0 or absf(c.y) > 400.0:
			continue
		# Keep the Sontek pond and the playing field clear of buildings.
		if c.distance_to(POND_CENTER) < POND_RADIUS:
			continue
		if absf(c.x - FIELD_CENTER.x) < FIELD_HALF.x and absf(c.y - FIELD_CENTER.y) < FIELD_HALF.y:
			continue
		var h := clampf(float(bd.get("h", 8.0)), 3.5, 22.0)
		var pick := (idx * 7 + mission * 3) % WALL_MATS.size()
		var wall: String = WALL_MATS[pick]
		var roof: String = ROOF_MATS[(idx + mission) % ROOF_MATS.size()]
		# Batched shell: one MultiMesh for the whole colony, with real wall
		# segments, window openings, floor slabs and a roof on every building.
		var bw := maxf(sz.x, 4.6)
		var bd2 := maxf(sz.y, 4.6)
		# 2-7 storeys for most blocks, a few 8-20 storey towers for the skyline.
		var nfloors: int = 2 + (idx % 6)
		if idx % 37 == 0:
			nfloors = 8 + (idx % 13)
		var side := "s" if idx % 2 == 0 else "n"
		var wc: Color = mass_wall_cols[pick % mass_wall_cols.size()]
		var rc: Color = mass_roof_cols[(idx + mission) % mass_roof_cols.size()]
		var fc := Color(0.42, 0.4, 0.36)
		var wins: Array = []
		var fps: Array = []
		mass_boxes.append({"p": Vector3(c.x, 0.05, c.y), "s": Vector3(bw, 0.1, bd2), "c": fc})
		for mf in nfloors:
			var fy: float = float(mf) * 3.2
			for sd in [-1.0, 1.0]:
				var wz: float = c.y + float(sd) * bd2 * 0.5
				var is_door: bool = mf == 0 and ((sd > 0.0 and side == "s") or (sd < 0.0 and side == "n"))
				var ow := 1.5 if is_door else 1.2
				var left := (bw - ow) * 0.5
				mass_boxes.append({"p": Vector3(c.x - (ow + left) * 0.5, fy + 1.5, wz), "s": Vector3(left, 3.0, 0.25), "c": wc})
				mass_boxes.append({"p": Vector3(c.x + (ow + left) * 0.5, fy + 1.5, wz), "s": Vector3(left, 3.0, 0.25), "c": wc})
				if mf < 3:  # detailed lower floors: sill and lintel
					if not is_door:
						mass_boxes.append({"p": Vector3(c.x, fy + 0.5, wz), "s": Vector3(ow, 1.0, 0.25), "c": wc})
					mass_boxes.append({"p": Vector3(c.x, fy + 2.65, wz), "s": Vector3(ow, 1.1, 0.25), "c": wc})
				wins.append({"out": Vector3(c.x, fy + 1.6, wz + sd * 0.8), "in": Vector3(c.x, fy + 1.6, wz - sd * 0.8)})
			fps.append(Vector3(c.x, fy + 0.2, c.y))
			# Visible staircase treads on EVERY floor plus a full-height lift shaft.
			for st in 2:
				var t: float = float(st) / 2.0
				mass_boxes.append({"p": Vector3(c.x + bw * 0.32, fy + 0.5 + t * 2.6, c.y + bd2 * 0.25 - t * bd2 * 0.5),
					"s": Vector3(1.1, 0.18, 0.5), "c": fc})
			if mf < nfloors - 1:
				mass_boxes.append({"p": Vector3(c.x, fy + 3.2, c.y), "s": Vector3(bw, 0.18, bd2), "c": fc})
		var roof_y := float(nfloors) * 3.2
		for sx in [-1.0, 1.0]:
			mass_boxes.append({"p": Vector3(c.x + sx * bw * 0.5, roof_y * 0.5, c.y), "s": Vector3(0.25, roof_y, bd2), "c": wc})
		mass_boxes.append({"p": Vector3(c.x + bw * 0.32, roof_y * 0.5, c.y - bd2 * 0.3),
			"s": Vector3(1.5, roof_y, 1.5), "c": Color(0.2, 0.24, 0.22)})
		mass_boxes.append({"p": Vector3(c.x, roof_y + 0.1, c.y), "s": Vector3(bw + 0.25, 0.2, bd2 + 0.25), "c": rc})
		var door_out := Vector3(c.x, 0.0, c.y + (bd2 * 0.5 + 1.2 if side == "s" else -bd2 * 0.5 - 1.2))
		var roof_pt := Vector3(c.x, roof_y + 0.2, c.y)
		var all_stops: Array = fps.duplicate(true)
		all_stops.append(roof_pt)
		mass_walkins.append({"pos": door_out, "inside": fps[0], "floors_pts": fps,
			"roof": roof_pt, "stops": all_stops, "windows": wins,
			"floors": nfloors, "simple": true, "label": "ভবন " + str(idx) + " — প্রবেশ / তলা / ছাদ"})
		rects.append([c, Vector2(sz.x * 0.5, sz.y * 0.5), 0.0, Color(0.45, 0.36, 0.3, 0.7)])
		var site := {"pos": Vector3(c.x, 0.0, c.y + sz.y * 0.5 + 1.6), "name": str(bd.get("name", "")), "h": h, "size": sz}
		sites.append(site)

	# Restore navmesh layer for the feature towers and street props.
	b.collider_layer = 1
	b.bodies.clear()

	# ---------------- real multi-storey Kajla houses ----------------
	# LevelBuilder.house() gives a door opening, partition walls, window grills,
	# floor slabs with a stairwell, physical stairs between every floor, and a
	# roof with a stair hut / water tank.  Hero and guards can walk all of it.
	var houses: Array = []
	var ref_panels := ["ref_room_a.jpg", "ref_living.jpg", "ref_bed_a.jpg", "ref_doorway.jpg", "ref_balcony_a.jpg"]
	var house_bds: Array = house_src.values()
	for k in mini(6, house_bds.size()):
		var pick_bd: Dictionary = house_bds[k]
		var pp2: Array = pick_bd["pts"]
		var lo2 := Vector2(INF, INF)
		var hi2 := Vector2(-INF, -INF)
		for q2 in pp2:
			var v2 := Vector2(q2[0], q2[1])
			lo2 = lo2.min(v2)
			hi2 = hi2.max(v2)
		var c2 := (lo2 + hi2) * 0.5
		var pick_site: Dictionary = {"pos": Vector3(c2.x, 0.0, c2.y + 4.0), "name": str(pick_bd.get("name", "")),
			"h": float(pick_bd.get("h", 8.0)), "size": hi2 - lo2}
		var sz2: Vector2 = pick_site.get("size", Vector2(10, 9))
		var w := clampf(sz2.x, 9.0, 12.5)
		var d := clampf(sz2.y, 8.0, 10.5)
		# 5-, 8-, 10-, 12- and 15-storey houses; every floor and the roof is walkable.
		var floors: int = HOUSE_FLOORS[k % HOUSE_FLOORS.size()]
		var side := "s" if k % 2 == 0 else "n"
		var info: Dictionary = b.house(c2.x, c2.y, w, d, floors,
			WALL_MATS[(k * 3 + 1) % WALL_MATS.size()], side, 0.0)
		# real interior photos from Image.pdf pasted on the room walls
		_photo_panel(b, ref_panels[k % ref_panels.size()], (info["room_g"] as Vector3) + Vector3(0, 1.35, -d * 0.5 + 0.32), 0.0)
		_photo_panel(b, ref_panels[(k + 2) % ref_panels.size()], (info["room_up"] as Vector3) + Vector3(0, 1.35, -d * 0.5 + 0.32), 0.0)
		_photo_panel(b, "ref_grill_window.jpg", (info["room_g2"] as Vector3) + Vector3(0, 1.35, d * 0.5 - 0.32), PI)
		b.sign_board(info["door_out"] + Vector3(0, 2.7, 0), 0.0,
			str(pick_site.get("name", "কাজলা বাড়ি")), 3.2, 0.7, "sign_blue")
		houses.append({"pos": info["door_out"], "inside": info["room_g"],
			"up": info["room_up"], "roof": info["roof_pad"],
			"stairs": info["stair_foot"], "name": str(pick_site.get("name", "")),
			"floors": floors, "colony": str((COLONIES[mini(k / 3, 2)] as Dictionary)["name"]),
			"lifts": info.get("lift_positions", []),
			"windows": info.get("window_positions", [])})


	# ---------------- roof-to-roof bridges between neighbouring towers ----------------
	# Plank walks let the hero run or jump from one roof to the next. Descend via
	# the roof hut door -> stairs -> ground-floor door -> street.
	for i in range(houses.size() - 1):
		var a: Vector3 = houses[i]["roof"]
		var c: Vector3 = houses[i + 1]["roof"]
		var flat := Vector2(c.x - a.x, c.z - a.z)
		var span := flat.length()
		if span < 8.0 or span > 46.0 or absf(c.y - a.y) > 4.0:
			continue
		var mid := Vector3((a.x + c.x) * 0.5, (a.y + c.y) * 0.5, (a.z + c.z) * 0.5)
		var yaw := atan2(flat.x, flat.y)
		b.box(mid, Vector3(1.4, 0.18, span + 1.2), "wood", true, yaw)
		for side in [-1.0, 1.0]:
			var perp := Vector2(-flat.y, flat.x).normalized() * 0.72
			b.box(mid + Vector3(perp.x, 0.5, perp.y), Vector3(0.08, 0.08, span + 1.2), "metal_dark", false, yaw)

	# ---------------- street life and drivable vehicles ----------------
	for i in range(0, sites.size(), 8):
		var s: Dictionary = sites[i]
		var p: Vector3 = s["pos"]
		b.crate(p + Vector3(b.rng.randf_range(-3, 3), 0, -2.0), 1.0)
	for i in range(0, sites.size(), 13):
		b.tree((sites[i]["pos"] as Vector3) + Vector3(2.0, 0, 1.0), 1.0)

	var vehicles: Array = []
	for i in 9:
		var kinds := ["car", "cng", "pickup", "rickshaw", "car", "cng", "pickup", "car", "rickshaw"]
		vehicles.append({"kind": kinds[i], "pos": Vector3(-310.0 + float(i) * 78.0, 0, 76.0 + float(i % 3) * 22.0),
			"yaw": PI * 0.5 if i % 2 == 0 else -PI * 0.5})
	# real OSM landmarks visible from the street
	b.sign_board(Vector3(-202.0, 0, 68.0), 0.0, "কাজলা বাস স্টপ  |  Kajla Bus Stop", 6.0, 1.0, "sign_green")
	b.sign_board(Vector3(-38.0, 0, 70.0), PI, "কাজলা, মোহাম্মদপুর — ঢাকা", 7.0, 1.2, "sign_blue")
	b.sign_board(Vector3(96.0, 0, 69.0), PI, "সনটেক কাজলা সেক্টর", 6.0, 1.0, "sign_green")
	b.sign_board(Vector3(150.0, 0, -60.0), 0.0, "কাজলা পার্ক  |  Kajla Park", 5.0, 1.0, "sign_green")
	b.barrier(Vector3(-410, 0, -410), Vector3(410, 0, -410), 6.0)
	b.barrier(Vector3(-410, 0, 410), Vector3(410, 0, 410), 6.0)
	b.barrier(Vector3(-410, 0, -410), Vector3(-410, 0, 410), 6.0)
	b.barrier(Vector3(410, 0, -410), Vector3(410, 0, 410), 6.0)

	# ---------------- mission anchors: ten spread-out real sites ----------------
	var zone_name := str(Game.mission_data(mission).get("zone", "full"))
	var zone: Dictionary = ZONES.get(zone_name, ZONES["full"])
	var spawn: Vector3 = zone["spawn"]
	var extract: Vector3 = zone["extract"]
	var zc: Vector2 = zone["c"]
	var zr: float = float(zone["r"])
	var candidates: Array = []
	for s in sites:
		var p: Vector3 = s["pos"]
		if Vector2(p.x, p.z).distance_to(zc) < zr and p.distance_to(spawn) > 22.0:
			candidates.append(s)
	var picked: Array = []
	var min_gap := 22.0
	for s in candidates:
		var p: Vector3 = s["pos"]
		var ok := true
		for q in picked:
			if p.distance_to(q["pos"] as Vector3) < min_gap:
				ok = false
				break
		if ok:
			picked.append(s)
		if picked.size() >= 18:
			break
	while picked.size() < 18:
		var k := picked.size()
		picked.append({"pos": Vector3(-150.0 + float(k) * 26.0, 0.0, -40.0 - float(k % 3) * 40.0), "name": ""})

	var enemies: Array = []
	var enemy_kinds := ["rifle", "pistol", "scout", "swat", "gunner", "marksman", "rifle", "swat", "scout", "gunner", "marksman", "rifle",
		"swat", "scout", "gunner", "marksman", "rifle", "pistol"]
	for i in range(mini(18, picked.size())):
		var p: Vector3 = picked[i]["pos"]
		var tag := ""
		if i == 4 or i == 9 or i == 14:
			tag = "commander"
		enemies.append({"pos": p + Vector3(3.5, 0, 2.0), "kind": enemy_kinds[i % enemy_kinds.size()],
			"patrol": [p + Vector3(12, 0, 6), p + Vector3(-12, 0, -6)], "tag": tag})
	for h in houses:
		var hp: Vector3 = h["inside"]
		enemies.append({"pos": hp, "kind": "rifle", "patrol": [hp + Vector3(1.8, 0, 1.0), hp + Vector3(-1.8, 0, -1.0)]})
		var up: Vector3 = h.get("up", hp)
		enemies.append({"pos": up, "kind": "pistol", "patrol": [up + Vector3(1.5, 0, 0.8), up + Vector3(-1.5, 0, -0.8)]})
		var roof: Vector3 = h.get("roof", hp)
		enemies.append({"pos": roof, "kind": "swat", "patrol": [roof + Vector3(1.6, 0, 1.0), roof + Vector3(-1.6, 0, -1.0)]})
	enemies.append({"pos": Vector3(-120, 0, 76), "kind": "rifle", "patrol": [Vector3(-170, 0, 76), Vector3(-60, 0, 76)]})
	enemies.append({"pos": Vector3(40, 0, 76), "kind": "pistol", "patrol": [Vector3(10, 0, 76), Vector3(90, 0, 76)]})
	enemies.append({"pos": Vector3(-10, 0, -40), "kind": "sniper", "patrol": []})

	# ---------------- colony shops / pharmacies (ground-floor frontages) ----------------
	var shops: Array = []
	var shop_labels := {"pharmacy": "ফার্মাসি", "clinic": "ক্লিনিক", "arms": "অস্ত্রের দোকান",
		"grocery": "মুদি দোকান", "general": "জেনারেল স্টোর", "mobile": "মোবাইল দোকান",
		"tea": "চায়ের দোকান", "hardware": "হার্ডওয়্যার"}
	for i in 30:
		var h: Dictionary = houses[i % houses.size()]
		var hp: Vector3 = h["pos"]
		var stype: String = SHOP_TYPES[i % SHOP_TYPES.size()]
		var kind := "pharmacy" if stype in ["pharmacy", "clinic"] else "shop"
		var label: String = shop_labels.get(stype, "দোকান")
		shops.append({"kind": kind, "type": stype, "pos": hp + Vector3(2.8, 0.0, 1.4), "yaw": 0.0,
			"name": label + " " + str(i + 1), "colony": str((COLONIES[mini(i / 3, 2)] as Dictionary)["name"])})

	# ---------------- neutral forces: at least 40 of every kind ----------------
	var neutrals: Array = []
	# Military: ten squads of four; a squad retaliates as one.
	for squad in 10:
		var sq: Dictionary = sites[(squad * 3 + 3) % sites.size()]
		var sp: Vector3 = sq["pos"]
		for j in 4:
			neutrals.append({"pos": sp + Vector3(float(j) * 2.2 - 3.0, 0.0, 1.5 + float(j % 2)),
				"kind": "swat", "faction": "military", "neutral": true, "simple_model": true, "slot_role": "ally",
				"group": "military_" + str(squad),
				"patrol": [sp + Vector3(10, 0, 4), sp + Vector3(-10, 0, -4)]})
	# Police: 40 armed individuals across colonies and main road.
	for i in 40:
		var pp: Vector3 = sites[(i * 7 + 1) % sites.size()]["pos"]
		neutrals.append({"pos": pp + Vector3(float(i % 5) * 1.4 - 2.8, 0.0, -1.2 - float(i % 3)),
			"kind": "pistol", "faction": "police", "neutral": true, "simple_model": true, "slot_role": "ally",
			"patrol": [pp + Vector3(8, 0, 2), pp + Vector3(-8, 0, -2)]})
	# Air force: 40 airmen. Killing one calls two bombs down on the attacker.
	for i in 40:
		var ap: Vector3 = sites[(i * 5 + 2) % sites.size()]["pos"]
		neutrals.append({"pos": ap + Vector3(float(i % 4) * 1.6 - 2.4, 0.0, 2.2),
			"kind": "airforce", "faction": "airforce", "neutral": true, "simple_model": true, "slot_role": "ally",
			"patrol": [ap + Vector3(9, 0, 3), ap + Vector3(-9, 0, -3)]})
	# Naval commandos: four teams of ten, retaliate when attacked.
	for team in 4:
		var np: Vector3 = sites[(team * 9 + 4) % sites.size()]["pos"]
		for j in 10:
			neutrals.append({"pos": np + Vector3(float(j) * 1.7 - 8.5, 0.0, 2.0 + float(j % 2)),
				"kind": "naval", "faction": "naval", "neutral": true, "simple_model": true, "slot_role": "ally",
				"group": "naval_" + str(team),
				"patrol": [np + Vector3(12, 0, 5), np + Vector3(-12, 0, -5)]})
	# Army commandos: lone bombers who answer any attack with a heavy bomb.
	for i in 4:
		var cp: Vector3 = sites[(i * 11 + 6) % sites.size()]["pos"]
		neutrals.append({"pos": cp + Vector3(-2.0, 0.0, 2.0), "kind": "heavy", "faction": "commando",
			"neutral": true, "simple_model": true, "bomb_thrower": true, "slot_role": "villain", "stationary": false,
			"patrol": [cp + Vector3(6, 0, 3), cp + Vector3(-6, 0, -3)]})
	# One man in full white punjabi: only fights when a civilian is attacked.
	var wp: Vector3 = sites[7 % sites.size()]["pos"]
	neutrals.append({"pos": wp + Vector3(3.0, 0.0, 2.0), "kind": "protector", "faction": "protector",
		"neutral": true, "simple_model": true, "slot_role": "ally", "patrol": [wp + Vector3(8, 0, 3), wp + Vector3(-8, 0, -3)]})

	# Kishor gangs: knife-wielding groups of three, hostile to everyone including civilians.
	var gangs: Array = []
	for g in 6:
		var gp: Vector3 = sites[(g * 13 + 8) % sites.size()]["pos"]
		for j in 3:
			gangs.append({"pos": gp + Vector3(float(j) * 1.6 - 2.0, 0.0, -2.0),
				"kind": "kishor", "faction": "kishor", "slot_role": "villain", "simple_model": true,
				"group": "kishor_" + str(g),
				"patrol": [gp + Vector3(14, 0, 6), gp + Vector3(-14, 0, -6)]})

	# ---------------- ordinary people who can be hurt or killed ----------------
	var civilians: Array = []
	for i in 200:
		var s: Dictionary = sites[(i * 3 + 2) % sites.size()]
		var p: Vector3 = s["pos"]
		civilians.append({"pos": p + Vector3(float(i % 4) * 1.6 - 2.4, 0.0, -2.0),
			"yaw": float(i) * 0.7, "patrol": [p + Vector3(6, 0, 3), p + Vector3(-6, 0, -3)]})

	return {
		"spawn": spawn, "yaw": PI * 0.5, "extract": extract,
		"sites": picked, "enemies": enemies, "houses": houses, "vehicles": vehicles,
		"shops": shops, "civilians": civilians, "colonies": COLONIES,
		"neutrals": neutrals, "gangs": gangs, "mass_boxes": mass_boxes,
		"mass_walkins": mass_walkins,
		"map_rects": rects, "cover_points": b.cover_points,
		"safe_zone": extract, "safe_radius": 7.0, "water_y": -30.0,
		"buildings": sites.size(),
	}


static func _photo_panel(b, file: String, pos: Vector3, yaw: float) -> void:
	var tex := load("res://assets/textures/ref/" + file) as Texture2D
	if tex == null:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 1.6)
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	b.deco.add_child(mi)
