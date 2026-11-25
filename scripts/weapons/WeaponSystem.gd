extends Node3D
## Player weapon handling: BD-08 rifle (1), Type-54 pistol (2), captured Type-56 (3).
## Raycast shooting with penetration, recoil, spread bloom, ADS zoom, muzzle flash, reload, viewmodel sway.

const WeaponData := preload("res://scripts/weapons/WeaponData.gd")
const Ballistics := preload("res://scripts/weapons/Ballistics.gd")
const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")

signal fired(weapon_id: String)
signal ammo_changed

var player: CharacterBody3D
var camera: Camera3D
var slots: Array = ["bd08", "pistol"]
var current := 0
var mag := {"bd08": 30, "pistol": 8, "type56": 0}
var reserve := {"rifle": 120, "pistol": 32}
var reloading := false
var switching := false
var aiming := false
var bloom := 0.0
var _cooldown := 0.0
var _action_timer := 0.0
var _models := {}
## detachable magazines (reload animation: out, fresh one in, seat, charge)
var _mags := {}
var _reload_stage := 0
var _flash: MeshInstance3D
var _flash_time := 0.0
var _sway := Vector2.ZERO
var _kick := 0.0
var _bob := 0.0
var _retract := 0.0
var _hip_pos := Vector3(0.2, -0.22, -0.42)
var _ads_pos := Vector3(0.0, -0.13, -0.3)


func setup(p_player: CharacterBody3D, p_camera: Camera3D) -> void:
	player = p_player
	camera = p_camera
	_build_models()
	_show_current()


func weapon_id() -> String:
	return str(slots[current])


func data() -> Dictionary:
	return WeaponData.WEAPONS[weapon_id()]


func ammo_type() -> String:
	return str(data()["ammo"])


func mag_ammo() -> int:
	return int(mag.get(weapon_id(), 0))


func reserve_ammo() -> int:
	return int(reserve.get(ammo_type(), 0))


func ammo_ratio() -> float:
	var r: float = float(reserve.get("rifle", 0)) / float(WeaponData.AMMO_MAX["rifle"])
	return clampf(r, 0.0, 1.0)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = CharacterModel.mat(color, 0.6)
	mi.position = pos
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


const VM_SHADER := preload("res://shaders/character.gdshader")
## sight-line aligned ADS positions (iron sights / scope centred on screen) and muzzle points
const ADS := {"bd08": Vector3(0, -0.073, -0.2), "type56": Vector3(0, -0.071, -0.2), "pistol": Vector3(0, -0.049, -0.27), "sniper": Vector3(0, -0.098, -0.1),
	"m4": Vector3(0, -0.073, -0.2), "mp5": Vector3(0, -0.06, -0.24), "lmg": Vector3(0, -0.08, -0.22), "awp": Vector3(0, -0.098, -0.1), "deagle": Vector3(0, -0.052, -0.26)}
const MUZZLE := {"bd08": Vector3(0, 0.012, -0.7), "type56": Vector3(0, 0.012, -0.66), "pistol": Vector3(0, 0.026, -0.2), "sniper": Vector3(0, 0.014, -0.92),
	"m4": Vector3(0, 0.012, -0.7), "mp5": Vector3(0, 0.012, -0.55), "lmg": Vector3(0, 0.014, -0.74), "awp": Vector3(0, 0.014, -0.92), "deagle": Vector3(0, 0.028, -0.24)}
var _vm_mat: ShaderMaterial


func _ads() -> Vector3:
	return ADS.get(weapon_id(), _ads_pos)


func _bx(m, c: Vector3, sz: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	m.box(Vector3.ZERO, sz, col, Transform3D(Basis.from_euler(rot), c))


func _vm(m, mname: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = CharacterModel._to_mesh(m)
	mi.material_override = _vm_mat
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := Node3D.new()
	n.name = mname
	n.add_child(mi)
	add_child(n)
	_models[mname] = n


func _vm_mag(mg, wname: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = CharacterModel._to_mesh(mg)
	mi.material_override = _vm_mat
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Mag"
	(_models[wname] as Node3D).add_child(mi)
	_mags[wname] = mi


## Gloved hands and olive sleeves holding a long gun (right hand on the grip, left on the handguard).
func _hands_long(m, grip_z: float, guard_z: float) -> void:
	var glove := Color(0.06, 0.06, 0.06, 0.75)
	var sleeve := Color(0.16, 0.18, 0.14, 1.0)
	var id := Transform3D()
	# right hand wraps the pistol grip, forearm runs back to the bottom-right of the screen
	_bx(m, Vector3(0.0, -0.075, grip_z + 0.005), Vector3(0.05, 0.075, 0.07), glove, Vector3(0.3, 0, 0))
	_bx(m, Vector3(0.018, -0.05, grip_z - 0.035), Vector3(0.022, 0.02, 0.05), glove, Vector3(0, 0, 0))
	m.loft([[Vector3(0, 0.0, 0), 0.034, 0.03, glove], [Vector3(0, 0.05, 0), 0.036, 0.034, sleeve], [Vector3(0, 0.3, 0), 0.046, 0.044, sleeve]], 10,
		Transform3D(Basis.from_euler(Vector3(1.25, -0.25, 0.0)), Vector3(0.01, -0.1, grip_z + 0.04)), true, true)
	# left hand under the handguard, forearm angled in from the bottom-left
	_bx(m, Vector3(-0.005, -0.045, guard_z), Vector3(0.06, 0.04, 0.085), glove)
	for f in 4:
		_bx(m, Vector3(0.026, -0.022, guard_z - 0.03 + f * 0.02), Vector3(0.016, 0.03, 0.016), glove)
	m.loft([[Vector3(0, 0.0, 0), 0.032, 0.03, glove], [Vector3(0, 0.05, 0), 0.036, 0.034, sleeve], [Vector3(0, 0.36, 0), 0.047, 0.045, sleeve]], 10,
		Transform3D(Basis.from_euler(Vector3(1.05, 0.55, 0.0)), Vector3(-0.03, -0.07, guard_z + 0.03)), true, true)


func _build_models() -> void:
	_vm_mat = ShaderMaterial.new()
	_vm_mat.shader = VM_SHADER
	_vm_mat.set_shader_parameter("skin_color", Color(0.5, 0.35, 0.25))
	var blk := Color(0.055, 0.055, 0.06, 0.5)
	var park := Color(0.09, 0.09, 0.085, 0.5)
	var poly := Color(0.1, 0.1, 0.095, 0.75)
	var wood := Color(0.36, 0.19, 0.08, 0.75)
	var mag_c := Color(0.22, 0.1, 0.04, 0.75)

	# ---- BD-08 (Type-81 pattern): stamped receiver, ribbed dust cover, gas tube, polymer furniture
	var m = CharacterModel.Mesher.new()
	_bx(m, Vector3(0, 0, -0.06), Vector3(0.05, 0.068, 0.3), blk)                      # receiver
	_bx(m, Vector3(0, 0.043, -0.05), Vector3(0.046, 0.018, 0.27), park)                # dust cover
	for i in 5:
		_bx(m, Vector3(0, 0.054, 0.04 - i * 0.045), Vector3(0.047, 0.004, 0.006), park)  # cover ribs
	_bx(m, Vector3(0.028, 0.012, -0.03), Vector3(0.006, 0.02, 0.07), park)             # ejection port rim
	_bx(m, Vector3(0.03, 0.012, -0.13), Vector3(0.024, 0.012, 0.012), blk)             # charging handle
	_bx(m, Vector3(0.027, -0.012, 0.03), Vector3(0.004, 0.012, 0.06), blk, Vector3(0.2, 0, 0))  # selector
	_bx(m, Vector3(0, 0.058, -0.2), Vector3(0.03, 0.02, 0.05), blk)                    # rear sight block
	_bx(m, Vector3(-0.009, 0.072, -0.2), Vector3(0.008, 0.012, 0.01), blk)             # rear notch posts
	_bx(m, Vector3(0.009, 0.072, -0.2), Vector3(0.008, 0.012, 0.01), blk)
	m.tube(Vector3(0, 0.034, -0.22), Vector3(0, 0.034, -0.47), 0.012, park)            # gas tube
	_bx(m, Vector3(0, -0.006, -0.33), Vector3(0.056, 0.05, 0.2), poly)                 # handguard
	for i in 4:
		_bx(m, Vector3(0.0285, -0.004, -0.27 - i * 0.04), Vector3(0.002, 0.026, 0.018), blk)  # vents
	m.tube(Vector3(0, 0.012, -0.43), Vector3(0, 0.012, -0.66), 0.0095, blk)            # barrel
	m.tube(Vector3(0, 0.012, -0.64), Vector3(0, 0.012, -0.7), 0.013, blk)              # muzzle brake
	_bx(m, Vector3(0, 0.045, -0.6), Vector3(0.026, 0.05, 0.022), blk)                  # front sight base
	_bx(m, Vector3(0, 0.0785, -0.6), Vector3(0.004, 0.017, 0.004), blk)                # front post
	_bx(m, Vector3(-0.012, 0.076, -0.6), Vector3(0.004, 0.026, 0.016), blk)            # hood
	_bx(m, Vector3(0.012, 0.076, -0.6), Vector3(0.004, 0.026, 0.016), blk)
	var mg = CharacterModel.Mesher.new()
	for i in 4:                                                                        # curved magazine
		_bx(mg, Vector3(0, -0.06 - i * 0.045, -0.12 - i * 0.022), Vector3(0.03, 0.05, 0.068), poly, Vector3(0.22 + i * 0.12, 0, 0))
	_bx(m, Vector3(0, -0.075, 0.055), Vector3(0.034, 0.1, 0.045), poly, Vector3(-0.3, 0, 0))  # pistol grip
	_bx(m, Vector3(0, -0.05, -0.005), Vector3(0.006, 0.006, 0.075), blk)               # trigger guard
	_bx(m, Vector3(0, -0.04, 0.0), Vector3(0.004, 0.025, 0.006), blk, Vector3(0.3, 0, 0))  # trigger
	_bx(m, Vector3(0, -0.015, 0.22), Vector3(0.042, 0.058, 0.24), poly)                # stock
	_bx(m, Vector3(0, -0.02, 0.345), Vector3(0.046, 0.085, 0.014), Color(0.03, 0.03, 0.03, 0.75))  # butt pad
	_hands_long(m, 0.05, -0.34)
	_vm(m, "bd08")
	_vm_mag(mg, "bd08")

	# ---- Type-56 (AK pattern) with wooden furniture and a red-brown bakelite magazine
	m = CharacterModel.Mesher.new()
	_bx(m, Vector3(0, 0, -0.05), Vector3(0.05, 0.068, 0.3), blk)
	_bx(m, Vector3(0, 0.043, -0.04), Vector3(0.046, 0.018, 0.26), park)
	_bx(m, Vector3(0, 0.058, -0.19), Vector3(0.03, 0.02, 0.05), blk)
	_bx(m, Vector3(-0.009, 0.07, -0.19), Vector3(0.008, 0.012, 0.01), blk)
	_bx(m, Vector3(0.009, 0.07, -0.19), Vector3(0.008, 0.012, 0.01), blk)
	_bx(m, Vector3(0, 0.032, -0.33), Vector3(0.04, 0.03, 0.2), wood)                   # upper handguard
	_bx(m, Vector3(0, -0.01, -0.31), Vector3(0.058, 0.05, 0.19), wood)                 # lower handguard
	m.tube(Vector3(0, 0.012, -0.42), Vector3(0, 0.012, -0.63), 0.0095, blk)
	m.tube(Vector3(0, 0.012, -0.6), Vector3(0, 0.012, -0.66), 0.012, blk)
	_bx(m, Vector3(0, 0.045, -0.58), Vector3(0.022, 0.05, 0.02), blk)
	_bx(m, Vector3(0, 0.0765, -0.58), Vector3(0.004, 0.017, 0.004), blk)
	mg = CharacterModel.Mesher.new()
	for i in 4:
		_bx(mg, Vector3(0, -0.06 - i * 0.046, -0.11 - i * 0.026), Vector3(0.03, 0.052, 0.07), mag_c, Vector3(0.25 + i * 0.13, 0, 0))
	_bx(m, Vector3(0, -0.075, 0.055), Vector3(0.034, 0.1, 0.045), wood, Vector3(-0.3, 0, 0))
	_bx(m, Vector3(0, -0.05, -0.005), Vector3(0.006, 0.006, 0.075), blk)
	_bx(m, Vector3(0, -0.025, 0.23), Vector3(0.04, 0.07, 0.26), wood, Vector3(-0.08, 0, 0))
	_bx(m, Vector3(0, -0.045, 0.36), Vector3(0.044, 0.095, 0.012), blk)
	_hands_long(m, 0.05, -0.32)
	_vm(m, "type56")
	_vm_mag(mg, "type56")

	# ---- Type-54 pistol (TT pattern): serrated slide, grip panels, hammer, two-handed grip
	m = CharacterModel.Mesher.new()
	_bx(m, Vector3(0, 0.025, -0.09), Vector3(0.028, 0.034, 0.19), blk)                 # slide
	for i in 6:
		_bx(m, Vector3(0, 0.025, -0.01 - i * 0.008), Vector3(0.03, 0.03, 0.003), park)  # serrations
	_bx(m, Vector3(0, 0.0, -0.1), Vector3(0.026, 0.02, 0.16), park)                    # frame
	m.tube(Vector3(0, 0.026, -0.18), Vector3(0, 0.026, -0.2), 0.008, blk)              # barrel bushing
	_bx(m, Vector3(0, 0.0475, -0.175), Vector3(0.004, 0.01, 0.006), blk)               # front sight
	_bx(m, Vector3(-0.006, 0.046, -0.005), Vector3(0.006, 0.008, 0.006), blk)          # rear sight
	_bx(m, Vector3(0.006, 0.046, -0.005), Vector3(0.006, 0.008, 0.006), blk)
	_bx(m, Vector3(0, 0.03, 0.012), Vector3(0.01, 0.022, 0.012), blk, Vector3(-0.4, 0, 0))  # hammer
	_bx(m, Vector3(0, -0.06, -0.01), Vector3(0.029, 0.105, 0.046), blk, Vector3(-0.22, 0, 0))
	_bx(m, Vector3(0, -0.06, -0.01), Vector3(0.033, 0.085, 0.04), Color(0.2, 0.12, 0.06, 0.75), Vector3(-0.22, 0, 0))  # grip panels
	_bx(m, Vector3(0, -0.02, -0.065), Vector3(0.005, 0.005, 0.05), blk)                # trigger guard
	var glove := Color(0.06, 0.06, 0.06, 0.75)
	var sleeve := Color(0.16, 0.18, 0.14, 1.0)
	_bx(m, Vector3(0, -0.065, 0.0), Vector3(0.05, 0.08, 0.06), glove, Vector3(-0.2, 0, 0))
	_bx(m, Vector3(-0.022, -0.075, -0.01), Vector3(0.03, 0.07, 0.065), glove, Vector3(-0.2, 0.3, 0))
	m.loft([[Vector3(0, 0.0, 0), 0.032, 0.03, glove], [Vector3(0, 0.05, 0), 0.036, 0.034, sleeve], [Vector3(0, 0.32, 0), 0.046, 0.044, sleeve]], 10,
		Transform3D(Basis.from_euler(Vector3(1.3, -0.35, 0.0)), Vector3(0.015, -0.09, 0.02)), true, true)
	m.loft([[Vector3(0, 0.0, 0), 0.032, 0.03, glove], [Vector3(0, 0.05, 0), 0.036, 0.034, sleeve], [Vector3(0, 0.32, 0), 0.046, 0.044, sleeve]], 10,
		Transform3D(Basis.from_euler(Vector3(1.3, 0.45, 0.0)), Vector3(-0.03, -0.09, 0.02)), true, true)
	_vm(m, "pistol")
	mg = CharacterModel.Mesher.new()
	_bx(mg, Vector3(0, -0.118, 0.0), Vector3(0.027, 0.03, 0.042), blk, Vector3(-0.22, 0, 0))   # magazine base plate
	_vm_mag(mg, "pistol")

	# ---- bolt-action sniper with a scope (picked up from dead marksmen)
	m = CharacterModel.Mesher.new()
	_bx(m, Vector3(0, 0, -0.05), Vector3(0.045, 0.06, 0.32), blk)
	m.tube(Vector3(0, 0.012, -0.2), Vector3(0, 0.012, -0.92), 0.011, blk)
	m.tube(Vector3(0, 0.098, 0.12), Vector3(0, 0.098, -0.24), 0.019, blk)              # scope tube
	m.tube(Vector3(0, 0.098, -0.24), Vector3(0, 0.098, -0.3), 0.027, blk)              # objective bell
	m.tube(Vector3(0, 0.098, 0.12), Vector3(0, 0.098, 0.17), 0.023, blk)               # eyepiece
	_bx(m, Vector3(0, 0.06, -0.12), Vector3(0.02, 0.03, 0.02), blk)                    # rings
	_bx(m, Vector3(0, 0.06, 0.04), Vector3(0.02, 0.03, 0.02), blk)
	m.tube(Vector3(0.025, 0.02, 0.05), Vector3(0.065, 0.0, 0.05), 0.006, park)          # bolt handle
	_bx(m, Vector3(0, -0.02, -0.38), Vector3(0.05, 0.05, 0.36), Color(0.22, 0.25, 0.16, 0.75))  # forend
	mg = CharacterModel.Mesher.new()
	_bx(mg, Vector3(0, -0.06, -0.08), Vector3(0.028, 0.06, 0.06), blk)                 # box magazine
	_bx(m, Vector3(0, -0.04, 0.24), Vector3(0.045, 0.09, 0.3), Color(0.22, 0.25, 0.16, 0.75), Vector3(-0.1, 0, 0))
	_hands_long(m, 0.06, -0.36)
	_vm(m, "sniper")
	_vm_mag(mg, "sniper")

	# extra weapons reuse the closest matching first-person / world model
	for alias in [["m4", "bd08"], ["mp5", "type56"], ["lmg", "bd08"], ["awp", "sniper"], ["deagle", "pistol"]]:
		if _models.has(alias[1]):
			_models[alias[0]] = _models[alias[1]]
	for alias in [["m4", "bd08"], ["mp5", "pistol"], ["lmg", "bd08"], ["awp", "sniper"], ["deagle", "pistol"]]:
		if _mags.has(alias[1]):
			_mags[alias[0]] = _mags[alias[1]]

	# muzzle flash: two crossed quads
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.8, 0.35)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = fm
	_flash = MeshInstance3D.new()
	_flash.mesh = q
	_flash.layers = 2
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q2 := MeshInstance3D.new()
	q2.mesh = q
	q2.rotation.y = PI * 0.5
	q2.layers = 2
	_flash.add_child(q2)
	_flash.visible = false
	add_child(_flash)


func _show_current() -> void:
	for k in _models.keys():
		(_models[k] as Node3D).visible = (k == weapon_id())
	ammo_changed.emit()


func _muzzle_local() -> Vector3:
	return MUZZLE.get(weapon_id(), Vector3(0, 0.015, -0.62))


func select_slot(i: int) -> void:
	if i < 0 or i >= slots.size() or i == current or switching:
		return
	reloading = false
	switching = true
	_action_timer = 0.35
	current = i
	AudioManager.play_2d("sfx_switch", -6.0)


func cycle(step: int) -> void:
	select_slot(wrapi(current + step, 0, slots.size()))


func give_weapon(id: String, rounds: int) -> void:
	if not slots.has(id):
		slots.append(id)
		mag[id] = int(WeaponData.WEAPONS[id]["mag"])
	add_ammo(str(WeaponData.WEAPONS[id]["ammo"]), rounds)
	select_slot(slots.find(id))


func add_ammo(kind: String, amount: int) -> void:
	var mx: int = int(WeaponData.AMMO_MAX.get(kind, 200))
	reserve[kind] = mini(int(reserve.get(kind, 0)) + amount, mx)
	ammo_changed.emit()


func start_reload() -> void:
	if reloading or switching:
		return
	var d := data()
	if mag_ammo() >= int(d["mag"]) or reserve_ammo() <= 0:
		return
	reloading = true
	_action_timer = float(d["reload"])
	_reload_stage = 0


func _finish_reload() -> void:
	var d := data()
	var need: int = int(d["mag"]) - mag_ammo()
	var take: int = mini(need, reserve_ammo())
	mag[weapon_id()] = mag_ammo() + take
	reserve[ammo_type()] = reserve_ammo() - take
	reloading = false
	ammo_changed.emit()


func current_spread() -> float:
	var d := data()
	var s: float = float(d["ads_spread"]) if aiming else float(d["spread"])
	var hv := Vector2(player.velocity.x, player.velocity.z).length()
	s += hv * (0.12 if aiming else 0.35)
	if player.get("crouching"):
		s *= 0.7
	if not player.is_on_floor():
		s += 3.0
	return s + bloom


var scope_toggle := false

## Hero-only scope toggle (key 8). EnemyAI never uses WeaponSystem.
func toggle_scope() -> void:
	scope_toggle = not scope_toggle


func process_weapon(delta: float, fire_held: bool, fire_pressed: bool, want_aim: bool) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	bloom = move_toward(bloom, 0.0, delta * 4.0)
	aiming = (want_aim or scope_toggle) and not reloading and not switching and not bool(player.get("sprinting"))
	if _action_timer > 0.0:
		_action_timer -= delta
		if _action_timer <= 0.0:
			if reloading:
				_finish_reload()
			if switching:
				switching = false
				_show_current()
	var d := data()
	var wants := fire_held if bool(d["auto"]) else fire_pressed
	if wants and _cooldown <= 0.0 and not reloading and not switching and not bool(player.get("sprinting")):
		if mag_ammo() <= 0:
			if fire_pressed:
				AudioManager.play_2d("sfx_empty", -4.0)
				start_reload()
			_cooldown = 0.25
		else:
			_fire(d)
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false
	_update_viewmodel(delta)


func _fire(d: Dictionary) -> void:
	_cooldown = 60.0 / float(d["rpm"])
	mag[weapon_id()] = mag_ammo() - 1
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var dir := Ballistics.spread_dir(forward, current_spread())
	var ex: Array = [player.get_rid()]
	var res: Dictionary = Ballistics.fire(get_world_3d(), origin, dir, float(d["damage"]), float(d["range"]), int(d["pen"]), player, ex, false)
	Game.stats["shots"] = int(Game.stats["shots"]) + 1
	if bool(res["hit_actor"]):
		var victim = res["victim"]
		if victim != null and is_instance_valid(victim) and (victim as Node).is_in_group("enemies"):
			Game.stats["hits"] = int(Game.stats["hits"]) + 1
			if bool(res["headshot"]):
				Game.stats["headshots"] = int(Game.stats["headshots"]) + 1
			if Game.level != null and Game.level.has_method("hitmarker"):
				Game.level.hitmarker(bool(res["killed"]))
	bloom = minf(bloom + float(d["recoil"]) * 0.45, 4.0)
	var kick: float = float(d["recoil"]) * (0.55 if aiming else 1.0)
	player.add_recoil(kick, randf_range(-0.35, 0.35) * kick)
	_kick = minf(_kick + 0.045, 0.12)
	_flash.position = _muzzle_local() + (_ads() if aiming else _hip_pos)
	_flash.rotation.z = randf() * TAU
	_flash.visible = true
	_flash_time = 0.045
	if Game.level != null and Game.level.get("fx") != null:
		Game.level.fx.muzzle_light(_flash.global_position)
	AudioManager.play_2d(str(d["sound"]), -2.0, randf_range(0.94, 1.06))
	# reverb tail: slap-back off Dhaka's buildings outside, a short boomy room inside a house
	var inside: bool = Game.level != null and Game.level.has_method("in_house") and Game.player != null and Game.level.in_house((Game.player as Node3D).global_position)
	AudioManager.play_2d("sfx_tail_room" if inside else "sfx_tail_city", -9.0 if str(d["sound"]) != "sfx_pistol" else -12.0, randf_range(0.95, 1.05))
	Game.noise(player.global_position, float(d["noise"]), "player")
	fired.emit(weapon_id())
	ammo_changed.emit()
	if mag_ammo() == 0 and reserve_ammo() > 0:
		get_tree().create_timer(0.25).timeout.connect(start_reload)


func add_sway(rel: Vector2) -> void:
	_sway += Vector2(-rel.x, rel.y) * 0.00035
	_sway = _sway.limit_length(0.05)


func _update_viewmodel(delta: float) -> void:
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	_kick = move_toward(_kick, 0.0, delta * 0.6)
	var hv := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor() and hv > 0.5:
		_bob += delta * hv * 1.9
	var bob := Vector3(sin(_bob) * 0.012, absf(cos(_bob)) * 0.014, 0.0) * (0.3 if aiming else 1.0)
	# retract the gun when the barrel would clip into a wall
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_transform.basis.z * 0.75, 1)
	var hit := space.intersect_ray(q)
	var want_retract := 0.0
	if not hit.is_empty():
		want_retract = 1.0 - from.distance_to(hit["position"]) / 0.75
	_retract = move_toward(_retract, want_retract, delta * 4.0)
	var base := _ads() if aiming else _hip_pos
	# slow breathing drift while aiming
	if aiming:
		var bt := Time.get_ticks_msec() * 0.001
		base += Vector3(sin(bt * 1.1) * 0.0012, sin(bt * 1.7) * 0.0015, 0.0)
	var target := base + bob + Vector3(_sway.x, _sway.y, _kick) + Vector3(0, -0.06, 0.18) * _retract
	var rot := Vector3(_kick * 1.2, 0, 0)
	if reloading:
		# tilt the gun to the magazine well; old magazine drops, a fresh one goes in, seat, charge
		var p := 1.0 - clampf(_action_timer / maxf(float(data()["reload"]), 0.1), 0.0, 1.0)
		target += Vector3(0, -0.12, 0.05)
		rot += Vector3(-0.5, 0.3, 0.4)
		var mag_off := Vector3.ZERO
		var mag_vis := true
		if p >= 0.15 and p < 0.38:
			var k := (p - 0.15) / 0.23
			mag_off = Vector3(0, -0.32 * k * k, 0.06 * k)
			if _reload_stage < 1:
				_reload_stage = 1
				AudioManager.play_2d("sfx_mag_out", -4.0, randf_range(0.95, 1.05))
		elif p >= 0.38 and p < 0.5:
			mag_vis = false
		elif p >= 0.5 and p < 0.78:
			var k2 := 1.0 - (p - 0.5) / 0.28
			mag_off = Vector3(-0.02 * k2, -0.2 * k2, 0.05 * k2)
		elif p >= 0.78 and p < 0.86:
			mag_off = Vector3(0, 0.006, 0)
			target += Vector3(0, 0.01, 0)
			if _reload_stage < 2:
				_reload_stage = 2
				AudioManager.play_2d("sfx_mag_in", -3.0, randf_range(0.95, 1.05))
		elif p >= 0.86:
			# charging handle / slide racked: a sharp jolt back
			target += Vector3(0.0, 0.0, 0.035) * (1.0 - (p - 0.86) / 0.14)
			rot += Vector3(0.0, -0.3, 0.0)
			if _reload_stage < 3:
				_reload_stage = 3
				AudioManager.play_2d("sfx_bolt", -3.0, randf_range(0.95, 1.05))
		if _mags.has(weapon_id()):
			var mgn: Node3D = _mags[weapon_id()]
			mgn.position = mag_off
			mgn.visible = mag_vis
	elif _mags.has(weapon_id()):
		(_mags[weapon_id()] as Node3D).position = Vector3.ZERO
		(_mags[weapon_id()] as Node3D).visible = true
	if switching:
		target += Vector3(0, -0.35, 0)
	if bool(player.get("sprinting")):
		target += Vector3(-0.05, -0.05, 0.05)
		rot += Vector3(-0.3, 0.6, 0)
	if not _models.has(weapon_id()):
		return
	var m: Node3D = _models[weapon_id()]
	# the sniper scope is drawn by the HUD, so hide the gun once fully zoomed
	m.visible = not (aiming and weapon_id() == "sniper" and m.position.distance_to(target) < 0.03)
	m.position = m.position.lerp(target, clampf(delta * (18.0 if aiming else 14.0), 0.0, 1.0))
	m.rotation = m.rotation.lerp(rot, clampf(delta * 10.0, 0.0, 1.0))
