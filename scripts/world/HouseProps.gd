extends Node3D
## Phase 3 house life, one script for small props (kind):
##   "gate"    - steel collapsible gate (কলাপসিবল গেট) locking the stairs at the ground floor, as in
##               almost every Dhaka apartment house. The resident opens it after a right MCQ answer;
##               a grenade / time bomb can also blow it open (loud).
##   "chair"   - moulded plastic chair; residents (and anyone placed there) sit on it.
##   "cache"   - the gang's weapons consignment (crates of rifles): only a grenade, Molotov fire or a
##               time bomb destroys it (side mission, points).
##   "vending" - snack machine: chocolate, biscuits, chips - free, one at a time (E). Snacks heal the
##               Freelancer (Y) or are given to a hungry hostage whose tape is off (Y).
##   "sofa"    - a two-seat cane sofa with cushions (beach houses: house hostages sit on it)

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")

var kind := "chair"
var open := false
var _body: StaticBody3D
var _bars: Node3D
var _label: Label3D
var _t := 0.0


static func make(p_kind: String) -> Node3D:
	var n: Node3D = load("res://scripts/world/HouseProps.gd").new()
	n.kind = p_kind
	return n


func _ready() -> void:
	match kind:
		"gate":
			_build_gate()
		"vending":
			_build_vending()
		"cache":
			_build_cache()
		"ammo":
			_build_ammo()
		"bed":
			_build_bed()
		"cage":
			_build_cage()
		"meter":
			_build_meter()
		"sofa":
			_build_sofa()
		_:
			_build_chair()


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _collider(size: Vector3, pos: Vector3) -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = Game.L_WORLD
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	_body.add_child(cs)
	add_child(_body)


# ---------------------------------------------------------------- collapsible gate
func _build_gate() -> void:
	add_to_group("actors")
	add_to_group("gates")
	var steel := CharacterModel.mat(Color(0.2, 0.22, 0.2), 0.45)
	_bars = Node3D.new()
	add_child(_bars)
	var w := 1.5
	# vertical channels + scissor lattice + top / bottom rails
	for i in 7:
		var x := -w * 0.5 + w * float(i) / 6.0
		_box(Vector3(0.035, 2.1, 0.05), Vector3(x, 1.05, 0), steel, _bars)
	for j in 4:
		for i in 6:
			var x0 := -w * 0.5 + w * float(i) / 6.0
			var bar := _box(Vector3(0.02, 0.62, 0.02), Vector3(x0 + w / 12.0, 0.28 + 0.52 * float(j), 0), steel, _bars)
			bar.rotation.z = 0.43 * (1.0 if (i + j) % 2 == 0 else -1.0)
	_box(Vector3(w + 0.1, 0.06, 0.08), Vector3(0, 2.1, 0), steel, _bars)
	_box(Vector3(w + 0.1, 0.05, 0.08), Vector3(0, 0.03, 0), steel, _bars)
	# padlock
	_box(Vector3(0.07, 0.09, 0.04), Vector3(0.0, 1.05, 0.05), CharacterModel.mat(Color(0.65, 0.55, 0.25), 0.4), _bars)
	_collider(Vector3(w, 2.2, 0.15), Vector3(0, 1.1, 0))
	# grille along the open side of the lowest steps so nobody climbs on from the hallway
	for i in 6:
		_box(Vector3(0.03, 2.0, 0.03), Vector3(-w * 0.5 - 0.02, 1.0, -0.3 * float(i) - 0.15), steel, _bars)
	_box(Vector3(0.05, 0.05, 1.9), Vector3(-w * 0.5 - 0.02, 2.0, -0.95), steel, _bars)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.12, 2.2, 1.9)
	cs.shape = sh
	cs.position = Vector3(-w * 0.5 - 0.02, 1.1, -0.95)
	_body.add_child(cs)


## Explosions (grenade / time bomb) can blow the gate off its rails or destroy the weapons cache.
func take_damage(amount: float, _from_pos: Vector3, _attacker: Node) -> void:
	if kind == "gate" and not open and amount >= 60.0:
		open_gate(true)
	elif kind == "ammo" and not open and amount >= 40.0:
		open = true
		remove_from_group("actors")
		if _label != null:
			_label.text = "গুলির বাক্স ধ্বংস"
		for c in get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = CharacterModel.mat(Color(0.06, 0.05, 0.04), 1.0)
	elif kind == "cache" and not open and amount >= 12.0:
		_hp -= amount
		if _hp <= 0.0:
			open = true
			remove_from_group("actors")
			if _label != null:
				_label.text = "চালান ধ্বংস"
			for c in get_children():
				if c is MeshInstance3D:
					(c as MeshInstance3D).material_override = CharacterModel.mat(Color(0.06, 0.05, 0.04), 1.0)
			if Game.level != null and Game.level.has_method("on_cache_destroyed"):
				Game.level.on_cache_destroyed(self)


var _hp := 100.0


## Gang ammo point: two green ammo boxes on a pallet. Gunmen who run dry come here to restock.
func _build_ammo() -> void:
	add_to_group("actors")
	add_to_group("ammo_crates")
	var green := CharacterModel.mat(Color(0.24, 0.3, 0.17), 0.7)
	var wood := CharacterModel.mat(Color(0.45, 0.35, 0.22), 0.9)
	_box(Vector3(1.0, 0.12, 0.8), Vector3(0, 0.06, 0), wood)
	_box(Vector3(0.45, 0.3, 0.28), Vector3(-0.24, 0.27, 0.0), green)
	_box(Vector3(0.45, 0.3, 0.28), Vector3(0.24, 0.27, 0.05), green)
	_box(Vector3(0.45, 0.3, 0.28), Vector3(0.0, 0.57, 0.02), green)
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "গুলির বাক্স"
	_label.font_size = 26
	_label.pixel_size = 0.003
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.75, 0.4)
	_label.position = Vector3(0, 1.1, 0)
	_label.visibility_range_end = 25.0
	add_child(_label)


func _build_cache() -> void:
	add_to_group("actors")
	add_to_group("caches")
	var wood := CharacterModel.mat(Color(0.32, 0.36, 0.2), 0.8)
	var dark := CharacterModel.mat(Color(0.12, 0.12, 0.1), 0.6)
	for i in 3:
		_box(Vector3(1.1, 0.42, 0.5), Vector3(0, 0.21 + 0.42 * float(i), 0), wood)
		_box(Vector3(1.12, 0.05, 0.52), Vector3(0, 0.4 + 0.42 * float(i), 0), dark)
	_box(Vector3(0.9, 0.4, 0.45), Vector3(0, 0.2, 0.55), wood)
	_collider(Vector3(1.1, 1.3, 1.0), Vector3(0, 0.65, 0.25))
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "অস্ত্রের চালান — গ্রেনেড / মলোটভ / টাইম বোমা দিয়ে ধ্বংস করুন"
	_label.font_size = 26
	_label.pixel_size = 0.003
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.6, 0.4)
	_label.position = Vector3(0, 1.6, 0)
	_label.visibility_range_end = 12.0
	add_child(_label)


func open_gate(blown: bool = false) -> void:
	if open:
		return
	open = true
	if _body != null:
		_body.queue_free()
		_body = null
	remove_from_group("actors")
	if blown:
		AudioManager.play_3d("sfx_impact", global_position + Vector3(0, 1, 0), 2.0, 0.7, 60.0)
		_bars.rotation = Vector3(-1.2, 0.3, 0.2)
		_bars.position = Vector3(0, 0.15, 0.8)
	else:
		# folded to one side, the way a collapsible gate concertinas
		AudioManager.play_3d("sfx_door", global_position + Vector3(0, 1, 0), -2.0, 1.2, 25.0)
		var tw := create_tween()
		tw.tween_property(_bars, "scale:x", 0.18, 1.1)
		tw.parallel().tween_property(_bars, "position:x", -0.62, 1.1)


# ---------------------------------------------------------------- plastic chair
func _build_chair() -> void:
	add_to_group("chairs")
	var c: Color = [Color(0.15, 0.35, 0.65), Color(0.75, 0.15, 0.12), Color(0.9, 0.88, 0.82), Color(0.2, 0.5, 0.28)][randi() % 4]
	var plastic := CharacterModel.mat(c, 0.55)
	_box(Vector3(0.44, 0.04, 0.42), Vector3(0, 0.45, 0), plastic)
	var back := _box(Vector3(0.44, 0.42, 0.035), Vector3(0, 0.68, 0.21), plastic)
	back.rotation.x = -0.12
	for sx: float in [-0.19, 0.19]:
		for sz: float in [-0.18, 0.18]:
			var leg := _box(Vector3(0.035, 0.46, 0.035), Vector3(sx, 0.23, sz), plastic)
			leg.rotation = Vector3(0.06 * signf(sz), 0, -0.06 * signf(sx))
	for sx2: float in [-0.23, 0.23]:
		_box(Vector3(0.035, 0.03, 0.36), Vector3(sx2, 0.62, 0.02), plastic)


# ---------------------------------------------------------------- snack machine
func _build_vending() -> void:
	add_to_group("interactables")
	var red := CharacterModel.mat(Color(0.62, 0.08, 0.08), 0.5)
	var dark := CharacterModel.mat(Color(0.06, 0.06, 0.07), 0.3)
	_box(Vector3(0.95, 1.85, 0.8), Vector3(0, 0.925, 0), red)
	_box(Vector3(0.62, 1.2, 0.02), Vector3(-0.1, 1.15, -0.405), dark)
	var cols := [Color(0.45, 0.25, 0.1), Color(0.9, 0.75, 0.2), Color(0.2, 0.45, 0.8), Color(0.85, 0.3, 0.2), Color(0.3, 0.6, 0.3)]
	for r in 4:
		for k in 4:
			_box(Vector3(0.11, 0.18, 0.05), Vector3(-0.35 + float(k) * 0.16, 0.7 + float(r) * 0.27, -0.39), CharacterModel.mat(cols[(r + k) % cols.size()], 0.6))
	_box(Vector3(0.18, 0.5, 0.02), Vector3(0.33, 1.25, -0.405), CharacterModel.mat(Color(0.1, 0.1, 0.12), 0.4))
	_box(Vector3(0.6, 0.14, 0.04), Vector3(-0.1, 0.3, -0.41), dark)
	_collider(Vector3(0.95, 1.85, 0.8), Vector3(0, 0.925, 0))
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "চকলেট • বিস্কুট • চিপস — বিনামূল্যে"
	_label.font_size = 30
	_label.pixel_size = 0.0035
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.85, 0.5)
	_label.position = Vector3(0, 2.15, 0)
	_label.visibility_range_end = 20.0
	add_child(_label)


func can_interact() -> bool:
	if kind == "cage":
		return not open
	return kind == "vending"


func prompt_text() -> String:
	if kind == "cage":
		var has_key: bool = Game.player != null and int(Game.player.get("keys")) > 0
		if has_key:
			return "[E] খাঁচার তালা চাবি দিয়ে খুলুন"
		return "[E চেপে ধরুন] তালা কেটে খুলুন — শব্দ হবে (%s%%)   চাবি থাকলে নিঃশব্দে খোলে" % Game.bn(int(_cut / CUT_TIME * 100.0))
	var p := Game.player
	var n: int = int(p.get("snacks")) if p != null else 0
	return "[E] চকলেট / বিস্কুট নিন (খাবার %sটি) • [Y] খান" % Game.bn(n)


func on_interact_pressed(player: Node) -> void:
	if kind == "cage":
		if not open and int(player.get("keys")) > 0:
			player.set("keys", int(player.get("keys")) - 1)
			AudioManager.play_3d("sfx_switch", global_position + Vector3(0, 1, 0), -2.0, 0.6, 15.0)
			open_cage()
		return
	if kind != "vending":
		return
	if int(player.get("snacks")) >= 6:
		AudioManager.say("", "পকেট ভরা — আগে কিছু খাবার কাজে লাগান।", 2.0)
		return
	player.set("snacks", int(player.get("snacks")) + 1)
	AudioManager.play_3d("sfx_coin", global_position + Vector3(0, 1.2, 0), -6.0, 1.0, 10.0)
	AudioManager.play_3d("sfx_vend", global_position + Vector3(0, 0.8, 0), -4.0, 1.0, 15.0)
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("একটি খাবার নিলেন", Color(1.0, 0.85, 0.5))


# ---------------------------------------------------------------- bed (resident's room)
## Wooden khaat with a mattress, pillow and a folded kantha. Two places to sit on the long edge
## (seat_transform): sheltered hostages sit there while the resident gives food, water and first aid.
## Phase 7: four corner posts for the X-bed tie (an unconscious hostage is strapped spread-eagle on
## the mattress for the medical procedure). lie_transform() places the body on its back, head to the
## pillow; occupant tracks who is strapped there.
var occupant: Node = null


func _build_bed() -> void:
	add_to_group("beds")
	var wood := CharacterModel.mat(Color(0.36, 0.22, 0.12), 0.7)
	var cloth := CharacterModel.mat(Color(0.86, 0.84, 0.78), 0.9)
	var sheet := CharacterModel.mat(Color(0.32, 0.45, 0.62), 0.85)
	_box(Vector3(1.15, 0.12, 2.0), Vector3(0, 0.32, 0), wood)
	for sx: float in [-0.52, 0.52]:
		for sz: float in [-0.93, 0.93]:
			_box(Vector3(0.07, 0.32, 0.07), Vector3(sx, 0.16, sz), wood)
	_box(Vector3(1.15, 0.6, 0.06), Vector3(0, 0.62, -0.98), wood)
	_box(Vector3(1.05, 0.12, 1.9), Vector3(0, 0.44, 0.02), cloth)
	_box(Vector3(1.06, 0.03, 1.2), Vector3(0, 0.51, 0.35), sheet)
	var pil := _box(Vector3(0.62, 0.11, 0.32), Vector3(0, 0.55, -0.72), cloth)
	pil.rotation.x = -0.12
	# corner posts the X-straps run to
	for sx2: float in [-0.52, 0.52]:
		for sz2: float in [-0.93, 0.93]:
			_box(Vector3(0.06, 0.5, 0.06), Vector3(sx2, 0.62, sz2), wood)
			_box(Vector3(0.09, 0.05, 0.09), Vector3(sx2, 0.88, sz2), wood)


## Where a strapped body lies: on the mattress, on its back, head towards the pillow (-Z).
func lie_transform() -> Transform3D:
	return Transform3D(global_transform.basis * Basis(Vector3.UP, PI), global_transform * Vector3(0, 0.58, 0.05))


func free_bed() -> bool:
	return occupant == null or not is_instance_valid(occupant)


## Cane sofa: the sitters face -Z (local), the back rest is at +Z. seat_transform(0 / 1): left / right.
func _build_sofa() -> void:
	add_to_group("sofas")
	var cane := CharacterModel.mat(Color(0.62, 0.45, 0.24), 0.7)
	var cush := CharacterModel.mat([Color(0.2, 0.55, 0.65), Color(0.85, 0.5, 0.3), Color(0.9, 0.85, 0.7)][randi() % 3], 0.95)
	_box(Vector3(1.8, 0.1, 0.7), Vector3(0, 0.34, 0.05), cane)
	_box(Vector3(1.7, 0.1, 0.62), Vector3(0, 0.44, 0.03), cush)
	_box(Vector3(1.8, 0.55, 0.08), Vector3(0, 0.66, 0.38), cane)
	_box(Vector3(1.6, 0.4, 0.1), Vector3(0, 0.7, 0.3), cush)
	for sx: float in [-0.93, 0.93]:
		_box(Vector3(0.08, 0.32, 0.7), Vector3(sx, 0.56, 0.05), cane)
		for sz: float in [-0.28, 0.36]:
			_box(Vector3(0.06, 0.34, 0.06), Vector3(sx * 0.95, 0.17, sz), cane)
	_collider(Vector3(1.8, 0.45, 0.7), Vector3(0, 0.22, 0.05))


func seat_transform(i: int) -> Transform3D:
	if kind == "sofa":
		return Transform3D(global_transform.basis, global_transform * Vector3(-0.45 + 0.9 * float(i), 0.0, 0.02))
	if kind == "chair":
		return global_transform
	# on the long edge (+X side), facing out of the bed
	var local := Vector3(0.36, 0.0, -0.35 + 0.72 * float(i))
	return Transform3D(global_transform.basis * Basis(Vector3.UP, -PI * 0.5), global_transform * local)


# ---------------------------------------------------------------- cage (captured Alpha members)
const CUT_TIME := 6.0
var _cut := 0.0

func _build_cage() -> void:
	add_to_group("interactables")
	add_to_group("cages")
	var steel := CharacterModel.mat(Color(0.18, 0.19, 0.2), 0.4)
	_bars = Node3D.new()
	add_child(_bars)
	var w := 2.2
	var h := 2.2
	for i in 12:
		var x := -w * 0.5 + w * float(i) / 11.0
		_box(Vector3(0.035, h, 0.035), Vector3(x, h * 0.5, w * 0.5), steel)
		_box(Vector3(0.035, h, 0.035), Vector3(x, h * 0.5, -w * 0.5), steel)
		_box(Vector3(0.035, h, 0.035), Vector3(w * 0.5, h * 0.5, x), steel)
	for i in 12:
		var x2 := -w * 0.5 + w * float(i) / 11.0
		_box(Vector3(0.035, h, 0.035), Vector3(-w * 0.5, h * 0.5, x2), steel, _bars)
	for yy: float in [0.06, h - 0.03]:
		_box(Vector3(w, 0.05, 0.05), Vector3(0, yy, w * 0.5), steel)
		_box(Vector3(w, 0.05, 0.05), Vector3(0, yy, -w * 0.5), steel)
		_box(Vector3(0.05, 0.05, w), Vector3(w * 0.5, yy, 0), steel)
		_box(Vector3(0.05, 0.05, w), Vector3(-w * 0.5, yy, 0), steel, _bars)
	_box(Vector3(0.12, 0.16, 0.06), Vector3(-w * 0.5 - 0.04, 1.05, 0.0), CharacterModel.mat(Color(0.75, 0.6, 0.2), 0.3), _bars)
	_body = StaticBody3D.new()
	_body.collision_layer = Game.L_WORLD
	for sp in [[Vector3(w, h, 0.08), Vector3(0, h * 0.5, w * 0.5)], [Vector3(w, h, 0.08), Vector3(0, h * 0.5, -w * 0.5)], [Vector3(0.08, h, w), Vector3(w * 0.5, h * 0.5, 0)], [Vector3(0.08, h, w), Vector3(-w * 0.5, h * 0.5, 0)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sp[0]
		cs.shape = sh
		cs.position = sp[1]
		_body.add_child(cs)
	add_child(_body)
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "তালাবন্ধ খাঁচা"
	_label.font_size = 30
	_label.pixel_size = 0.0035
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.6, 0.45)
	_label.position = Vector3(0, 2.5, 0)
	_label.visibility_range_end = 16.0
	add_child(_label)


func on_interact_held(_player: Node, holding: bool, delta: float) -> void:
	if kind != "cage" or open:
		return
	if holding and int(_player.get("keys")) <= 0:
		_cut += delta
		if int(_cut * 3.0) != int((_cut - delta) * 3.0):
			AudioManager.play_3d("sfx_rope", global_position + Vector3(0, 1, 0), -4.0, 0.5, 25.0)
			Game.noise(global_position, 22.0, "player")
		if _cut >= CUT_TIME:
			open_cage()
	else:
		_cut = maxf(_cut - delta, 0.0)


func progress() -> float:
	return _cut / CUT_TIME if kind == "cage" else 0.0


func open_cage() -> void:
	if open:
		return
	open = true
	remove_from_group("interactables")
	AudioManager.play_3d("sfx_door", global_position + Vector3(0, 1, 0), -2.0, 0.8, 25.0)
	if _body != null:
		# the door side swings open: drop its collider
		for c in _body.get_children():
			if (c as CollisionShape3D).position.x < -0.5:
				c.queue_free()
	var tw := create_tween()
	tw.tween_property(_bars, "rotation:y", -1.5, 0.9)
	if _label != null:
		_label.text = "খাঁচা খোলা"
		_label.modulate = Color(0.6, 1.0, 0.6)
	if Game.level != null and Game.level.get("utils") != null:
		Game.level.utils.on_cage_open(self)


# ---------------------------------------------------------------- electric meter box
var power_off := false
var _lamp: MeshInstance3D

func _build_meter() -> void:
	add_to_group("meters")
	var grey := CharacterModel.mat(Color(0.55, 0.57, 0.55), 0.6)
	_box(Vector3(0.42, 0.55, 0.16), Vector3(0, 1.55, 0), grey)
	_box(Vector3(0.3, 0.14, 0.02), Vector3(0, 1.62, -0.085), CharacterModel.mat(Color(0.75, 0.82, 0.75), 0.2))
	_lamp = _box(Vector3(0.05, 0.05, 0.03), Vector3(0.12, 1.42, -0.085), CharacterModel.mat(Color(0.2, 1.0, 0.3), 0.3))
	for i in 3:
		_box(Vector3(0.025, 1.4, 0.025), Vector3(-0.12 + 0.12 * float(i), 2.5, 0.0), CharacterModel.mat(Color(0.08, 0.08, 0.08), 0.6))


func set_power(on: bool) -> void:
	power_off = not on
	if _lamp != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 1.0, 0.3) if on else Color(1.0, 0.15, 0.1)
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.5
		_lamp.material_override = m
