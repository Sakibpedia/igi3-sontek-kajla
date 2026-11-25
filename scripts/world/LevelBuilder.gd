extends RefCounted
## Procedural level geometry for low-end GPUs.
## - Every box/cylinder is recorded, then merged into ONE mesh per material per 24 m chunk (few draw calls).
## - "Baked lighting": street-lamp light and ambient occlusion are computed once at load time and stored
##   in vertex colours (rgb = lamp light, a = AO). Zero runtime cost, works on any Intel iGPU.
## - Collision uses simple BoxShape3D / CylinderShape3D grouped into StaticBody3D per bullet material,
##   so bullets can penetrate wood / tin / glass but not brick or concrete.

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const CHUNK := 24.0
const SUB := 3.0

# name: [albedo, albedo2, pattern, roughness, pattern_scale, physics material, metallic, emission]
const MATS := {
	"asphalt": [Color(0.17, 0.17, 0.18), Color(0.42, 0.42, 0.44), 6, 0.92, 1.0, "concrete"],
	"pavement": [Color(0.5, 0.48, 0.44), Color(0.32, 0.31, 0.29), 2, 0.9, 1.0, "concrete"],
	"dirt": [Color(0.4, 0.31, 0.22), Color(0.3, 0.24, 0.17), 0, 1.0, 1.0, "concrete"],
	"mud": [Color(0.28, 0.22, 0.16), Color(0.2, 0.16, 0.12), 0, 0.5, 1.0, "concrete"],
	"grass": [Color(0.24, 0.4, 0.17), Color(0.18, 0.3, 0.12), 0, 1.0, 1.0, "concrete"],
	"brick": [Color(0.56, 0.25, 0.16), Color(0.62, 0.58, 0.52), 1, 0.92, 1.0, "concrete"],
	"brick_old": [Color(0.44, 0.21, 0.15), Color(0.36, 0.34, 0.31), 1, 0.95, 1.0, "concrete"],
	"plaster_cream": [Color(0.78, 0.72, 0.58), Color(0.45, 0.42, 0.36), 7, 0.95, 1.0, "concrete"],
	"plaster_blue": [Color(0.46, 0.6, 0.7), Color(0.33, 0.37, 0.4), 7, 0.95, 1.0, "concrete"],
	"plaster_green": [Color(0.5, 0.66, 0.5), Color(0.34, 0.38, 0.33), 7, 0.95, 1.0, "concrete"],
	"plaster_pink": [Color(0.8, 0.56, 0.56), Color(0.45, 0.38, 0.38), 7, 0.95, 1.0, "concrete"],
	"plaster_yellow": [Color(0.86, 0.72, 0.36), Color(0.5, 0.45, 0.32), 7, 0.95, 1.0, "concrete"],
	"plaster_white": [Color(0.86, 0.85, 0.8), Color(0.55, 0.54, 0.5), 7, 0.95, 1.0, "concrete"],
	"concrete": [Color(0.56, 0.56, 0.54), Color(0.42, 0.42, 0.41), 2, 0.9, 0.5, "concrete"],
	"concrete_dark": [Color(0.35, 0.35, 0.34), Color(0.26, 0.26, 0.26), 2, 0.9, 0.5, "concrete"],
	"office": [Color(0.74, 0.7, 0.62), Color(0.16, 0.22, 0.3), 3, 0.85, 1.0, "concrete"],
	"office_blue": [Color(0.55, 0.62, 0.7), Color(0.12, 0.2, 0.32), 3, 0.8, 1.0, "concrete"],
	"glass_tower": [Color(0.3, 0.4, 0.48), Color(0.1, 0.18, 0.28), 3, 0.35, 1.0, "concrete"],
	"tin": [Color(0.52, 0.53, 0.55), Color(0.4, 0.4, 0.4), 4, 0.55, 1.0, "metal", 0.3],
	"tin_rust": [Color(0.52, 0.33, 0.2), Color(0.4, 0.3, 0.2), 4, 0.8, 1.0, "metal", 0.2],
	"tin_blue": [Color(0.25, 0.4, 0.6), Color(0.2, 0.3, 0.45), 4, 0.6, 1.0, "metal", 0.2],
	"wood": [Color(0.44, 0.29, 0.17), Color(0.33, 0.22, 0.13), 4, 0.9, 1.0, "wood"],
	"wood_dark": [Color(0.27, 0.18, 0.11), Color(0.2, 0.13, 0.08), 4, 0.9, 1.0, "wood"],
	"crate": [Color(0.55, 0.42, 0.25), Color(0.4, 0.3, 0.18), 4, 0.9, 1.0, "wood"],
	"ship_white": [Color(0.88, 0.88, 0.86), Color(0.6, 0.6, 0.58), 7, 0.6, 1.0, "metal"],
	"ship_red": [Color(0.7, 0.14, 0.12), Color(0.45, 0.12, 0.1), 7, 0.6, 1.0, "metal"],
	"ship_green": [Color(0.16, 0.45, 0.3), Color(0.12, 0.3, 0.2), 7, 0.6, 1.0, "metal"],
	"ship_blue": [Color(0.15, 0.3, 0.6), Color(0.1, 0.2, 0.4), 7, 0.6, 1.0, "metal"],
	"rust": [Color(0.42, 0.24, 0.15), Color(0.3, 0.17, 0.1), 7, 0.85, 1.0, "metal", 0.2],
	"container_red": [Color(0.65, 0.18, 0.12), Color(0.45, 0.14, 0.1), 4, 0.7, 1.0, "metal", 0.2],
	"container_blue": [Color(0.15, 0.32, 0.55), Color(0.1, 0.22, 0.4), 4, 0.7, 1.0, "metal", 0.2],
	"container_green": [Color(0.2, 0.42, 0.25), Color(0.14, 0.3, 0.18), 4, 0.7, 1.0, "metal", 0.2],
	"water": [Color(0.07, 0.13, 0.15), Color(0.15, 0.23, 0.25), 5, 0.06, 0.25, "water"],
	"water_lake": [Color(0.1, 0.22, 0.24), Color(0.2, 0.34, 0.32), 5, 0.06, 0.25, "water"],
	"red_fort": [Color(0.62, 0.28, 0.18), Color(0.7, 0.62, 0.5), 1, 0.9, 0.7, "concrete"],
	"marble": [Color(0.9, 0.88, 0.84), Color(0.76, 0.73, 0.69), 2, 0.4, 1.0, "concrete"],
	"kahn": [Color(0.62, 0.6, 0.56), Color(0.92, 0.9, 0.86), 8, 0.85, 1.0, "concrete"],
	"tarmac": [Color(0.26, 0.26, 0.27), Color(0.5, 0.5, 0.5), 6, 0.9, 1.0, "concrete"],
	"plane_white": [Color(0.9, 0.91, 0.93), Color(0.7, 0.72, 0.75), 0, 0.4, 1.0, "metal", 0.3],
	"plane_green": [Color(0.0, 0.42, 0.3), Color(0.0, 0.3, 0.2), 0, 0.4, 1.0, "metal", 0.3],
	"mall_floor": [Color(0.84, 0.82, 0.78), Color(0.6, 0.58, 0.55), 2, 0.22, 0.5, "concrete"],
	"mall_wall": [Color(0.86, 0.84, 0.8), Color(0.7, 0.68, 0.65), 0, 0.6, 1.0, "concrete"],
	"shopfront": [Color(0.32, 0.42, 0.52), Color(0.6, 0.75, 0.85), 3, 0.2, 1.0, "glass"],
	"glass": [Color(0.45, 0.6, 0.7), Color(0.3, 0.45, 0.55), 0, 0.1, 1.0, "glass"],
	"foliage": [Color(0.17, 0.33, 0.13), Color(0.1, 0.22, 0.08), 0, 1.0, 1.0, "cloth"],
	"foliage_dark": [Color(0.1, 0.24, 0.1), Color(0.07, 0.16, 0.06), 0, 1.0, 1.0, "cloth"],
	"trunk": [Color(0.3, 0.22, 0.15), Color(0.2, 0.15, 0.1), 4, 1.0, 1.0, "wood"],
	"metal_dark": [Color(0.12, 0.12, 0.13), Color(0.08, 0.08, 0.08), 0, 0.5, 1.0, "metal", 0.5],
	"metal_grey": [Color(0.46, 0.47, 0.49), Color(0.3, 0.3, 0.32), 0, 0.5, 1.0, "metal", 0.5],
	"rubber": [Color(0.05, 0.05, 0.05), Color(0.03, 0.03, 0.03), 0, 0.9, 1.0, "metal"],
	"fabric_red": [Color(0.75, 0.1, 0.12), Color(0.55, 0.08, 0.1), 0, 1.0, 1.0, "cloth"],
	"fabric_blue": [Color(0.12, 0.3, 0.7), Color(0.1, 0.2, 0.5), 0, 1.0, 1.0, "cloth"],
	"fabric_yellow": [Color(0.92, 0.72, 0.12), Color(0.7, 0.55, 0.1), 0, 1.0, 1.0, "cloth"],
	"fabric_green": [Color(0.1, 0.5, 0.25), Color(0.08, 0.35, 0.18), 0, 1.0, 1.0, "cloth"],
	"fabric_orange": [Color(0.92, 0.42, 0.1), Color(0.7, 0.3, 0.08), 0, 1.0, 1.0, "cloth"],
	"fabric_pink": [Color(0.9, 0.3, 0.55), Color(0.7, 0.2, 0.4), 0, 1.0, 1.0, "cloth"],
	"white": [Color(0.9, 0.9, 0.88), Color(0.8, 0.8, 0.78), 0, 0.8, 1.0, "concrete"],
	"yellow_line": [Color(0.86, 0.7, 0.12), Color(0.86, 0.7, 0.12), 0, 0.8, 1.0, "concrete"],
	"black": [Color(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05), 0, 0.8, 1.0, "metal"],
	"lamp": [Color(1.0, 0.9, 0.65), Color(1.0, 0.9, 0.65), 0, 0.5, 1.0, "glass", 0.0, 3.0],
	"lamp_white": [Color(0.85, 0.92, 1.0), Color(0.85, 0.92, 1.0), 0, 0.5, 1.0, "glass", 0.0, 3.0],
	"neon_green": [Color(0.2, 1.0, 0.4), Color(0.2, 1.0, 0.4), 0, 0.5, 1.0, "glass", 0.0, 2.0],
	"neon_red": [Color(1.0, 0.2, 0.2), Color(1.0, 0.2, 0.2), 0, 0.5, 1.0, "glass", 0.0, 2.0],
	"sign_green": [Color(0.08, 0.42, 0.22), Color(0.06, 0.3, 0.16), 0, 0.7, 1.0, "metal"],
	"sign_red": [Color(0.7, 0.1, 0.1), Color(0.5, 0.08, 0.08), 0, 0.7, 1.0, "metal"],
	"sign_blue": [Color(0.1, 0.22, 0.55), Color(0.08, 0.15, 0.4), 0, 0.7, 1.0, "metal"],
	"police_blue": [Color(0.12, 0.2, 0.45), Color(0.9, 0.9, 0.9), 0, 0.5, 1.0, "metal", 0.2],
	"cng_green": [Color(0.12, 0.5, 0.22), Color(0.08, 0.35, 0.15), 0, 0.5, 1.0, "metal", 0.2],
	"bus_red": [Color(0.72, 0.12, 0.1), Color(0.5, 0.1, 0.08), 7, 0.6, 1.0, "metal", 0.2],
	"bus_green": [Color(0.15, 0.45, 0.25), Color(0.1, 0.3, 0.18), 7, 0.6, 1.0, "metal", 0.2],
	"bus_blue": [Color(0.18, 0.3, 0.6), Color(0.12, 0.2, 0.4), 7, 0.6, 1.0, "metal", 0.2],
	"sandbag": [Color(0.56, 0.5, 0.38), Color(0.45, 0.4, 0.3), 2, 1.0, 2.0, "concrete"],
	"veg_green": [Color(0.25, 0.6, 0.15), Color(0.15, 0.45, 0.1), 0, 1.0, 1.0, "cloth"],
	"veg_orange": [Color(0.95, 0.5, 0.1), Color(0.8, 0.4, 0.08), 0, 1.0, 1.0, "cloth"],
	"veg_red": [Color(0.8, 0.12, 0.1), Color(0.6, 0.1, 0.08), 0, 1.0, 1.0, "cloth"],
	"veg_yellow": [Color(0.95, 0.85, 0.2), Color(0.8, 0.7, 0.15), 0, 1.0, 1.0, "cloth"],
	"fish": [Color(0.7, 0.72, 0.75), Color(0.5, 0.52, 0.55), 0, 0.3, 1.0, "cloth"],
	"invisible": [Color(0, 0, 0), Color(0, 0, 0), 0, 1.0, 1.0, "concrete"],
	# Cox's Bazar coast
	"sand": [Color(0.86, 0.78, 0.6), Color(0.77, 0.69, 0.52), 2, 1.0, 2.0, "concrete"],
	"sand_wet": [Color(0.6, 0.53, 0.4), Color(0.52, 0.46, 0.34), 2, 0.55, 2.0, "concrete"],
	"water_sea": [Color(0.07, 0.26, 0.32), Color(0.24, 0.45, 0.5), 5, 0.05, 0.22, "water"],
	"rock": [Color(0.38, 0.37, 0.34), Color(0.27, 0.27, 0.25), 2, 0.95, 1.4, "concrete"],
	"plaster_aqua": [Color(0.5, 0.78, 0.76), Color(0.36, 0.44, 0.43), 7, 0.95, 1.0, "concrete"],
	"plaster_coral": [Color(0.93, 0.58, 0.47), Color(0.48, 0.38, 0.35), 7, 0.95, 1.0, "concrete"],
	"plaster_sky": [Color(0.62, 0.78, 0.92), Color(0.4, 0.45, 0.5), 7, 0.95, 1.0, "concrete"],
	"plaster_lime": [Color(0.78, 0.86, 0.5), Color(0.45, 0.48, 0.36), 7, 0.95, 1.0, "concrete"],
	"container_orange": [Color(0.85, 0.42, 0.12), Color(0.6, 0.3, 0.1), 4, 0.7, 1.0, "metal", 0.2],
	"container_white": [Color(0.86, 0.86, 0.84), Color(0.62, 0.62, 0.6), 4, 0.7, 1.0, "metal", 0.2],
	"fabric_white": [Color(0.94, 0.93, 0.9), Color(0.82, 0.8, 0.76), 0, 1.0, 1.0, "cloth"],
	"thatch": [Color(0.62, 0.5, 0.3), Color(0.48, 0.38, 0.22), 4, 1.0, 1.0, "wood"],
}

var root: Node3D
var deco: Node3D
var quality := 1
var night := false
var bodies := {}
var boxes: Array = []
var cyls: Array = []
var domes: Array = []
var lamps: Array = []
var cover_points: Array = []
var materials := {}
var rng := RandomNumberGenerator.new()
var bounds := Rect2(-90, -90, 180, 180)
var light_count := 0
var max_lights := 16
## Cox's Bazar: beach houses (house()) skip the steel window grills and get a veranda roof at the door
var beach_style := false
var _chunks := {}
var _occ := PackedByteArray()
var _occ_w := 0
var _occ_h := 0
var _occ_min := Vector2.ZERO


func _init(p_root: Node3D, p_deco: Node3D, p_quality: int) -> void:
	root = p_root
	deco = p_deco
	quality = p_quality
	max_lights = [0, 14, 24][clampi(quality, 0, 2)]
	rng.seed = 20240626


# ------------------------------------------------------------------ materials
func material(mname: String) -> ShaderMaterial:
	if materials.has(mname):
		return materials[mname]
	var d: Array = MATS.get(mname, MATS["concrete"])
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo", d[0])
	m.set_shader_parameter("albedo2", d[1])
	m.set_shader_parameter("pattern", d[2])
	m.set_shader_parameter("roughness", d[3])
	m.set_shader_parameter("pattern_scale", d[4])
	if d.size() > 6:
		m.set_shader_parameter("metallic", d[6])
	if d.size() > 7:
		m.set_shader_parameter("emission_color", d[0])
		m.set_shader_parameter("emission_energy", d[7])
	if mname == "water" or mname == "water_lake":
		m.set_shader_parameter("receives_wet", false)
	materials[mname] = m
	return m


func phys_of(mname: String) -> String:
	var d: Array = MATS.get(mname, MATS["concrete"])
	return str(d[5])


## Colliders of the dense mass buildings go on this layer so the navmesh bake
## only has to process the 30 feature towers. The hero still collides with it.
var collider_layer: int = 1


func _body(phys: String) -> StaticBody3D:
	if bodies.has(phys):
		return bodies[phys]
	var b := StaticBody3D.new()
	b.name = "Static_" + phys
	b.collision_layer = collider_layer
	b.collision_mask = 0
	b.set_meta("mat", phys)
	root.add_child(b)
	bodies[phys] = b
	return b


# ------------------------------------------------------------------ primitives
## Generic box. `center` is the box centre. Collision optional.
func box_b(center: Vector3, size: Vector3, b: Basis, mname: String, collide: bool = true, phys: String = "", visual: bool = true) -> void:
	if visual and mname != "invisible":
		boxes.append({"c": center, "s": size, "b": b, "m": mname})
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.transform = Transform3D(b, center)
		_body(phys if phys != "" else phys_of(mname)).add_child(cs)


func box(center: Vector3, size: Vector3, mname: String, collide: bool = true, yaw: float = 0.0, phys: String = "") -> void:
	box_b(center, size, Basis(Vector3.UP, yaw), mname, collide, phys)


## Box standing on y0 with footprint centred at (x, z).
func block(x: float, z: float, w: float, d: float, h: float, mname: String, y0: float = 0.0, yaw: float = 0.0, collide: bool = true) -> void:
	box(Vector3(x, y0 + h * 0.5, z), Vector3(w, h, d), mname, collide, yaw)


## Vertical-ish cylinder (any orientation via basis; local Y is the axis).
func cyl_b(center: Vector3, radius: float, height: float, b: Basis, mname: String, collide: bool = false, seg: int = 8) -> void:
	cyls.append({"c": center, "r": radius, "h": height, "b": b, "m": mname, "seg": seg})
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.transform = Transform3D(b, center)
		_body(phys_of(mname)).add_child(cs)


func cyl(base: Vector3, radius: float, height: float, mname: String, collide: bool = false, seg: int = 8) -> void:
	cyl_b(base + Vector3(0, height * 0.5, 0), radius, height, Basis.IDENTITY, mname, collide, seg)


func dome(center: Vector3, radius: float, mname: String, height_scale: float = 1.0, seg: int = 12, rings: int = 5) -> void:
	domes.append({"c": center, "r": radius, "hs": height_scale, "m": mname, "seg": seg, "rings": rings, "full": false})


func blob(center: Vector3, radius: float, mname: String, height_scale: float = 1.0) -> void:
	domes.append({"c": center, "r": radius, "hs": height_scale, "m": mname, "seg": 7, "rings": 4, "full": true})


func ground(rect: Rect2, y: float, mname: String) -> void:
	box(Vector3(rect.position.x + rect.size.x * 0.5, y - 0.5, rect.position.y + rect.size.y * 0.5), Vector3(rect.size.x, 1.0, rect.size.y), mname)


## Invisible wall between two XZ points (keeps players out of rivers / off the map).
func barrier(a: Vector3, b: Vector3, h: float = 4.0) -> void:
	var d := b - a
	d.y = 0.0
	var length := d.length()
	if length < 0.01:
		return
	var yaw := atan2(d.x, d.z)
	box_b((a + b) * 0.5 + Vector3(0, h * 0.5, 0), Vector3(0.4, h, length), Basis(Vector3.UP, yaw), "invisible", true, "concrete", false)


## Thin wall segment between two XZ points.
func wall(a: Vector3, b: Vector3, h: float, thick: float, mname: String, y0: float = 0.0) -> void:
	var d := b - a
	d.y = 0.0
	var length := d.length()
	if length < 0.01:
		return
	var yaw := atan2(d.x, d.z)
	var mid := (a + b) * 0.5
	box_b(Vector3(mid.x, y0 + h * 0.5, mid.z), Vector3(thick, h, length), Basis(Vector3.UP, yaw), mname, true)


## Walkable ramp from a (bottom) to b (top), centre line, given width.
func ramp(a: Vector3, b: Vector3, width: float, mname: String, thick: float = 0.3) -> void:
	var d := b - a
	var length := d.length()
	var flat := Vector2(d.x, d.z).length()
	var yaw := atan2(d.x, d.z)
	var pitch := atan2(d.y, flat)
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	var up := bs * Vector3.UP
	box_b((a + b) * 0.5 - up * thick * 0.5, Vector3(width, thick, length + 0.3), bs, mname, true)


func cover(pos: Vector3, dir: Vector3) -> void:
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	cover_points.append({"pos": pos, "dir": d.normalized(), "taken": null})


## Adds cover points on all four sides of an object (centre, half extents, yaw).
func cover_around(center: Vector3, half: Vector2, yaw: float = 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var sides := [[Vector3(1, 0, 0), half.x], [Vector3(-1, 0, 0), half.x], [Vector3(0, 0, 1), half.y], [Vector3(0, 0, -1), half.y]]
	for s in sides:
		var n: Vector3 = b * (s[0] as Vector3)
		var p := Vector3(center.x, 0.0, center.z) + n * (float(s[1]) + 0.65)
		p.y = center.y
		cover(p, -n)


func lamp(pos: Vector3, color: Color = Color(1.0, 0.78, 0.45), rng_m: float = 11.0, energy: float = 1.0) -> void:
	lamps.append({"p": pos, "c": color, "r": rng_m, "e": energy})
	if light_count < max_lights:
		light_count += 1
		var l := OmniLight3D.new()
		l.position = pos
		l.omni_range = rng_m * 0.8
		l.light_color = color
		l.light_energy = energy * 1.2
		l.light_cull_mask = 2
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 35.0
		l.distance_fade_length = 10.0
		deco.add_child(l)


func label(pos: Vector3, yaw: float, text: String, size: int = 64, color: Color = Color.WHITE, pixel: float = 0.012) -> Label3D:
	var l := Label3D.new()
	l.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = 70.0
	deco.add_child(l)
	return l


# ------------------------------------------------------------------ props
func rickshaw(pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hoods := ["fabric_red", "fabric_blue", "fabric_yellow", "fabric_green", "fabric_pink"]
	var hood: String = hoods[rng.randi_range(0, hoods.size() - 1)]
	box_b(pos + b * Vector3(0, 0.75, 0.55), Vector3(1.05, 0.5, 0.85), b, "tin_blue", true, "metal")
	box_b(pos + b * Vector3(0, 1.45, 0.75), Vector3(1.1, 0.9, 0.9), b, hood, false)
	box_b(pos + b * Vector3(0, 1.95, 0.6), Vector3(1.0, 0.1, 1.1), b, hood, false)
	box_b(pos + b * Vector3(0, 0.55, -0.35), Vector3(0.1, 0.1, 1.5), b, "metal_dark", false)
	box_b(pos + b * Vector3(0, 0.95, -0.95), Vector3(0.35, 0.1, 0.28), b, "wood_dark", false)
	box_b(pos + b * Vector3(0, 1.25, -1.2), Vector3(0.6, 0.06, 0.06), b, "metal_dark", false)
	for wx in [-0.55, 0.55]:
		cyl_b(pos + b * Vector3(wx, 0.4, 0.6), 0.4, 0.06, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", false, 10)
	cyl_b(pos + b * Vector3(0, 0.33, -1.1), 0.33, 0.06, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", false, 10)
	cover_around(pos, Vector2(0.6, 1.3), yaw)


func cng(pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	box_b(pos + b * Vector3(0, 0.85, 0.2), Vector3(1.4, 1.3, 2.2), b, "cng_green", true, "metal")
	box_b(pos + b * Vector3(0, 1.6, 0.25), Vector3(1.42, 0.25, 2.25), b, "cng_green", false)
	box_b(pos + b * Vector3(0, 1.1, -0.95), Vector3(1.2, 0.8, 0.05), b, "glass", false)
	box_b(pos + b * Vector3(0, 0.5, -1.2), Vector3(0.5, 0.4, 0.5), b, "cng_green", false)
	for p in [Vector3(-0.65, 0.25, 0.8), Vector3(0.65, 0.25, 0.8), Vector3(0, 0.25, -1.3)]:
		cyl_b(pos + b * (p as Vector3), 0.25, 0.15, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", false, 8)
	cover_around(pos, Vector2(0.75, 1.3), yaw)


func bus(pos: Vector3, yaw: float, mname: String = "") -> void:
	var b := Basis(Vector3.UP, yaw)
	var m := mname
	if m == "":
		m = ["bus_red", "bus_green", "bus_blue"][rng.randi_range(0, 2)]
	box_b(pos + b * Vector3(0, 1.75, 0), Vector3(2.5, 2.5, 10.4), b, m, true, "metal")
	box_b(pos + b * Vector3(0, 2.25, 0.2), Vector3(2.54, 0.85, 9.4), b, "glass", false)
	box_b(pos + b * Vector3(0, 0.95, 0), Vector3(2.54, 0.25, 10.44), b, "white", false)
	box_b(pos + b * Vector3(0, 2.0, -5.22), Vector3(2.2, 1.0, 0.05), b, "glass", false)
	for z in [-3.6, 3.4]:
		for x in [-1.15, 1.15]:
			cyl_b(pos + b * Vector3(x, 0.48, z), 0.48, 0.3, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", false, 10)
	cover_around(pos, Vector2(1.3, 5.2), yaw)


func truck(pos: Vector3, yaw: float, police: bool = false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var body := "police_blue" if police else "bus_red"
	box_b(pos + b * Vector3(0, 1.3, -2.2), Vector3(2.3, 1.9, 1.9), b, body, true, "metal")
	box_b(pos + b * Vector3(0, 1.6, -3.16), Vector3(2.0, 0.8, 0.05), b, "glass", false)
	box_b(pos + b * Vector3(0, 0.95, 1.0), Vector3(2.4, 0.4, 4.6), b, "metal_dark", true, "metal")
	box_b(pos + b * Vector3(0, 2.0, 1.0), Vector3(2.4, 1.9, 4.6), b, "tin" if police else "fabric_green", false)
	for z in [-2.2, 0.4, 2.4]:
		for x in [-1.1, 1.1]:
			cyl_b(pos + b * Vector3(x, 0.45, z), 0.45, 0.35, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", false, 10)
	if police:
		box_b(pos + b * Vector3(0, 2.32, -2.2), Vector3(1.2, 0.15, 0.3), b, "neon_red", false)
		label(pos + b * Vector3(1.22, 1.3, -2.2), yaw + PI * 0.5, "পুলিশ", 72, Color.WHITE, 0.008)
	cover_around(pos, Vector2(1.2, 3.4), yaw)


func car(pos: Vector3, yaw: float, mname: String = "white") -> void:
	var b := Basis(Vector3.UP, yaw)
	box_b(pos + b * Vector3(0, 0.6, 0), Vector3(1.8, 0.7, 4.3), b, mname, true, "metal")
	box_b(pos + b * Vector3(0, 1.2, 0.2), Vector3(1.6, 0.55, 2.2), b, "glass", false)
	for z in [-1.35, 1.35]:
		for x in [-0.85, 0.85]:
			cyl_b(pos + b * Vector3(x, 0.32, z), 0.32, 0.2, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", false, 8)
	cover_around(pos, Vector2(0.95, 2.2), yaw)


func crate(pos: Vector3, s: float = 1.2, yaw: float = 0.0, mname: String = "crate", add_cover: bool = true) -> void:
	box(pos + Vector3(0, s * 0.5, 0), Vector3(s, s, s), mname, true, yaw)
	if add_cover:
		cover_around(pos, Vector2(s * 0.5, s * 0.5), yaw)


func crate_stack(pos: Vector3, yaw: float = 0.0) -> void:
	crate(pos, 1.2, yaw)
	crate(pos + Basis(Vector3.UP, yaw) * Vector3(1.25, 0, 0), 1.2, yaw, "crate", false)
	crate(pos + Vector3(0.6, 1.2, 0), 1.1, yaw + 0.2, "crate", false)


func container(pos: Vector3, yaw: float, mname: String = "") -> void:
	var m := mname
	if m == "":
		m = ["container_red", "container_blue", "container_green"][rng.randi_range(0, 2)]
	box(pos + Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 6.0), m, true, yaw)
	cover_around(pos, Vector2(1.2, 3.0), yaw)


## Walk-in shipping container (safe point): steel walls and roof, doors swung open at the +Z end.
## Hostages left inside are out of the gangs' sight and count as safe.
func safe_container(pos: Vector3, yaw: float, mname: String = "container_blue") -> Dictionary:
	var b := Basis(Vector3.UP, yaw)
	var L := 6.0
	var W := 2.4
	var H := 2.6
	var t := 0.08
	box_b(pos + b * Vector3(0, 0.04, 0), Vector3(W, 0.08, L), b, mname, true, "metal")
	box_b(pos + b * Vector3(-W * 0.5 + t * 0.5, H * 0.5, 0), Vector3(t, H, L), b, mname, true, "metal")
	box_b(pos + b * Vector3(W * 0.5 - t * 0.5, H * 0.5, 0), Vector3(t, H, L), b, mname, true, "metal")
	box_b(pos + b * Vector3(0, H * 0.5, -L * 0.5 + t * 0.5), Vector3(W, H, t), b, mname, true, "metal")
	box_b(pos + b * Vector3(0, H - t * 0.5, 0), Vector3(W, t, L), b, mname, true, "metal")
	# the two door leaves swung right open against the side walls
	for sx: float in [-1.0, 1.0]:
		box_b(pos + b * Vector3(sx * (W * 0.5 + 0.06), H * 0.5, L * 0.5 - 0.62), Vector3(0.06, H - 0.1, 1.2), b, mname, true, "metal")
	cover_around(pos, Vector2(W * 0.5, L * 0.5), yaw)
	return {"pos": pos, "yaw": yaw, "inside": pos + b * Vector3(0, 0, -0.8),
		"slots": [pos + b * Vector3(-0.6, 0, -2.2), pos + b * Vector3(0.6, 0, -2.2), pos + b * Vector3(-0.6, 0, -1.0), pos + b * Vector3(0.6, 0, -1.0)],
		"door": pos + b * Vector3(0, 0, L * 0.5 + 1.2), "rect_half": Vector2(W * 0.5, L * 0.5)}


func sandbags(pos: Vector3, length: float, yaw: float) -> void:
	box(pos + Vector3(0, 0.55, 0), Vector3(length, 1.1, 0.7), "sandbag", true, yaw)
	var b := Basis(Vector3.UP, yaw)
	cover(pos + b * Vector3(0, 0, 0.9), b * Vector3(0, 0, -1))
	cover(pos + b * Vector3(0, 0, -0.9), b * Vector3(0, 0, 1))
	if length > 3.0:
		cover(pos + b * Vector3(length * 0.3, 0, 0.9), b * Vector3(0, 0, -1))
		cover(pos + b * Vector3(-length * 0.3, 0, 0.9), b * Vector3(0, 0, -1))
		cover(pos + b * Vector3(length * 0.3, 0, -0.9), b * Vector3(0, 0, 1))
		cover(pos + b * Vector3(-length * 0.3, 0, -0.9), b * Vector3(0, 0, 1))


func barrel(pos: Vector3, mname: String = "ship_blue") -> void:
	cyl(pos, 0.32, 0.95, mname, true, 8)


func lamp_post(pos: Vector3, color: Color = Color(1.0, 0.78, 0.45), height: float = 5.5, arm_yaw: float = 0.0) -> void:
	cyl(pos, 0.08, height, "metal_dark", true, 6)
	var b := Basis(Vector3.UP, arm_yaw)
	box_b(pos + Vector3(0, height, 0) + b * Vector3(0, 0, -0.6), Vector3(0.08, 0.08, 1.2), b, "metal_dark", false)
	var head := pos + Vector3(0, height - 0.1, 0) + b * Vector3(0, 0, -1.15)
	box_b(head, Vector3(0.35, 0.12, 0.5), b, "lamp" if color.b < 0.7 else "lamp_white", false)
	lamp(head - Vector3(0, 0.3, 0), color, 12.0, 1.1)


func tree(pos: Vector3, s: float = 1.0, kind: String = "round") -> void:
	cyl(pos, 0.22 * s, 3.2 * s, "trunk", true, 6)
	if kind == "palm":
		for i in 6:
			var yaw := TAU * float(i) / 6.0
			var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.5)
			box_b(pos + Vector3(0, 3.2 * s, 0) + Basis(Vector3.UP, yaw) * Vector3(0, -0.2, -1.1 * s), Vector3(0.5 * s, 0.06, 2.4 * s), b, "foliage", false)
	else:
		blob(pos + Vector3(0, 3.8 * s, 0), 1.9 * s, "foliage" if rng.randf() < 0.5 else "foliage_dark", 0.8)
		blob(pos + Vector3(0.8 * s, 3.3 * s, 0.4 * s), 1.2 * s, "foliage", 0.9)


func stall(pos: Vector3, yaw: float, canopy: String = "") -> void:
	var b := Basis(Vector3.UP, yaw)
	var c := canopy
	if c == "":
		c = ["fabric_red", "fabric_blue", "fabric_yellow", "fabric_green", "fabric_orange", "tin"][rng.randi_range(0, 5)]
	box_b(pos + b * Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 1.4), b, "wood", true, "wood")
	var produce := ["veg_green", "veg_orange", "veg_red", "veg_yellow", "fish"]
	for i in 3:
		box_b(pos + b * Vector3(-0.75 + i * 0.75, 1.0, 0), Vector3(0.65, 0.22, 1.1), b, produce[rng.randi_range(0, produce.size() - 1)], false)
	for px in [-1.25, 1.25]:
		for pz in [-0.8, 0.8]:
			box_b(pos + b * Vector3(px, 1.25, pz), Vector3(0.06, 2.5, 0.06), b, "wood_dark", false)
	box_b(pos + b * Vector3(0, 2.55, 0), Vector3(2.9, 0.06, 2.1), b * Basis(Vector3.RIGHT, 0.12), c, true, "cloth")
	cover_around(pos, Vector2(1.2, 0.7), yaw)


func tin_shed(x: float, z: float, w: float, d: float, h: float, mname: String = "tin_rust") -> void:
	block(x, z, w, d, h, mname)
	box(Vector3(x, h + 0.08, z), Vector3(w + 0.6, 0.12, d + 0.6), "tin", true, 0.0, "metal")


## Hanging electric cables across an alley (Old Dhaka).
func wires(a: Vector3, b: Vector3, count: int = 4) -> void:
	for i in count:
		var h := rng.randf_range(4.5, 7.5)
		var sag := rng.randf_range(0.3, 0.9)
		var p0 := a + Vector3(0, h, rng.randf_range(-0.4, 0.4))
		var p2 := b + Vector3(0, h + rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4))
		var p1 := (p0 + p2) * 0.5 - Vector3(0, sag, 0)
		for seg in [[p0, p1], [p1, p2]]:
			var s0: Vector3 = seg[0]
			var s1: Vector3 = seg[1]
			var d := s1 - s0
			var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD
			box_b((s0 + s1) * 0.5, Vector3(0.03, 0.03, d.length()), Basis.looking_at(d.normalized(), up), "black", false)


func sign_board(pos: Vector3, yaw: float, text: String, w: float = 3.0, h: float = 0.8, mname: String = "sign_green", text_color: Color = Color(1, 1, 0.9)) -> void:
	var b := Basis(Vector3.UP, yaw)
	box_b(pos, Vector3(w, h, 0.08), b, mname, false)
	label(pos + b * Vector3(0, 0, -0.06), yaw + PI, text, 64, text_color, minf(0.011, h / 70.0))


## Building with facade details. style: old | office | tower | plain. sides: which faces get windows/shops ("n","s","e","w").
func building(x: float, z: float, w: float, d: float, h: float, mname: String, style: String = "old", sides: Array = ["n", "s", "e", "w"], roof: bool = true, y0: float = 0.0) -> void:
	block(x, z, w, d, h, mname, y0)
	var top := y0 + h
	if roof:
		box(Vector3(x, top + 0.45, z - d * 0.5 + 0.1), Vector3(w, 0.9, 0.2), mname)
		box(Vector3(x, top + 0.45, z + d * 0.5 - 0.1), Vector3(w, 0.9, 0.2), mname)
		box(Vector3(x - w * 0.5 + 0.1, top + 0.45, z), Vector3(0.2, 0.9, d - 0.4), mname)
		box(Vector3(x + w * 0.5 - 0.1, top + 0.45, z), Vector3(0.2, 0.9, d - 0.4), mname)
		if rng.randf() < 0.6 and w > 5.0 and d > 5.0:
			var tx := x + rng.randf_range(-w * 0.25, w * 0.25)
			var tz := z + rng.randf_range(-d * 0.25, d * 0.25)
			cyl(Vector3(tx, top, tz), 0.7, 1.6, "black" if rng.randf() < 0.5 else "ship_blue", true, 8)
	if style == "office" or style == "tower" or style == "plain":
		return
	var floors := int(h / 3.2)
	for s in sides:
		var n := Vector3.ZERO
		var length := w
		match str(s):
			"n":
				n = Vector3(0, 0, -1)
			"s":
				n = Vector3(0, 0, 1)
			"e":
				n = Vector3(1, 0, 0)
				length = d
			"w":
				n = Vector3(-1, 0, 0)
				length = d
		var along := Vector3(-n.z, 0, n.x)
		var face_c := Vector3(x, 0, z) + n * ((d if absf(n.z) > 0.5 else w) * 0.5)
		var cols := int(length / 3.0)
		var yaw := atan2(n.x, n.z)
		var b := Basis(Vector3.UP, yaw)
		for f in floors:
			var fy := y0 + f * 3.2
			if f == 0:
				# shop shutters at street level
				for c in cols:
					if rng.randf() < 0.7:
						var off := (c - (cols - 1) * 0.5) * 3.0
						box_b(face_c + along * off + n * 0.06 + Vector3(0, fy + 1.3, 0), Vector3(2.4, 2.4, 0.1), b, "tin", false)
				continue
			for c in cols:
				var off2 := (c - (cols - 1) * 0.5) * 3.0
				var wp := face_c + along * off2 + Vector3(0, fy + 1.6, 0)
				box_b(wp + n * 0.04, Vector3(1.2, 1.4, 0.1), b, "black", false)
				if rng.randf() < 0.5:
					box_b(wp + n * 0.08 + Vector3(0, 0.78, 0), Vector3(1.5, 0.12, 0.25), b, "concrete_dark", false)
				if rng.randf() < 0.25 and f < floors:
					box_b(wp + n * 0.55 + Vector3(0, -0.75, 0), Vector3(2.4, 0.12, 1.0), b, "concrete", false)
					box_b(wp + n * 1.02 + Vector3(0, -0.45, 0), Vector3(2.4, 0.6, 0.06), b, "metal_dark", false)
					if rng.randf() < 0.5:
						box_b(wp + n * 0.95 + Vector3(0, -0.2, 0), Vector3(0.8, 0.9, 0.04), b, ["fabric_red", "fabric_blue", "fabric_yellow", "fabric_pink"][rng.randi_range(0, 3)], false)


## Hollow building with an interior, a door gap and optional interior lamp.
func hall(x: float, z: float, w: float, d: float, h: float, mname: String, door_side: String = "s", door_w: float = 2.4, y0: float = 0.0, lit: bool = true, floor_mat: String = "concrete") -> void:
	var t := 0.4
	var hw := w * 0.5
	var hd := d * 0.5
	box(Vector3(x, y0 + 0.05, z), Vector3(w, 0.1, d), floor_mat)
	box(Vector3(x, y0 + h + 0.2, z), Vector3(w + 0.4, 0.4, d + 0.4), mname)
	var walls := {
		"n": [Vector3(x - hw, 0, z - hd), Vector3(x + hw, 0, z - hd)],
		"s": [Vector3(x - hw, 0, z + hd), Vector3(x + hw, 0, z + hd)],
		"w": [Vector3(x - hw, 0, z - hd), Vector3(x - hw, 0, z + hd)],
		"e": [Vector3(x + hw, 0, z - hd), Vector3(x + hw, 0, z + hd)],
	}
	for k in walls.keys():
		var a: Vector3 = walls[k][0]
		var b: Vector3 = walls[k][1]
		if k == door_side:
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			wall(a, mid - dir * door_w * 0.5, h, t, mname, y0)
			wall(mid + dir * door_w * 0.5, b, h, t, mname, y0)
			box(Vector3(mid.x, y0 + h - 0.4, mid.z), Vector3(door_w if absf(dir.x) > 0.5 else t, 0.8, t if absf(dir.x) > 0.5 else door_w), mname)
		else:
			wall(a, b, h, t, mname, y0)
	if lit:
		lamp(Vector3(x, y0 + h - 0.5, z), Color(1.0, 0.85, 0.6), maxf(w, d) * 0.9, 1.0)
		box(Vector3(x, y0 + h - 0.05, z), Vector3(0.8, 0.08, 0.3), "lamp", false)


## Wall along one side of a rectangle with real openings (doors / windows the AI can see and shoot
## through). openings: [[offset along the wall from its centre, width, sill, top], ...]
func _wall_open(side: String, x: float, z: float, hw: float, hd: float, fy: float, fh: float, t: float, openings: Array, mname: String) -> void:
	var along_x := side == "n" or side == "s"
	var length := hw * 2.0 if along_x else hd * 2.0
	var line := (z - hd if side == "n" else z + hd) if along_x else (x + hw if side == "e" else x - hw)
	var ops := openings.duplicate()
	ops.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var cur := -length * 0.5
	var segs := []
	for o in ops:
		var o0: float = float(o[0]) - float(o[1]) * 0.5
		var o1: float = float(o[0]) + float(o[1]) * 0.5
		if o0 > cur + 0.01:
			segs.append([cur, o0, 0.0, fh])
		if float(o[2]) > 0.01:
			segs.append([o0, o1, 0.0, float(o[2])])
		if float(o[3]) < fh - 0.01:
			segs.append([o0, o1, float(o[3]), fh])
		cur = o1
	if cur < length * 0.5 - 0.01:
		segs.append([cur, length * 0.5, 0.0, fh])
	for sg in segs:
		var a0: float = sg[0]
		var a1: float = sg[1]
		var yb: float = sg[2]
		var yt: float = sg[3]
		var mid := (a0 + a1) * 0.5
		var cy := fy + (yb + yt) * 0.5
		if along_x:
			box(Vector3(x + mid, cy, line), Vector3(a1 - a0, yt - yb, t), mname)
		else:
			box(Vector3(line, cy, z + mid), Vector3(t, yt - yb, a1 - a0), mname)


## Lean walk-in building for the dense colony mass: real street door, a window on
## every floor of every side, floor slabs with a stairwell, a walkable stair and
## a reachable roof. Used for all 1,400+ colony footprints; the 30 feature towers
## use the fully detailed house() above.
func simple_house(x: float, z: float, w: float, d: float, floors: int, mname: String, door_side: String = "s") -> Dictionary:
	var fh := 3.2
	var t := 0.25
	var hw := w * 0.5
	var hd := d * 0.5
	var normals := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}
	var nd: Vector3 = normals[door_side]
	var sx := x + hw - 1.0
	var sz := z - hd + 1.0
	var windows: Array = []
	var floor_points: Array = []
	box(Vector3(x, 0.05, z), Vector3(w, 0.1, d), "concrete")
	for f in floors:
		var fy := f * fh
		for side in ["n", "s", "e", "w"]:
			var along_x: bool = side == "n" or side == "s"
			var ops: Array = []
			if f == 0 and side == door_side:
				ops.append([0.0, 1.4, 0.0, 2.3])
			else:
				var ow := 1.2 if along_x else minf(1.2, d * 0.35)
				ops.append([0.0, ow, 0.95, 2.15])
			_wall_open(side, x, z, hw, hd, fy, fh, t, ops, mname)
			if side == "s" or side == "n":
				var nrm: Vector3 = normals[side]
				var wp := Vector3(x, fy + 1.5, z + nrm.z * hd)
				windows.append({"out": wp + nrm * 0.7, "in": wp - nrm * 0.7})
		floor_points.append(Vector3(x - hw * 0.3, fy + 0.1, z))
		if f < floors - 1:
			# slab with a stairwell gap at the east side
			box(Vector3(x - 0.8, fy + fh, z), Vector3(w - 2.4, 0.16, d), "concrete", false)
			box(Vector3(x + hw - 0.4, fy + fh, z), Vector3(0.8, 0.16, d), "concrete", false)
			ramp(Vector3(sx, fy, sz + 1.8), Vector3(sx, fy + fh, sz), 1.4, "invisible", 0.2)
	var roof_y := floors * fh
	box(Vector3(x, roof_y, z), Vector3(w, 0.18, d), "concrete", false)
	var door := Vector3(x, 0, z) + nd * (hd if (door_side == "n" or door_side == "s") else hw)
	return {"door_out": door + nd * 1.5, "door_in": door - nd * 0.9, "inside": floor_points[0],
		"floors_points": floor_points, "roof": Vector3(x - hw * 0.3, roof_y + 0.1, z),
		"windows": windows, "roof_y": roof_y}


## Enterable multi-storey house (Phase 2): door, glassless windows, interior partition with a
## doorway (hallway beside the stairwell), stairs between floors with a railing, lit rooms, flat roof
## with parapet. Returns its footprint, door point and the window posts of the upper floors.
func house(x: float, z: float, w: float, d: float, floors: int, mname: String, door_side: String = "s", y0: float = 0.0) -> Dictionary:
	var fh := 3.2
	var t := 0.3
	var hw := w * 0.5
	var hd := d * 0.5
	var posts: Array = []
	var window_positions: Array = []
	box(Vector3(x, y0 + 0.05, z), Vector3(w, 0.1, d), "concrete")
	var sw := 1.4
	var sx := x + hw - t - sw * 0.5 - 0.05
	var hx0 := sx - sw * 0.5 - 0.1
	var s_len := 4.4
	var s_z0 := z - hd + t + 0.3
	var normals := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}
	for f in floors:
		var fy := y0 + f * fh
		for side in ["n", "s", "e", "w"]:
			var length := w if (side == "n" or side == "s") else d
			var n_win := maxi(1, int((length - 1.0) / 3.0))
			var openings := []
			for i in n_win:
				var off := (float(i) - float(n_win - 1) * 0.5) * 3.0
				if side == "e" and f > 0 and absf(z + off - (s_z0 + s_len * 0.5)) < s_len * 0.5:
					continue
				openings.append([off, 1.2, 0.95, 2.15])
			if f == 0 and side == door_side:
				openings = openings.filter(func(o): return absf(float(o[0])) > 1.6)
				openings.append([0.0, 1.3, 0.0, 2.3])
			_wall_open(side, x, z, hw, hd, fy, fh, t, openings, mname)
			# a concrete sunshade over every window; steel grills on town houses (beach houses: open
			# shutters instead) - visual only: bullets and eyes pass through
			var nrm2: Vector3 = normals[side]
			var along2 := Vector3(1, 0, 0) if (side == "n" or side == "s") else Vector3(0, 0, 1)
			for o in openings:
				if float(o[2]) < 0.5:
					continue
				if beach_style:
					var wpb := Vector3(x, fy, z) + nrm2 * ((hd if (side == "n" or side == "s") else hw)) + along2 * float(o[0])
					for sd: float in [-1.0, 1.0]:
						box(wpb + nrm2 * 0.06 + along2 * sd * (float(o[1]) * 0.5 + 0.28) + Vector3(0, (float(o[2]) + float(o[3])) * 0.5, 0), along2 * 0.5 + nrm2.abs() * 0.04 + Vector3(0, float(o[3]) - float(o[2]), 0), "wood", false)
					continue
				var wp := Vector3(x, fy, z) + nrm2 * ((hd if (side == "n" or side == "s") else hw)) + along2 * float(o[0])
				# Traversable window: E vaults the hero between outside and inside.
				if (side == "n" or side == "s") and window_positions.size() < 30:
					window_positions.append({"out": wp + nrm2 * 0.85, "in": wp - nrm2 * 0.85})
				var ow := float(o[1])
				var sill := float(o[2])
				var top := float(o[3])
				var shade_sz := along2 * (ow + 0.5) + nrm2.abs() * 0.55 + Vector3(0, 0.07, 0)
				box(wp + nrm2 * 0.27 + Vector3(0, top + 0.12, 0), shade_sz, "concrete", false)
				for k in 5:
					var ax := (float(k) / 4.0 - 0.5) * (ow - 0.1)
					box(wp - nrm2 * 0.04 + along2 * ax + Vector3(0, (sill + top) * 0.5, 0), along2 * 0.02 + nrm2.abs() * 0.02 + Vector3(0, top - sill, 0), "metal_dark", false)
				box(wp - nrm2 * 0.04 + Vector3(0, (sill + top) * 0.5, 0), along2 * ow + nrm2.abs() * 0.02 + Vector3(0, 0.025, 0), "metal_dark", false)
			if f > 0:
				var nrm: Vector3 = normals[side]
				for o in openings:
					var along := Vector3(1, 0, 0) if (side == "n" or side == "s") else Vector3(0, 0, 1)
					var wall_pt := Vector3(x, fy, z) + nrm * ((hd if (side == "n" or side == "s") else hw)) + along * float(o[0])
					posts.append({"pos": wall_pt - nrm * 0.9, "dir": nrm})
					cover(wall_pt - nrm * 0.75, nrm)
		# interior partition across the west rooms, doorway in the middle, hallway beside the stairs
		var px1 := hx0 - 1.2
		if px1 > x - hw + 2.0:
			var pmid := (x - hw + px1) * 0.5
			var plen := px1 - (x - hw)
			var dw := 1.0
			box(Vector3(x - hw + (plen - dw) * 0.25, fy + fh * 0.5, z + 0.4), Vector3((plen - dw) * 0.5, fh, 0.18), "plaster_white")
			box(Vector3(px1 - (plen - dw) * 0.25, fy + fh * 0.5, z + 0.4), Vector3((plen - dw) * 0.5, fh, 0.18), "plaster_white")
			box(Vector3(pmid, fy + fh - 0.45, z + 0.4), Vector3(dw, 0.9, 0.18), "plaster_white")
		lamp(Vector3(x - hw * 0.4, fy + fh - 0.45, z), Color(1.0, 0.86, 0.62), 7.0, 0.8)
		box(Vector3(x - hw * 0.4, fy + fh - 0.06, z), Vector3(0.6, 0.06, 0.2), "lamp", false)
		# a few things to hide behind inside
		crate(Vector3(x - hw + 1.2, fy + 0.45, z - hd + 1.3), 0.9)
		if f > 0:
			box(Vector3(x - hw * 0.5, fy + 0.4, z + hd - 1.0), Vector3(1.6, 0.8, 0.6), "wood_dark")
			cover_around(Vector3(x - hw * 0.5, fy, z + hd - 1.0), Vector2(0.8, 0.3))
	# floor slabs (stair hole on the inner floors) + roof
	for f in range(1, floors + 1):
		var sy := y0 + f * fh - 0.12
		if f < floors:
			box(Vector3((x - hw + hx0) * 0.5, sy, z), Vector3(hx0 - (x - hw), 0.24, d), "concrete")
			var n_len := s_z0 - (z - hd)
			box(Vector3((hx0 + x + hw) * 0.5, sy, z - hd + n_len * 0.5), Vector3(x + hw - hx0, 0.24, n_len), "concrete")
			var s_len2 := (z + hd) - (s_z0 + s_len)
			box(Vector3((hx0 + x + hw) * 0.5, sy, z + hd - s_len2 * 0.5), Vector3(x + hw - hx0, 0.24, s_len2), "concrete")
			# railing on the open side of the stair hole
			box(Vector3(hx0 - 0.05, sy + 0.62, s_z0 + s_len * 0.5 + 0.6), Vector3(0.08, 1.0, s_len - 1.2), "metal_dark")
		else:
			# roof slab with the stair opening, covered by a stair hut (chilekotha) as on every Dhaka
			# house roof, plus the black plastic water tank on its stand
			box(Vector3((x - hw + hx0) * 0.5, sy, z), Vector3(hx0 - (x - hw), 0.24, d), "concrete")
			var rn_len := s_z0 - (z - hd)
			box(Vector3((hx0 + x + hw) * 0.5, sy, z - hd + rn_len * 0.5), Vector3(x + hw - hx0, 0.24, rn_len), "concrete")
			var rs_len := (z + hd) - (s_z0 + s_len)
			box(Vector3((hx0 + x + hw) * 0.5, sy, z + hd - rs_len * 0.5), Vector3(x + hw - hx0, 0.24, rs_len), "concrete")
			var hut_x0 := hx0 - 0.15
			var hut_x1 := x + hw
			var hut_z0 := z - hd + 0.1
			var hut_z1 := s_z0 + s_len + 0.15
			var hy := sy + 0.12
			var hh := 2.5
			box(Vector3((hut_x0 + hut_x1) * 0.5, hy + hh * 0.5, hut_z0), Vector3(hut_x1 - hut_x0, hh, 0.2), mname)
			box(Vector3((hut_x0 + hut_x1) * 0.5, hy + hh * 0.5, hut_z1), Vector3(hut_x1 - hut_x0, hh, 0.2), mname)
			box(Vector3(hut_x1 - 0.1, hy + hh * 0.5, (hut_z0 + hut_z1) * 0.5), Vector3(0.2, hh, hut_z1 - hut_z0), mname)
			# west wall of the hut with a doorway onto the roof, next to the top of the stairs
			var dz0 := s_z0 - 0.45
			var dz1 := s_z0 + 0.85
			box(Vector3(hut_x0, hy + hh * 0.5, (dz1 + hut_z1) * 0.5), Vector3(0.2, hh, hut_z1 - dz1), mname)
			if dz0 - hut_z0 > 0.05:
				box(Vector3(hut_x0, hy + hh * 0.5, (hut_z0 + dz0) * 0.5), Vector3(0.2, hh, dz0 - hut_z0), mname)
			box(Vector3(hut_x0, hy + hh - 0.25, (dz0 + dz1) * 0.5), Vector3(0.2, 0.5, dz1 - dz0), mname)
			box(Vector3((hut_x0 + hut_x1) * 0.5, hy + hh + 0.1, (hut_z0 + hut_z1) * 0.5), Vector3(hut_x1 - hut_x0 + 0.3, 0.2, hut_z1 - hut_z0 + 0.3), "concrete")
			cyl(Vector3(x - hw + 1.3, hy + 0.6, z - hd + 1.3), 0.15, 1.2, "metal_dark", false, 6)
			cyl(Vector3(x - hw + 1.3, hy + 1.2, z - hd + 1.3), 0.62, 1.15, "metal_dark", true, 12)
			box(Vector3(x, sy + 0.55, z - hd + 0.1), Vector3(w, 0.9, 0.2), mname)
			box(Vector3(x, sy + 0.55, z + hd - 0.1), Vector3(w, 0.9, 0.2), mname)
			box(Vector3(x - hw + 0.1, sy + 0.55, z), Vector3(0.2, 0.9, d), mname)
			box(Vector3(x + hw - 0.1, sy + 0.55, z), Vector3(0.2, 0.9, d), mname)
	# lift shaft: a cabin and door at every floor of the tower
	var lx := x - hw + 1.2
	var lz := z + hd * 0.45
	var lift_positions: Array = []
	for f in floors:
		var fy3 := y0 + f * fh
		box(Vector3(lx, fy3 + 1.25, lz), Vector3(1.5, 2.5, 1.5), "metal_dark", false)
		box(Vector3(lx - 0.78, fy3 + 1.2, lz), Vector3(0.06, 2.0, 1.1), "glass", false)
		box(Vector3(lx, fy3 + 2.5, lz), Vector3(1.7, 0.15, 1.7), "concrete", false)
		lift_positions.append(Vector3(lx + 1.1, fy3 + 0.15, lz))
	# stairs: invisible ramp for walking + visible concrete steps
	for f in floors:
		var fy2 := y0 + f * fh
		var a := Vector3(sx, fy2, s_z0 + s_len)
		var b := Vector3(sx, fy2 + fh, s_z0)
		ramp(a, b, sw, "invisible", 0.2)
		var steps := 6
		for i in steps:
			var k := (float(i) + 0.5) / float(steps)
			var pz := lerpf(a.z, b.z, k)
			var py := lerpf(a.y, b.y, k)
			box(Vector3(sx, py - 0.1, pz), Vector3(sw, 0.2 + fh / float(steps), s_len / float(steps) + 0.02), "concrete_dark", false)
	var nd: Vector3 = normals[door_side]
	var door := Vector3(x, y0, z) + nd * ((hd if (door_side == "n" or door_side == "s") else hw))
	cover(door + nd * 1.2, -nd)
	if beach_style:
		# veranda: a sloping tin roof on two wooden posts over the door
		var side_v := Vector3(-nd.z, 0, nd.x)
		for sd: float in [-1.0, 1.0]:
			cyl(door + nd * 1.7 + side_v * sd * 1.6, 0.07, 2.6, "wood", true, 6)
		box_b(door + nd * 1.0 + Vector3(0, 2.75, 0), side_v.abs() * 4.0 + nd.abs() * 2.2 + Vector3(0, 0.06, 0), Basis(side_v.normalized(), 0.12), "tin_blue", false)
	var roof_y := y0 + floors * fh
	return {"rect": Rect2(x - hw, z - hd, w, d), "y0": y0, "y1": y0 + floors * fh, "door_out": door + nd * 1.6, "door_in": door - nd * 1.2, "posts": posts,
		# Phase 3: stair foot (collapsible gate), rooms for residents / chairs / the gang leader, roof
		"stair_foot": Vector3(sx, y0, s_z0 + s_len + 0.25), "stair_w": sw,
		"room_g": Vector3(x - hw + 1.6, y0, z + hd * 0.45), "room_g2": Vector3(x - hw + 1.6, y0, z - hd * 0.5),
		"room_up": Vector3(x - hw + 2.2, y0 + fh, z - hd * 0.35), "room_up2": Vector3(x - hw + 2.4, y0 + fh, z + hd * 0.4),
		"roof_y": roof_y, "roof_pad": Vector3(x - hw * 0.3, roof_y, z + hd * 0.15),
		"lift_positions": lift_positions, "window_positions": window_positions}


## Can a house of this footprint stand here? (flat street-level ground, nothing in the way)
func area_clear(rect: Rect2, avoid: Array) -> bool:
	if not bounds.grow(-4.0).encloses(rect):
		return false
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), rect.get_center()]:
		if not _ground_ok(corner):
			return false
	for bx in boxes:
		var c: Vector3 = bx["c"]
		var sz: Vector3 = bx["s"]
		if c.y + sz.y * 0.5 < 0.25:
			continue
		var bs: Basis = bx["b"]
		var hx := absf(bs.x.x) * sz.x * 0.5 + absf(bs.z.x) * sz.z * 0.5
		var hz := absf(bs.x.z) * sz.x * 0.5 + absf(bs.z.z) * sz.z * 0.5
		if rect.intersects(Rect2(c.x - hx, c.z - hz, hx * 2.0, hz * 2.0)):
			return false
	for cy in cyls:
		var cc: Vector3 = cy["c"]
		if rect.grow(float(cy["r"])).has_point(Vector2(cc.x, cc.z)):
			return false
	for dm in domes:
		var dc: Vector3 = dm["c"]
		if rect.grow(float(dm["r"])).has_point(Vector2(dc.x, dc.z)):
			return false
	for p in avoid:
		if rect.has_point(Vector2((p as Vector3).x, (p as Vector3).z)):
			return false
	return true


func _ground_ok(p: Vector2) -> bool:
	for bx in boxes:
		var c: Vector3 = bx["c"]
		var sz: Vector3 = bx["s"]
		var top := c.y + sz.y * 0.5
		if top < -0.12 or top > 0.15 or sz.y < 0.4:
			continue
		if str(bx["m"]).begins_with("water"):
			continue
		if absf(p.x - c.x) <= sz.x * 0.5 and absf(p.y - c.z) <= sz.z * 0.5:
			return true
	return false


func launch(pos: Vector3, yaw: float, length: float = 26.0, stripe: String = "ship_red") -> void:
	## Sadarghat passenger launch: hull + walkable lower deck + upper deck reached by a ramp.
	## Local +X is the boarding (shore) side and has no lower railing so gangplanks can reach it.
	var b := Basis(Vector3.UP, yaw)
	var w := 7.0
	box_b(pos + b * Vector3(0, 0.6, 0), Vector3(w, 2.4, length), b, "ship_white", true, "metal")
	box_b(pos + b * Vector3(0, 1.4, 0), Vector3(w + 0.05, 0.4, length + 0.05), b, stripe, false)
	box_b(pos + b * Vector3(0, 1.85, 0), Vector3(w, 0.1, length), b, "wood", true)
	box_b(pos + b * Vector3(0, 4.5, 4.5), Vector3(w - 0.6, 0.2, 15.0), b, "ship_white", true, "metal")
	box_b(pos + b * Vector3(-(w * 0.5 - 0.05), 2.55, 0), Vector3(0.08, 1.3, length), b, "metal_grey", true, "metal")
	for side in [-1.0, 1.0]:
		box_b(pos + b * Vector3(side * (w * 0.5 - 0.35), 5.25, 4.5), Vector3(0.08, 1.3, 15.0), b, "metal_grey", true, "metal")
		for i in int(length / 3.0):
			var zz := -length * 0.5 + 2.0 + i * 3.0
			box_b(pos + b * Vector3(side * (w * 0.5 - 0.3), 3.2, zz), Vector3(0.15, 2.6, 0.15), b, "ship_white", false)
	box_b(pos + b * Vector3(0, 6.1, 6.0), Vector3(4.0, 3.0, 5.0), b, "ship_white", true, "metal")
	box_b(pos + b * Vector3(0, 6.5, 3.48), Vector3(3.6, 1.0, 0.05), b, "glass", false)
	cyl_b(pos + b * Vector3(0, 8.6, 9.5), 0.5, 2.5, b, stripe, false)
	ramp(pos + b * Vector3(-w * 0.5 + 1.0, 1.9, -10.0), pos + b * Vector3(-w * 0.5 + 1.0, 4.6, -3.2), 1.4, "wood")
	label(pos + b * Vector3(-w * 0.5 - 0.06, 1.4, 0), yaw - PI * 0.5, ["এমভি সুন্দরবন", "এমভি পারাবত", "এমভি কীর্তনখোলা", "এমভি সুরভী"][rng.randi_range(0, 3)], 96, Color(0.1, 0.1, 0.4), 0.02)


func barge(pos: Vector3, yaw: float, length: float = 20.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	box_b(pos + b * Vector3(0, 0.3, 0), Vector3(8.0, 1.6, length), b, "rust", true, "metal")
	for side in [-1.0, 1.0]:
		box_b(pos + b * Vector3(side * 3.95, 1.5, 0), Vector3(0.1, 0.8, length), b, "rust", true, "metal")


func plane(pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var axis := b * Basis(Vector3.RIGHT, PI * 0.5)
	cyl_b(pos + b * Vector3(0, 3.0, 0), 2.0, 34.0, axis, "plane_white", true, 12)
	box_b(pos + b * Vector3(0, 3.0, -17.5), Vector3(2.6, 2.6, 1.5), b, "plane_white", false)
	box_b(pos + b * Vector3(0, 3.6, -16.8), Vector3(2.0, 0.6, 0.05), b, "glass", false)
	box_b(pos + b * Vector3(0, 2.4, 1.0), Vector3(34.0, 0.4, 5.0), b, "plane_white", true, "metal")
	box_b(pos + b * Vector3(0, 6.5, 15.5), Vector3(0.4, 6.0, 4.0), b, "plane_green", false)
	box_b(pos + b * Vector3(0, 3.4, 15.5), Vector3(11.0, 0.3, 3.0), b, "plane_white", false)
	box_b(pos + b * Vector3(0, 3.0, 0), Vector3(4.05, 0.5, 30.0), b, "plane_green", false)
	for ex in [-8.0, 8.0]:
		cyl_b(pos + b * Vector3(ex, 1.6, -0.5), 0.9, 3.5, axis, "metal_grey", true, 10)
	for gp in [Vector3(0, 0.6, -12.0), Vector3(-3.0, 0.6, 2.0), Vector3(3.0, 0.6, 2.0)]:
		cyl_b(pos + b * (gp as Vector3), 0.6, 0.5, b * Basis(Vector3.FORWARD, PI * 0.5), "rubber", true, 8)
		box_b(pos + b * ((gp as Vector3) + Vector3(0, 0.9, 0)), Vector3(0.2, 1.4, 0.2), b, "metal_grey", false)
	cover_around(pos + b * Vector3(0, 0, -12.0), Vector2(0.8, 0.8), yaw)


func fence(a: Vector3, b: Vector3, h: float = 2.8) -> void:
	var d := b - a
	d.y = 0.0
	var length := d.length()
	var yaw := atan2(d.x, d.z)
	var bs := Basis(Vector3.UP, yaw)
	var mid := (a + b) * 0.5
	box_b(Vector3(mid.x, h * 0.5, mid.z), Vector3(0.06, h, length), bs, "invisible", true, "metal", false)
	for i in int(length / 3.0) + 1:
		var p := a + d.normalized() * minf(i * 3.0, length)
		box(Vector3(p.x, h * 0.5, p.z), Vector3(0.1, h, 0.1), "metal_grey", false, yaw)
	for hh in [0.4, 1.1, 1.8, 2.5]:
		box_b(Vector3(mid.x, hh, mid.z), Vector3(0.03, 0.03, length), bs, "metal_grey", false)
	for i in int(length / 0.5):
		var p2 := a + d.normalized() * (i * 0.5 + 0.25)
		box_b(Vector3(p2.x, h * 0.5, p2.z), Vector3(0.015, h, 0.015), bs, "metal_grey", false)


# ------------------------------------------------------------------ finalize
func finalize() -> void:
	_build_occupancy()
	for b in boxes:
		_emit_box(b)
	for c in cyls:
		_emit_cyl(c)
	for d in domes:
		_emit_dome(d)
	for key in _chunks.keys():
		var ch: Dictionary = _chunks[key]
		var st: SurfaceTool = ch["st"]
		var mesh := st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material(str(ch["m"]))
		if str(ch["m"]) in ["water", "water_lake", "water_sea", "lamp", "lamp_white", "neon_green", "neon_red", "glass"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		deco.add_child(mi)
	boxes.clear()
	cyls.clear()
	domes.clear()


func _chunk_st(mname: String, p: Vector3) -> SurfaceTool:
	var cx := int(floorf(p.x / CHUNK))
	var cz := int(floorf(p.z / CHUNK))
	var key := "%s|%d|%d" % [mname, cx, cz]
	if not _chunks.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_chunks[key] = {"st": st, "m": mname}
	return _chunks[key]["st"]


func _build_occupancy() -> void:
	_occ_min = bounds.position
	_occ_w = int(bounds.size.x)
	_occ_h = int(bounds.size.y)
	_occ = PackedByteArray()
	_occ.resize(_occ_w * _occ_h)
	for b in boxes:
		var s: Vector3 = b["s"]
		var c: Vector3 = b["c"]
		var bot := c.y - s.y * 0.5
		if s.y < 0.7 or bot > 0.8 or c.y + s.y * 0.5 < 0.6:
			continue
		if s.x > 60.0 or s.z > 60.0:
			continue
		var bs: Basis = b["b"]
		var hx := absf(bs.x.x) * s.x * 0.5 + absf(bs.y.x) * s.y * 0.5 + absf(bs.z.x) * s.z * 0.5
		var hz := absf(bs.x.z) * s.x * 0.5 + absf(bs.y.z) * s.y * 0.5 + absf(bs.z.z) * s.z * 0.5
		for ix in range(int(floorf(c.x - hx - _occ_min.x)), int(ceilf(c.x + hx - _occ_min.x))):
			for iz in range(int(floorf(c.z - hz - _occ_min.y)), int(ceilf(c.z + hz - _occ_min.y))):
				if ix >= 0 and iz >= 0 and ix < _occ_w and iz < _occ_h:
					_occ[iz * _occ_w + ix] = 1


func _occ_at(x: float, z: float) -> int:
	var ix := int(floorf(x - _occ_min.x))
	var iz := int(floorf(z - _occ_min.y))
	if ix < 0 or iz < 0 or ix >= _occ_w or iz >= _occ_h:
		return 0
	return _occ[iz * _occ_w + ix]


func _ground_ao(p: Vector3) -> float:
	if p.y > 1.0:
		return 1.0
	var occ := 0.0
	for dx in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		for dz in [-1.6, -0.8, 0.0, 0.8, 1.6]:
			occ += float(_occ_at(p.x + dx, p.z + dz))
	return clampf(1.0 - occ / 25.0 * 0.75, 0.45, 1.0)


func _vcolor(p: Vector3, n: Vector3, base_y: float, near_lamps: Array) -> Color:
	var ao := 1.0
	if n.y > 0.5:
		ao = _ground_ao(p)
	elif n.y > -0.5:
		ao = clampf(0.55 + (p.y - base_y) * 0.32, 0.55, 1.0)
	else:
		ao = 0.6
	var lr := 0.0
	var lg := 0.0
	var lb := 0.0
	for l in near_lamps:
		var lp: Vector3 = l["p"]
		var to := lp - p
		var d := to.length()
		var r: float = l["r"]
		if d >= r or d < 0.001:
			continue
		var att := 1.0 - d / r
		att *= att
		var ndl := maxf(n.dot(to / d), 0.0) * 0.8 + 0.2
		var k: float = att * ndl * float(l["e"])
		var c: Color = l["c"]
		lr += c.r * k
		lg += c.g * k
		lb += c.b * k
	return Color(minf(lr, 1.0), minf(lg, 1.0), minf(lb, 1.0), ao)


func _lamps_near(center: Vector3, radius: float) -> Array:
	var out: Array = []
	for l in lamps:
		var lp: Vector3 = l["p"]
		if lp.distance_to(center) < float(l["r"]) + radius:
			out.append(l)
	return out


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, n: Vector3) -> void:
	# Godot front faces are clockwise: (b-a)x(c-a) must point away from the normal.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
		var tc := cb
		cb = cc
		cc = tc
	st.set_normal(n)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(cc)
	st.add_vertex(c)


func _emit_quad(mname: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, base_y: float) -> void:
	var du := p1 - p0
	var dv := p3 - p0
	var nu := clampi(int(ceilf(du.length() / SUB)), 1, 16)
	var nv := clampi(int(ceilf(dv.length() / SUB)), 1, 16)
	var center := (p0 + p2) * 0.5
	var near := _lamps_near(center, (p2 - p0).length() * 0.5)
	var cols: Array = []
	for j in nv + 1:
		for i in nu + 1:
			var q := p0 + du * (float(i) / nu) + dv * (float(j) / nv)
			cols.append(_vcolor(q, n, base_y, near))
	for j in nv:
		for i in nu:
			var q00 := p0 + du * (float(i) / nu) + dv * (float(j) / nv)
			var q10 := p0 + du * (float(i + 1) / nu) + dv * (float(j) / nv)
			var q11 := p0 + du * (float(i + 1) / nu) + dv * (float(j + 1) / nv)
			var q01 := p0 + du * (float(i) / nu) + dv * (float(j + 1) / nv)
			var c00: Color = cols[j * (nu + 1) + i]
			var c10: Color = cols[j * (nu + 1) + i + 1]
			var c11: Color = cols[(j + 1) * (nu + 1) + i + 1]
			var c01: Color = cols[(j + 1) * (nu + 1) + i]
			var st := _chunk_st(mname, (q00 + q11) * 0.5)
			_tri(st, q00, q10, q11, c00, c10, c11, n)
			_tri(st, q00, q11, q01, c00, c11, c01, n)


func _emit_box(rec: Dictionary) -> void:
	var c: Vector3 = rec["c"]
	var s: Vector3 = rec["s"] * 0.5
	var b: Basis = rec["b"]
	var mname: String = rec["m"]
	var base_y := c.y - absf((b * Vector3(0, s.y, 0)).y) - absf((b * Vector3(s.x, 0, 0)).y) - absf((b * Vector3(0, 0, s.z)).y)
	var skip_bottom := base_y < 0.3
	# local face definitions: normal, u axis, v axis, half sizes
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), s.x, s.z, s.y],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), s.x, s.z, s.y],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), s.z, s.x, s.y],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0), s.z, s.x, s.y],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), s.y, s.x, s.z],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), s.y, s.x, s.z],
	]
	for f in faces:
		var ln: Vector3 = f[0]
		if ln.y < -0.5 and skip_bottom:
			continue
		var lu: Vector3 = f[1]
		var lv: Vector3 = f[2]
		var dn: float = f[3]
		var hu: float = f[4]
		var hv: float = f[5]
		var fc := ln * dn
		var p0 := c + b * (fc - lu * hu - lv * hv)
		var p1 := c + b * (fc + lu * hu - lv * hv)
		var p2 := c + b * (fc + lu * hu + lv * hv)
		var p3 := c + b * (fc - lu * hu + lv * hv)
		var wn := (b * ln).normalized()
		_emit_quad(mname, p0, p1, p2, p3, wn, base_y)


func _emit_cyl(rec: Dictionary) -> void:
	var c: Vector3 = rec["c"]
	var r: float = rec["r"]
	var h: float = rec["h"]
	var b: Basis = rec["b"]
	var mname: String = rec["m"]
	var seg: int = rec["seg"]
	var near := _lamps_near(c, maxf(r, h))
	var st := _chunk_st(mname, c)
	var base_y := c.y - absf((b * Vector3(0, h * 0.5, 0)).y)
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := c + b * (d0 * r + Vector3(0, -h * 0.5, 0))
		var p1 := c + b * (d1 * r + Vector3(0, -h * 0.5, 0))
		var p2 := c + b * (d1 * r + Vector3(0, h * 0.5, 0))
		var p3 := c + b * (d0 * r + Vector3(0, h * 0.5, 0))
		var n0 := (b * d0).normalized()
		var n1 := (b * d1).normalized()
		var nm := (n0 + n1).normalized()
		var c0 := _vcolor(p0, n0, base_y, near)
		var c1 := _vcolor(p1, n1, base_y, near)
		var c2 := _vcolor(p2, n1, base_y, near)
		var c3 := _vcolor(p3, n0, base_y, near)
		_tri(st, p0, p1, p2, c0, c1, c2, nm)
		_tri(st, p0, p2, p3, c0, c2, c3, nm)
		var top := c + b * Vector3(0, h * 0.5, 0)
		var tn := (b * Vector3.UP).normalized()
		var ct := _vcolor(top, tn, base_y, near)
		_tri(st, top, p3, p2, ct, ct, ct, tn)
		if base_y > 0.3:
			var bot := c + b * Vector3(0, -h * 0.5, 0)
			var bn := -tn
			_tri(st, bot, p0, p1, ct, ct, ct, bn)


func _emit_dome(rec: Dictionary) -> void:
	var c: Vector3 = rec["c"]
	var r: float = rec["r"]
	var hs: float = rec["hs"]
	var mname: String = rec["m"]
	var seg: int = rec["seg"]
	var rings: int = rec["rings"]
	var full: bool = rec["full"]
	var near := _lamps_near(c, r)
	var st := _chunk_st(mname, c)
	var lat0 := -PI * 0.5 if full else 0.0
	for j in rings:
		var la := lerpf(lat0, PI * 0.5, float(j) / rings)
		var lb := lerpf(lat0, PI * 0.5, float(j + 1) / rings)
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var pts: Array = []
			var nrm: Array = []
			for pair in [[la, a0], [la, a1], [lb, a1], [lb, a0]]:
				var lat: float = pair[0]
				var lon: float = pair[1]
				var dir := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
				pts.append(c + Vector3(dir.x * r, dir.y * r * hs, dir.z * r))
				nrm.append(dir)
			var nm := ((nrm[0] as Vector3) + (nrm[2] as Vector3)).normalized()
			var cs: Array = []
			for k in 4:
				cs.append(_vcolor(pts[k], nrm[k], c.y, near))
			_tri(st, pts[0], pts[1], pts[2], cs[0], cs[1], cs[2], nm)
			_tri(st, pts[0], pts[2], pts[3], cs[0], cs[2], cs[3], nm)



# =====================================================================================
# Cox's Bazar coast props
# =====================================================================================
## Coconut palm: a leaning, slightly curved trunk and a crown of drooping fronds.
func palm(pos: Vector3, s: float = 1.0, lean: float = 0.15, lean_yaw: float = 0.0) -> void:
	var dir := Basis(Vector3.UP, lean_yaw) * Vector3(0, 0, -1)
	var top := pos
	for i in 4:
		var k := float(i) / 4.0
		var seg := 1.6 * s
		var bend := lean * (0.6 + k)
		var a := top
		var b2 := a + Vector3(0, seg * cos(bend), 0) + dir * seg * sin(bend)
		var mid := (a + b2) * 0.5
		var up := (b2 - a).normalized()
		var axis := Vector3.UP.cross(up)
		var basis := Basis.IDENTITY if axis.length() < 0.001 else Basis(axis.normalized(), Vector3.UP.angle_to(up))
		cyl_b(mid, 0.17 * s * (1.0 - 0.15 * k), seg * 1.02, basis, "trunk", i == 0, 6)
		top = b2
	for i in 8:
		var yaw := TAU * float(i) / 8.0 + rng.randf_range(-0.2, 0.2)
		var fb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.35)
		box_b(top + Basis(Vector3.UP, yaw) * Vector3(0, -0.25, -1.2 * s), Vector3(0.55 * s, 0.05, 2.6 * s), fb, "foliage" if i % 2 == 0 else "foliage_dark", false)
	blob(top + Vector3(0, -0.1, 0), 0.35 * s, "trunk", 0.8)


## Beach umbrella with two loungers under it.
func umbrella(pos: Vector3, canopy: String = "", yaw: float = 0.0) -> void:
	var c := canopy
	if c == "":
		c = ["fabric_red", "fabric_blue", "fabric_yellow", "fabric_orange", "fabric_white", "fabric_green"][rng.randi_range(0, 5)]
	cyl(pos, 0.04, 2.4, "metal_grey", false, 6)
	dome(pos + Vector3(0, 2.25, 0), 1.6, c, 0.35, 10, 3)
	var b := Basis(Vector3.UP, yaw)
	for sd: float in [-0.75, 0.75]:
		lounger(pos + b * Vector3(sd, 0, 0.9), yaw)


## Wooden beach lounger (the slatted "kitkat" chairs of Cox's Bazar), back rest up.
func lounger(pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	box_b(pos + b * Vector3(0, 0.3, 0.25), Vector3(0.62, 0.08, 1.3), b, "wood", true, "wood")
	box_b(pos + b * Vector3(0, 0.62, -0.55), Vector3(0.62, 0.08, 0.8), b * Basis(Vector3.RIGHT, 0.85), "wood", false)
	for sx: float in [-0.26, 0.26]:
		for sz: float in [-0.25, 0.8]:
			box_b(pos + b * Vector3(sx, 0.13, sz), Vector3(0.05, 0.26, 0.05), b, "wood_dark", false)


## Wooden fishing boat drawn up on the sand: hull, raised bow and stern, a thatched shelter.
func fishing_boat(pos: Vector3, yaw: float, length: float = 9.0, paint: String = "ship_blue") -> void:
	var b := Basis(Vector3.UP, yaw)
	box_b(pos + b * Vector3(0, 0.45, 0), Vector3(2.2, 0.9, length), b, "wood_dark", true, "wood")
	box_b(pos + b * Vector3(0, 0.75, 0), Vector3(2.25, 0.18, length + 0.05), b, paint, false)
	for e: float in [-1.0, 1.0]:
		box_b(pos + b * Vector3(0, 1.2, e * length * 0.5), Vector3(1.4, 0.7, 1.0), b * Basis(Vector3.RIGHT, -0.5 * e), "wood_dark", true, "wood")
	box_b(pos + b * Vector3(0, 1.75, -length * 0.1), Vector3(2.0, 0.08, 2.6), b, "thatch", false)
	cover_around(pos, Vector2(1.1, length * 0.5), yaw)


## Lifeguard tower: four legs, a platform 2.4 m up reached by a ramp, a sun roof.
func lifeguard_tower(pos: Vector3, yaw: float) -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	for sx: float in [-0.9, 0.9]:
		for sz: float in [-0.9, 0.9]:
			box_b(pos + b * Vector3(sx, 1.2, sz), Vector3(0.12, 2.4, 0.12), b, "wood", true, "wood")
	box_b(pos + b * Vector3(0, 2.45, 0), Vector3(2.2, 0.12, 2.2), b, "wood", true, "wood")
	box_b(pos + b * Vector3(0, 2.85, -1.05), Vector3(2.2, 0.7, 0.06), b, "fabric_red", false)
	box_b(pos + b * Vector3(0, 4.0, 0), Vector3(2.4, 0.08, 2.4), b, "fabric_white", false)
	ramp(pos + b * Vector3(0, 0.0, 4.6), pos + b * Vector3(0, 2.45, 1.0), 0.9, "wood")
	return pos + Vector3(0, 2.51, 0)


## Wooden jetty from the shore (a, on the sand) out over the water (b): deck on piles, rails.
func jetty(a: Vector3, b2: Vector3, width: float = 3.2, deck_y: float = 0.2) -> void:
	var d := b2 - a
	d.y = 0.0
	var length := d.length()
	var yaw := atan2(d.x, d.z)
	var bs := Basis(Vector3.UP, yaw)
	var mid := (a + b2) * 0.5
	box_b(Vector3(mid.x, deck_y - 0.1, mid.z), Vector3(width, 0.2, length), bs, "wood", true, "wood")
	var n := int(length / 4.0)
	for i in n + 1:
		var p := a + d * (float(i) / float(maxi(n, 1)))
		for sx: float in [-1.0, 1.0]:
			cyl(Vector3(p.x, -3.0, p.z) + bs * Vector3(sx * (width * 0.5 - 0.15), 0, 0), 0.12, 3.0 + deck_y + 0.9, "wood_dark", false, 6)
	for sx: float in [-1.0, 1.0]:
		box_b(Vector3(mid.x, deck_y + 0.85, mid.z) + bs * Vector3(sx * (width * 0.5 - 0.1), 0, 0), Vector3(0.08, 0.08, length), bs, "wood", false)
		barrier(a + bs * Vector3(sx * (width * 0.5 + 0.05), 0, 0), b2 + bs * Vector3(sx * (width * 0.5 + 0.05), 0, 0), 1.2)


## Two closed containers stacked (cover, not enterable).
func container_stack(pos: Vector3, yaw: float) -> void:
	container(pos, yaw)
	box(pos + Vector3(0, 3.9, 0), Vector3(2.4, 2.6, 6.0), ["container_orange", "container_white", "container_red", "container_green"][rng.randi_range(0, 3)], true, yaw + rng.randf_range(-0.04, 0.04))


## Rock outcrop (Inani coral rocks, Himchari boulders).
func rock(pos: Vector3, r: float) -> void:
	blob(pos + Vector3(0, r * 0.25, 0), r, "rock", 0.6)
	box_b(pos + Vector3(0, r * 0.2, 0), Vector3(r * 1.1, r * 0.4, r * 1.1), Basis.IDENTITY, "invisible", true, "concrete", false)
