extends Node
## Face photos for "Silent Rescue: Cox's Bazar".
## Scans res://assets/faces/ AND external folders. Fully supports Hero and Hostage photo uploads.

const FaceAlign := preload("res://scripts/actors/FaceAlign.gd")
const FACE_DIR := "res://assets/faces"
const IMAGE_EXTS := ["png", "jpg", "jpeg", "webp", "bmp", "tga"]
const MAX_SIZE := 512
const DEFAULT_SKIN := Color(0.56, 0.39, 0.29)
const DEFAULT_HAIR := Color(0.05, 0.04, 0.035)

var groups := {"hero": {}, "villain": {}, "ally": {}, "hostage": {}}
## character slot photos: role -> {slot number: path}
var slot_paths := {"hero": {}, "ally": {}, "villain": {}, "enemy": {}, "boss": {}, "hostage": {}}
var _tex_cache := {}
var _path_of := {}
const FIT_PATH := "user://faces/fit.cfg"
const ALIGN_PATH := "user://faces/align.cfg"
const SRC_DIR := "user://faces/src"
var _map_of := {}
var _color_cache := {}
var _mission_variant := {}
var _queues := {"villain": [], "ally": [], "hostage": []}
var _queue_pos := {"villain": 0, "ally": 0, "hostage": 0}
var _rng := RandomNumberGenerator.new()
var _face_shader: Shader


func _ready() -> void:
	_rng.randomize()
	_face_shader = load("res://shaders/face.gdshader")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://faces"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SRC_DIR))
	rescan()


func external_dirs() -> Array:
	var dirs: Array = []
	if not OS.has_feature("editor"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("faces"))
	dirs.append(ProjectSettings.globalize_path("user://faces"))
	return dirs


func rescan() -> void:
	groups = {"hero": {}, "villain": {}, "ally": {}, "hostage": {}}
	_tex_cache.clear()
	_color_cache.clear()
	_map_of.clear()
	var found: Array = []
	_collect(FACE_DIR, found)
	for d in external_dirs():
		_collect(str(d), found)
	for p in found:
		_classify(str(p))
	_assign_slots(found)
	begin_mission()
	print("[AssetLoader] heroes=%d villains=%d allies=%d hostages=%d" % [groups["hero"].size(), groups["villain"].size(), groups["ally"].size(), groups["hostage"].size()])


func _collect(dir_path: String, out: Array) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	var seen := {}
	for f in da.get_files():
		var fname: String = f
		if fname.ends_with(".import"):
			fname = fname.trim_suffix(".import")
		elif fname.ends_with(".remap"):
			continue
		var ext := fname.get_extension().to_lower()
		if not IMAGE_EXTS.has(ext) or seen.has(fname):
			continue
		seen[fname] = true
		out.append(dir_path.path_join(fname))


func _classify(path: String) -> void:
	var base := path.get_file().get_basename().to_lower()
	var role := ""
	var rest := ""
	var tag := ""
	if base.begins_with("hero"):
		role = "hero"
	elif base.begins_with("profile"):
		role = "villain"
		rest = base.substr(7)
	elif base.begins_with("villain"):
		role = "villain"
		rest = base.substr(7)
	elif base.begins_with("hostage"):
		role = "hostage"
		rest = base.substr(7)
	elif base.begins_with("other"):
		role = "ally"
		rest = base.substr(5)
	elif base.begins_with("police"):
		role = "ally"
		rest = base.substr(6)
		tag = "police:"
	elif base.begins_with("ally"):
		role = "ally"
		rest = base.substr(4)
	else:
		return
	var key := "hero" if role == "hero" else tag + _person_key(rest)
	var g: Dictionary = groups[role]
	if not g.has(key):
		g[key] = []
	var arr: Array = g[key]
	if not arr.has(path):
		arr.append(path)


func _person_key(rest: String) -> String:
	var tokens := rest.replace("-", "_").replace(" ", "_").replace(".", "_").split("_", false)
	if tokens.is_empty():
		return "0"
	var first: String = tokens[0]
	if first.is_valid_int():
		return str(first.to_int())
	var stripped := first
	while stripped.length() > 1 and stripped.right(1).is_valid_int():
		stripped = stripped.left(stripped.length() - 1)
	return stripped


## slot_<role>_<n> files first; loose legacy photos fill the empty slots in alphabetical order.
func _assign_slots(found: Array) -> void:
	slot_paths = {"hero": {}, "ally": {}, "villain": {}, "enemy": {}, "boss": {}, "hostage": {}}
	var sorted := found.duplicate()
	sorted.sort()
	var legacy_ally: Array = []
	var legacy_gang: Array = []
	
	for p in sorted:
		var base := str(p).get_file().get_basename().to_lower()
		if base.begins_with("slot_"):
			var parts := base.split("_")
			if parts.size() >= 3 and slot_paths.has(parts[1]) and parts[2].is_valid_int():
				(slot_paths[parts[1]] as Dictionary)[int(parts[2])] = str(p)
		elif base.begins_with("hostage_custom"):
			var num_str := base.trim_prefix("hostage_custom")
			if num_str.is_valid_int():
				(slot_paths["hostage"] as Dictionary)[int(num_str)] = str(p)
		elif base.begins_with("hero_custom"):
			var num_str := base.trim_prefix("hero_custom")
			if num_str.is_valid_int():
				(slot_paths["hero"] as Dictionary)[int(num_str)] = str(p)
		elif base.begins_with("hostage_"):
			# Legacy fallback for hostages
			var num_str := base.trim_prefix("hostage_")
			if num_str.is_valid_int():
				(slot_paths["hostage"] as Dictionary)[int(num_str)] = str(p)
		elif base.begins_with("other") or base.begins_with("ally") or base.begins_with("police"):
			legacy_ally.append(str(p))
		elif base.begins_with("profile") or base.begins_with("villain"):
			legacy_gang.append(str(p))
			
	for p in legacy_ally:
		for n in range(1, Game.ALLY_SLOTS + 1):
			if not (slot_paths["ally"] as Dictionary).has(n):
				slot_paths["ally"][n] = p
				break
				
	var gang_slots: Array = []
	for n in range(1, Game.VILLAIN_SLOTS + 1):
		gang_slots.append(["villain", n])
	for n in range(1, Game.ENEMY_SLOTS + 1):
		gang_slots.append(["enemy", n])
	gang_slots.append(["boss", 1])
	
	for p in legacy_gang:
		for gs in gang_slots:
			if not (slot_paths[gs[0]] as Dictionary).has(int(gs[1])):
				slot_paths[gs[0]][int(gs[1])] = p
				break


## The photo of a character slot ("" = slider face).
func slot_face_key(role: String, slot: int) -> String:
	return str((slot_paths.get(role, {}) as Dictionary).get(slot, ""))


func slot_file_name(role: String, slot: int) -> String:
	return "slot_%s_%d.png" % [role, slot]


func begin_mission() -> void:
	_mission_variant.clear()
	for role in ["villain", "ally", "hostage"]:
		var keys: Array = groups[role].keys()
		keys.sort()
		_queues[role] = keys
		_queue_pos[role] = 0


func next_person(role: String) -> String:
	var q: Array = _queues.get(role, [])
	if q.is_empty():
		return ""
	var pos: int = int(_queue_pos[role])
	var key: String = q[pos % q.size()]
	_queue_pos[role] = pos + 1
	return key


func has_role(role: String) -> bool:
	return not (groups.get(role, {}) as Dictionary).is_empty()


func variant_path(role: String, key: String) -> String:
	var g: Dictionary = groups.get(role, {})
	if key == "" or not g.has(key):
		return ""
	var vk := role + "|" + key
	if not _mission_variant.has(vk):
		var variants: Array = (g[key] as Array).duplicate()
		variants.sort()
		_mission_variant[vk] = variants[0]
	return str(_mission_variant[vk])


func face_texture(role: String, key: String) -> Texture2D:
	var p := variant_path(role, key)
	return null if p == "" else get_texture(p)


## Now actually returns the hero's uploaded texture if it exists!
func hero_texture() -> Texture2D:
	var p := slot_face_key("hero", 1)
	if p != "":
		return get_texture(p)
	return null


func display_name(_role: String, key: String) -> String:
	var k := key.replace("police:", "")
	if k == "" or k.is_valid_int():
		return ""
	return k.capitalize()


func _load_image(path: String) -> Image:
	var img: Image = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		if t != null:
			img = t.get_image()
	if img == null:
		img = Image.new()
		if img.load(path) != OK:
			return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	if maxi(w, h) > MAX_SIZE:
		var s: float = float(MAX_SIZE) / float(maxi(w, h))
		img.resize(maxi(1, int(w * s)), maxi(1, int(h * s)), Image.INTERPOLATE_LANCZOS)
	return img


func get_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	var img := _load_image(path)
	if img != null:
		var map := face_map(path, Vector2(img.get_width(), img.get_height()))
		_color_cache[path] = _sample_colors(img, map)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
		_color_cache[tex.get_instance_id()] = _color_cache[path]
		_path_of[tex.get_instance_id()] = path
		_map_of[tex.get_instance_id()] = map
	_tex_cache[path] = tex
	return tex


func _patch(img: Image, c: Vector2, r: float) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var acc := Color(0, 0, 0)
	var n := 0
	var cx := int(c.x)
	var cy := int(c.y)
	var rr := maxi(1, int(r))
	var step := maxi(1, rr / 4)
	for y in range(cy - rr, cy + rr + 1, step):
		for x in range(cx - rr, cx + rr + 1, step):
			if x >= 0 and y >= 0 and x < w and y < h:
				acc += img.get_pixel(x, y)
				n += 1
	if n == 0:
		return DEFAULT_SKIN
	return Color(acc.r / n, acc.g / n, acc.b / n)


static func _lum(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


const SKIN_SPOTS := [[Vector2(0.0324, -0.018), 0.0067], [Vector2(-0.0324, -0.018), 0.0067], [Vector2(0.0, 0.0405), 0.0067], [Vector2(0.0, -0.0229), 0.0048], [Vector2(0.0152, -0.0473), 0.0057], [Vector2(-0.0152, -0.0473), 0.0057]]
const HAIR_SPOTS := [[Vector2(0.0, 0.104), 0.0076], [Vector2(0.023, 0.0965), 0.0067], [Vector2(-0.023, 0.0965), 0.0067], [Vector2(0.0, 0.0868), 0.0067]]


func _sample_colors(img: Image, map: Transform2D) -> Dictionary:
	var ppm := map.x.length()
	var sk := []
	for sp in SKIN_SPOTS:
		sk.append(_patch(img, map * (sp[0] as Vector2), float(sp[1]) * ppm))
	sk.sort_custom(func(a: Color, b: Color): return _lum(a) < _lum(b))
	var skin: Color = (sk[2] as Color).lerp(sk[3], 0.5)
	if skin.r < skin.b or _lum(skin) < 0.08:
		skin = DEFAULT_SKIN
	skin = Color.from_hsv(clampf(skin.h if skin.h < 0.5 else 0.05, 0.03, 0.085), clampf(skin.s, 0.3, 0.55), clampf(skin.v, 0.32, 0.82))
	var hs := []
	for hp in HAIR_SPOTS:
		hs.append(_patch(img, map * (hp[0] as Vector2), float(hp[1]) * ppm))
	hs.sort_custom(func(a: Color, b: Color): return _lum(a) < _lum(b))
	var hair: Color = hs[0]
	var d := Vector3(hair.r - skin.r, hair.g - skin.g, hair.b - skin.b).length()
	if _lum(hair) > 0.45:
		hair = DEFAULT_HAIR
	elif d < 0.12:
		hair = skin.darkened(0.12)
	else:
		hair = hair.darkened(0.1)
	hair = Color.from_hsv(0.07, clampf(hair.s, 0.0, 0.35), clampf(hair.v, 0.02, 0.32))
	if d < 0.12:
		hair = skin.darkened(0.12)
	return {"skin": skin, "hair": hair}


func colors_for(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {"skin": DEFAULT_SKIN, "hair": DEFAULT_HAIR}
	return _color_cache.get(tex.get_instance_id(), {"skin": DEFAULT_SKIN, "hair": DEFAULT_HAIR})


func load_fit(file_name: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(FIT_PATH) != OK or not cf.has_section(file_name):
		return {}
	return {"l": cf.get_value(file_name, "l", Vector2(0.4, 0.45)), "r": cf.get_value(file_name, "r", Vector2(0.6, 0.45)), "m": cf.get_value(file_name, "m", Vector2(0.5, 0.7))}


func save_fit(file_name: String, l: Vector2, r: Vector2, mo: Vector2) -> void:
	var cf := ConfigFile.new()
	cf.load(FIT_PATH)
	cf.set_value(file_name, "l", l)
	cf.set_value(file_name, "r", r)
	cf.set_value(file_name, "m", mo)
	cf.save(FIT_PATH)


func remove_fit(file_name: String) -> void:
	var cf := ConfigFile.new()
	if cf.load(FIT_PATH) == OK and cf.has_section(file_name):
		cf.erase_section(file_name)
		cf.save(FIT_PATH)


func load_align(file_name: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(ALIGN_PATH) != OK or not cf.has_section(file_name):
		return {}
	var d := {}
	for k in cf.get_section_keys(file_name):
		d[k] = cf.get_value(file_name, k)
	return d


func save_align(file_name: String, src_name: String, l: Vector2, r: Vector2, m: Vector2, xf: Transform2D, src_size: Vector2, extra: Dictionary = {}) -> void:
	var cf := ConfigFile.new()
	cf.load(ALIGN_PATH)
	if cf.has_section(file_name):
		cf.erase_section(file_name)
	cf.set_value(file_name, "src", src_name)
	cf.set_value(file_name, "l", l)
	cf.set_value(file_name, "r", r)
	cf.set_value(file_name, "m", m)
	cf.set_value(file_name, "xf", xf)
	cf.set_value(file_name, "size", src_size)
	for k in extra.keys():
		cf.set_value(file_name, k, extra[k])
	cf.save(ALIGN_PATH)


## The measured 3-D face shape saved by the 41-landmark fit, if any.
func face_shape(file_name: String) -> Dictionary:
	if file_name == "":
		return {}
	var a := load_align(file_name)
	var s: Variant = a.get("shape", null)
	return s if s is Dictionary else {}


func remove_align(file_name: String) -> void:
	var cf := ConfigFile.new()
	if cf.load(ALIGN_PATH) == OK and cf.has_section(file_name):
		cf.erase_section(file_name)
		cf.save(ALIGN_PATH)


func src_dir() -> String:
	var d := ProjectSettings.globalize_path(SRC_DIR)
	DirAccess.make_dir_recursive_absolute(d)
	return d


func face_map(path: String, size: Vector2) -> Transform2D:
	var fname := path.get_file()
	var al := load_align(fname)
	if not al.is_empty():
		# A 41-landmark fit stores the exact head -> photo map used for the shader.
		if al.get("map") is Transform2D:
			return al["map"]
		# Older aligned files are always exactly OUT_SIZE square.
		var k := size.x / float(FaceAlign.OUT_SIZE)
		return Transform2D(Vector2(k, 0.0), Vector2(0.0, k), Vector2.ZERO) * FaceAlign.head_to_aligned()
	var pts: Array = []
	var fit := load_fit(fname)
	if not fit.is_empty():
		pts = FaceAlign.order_points((fit["l"] as Vector2) * size, (fit["r"] as Vector2) * size, (fit["m"] as Vector2) * size)
	else:
		pts = FaceAlign.default_points(size)
	return FaceAlign.head_to_photo(FaceAlign.alignment(pts[0], pts[1], pts[2]))


func make_face_material(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _face_shader
	m.set_shader_parameter("face_tex", tex)
	m.set_shader_parameter("has_photo", tex != null)
	if tex != null:
		var size := Vector2(tex.get_width(), tex.get_height())
		m.set_shader_parameter("tex_size", size)
		var map: Transform2D = _map_of.get(tex.get_instance_id(), FaceAlign.head_to_photo(FaceAlign.alignment(Vector2(0.4, 0.45) * size, Vector2(0.6, 0.45) * size, Vector2(0.5, 0.7) * size)))
		m.set_shader_parameter("face_xform", FaceAlign.shader_matrix(map, size))
		var c := colors_for(tex)
		m.set_shader_parameter("skin_color", c["skin"])
		m.set_shader_parameter("hair_color", c["hair"])
	return m


func apply_face(model: Node, role: String, key: String) -> bool:
	if key == "":
		return false
	var tex: Texture2D = get_texture(key) if (key.begins_with("res://") or key.begins_with("user://") or key.is_absolute_path()) else face_texture(role, key)
	if tex == null or model == null:
		return false
	if model.has_method("apply_photo"):
		var fname := ""
		if key.begins_with("res://") or key.begins_with("user://") or key.is_absolute_path():
			fname = key.get_file()
		else:
			fname = variant_path(role, key).get_file()
		if model.has_method("apply_face_shape"):
			model.apply_face_shape(face_shape(fname))
		model.apply_photo(make_face_material(tex))
		return true
	return false
