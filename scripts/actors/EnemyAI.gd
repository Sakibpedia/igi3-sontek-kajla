extends CharacterBody3D
## Villain AI ("Kalo Chhaya" fighters).
## State machine: IDLE -> PATROL -> ALERT (investigate) -> COMBAT, plus DEAD.
## Vision cone + line of sight, stealth suspicion meter, hearing (gunshots/footsteps),
## alarm propagation, cover usage behind rickshaws/walls/crates, burst fire.
## Prioritises the player but will also shoot allies, the VIP and escort vehicles.

signal died(enemy: Node, killer: Node)

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")
const Ballistics := preload("res://scripts/weapons/Ballistics.gd")
const WeaponData := preload("res://scripts/weapons/WeaponData.gd")
const Throwable := preload("res://scripts/weapons/Throwable.gd")

enum State { IDLE, PATROL, ALERT, COMBAT, FLEE, DEAD }

const KINDS := {
	"rifle": {"hp": 100.0, "weapon": "type56", "spread": 2.7, "view": 40.0, "walk": 2.0, "run": 4.6, "dmg": 0.5},
	"pistol": {"hp": 90.0, "weapon": "pistol", "spread": 3.2, "view": 32.0, "walk": 2.0, "run": 4.8, "dmg": 0.55},
	"heavy": {"hp": 240.0, "weapon": "type56", "spread": 2.6, "view": 40.0, "walk": 1.8, "run": 3.8, "dmg": 0.55},
	"sniper": {"hp": 80.0, "weapon": "sniper", "spread": 0.45, "view": 120.0, "walk": 1.8, "run": 3.5, "dmg": 0.6},
	"boss": {"hp": 1500.0, "weapon": "type56", "spread": 2.4, "view": 70.0, "walk": 2.2, "run": 4.4, "dmg": 0.6},
	"dealer": {"hp": 450.0, "weapon": "type56", "spread": 2.8, "view": 50.0, "walk": 2.0, "run": 4.4, "dmg": 0.55},
	"courier": {"hp": 110.0, "weapon": "pistol", "spread": 5.0, "view": 30.0, "walk": 2.2, "run": 5.4, "dmg": 0.4},
	"scout": {"hp": 70.0, "weapon": "mp5", "spread": 3.4, "view": 55.0, "walk": 2.9, "run": 6.4, "dmg": 0.4},
	"swat": {"hp": 260.0, "weapon": "m4", "spread": 1.8, "view": 58.0, "walk": 2.3, "run": 5.0, "dmg": 0.7},
	"gunner": {"hp": 340.0, "weapon": "lmg", "spread": 3.8, "view": 46.0, "walk": 1.6, "run": 3.4, "dmg": 0.65},
	"marksman": {"hp": 120.0, "weapon": "awp", "spread": 0.6, "view": 105.0, "walk": 1.9, "run": 3.6, "dmg": 0.75},
	"kishor": {"hp": 70.0, "weapon": "knife", "spread": 2.5, "view": 45.0, "walk": 3.2, "run": 5.4, "dmg": 0.5},
	"airforce": {"hp": 140.0, "weapon": "type56", "spread": 2.4, "view": 45.0, "walk": 2.2, "run": 4.6, "dmg": 0.6},
	"naval": {"hp": 280.0, "weapon": "m4", "spread": 1.9, "view": 60.0, "walk": 2.2, "run": 5.0, "dmg": 0.7},
	"protector": {"hp": 130.0, "weapon": "pistol", "spread": 2.8, "view": 45.0, "walk": 2.4, "run": 5.0, "dmg": 0.6},
}

var faction := "enemy"
## Neutral forces (military / police / commando) never open fire on their own.
## They only retaliate against whoever damaged them — hero or villain alike.
var neutral := false
var bomb_thrower := false
var squad := ""
var simple_model := false
var _bomb_cd := 6.0
var kind := "rifle"
## red-scarf villain: never shoots hostages - carries rescued ones back to where the gang held them
var abductor := false
var carrying: Node = null
var _abduct: Node = null
var _abd_stuck := 0.0
var tag := ""
## Phase 3 boss raids: the gang leader ("leader" tag) of either gender surrenders when the Freelancer
## covers him / her at close range (aiming, within 8 m) or when badly hurt; X (hold) handcuffs, then
## the prisoner walks behind the Freelancer and boards the helicopter on the house roof.
var leader := false
var female := false
## Cox's Bazar: character slot (villain_1..2, enemy_1..8, boss) - the face and gender come from it;
## a second gunman on a slot (variant 1+) has a face of his / her own and never the slot's photo
var slot_role := "villain"
var slot := 0
var variant := 0
var outfit_used: Dictionary = {}
## senior guard: older; hit hard (or worn out while firing) he / she faints instead of dying and can be
## tied, gagged and carried to the tourist police (HostageOps.senior_fainted)
var senior := false
var _combat_t := 0.0
## villains only: the beach visitor this villain is going to capture (HostageOps._do_captures)
var capture_civ: Node3D = null
var surrendered := false
var arrested := false
var boarded := false
var _cuff := 0.0
## Limited ammunition (ordinary gunmen): -1 = unlimited (snipers, the boss, gang leaders). When it runs
## out they stop shooting and run to the nearest ammo crate to restock; cornered while empty (within
## 6 m of the Freelancer or an Alpha) they surrender and can be handcuffed and walked to extraction.
var ammo := -1
var ammo_full := 0
var _resupply := false
var _restock_t := 0.0
var _shout_t := 0.0
var face_key := ""
var health := 100.0
var max_health := 100.0
var alive := true
var crouching := false
var state: State = State.IDLE
var patrol: Array = []
var flee_path: Array = []
var stationary := false
## Phase 3h: the teacher companion's former student (can be talked into surrendering)
var young := false
## marked on the minimap by a companion who knows the guards (ticks in ms)
var mark_until_ms := 0
## shift change / radio lure: walk here and stay while set (INF = at the post)
var shift_point := Vector3.INF
var post := Vector3.INF
var model: Node3D
var agent: NavigationAgent3D
var target: Node3D = null
var target_visible := false
var last_known := Vector3.ZERO
var suspicion := 0.0
var weapon_id := "type56"
var _spec := {}
var _k := {}
var _patrol_i := 0
var _think_t := 0.0
var _lost_t := 0.0
var _alert_t := 0.0
var _wait_t := 0.0
var _burst_left := 0
var _fire_cd := 0.0
var _reaction := 0.0
var _cover: Dictionary = {}
var _cover_t := 0.0
var _cover_search_t := 0.0
var _peeking := true
var _strafe_t := 0.0
var _strafe_dir := 1.0
var _aim_t := 0.0
var _desired_v := Vector3.ZERO
var _gravity := 13.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _seen_corpses := {}
var _search_points: Array = []
var _flee_i := 0
var _phase_flags := 0
var _laser: MeshInstance3D
var _indicator: Label3D
var _rng := RandomNumberGenerator.new()


func setup(spec: Dictionary) -> void:
	_spec = spec
	kind = str(spec.get("kind", "rifle"))
	tag = str(spec.get("tag", ""))
	patrol = spec.get("patrol", [])
	flee_path = spec.get("flee", [])
	stationary = bool(spec.get("stationary", kind == "sniper"))
	abductor = bool(spec.get("abductor", false))
	leader = tag == "leader"
	female = bool(spec.get("female", false))
	slot_role = str(spec.get("slot_role", "villain"))
	slot = int(spec.get("slot", 0))
	variant = int(spec.get("variant", 0))
	senior = bool(spec.get("senior", false))
	neutral = bool(spec.get("neutral", false))
	faction = str(spec.get("faction", "enemy"))
	bomb_thrower = bool(spec.get("bomb_thrower", false))
	squad = str(spec.get("group", ""))
	simple_model = bool(spec.get("simple_model", false))


func _ready() -> void:
	_rng.randomize()
	if neutral:
		add_to_group("neutrals")
		add_to_group("neutral_" + faction)
		if squad != "":
			add_to_group("squad_" + squad)
	else:
		add_to_group("enemies")
	add_to_group("actors")
	_k = KINDS.get(kind, KINDS["rifle"])
	max_health = float(_k["hp"])
	health = max_health
	weapon_id = str(_k["weapon"])
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 13.0))
	collision_layer = Game.L_ENEMY
	collision_mask = Game.L_WORLD | Game.L_PLAYER
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	if simple_model:
		model = (preload("res://scripts/actors/SimpleModel.gd") as GDScript).new()
	else:
		model = CharacterModel.new()
	add_child(model)
	var role := "boss" if kind == "boss" else "villain"
	var o := CharacterModel.outfit_for(slot_role if slot > 0 else role, _rng, slot, variant)
	if slot > 0:
		o["female"] = female
	if senior:
		# an older guard: lined face, grey hair, a little heavier
		if o.get("face") is Dictionary:
			(o["face"] as Dictionary)["age"] = 0.9
		o["hair"] = Color(0.55, 0.53, 0.5)
		o["build"] = "female" if female else "heavy"
	if abductor:
		o["hat"] = "bandana"
		o["hat_color"] = Color(0.7, 0.05, 0.05)
		o["shirt"] = Color(0.06, 0.06, 0.06)
		add_to_group("villains")
	if leader:
		if female:
			CharacterModel.feminize(o, _rng)
			o["top"] = "beachshirt"
			o["sleeve"] = "short"
			o["pants_style"] = "capri"
			o["shirt"] = Color(0.1, 0.1, 0.12)
			o["pants"] = Color(0.86, 0.82, 0.72)
		else:
			o["top"] = "shirt"
			o["sleeve"] = "long"
			o["pants_style"] = "trousers"
			o["shirt"] = Color(0.92, 0.9, 0.84)
		o.erase("vest")
		o["hat"] = "none"
		o["gold_watch"] = true
	elif bool(o.get("female", false)):
		female = true
	if neutral:
		make_neutral_outfit(o)
	outfit_used = o
	model.setup(role, o)
	if kind == "kishor":
		_add_knife()
	if neutral:
		_add_neutral_indicator()
	if not leader and (kind == "rifle" or kind == "pistol" or kind == "heavy" or kind == "dealer"):
		var mag: int = int(WeaponData.WEAPONS[weapon_id].get("mag", 30))
		ammo_full = mag * (2 if kind != "pistol" else 3)
		ammo = _rng.randi_range(mag, ammo_full)
	# a photo only on the first person of a slot, and never on a senior guard (who can end up tied)
	face_key = ""
	if slot > 0 and variant == 0 and not senior:
		face_key = AssetLoader.slot_face_key(slot_role, slot)
		if face_key != "":
			AssetLoader.apply_face(model, slot_role, face_key)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 0.9
	agent.radius = 0.4
	agent.height = 1.8
	agent.avoidance_enabled = false
	add_child(agent)
	_indicator = Label3D.new()
	_indicator.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.font_size = 96
	_indicator.pixel_size = 0.004
	_indicator.outline_size = 12
	_indicator.position = Vector3(0, 2.25, 0)
	_indicator.no_depth_test = true
	_indicator.visible = false
	add_child(_indicator)
	if kind == "sniper" or kind == "marksman":
		_build_laser()
	_think_t = _rng.randf_range(0.0, 0.25)
	state = State.PATROL if patrol.size() > 1 and not stationary else State.IDLE
	Game.noise_made.connect(_on_noise)
	_last_pos = global_position


func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.05, 0.05)
	bm.material = m
	_laser.mesh = bm
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.top_level = true
	_laser.visible = false
	add_child(_laser)


# ------------------------------------------------------------------ queries used by others
func is_alive() -> bool:
	return alive


func eye_position() -> Vector3:
	return global_position + Vector3(0, (1.1 if crouching else 1.62) * model.scale.y, 0)


func chest_position() -> Vector3:
	return global_position + Vector3(0, (0.9 if crouching else 1.3) * model.scale.y, 0)


func is_headshot(pos: Vector3) -> bool:
	return pos.y > global_position.y + (1.12 if crouching else 1.5) * model.scale.y


func is_hostile_to(n: Node) -> bool:
	return n != null and (n.is_in_group("friendly") or n.is_in_group("escort_vehicle"))


# ------------------------------------------------------------------ damage
func _add_knife() -> void:
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.06, 0.42)
	blade.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.78, 0.8)
	mat.metallic = 0.8
	blade.material_override = mat
	blade.position = Vector3(0.34, 1.05, -0.3)
	add_child(blade)
	var tag_lbl := Label3D.new()
	tag_lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	tag_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag_lbl.no_depth_test = true
	tag_lbl.font_size = 19
	tag_lbl.pixel_size = 0.0025
	tag_lbl.modulate = Color(1.0, 0.5, 0.4)
	tag_lbl.position = Vector3(0, 2.35, 0)
	tag_lbl.text = "কিশোর গ্যাং — ছুরি"
	add_child(tag_lbl)


func make_neutral_outfit(o: Dictionary) -> void:
	# Distinct uniforms: army olive, police navy, commando black.
	if faction == "military":
		o["shirt"] = Color(0.22, 0.29, 0.16)
		o["pants"] = Color(0.25, 0.3, 0.18)
		o["hat"] = "cap"
		o["hat_color"] = Color(0.16, 0.22, 0.12)
	elif faction == "police":
		o["shirt"] = Color(0.1, 0.17, 0.3)
		o["pants"] = Color(0.09, 0.12, 0.22)
		o["hat"] = "cap"
		o["hat_color"] = Color(0.05, 0.09, 0.2)
	elif faction == "airforce":
		o["shirt"] = Color(0.3, 0.38, 0.5)
		o["pants"] = Color(0.24, 0.3, 0.42)
		o["hat"] = "cap"
		o["hat_color"] = Color(0.12, 0.18, 0.3)
	elif faction == "naval":
		o["shirt"] = Color(0.08, 0.22, 0.32)
		o["pants"] = Color(0.07, 0.16, 0.24)
		o["hat"] = "cap"
		o["hat_color"] = Color(0.04, 0.1, 0.16)
	elif faction == "protector":
		o["shirt"] = Color(0.96, 0.96, 0.93)
		o["pants"] = Color(0.93, 0.93, 0.9)
		o["top"] = "tshirt"
		o["pants_style"] = "long"
		o["hat"] = "none"
		o["vest"] = Color(0.9, 0.9, 0.88)
	else:
		o["shirt"] = Color(0.08, 0.09, 0.08)
		o["pants"] = Color(0.1, 0.1, 0.09)
		o["hat"] = "cap"
		o["hat_color"] = Color(0.05, 0.05, 0.05)
	o["vest"] = Color(0.12, 0.14, 0.12) if faction != "protector" else Color(0.9, 0.9, 0.88)


func _add_neutral_indicator() -> void:
	var lbl := Label3D.new()
	lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 20
	lbl.pixel_size = 0.0025
	lbl.outline_size = 6
	lbl.modulate = Color(0.55, 0.85, 1.0) if faction == "police" else (Color(0.6, 1.0, 0.6) if faction == "military" else Color(1.0, 0.6, 0.5))
	lbl.position = Vector3(0, 2.35, 0)
	lbl.text = {"military": "সেনাবাহিনী — নিরপেক্ষ", "police": "পুলিশ — নিরপেক্ষ",
		"commando": "কমান্ডো — নিরপেক্ষ", "airforce": "বিমান বাহিনী — নিরপেক্ষ",
		"naval": "নৌ কমান্ডো — নিরপেক্ষ", "protector": "সাদা পোশাকী — নিরপেক্ষ"}.get(faction, "নিরপেক্ষ")
	add_child(lbl)


func take_damage(amount: float, from_pos: Vector3, attacker: Node) -> void:
	if not alive:
		return
	if not neutral and attacker != null and attacker.is_in_group("enemies"):
		return
	var dmg := amount
	if kind == "boss":
		dmg *= 0.55
	elif kind == "heavy" or kind == "dealer":
		dmg *= 0.8
	health -= dmg
	model.flash_hit()
	if health <= 0.0 and senior and not surrendered:
		_faint()
		return
	if health <= 0.0:
		_die(attacker, from_pos)
		return
	if kind == "boss" and Game.level != null and Game.level.has_method("boss_phase"):
		var frac := health / max_health
		if frac < 0.66 and (_phase_flags & 1) == 0:
			_phase_flags |= 1
			Game.level.boss_phase(1)
		if frac < 0.33 and (_phase_flags & 2) == 0:
			_phase_flags |= 2
			Game.level.boss_phase(2)
	if state == State.FLEE:
		return
	if attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		target = attacker as Node3D
		last_known = (attacker as Node3D).global_position
		if neutral and squad != "":
			# A squad answers as one: every member takes the same attacker.
			for mate in get_tree().get_nodes_in_group("squad_" + squad):
				if mate == self or not mate.has_method("take_damage"):
					continue
				var m = mate
				if m.alive:
					m.target = attacker as Node3D
					m.last_known = (attacker as Node3D).global_position
					m._enter_combat()
	else:
		last_known = from_pos
	_enter_combat()


# ---------------------------------------------------------------- ammunition
func _out_of_ammo() -> void:
	if _resupply:
		return
	_resupply = true
	_restock_t = 0.0
	_release_cover()
	_burst_left = 0
	if _laser != null:
		_laser.visible = false
	AudioManager.play_3d("sfx_empty", eye_position(), 0.0, 0.9, 25.0)
	if _shout_t <= 0.0:
		_shout_t = 8.0
		AudioManager.say("সন্ত্রাসী", "গুলি শেষ! গুলির বাক্সের দিকে যাচ্ছি — কভার দাও!", 2.2, 0.8)
	Game.noise(global_position, 12.0, "enemy")


## Out of ammo: run to the nearest ammo crate and restock (3 s); surrender if cornered first.
func _do_resupply(delta: float) -> void:
	_desired_v = Vector3.ZERO
	_shout_t -= delta
	crouching = false
	# cornered with an empty gun?
	for n in get_tree().get_nodes_in_group("friendly"):
		var f := n as Node3D
		if f == null or not f.has_method("is_alive") or not f.is_alive():
			continue
		if f.global_position.distance_to(global_position) < 6.0 and Ballistics.has_line_of_sight(get_world_3d(), eye_position(), f.global_position + Vector3(0, 1.4, 0), [get_rid()]):
			_surrender()
			return
	var crate = Game.level.nearest_ammo(global_position) if Game.level != null and Game.level.has_method("nearest_ammo") else null
	if crate == null:
		# nowhere to restock: back away from the Freelancer and hide
		var p := Game.player as Node3D
		if p != null:
			var away := global_position - p.global_position
			away.y = 0.0
			if away.length() < 25.0:
				_nav_move(global_position + away.normalized() * 6.0, float(_k["run"]), delta)
		return
	var cp: Vector3 = (crate as Node3D).global_position
	if global_position.distance_to(cp) > 1.6:
		_nav_move(cp, float(_k["run"]), delta)
		return
	crouching = true
	_restock_t += delta
	if _restock_t >= 3.0:
		ammo = ammo_full
		_resupply = false
		AudioManager.play_3d("sfx_reload", global_position + Vector3(0, 1.0, 0), -2.0, 1.0, 25.0)


# ---------------------------------------------------------------- gang leader (boss raids)
func _check_surrender() -> void:
	var p := Game.player as Node3D
	if p == null or not p.has_method("is_alive") or not p.is_alive():
		return
	var d := p.global_position.distance_to(global_position)
	var covered := false
	if d < 8.0 and p.get("weapon") != null and bool(p.weapon.aiming):
		var cam: Camera3D = p.camera
		var to := (chest_position() - cam.global_position).normalized()
		covered = (-cam.global_transform.basis.z).dot(to) > 0.965 and Ballistics.has_line_of_sight(get_world_3d(), cam.global_position, chest_position(), [get_rid(), p.get_rid()])
	if covered or (health < max_health * 0.45 and d < 15.0):
		_surrender()


func _surrender() -> void:
	surrendered = true
	target = null
	target_visible = false
	_release_cover()
	model.pose = "hands_head"
	model.kneel = true
	if model.gun != null:
		model.gun.visible = false
	if _laser != null:
		_laser.visible = false
	remove_from_group("enemies")
	remove_from_group("villains")
	add_to_group("interactables")
	add_to_group("prisoners")
	_indicator.visible = false
	_resupply = false
	AudioManager.say("চক্রের নেতা" if leader else "সন্ত্রাসী", "গুলি করবেন না! আমি আত্মসমর্পণ করছি!", 2.6, 1.2 if female else 0.8)
	if Game.level != null and Game.level.has_method("on_leader_surrendered"):
		Game.level.on_leader_surrendered(self)


func can_interact() -> bool:
	if arrested:
		return alive and not boarded
	return surrendered and alive


var interrogated := false
var revealed := false
var _talk_t := -1.0


func prompt_text() -> String:
	if arrested:
		var parts: PackedStringArray = []
		if not leader and not interrogated:
			parts.append("[E] জিজ্ঞাসাবাদ — চক্রের নেতা কোথায়?")
		parts.append("[J] আলফাকে পাহারায় দিন" if not _escorted() else "আলফার পাহারায়")
		parts.append("নজরে না রাখলে চিৎকার করে দলকে ডাকবে")
		return ("চক্রের নেতা (বন্দি)" if leader else "বন্দি") + ":  " + "   ".join(parts)
	if leader:
		return "[X] চেপে ধরে হাতকড়া পরান — চক্রের নেতা (জিজ্ঞাসাবাদের জন্য হেলিকপ্টারে পাঠাতে হবে)"
	return "[X] চেপে ধরে হাতকড়া পরান — আত্মসমর্পণকারী সন্ত্রাসী (উদ্ধার যানের কাছে নিয়ে যান)"


func progress() -> float:
	return _cuff / 1.3


## E on a handcuffed gang member: interrogation. After some denial the prisoner gives up where the
## gang leader is hiding; the leader is marked on the minimap and above the head.
func on_interact_pressed(_p: Node) -> void:
	if not arrested or leader or interrogated or _talk_t >= 0.0:
		return
	_talk_t = 0.0
	var pitch := 1.2 if female else 0.8
	AudioManager.say("ফ্রিল্যান্সার", "তোদের নেতা কোথায়? সত্যি বললে আদালতে তোর জন্য বলব।", 2.6, 0.85)
	get_tree().create_timer(2.8).timeout.connect(func():
		if is_instance_valid(self):
			AudioManager.say("বন্দি", "আমি কিছু জানি না! আমি শুধু পাহারা দিতাম…", 2.4, pitch))
	get_tree().create_timer(5.6).timeout.connect(func():
		if not is_instance_valid(self):
			return
		interrogated = true
		_talk_t = -1.0
		var L = Game.level.get("leader") if Game.level != null else null
		if L != null and is_instance_valid(L) and L.is_alive():
			AudioManager.say("বন্দি", "ঠিক আছে, ঠিক আছে… নেতা ওই বাড়ির দোতলায় থাকে। সিঁড়িতে গেট, বাসিন্দারা চাবি রাখে।", 4.0, pitch)
			L.revealed = true
			if Game.level.has_method("on_leader_revealed"):
				Game.level.on_leader_revealed(L)
		else:
			AudioManager.say("বন্দি", "নেতা আর নেই… বাকিরা গুলির বাক্সের কাছে জড়ো হয়।", 3.0, pitch))


func on_interact_held(_p: Node, _holding: bool, _delta: float) -> void:
	pass


func on_tie_held(_p: Node, holding: bool, delta: float) -> void:
	if not (surrendered and not arrested and alive):
		return
	if holding:
		_cuff += delta
		if _cuff >= 1.3:
			_arrest()
	else:
		_cuff = maxf(_cuff - delta * 2.0, 0.0)


func _arrest() -> void:
	arrested = true
	model.pose = ""
	model.kneel = false
	model.set_tied(true)
	_help_t = _rng.randf_range(6.0, 10.0)
	AudioManager.play_3d("sfx_handcuff", global_position + Vector3(0, 1.0, 0), -2.0, 1.0, 20.0)
	AudioManager.say("ফ্রিল্যান্সার", "আপনি গ্রেপ্তার। চুপচাপ আমার পেছনে হাঁটুন।", 2.4, 0.85)
	if Game.level != null and Game.level.has_method("on_leader_arrested"):
		Game.level.on_leader_arrested(self)


var _help_t := 8.0
static var _last_shout_ms := -100000


## Is someone keeping this prisoner quiet? An Alpha escorting (hand on the arm), the Freelancer right
## beside, or the Freelancer covering them with an aimed weapon within 12 m.
func _escorted() -> bool:
	for a in get_tree().get_nodes_in_group("allies"):
		if a.get("escort_target") == self and a.is_alive() and (a as Node3D).global_position.distance_to(global_position) < 2.5:
			return true
	return false


func _watched() -> bool:
	if _escorted():
		return true
	var p := Game.player as Node3D
	if p == null or not p.is_alive():
		return false
	var d := p.global_position.distance_to(global_position)
	if d < 2.5:
		return true
	if d < 12.0 and p.get("weapon") != null and bool(p.weapon.aiming):
		var cam: Camera3D = p.camera
		return (-cam.global_transform.basis.z).dot((chest_position() - cam.global_position).normalized()) > 0.9
	return false


## A loud call ("ওই যে!" / "বাঁচাও!"): male or female shout, subtitle near the Freelancer, and every
## gang member within 40 m comes to look.
func shout(text: String, alarm_pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_shout_ms < 1500:
		if Game.level != null and Game.level.has_method("raise_alarm"):
			Game.level.raise_alarm(self, alarm_pos)
		return
	_last_shout_ms = now
	AudioManager.play_3d("sfx_shout_%s%d" % ["f" if female else "m", _rng.randi_range(1, 2)], eye_position(), 4.0, _rng.randf_range(0.95, 1.05), 70.0)
	var p := Game.player as Node3D
	if p != null and p.global_position.distance_to(global_position) < 35.0:
		AudioManager.say("চক্রের নেতা" if leader else ("বন্দি" if arrested else "সন্ত্রাসী"), text, 1.8, 1.2 if female else 0.8)
	Game.noise(global_position, 40.0, "enemy")
	if Game.level != null and Game.level.has_method("raise_alarm"):
		Game.level.raise_alarm(self, alarm_pos)


## Hands up until cuffed; then walks behind the Freelancer and boards the helicopter when it is close.
func _do_prisoner(delta: float) -> void:
	_desired_v = Vector3.ZERO
	# left unwatched, a prisoner shouts for the gang (faster when gang members are near)
	if alive and not boarded:
		_help_t -= delta
		var near_gang := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and (e as Node3D).global_position.distance_to(global_position) < 18.0:
				near_gang = true
				break
		if _help_t <= 0.0 or (near_gang and _help_t < 4.0):
			_help_t = _rng.randf_range(7.0, 14.0)
			if not _watched():
				shout(["বাঁচাও! এই যে, এদিকে!", "ভাইয়েরা, আমাকে ধরে নিয়ে যাচ্ছে!", "এদিকে আয়, পুলিশ এখানে!"][_rng.randi_range(0, 2)], global_position)
	var p := Game.player as Node3D
	if p != null:
		var to := p.global_position - global_position
		if not arrested:
			_face_dir(to, delta, 4.0)
		elif to.length() > 2.2 and to.length() < 40.0:
			var goal := p.global_position + p.global_transform.basis.z * 1.6
			_nav_move(goal, 3.4 if to.length() < 8.0 else 4.6, delta)
		elif to.length() <= 2.2:
			_face_dir(to, delta, 4.0)
	if arrested and not boarded and Game.level != null:
		if leader and Game.level.has_method("heli_pickup_ok") and Game.level.heli_pickup_ok(global_position):
			boarded = true
			Game.level.on_leader_boarded(self)
			return
		if not leader:
			var z: Vector3 = Game.level.get("safe_zone")
			var fz := global_position - z
			fz.y = 0.0
			if fz.length() < float(Game.level.get("safe_radius")):
				boarded = true
				Game.level.on_prisoner_delivered(self)
				return
	velocity.x = move_toward(velocity.x, _desired_v.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, _desired_v.z, 20.0 * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	model.breath_rate = 2.6
	model.animate(delta, Vector2(velocity.x, velocity.z).length(), false, false)


## Senior guard: faints (lies down, alive). The body that can be tied and carried takes over.
func _faint() -> void:
	if not alive:
		return
	AudioManager.say("পাহারাদার", "আহ্‌… বুকে…", 1.6)
	if Game.level != null and Game.level.get("utils") != null:
		Game.level.utils.senior_fainted(self)
	else:
		_die(null, global_position)


## Lethal half of an Alpha woman's silent takedown. Bypasses the senior guard's faint rule.
func force_kill(from_pos: Vector3, killer: Node) -> void:
	if not alive:
		return
	_die(killer, from_pos)


## Replaced by a captive body (fainted senior / gunman taken down by an Alpha): gone from the gang.
func become_captive() -> void:
	alive = false
	state = State.DEAD
	collision_layer = 0
	_release_cover()
	_drop_hostage()
	if _laser != null:
		_laser.visible = false
	remove_from_group("enemies")
	remove_from_group("actors")
	remove_from_group("villains")
	visible = false
	set_physics_process(false)
	if Game.level != null:
		Game.level.set("_rids_dirty", true)
	get_tree().create_timer(1.0).timeout.connect(queue_free)


func _die(killer: Node, from_pos: Vector3) -> void:
	if Game.debug_log:
		print("[AI] %s %s died at %s killer=%s" % [name, kind, str(global_position.round()), str(killer.name) if killer != null else "-"])
	alive = false
	state = State.DEAD
	collision_layer = 0
	_release_cover()
	if Game.level != null and Game.level.get("utils") != null:
		Game.level.utils.on_enemy_down(self)
	if _laser != null:
		_laser.visible = false
	_indicator.visible = false
	remove_from_group("actors")
	add_to_group("corpses")
	_drop_hostage()
	var dir := global_position - from_pos
	dir.y = 0.0
	model.die(dir.normalized() if dir.length() > 0.01 else Vector3.BACK)
	velocity = Vector3.ZERO
	if killer != null and killer.is_in_group("player"):
		Game.stats["kills"] = int(Game.stats["kills"]) + 1
	# Air force rules: killing an airman calls two bombs down on the attacker.
	if faction == "airforce" and killer != null and killer is Node3D and Game.level != null \
			and Game.level.has_method("call_airstrike"):
		Game.level.call("call_airstrike", (killer as Node3D).global_position, 2)
	died.emit(self, killer)
	if Game.level != null and Game.level.has_method("on_enemy_died"):
		Game.level.on_enemy_died(self, killer)
	var t := get_tree().create_timer(60.0)
	t.timeout.connect(queue_free)


# ------------------------------------------------------------------ hearing / alarm
func _on_noise(pos: Vector3, radius: float, src_faction: String) -> void:
	if neutral:
		return
	if not alive or state == State.COMBAT or state == State.FLEE:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	if src_faction == "enemy":
		if radius >= 30.0:
			_go_alert(pos, 20.0)
		return
	if radius >= 30.0 and d < radius * 0.6:
		last_known = pos
		_enter_combat()
	else:
		_go_alert(pos, 15.0)


func alert_to(pos: Vector3) -> void:
	if alive and state != State.COMBAT and state != State.FLEE:
		_go_alert(pos, 20.0)


func _go_alert(pos: Vector3, duration: float) -> void:
	if state == State.FLEE or kind == "courier":
		return
	last_known = pos
	_alert_t = duration
	_wait_t = 0.0
	_search_points.clear()
	if state != State.ALERT:
		state = State.ALERT
		suspicion = maxf(suspicion, 0.4)
		model.set_expression(0.2, 0.35, 0.0, 0.0)


func _enter_combat() -> void:
	if not alive or kind == "courier" and state == State.FLEE:
		return
	var was := state
	if Game.debug_log and was != State.COMBAT:
		print("[AI] %s %s enters COMBAT at %s target=%s last=%s" % [name, kind, str(global_position.round()), str(target.name) if target != null else "-", str(last_known.round())])
	state = State.COMBAT
	suspicion = 1.0
	_lost_t = 0.0
	model.set_expression(0.1, 0.85, 0.0, 0.0)
	if was != State.COMBAT:
		_reaction = _rng.randf_range(0.35, 0.8)
		_cover_search_t = 0.0
		if target != null and target.is_in_group("friendly") and not surrendered:
			shout(["ওই যে! ধর ওকে!", "পুলিশ! সবাই এদিকে আয়!", "গুলি কর! ওখানে!"][_rng.randi_range(0, 2)], last_known)
		if Game.level != null and Game.level.has_method("raise_alarm"):
			Game.level.raise_alarm(self, last_known)
	if kind == "courier" and flee_path.size() > 0:
		start_flee()


func start_flee() -> void:
	if not alive or state == State.FLEE:
		return
	state = State.FLEE
	_flee_i = 0


# ------------------------------------------------------------------ villains: hostage recapture
## Returns true while busy carrying / walking to a hostage (normal state machine paused).
func _do_abduct(delta: float) -> bool:
	# only an enemy actually in sight makes him drop her and fight
	if state == State.COMBAT and target_visible:
		_drop_hostage()
		_abduct = null
		capture_civ = null
		return false
	# going for a beach visitor (HostageOps picked one nobody on the team is watching)
	if carrying == null and capture_civ != null:
		if not is_instance_valid(capture_civ) or not capture_civ.is_alive() or float(capture_civ.get("_panic")) > 0.0:
			capture_civ = null
			return false
		var cp := capture_civ.global_position
		if global_position.distance_to(cp) < 1.4:
			var h = Game.level.utils.capture_visitor(self, capture_civ) if Game.level != null and Game.level.get("utils") != null else null
			capture_civ = null
			if h != null:
				_abduct = h
			return true
		_nav_move(cp, float(_k["walk"]) * 1.2, delta)
		return true
	if carrying != null:
		if not is_instance_valid(carrying) or not carrying.is_carried():
			carrying = null
			return false
		var home: Vector3 = carrying.get("home")
		_nav_move(home, float(_k["walk"]) * 1.15, delta)
		# raised plinths / tight doorways near the holding spot: step in once stuck close by
		var flat := home - global_position
		flat.y = 0.0
		if Vector2(velocity.x, velocity.z).length() < 0.3:
			_abd_stuck += delta
		else:
			_abd_stuck = 0.0
		if _abd_stuck > 2.0 and flat.length() < 10.0:
			_abd_stuck = 0.0
			global_position = home - flat.normalized() * 1.2 + Vector3(0, 0.2, 0)
		return true
	if _abduct == null:
		_find_hostage()
		if _abduct == null:
			return false
	if not is_instance_valid(_abduct) or not _abduct.can_be_picked() or not bool(_abduct.get("rescued")):
		_abduct = null
		return false
	var hp: Vector3 = (_abduct as Node3D).global_position
	if global_position.distance_to(hp) < 1.4:
		if _abduct.abduct_by(self):
			carrying = _abduct
		_abduct = null
		return true
	_nav_move(hp, float(_k["run"]) * 0.8, delta)
	return true


func _find_hostage() -> void:
	var eye := eye_position()
	var view: float = float(_k["view"])
	for h in get_tree().get_nodes_in_group("hostages"):
		if not bool(h.get("rescued")) or not h.can_be_picked():
			continue
		if h.has_method("abductable") and not h.abductable():
			continue
		# opposite-gender rule: a villain drags back only hostages of the other gender
		if not Game.can_handle(self, h):
			continue
		var cp: Vector3 = h.chest_position()
		if eye.distance_to(cp) > view:
			continue
		if Ballistics.has_line_of_sight(get_world_3d(), eye, cp, [get_rid()]):
			_abduct = h
			return


func _drop_hostage() -> void:
	if carrying != null and is_instance_valid(carrying) and carrying.has_method("carrier_lost"):
		var c := carrying
		carrying = null
		c.carrier_lost()
	carrying = null


func delivered() -> void:
	carrying = null


func abduction_done() -> void:
	carrying = null


# ------------------------------------------------------------------ perception
func _candidates() -> Array:
	# Neutral soldiers never hunt anyone; they only fire back at the attacker
	# recorded by take_damage().
	if neutral:
		return []
	var out: Array = []
	# Kishor gangs attack absolutely anyone: civilians, police, soldiers, the hero.
	if kind == "kishor":
		for g in ["civilians", "neutrals", "friendly"]:
			for n in get_tree().get_nodes_in_group(g):
				if not out.has(n):
					out.append(n)
		return out
	for n in get_tree().get_nodes_in_group("friendly"):
		out.append(n)
	# gunmen open fire on hostages that were moved / untied or overheard talking
	if not abductor:
		for h in get_tree().get_nodes_in_group("hostages"):
			if h.is_exposed():
				out.append(h)
	for n in get_tree().get_nodes_in_group("escort_vehicle"):
		out.append(n)
	return out


func _think() -> void:
	var lv := Game.level
	var vis_mul: float = 1.0
	var dark: float = 1.0
	if lv != null:
		vis_mul = float(lv.get("visibility"))
		dark = float(lv.get("darkness"))
	var view: float = float(_k["view"]) * (vis_mul if kind != "sniper" else maxf(vis_mul, 0.6))
	if Game.level != null and Game.level.get("utils") != null:
		view *= float(Game.level.utils.vision_mul(global_position))
	var eye := eye_position()
	var fwd := -global_transform.basis.z
	var best: Node3D = null
	var best_score := 1e9
	var player_seen := false
	var player_dist := 0.0
	for c in _candidates():
		var n := c as Node3D
		if n == null or not n.has_method("chest_position"):
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		if n.has_method("is_targetable") and not n.is_targetable():
			continue
		var cp: Vector3 = n.chest_position()
		var to := cp - eye
		var d := to.length()
		if d > view or d < 0.01:
			continue
		var in_fov := fwd.dot(to / d) > 0.42 or d < 2.5 or (state == State.COMBAT and d < 15.0)
		if not in_fov:
			continue
		if not Ballistics.has_line_of_sight(get_world_3d(), eye, cp, [get_rid()]):
			continue
		var score := d
		if n.is_in_group("player"):
			score *= 0.6
			player_seen = true
			player_dist = d
		elif n.is_in_group("escort_vehicle"):
			score *= 1.4
		if score < best_score:
			best_score = score
			best = n
	target_visible = false
	if best != null:
		if state == State.COMBAT or kind == "sniper":
			target = best
			target_visible = true
			last_known = best.global_position
			_lost_t = 0.0
			if state != State.COMBAT:
				_enter_combat()
		elif best.is_in_group("player") and state != State.FLEE:
			var p: Node = best
			var rate := (1.7 - player_dist / view) * dark
			if bool(p.get("prone")):
				# lying flat (IGI-style): very hard to spot unless close
				rate *= 0.18 if player_dist > 8.0 else 0.5
			elif bool(p.get("crouching")):
				rate *= 0.45
			if bool(p.get("swimming")):
				rate *= 0.3
			if bool(p.get("sprinting")):
				rate *= 1.6
			if state == State.ALERT:
				rate *= 1.8
			suspicion += rate * 0.2 * 1.6
			last_known = best.global_position
			if suspicion >= 1.0:
				target = best
				target_visible = true
				Game.stats["detected"] = true
				_enter_combat()
			elif suspicion > 0.35 and state != State.ALERT:
				_go_alert(last_known, 12.0)
		elif state != State.FLEE:
			if best_score < view * 0.75:
				target = best
				target_visible = true
				last_known = best.global_position
				_enter_combat()
	elif state != State.COMBAT:
		suspicion = maxf(suspicion - 0.04, 0.0)
	if not player_seen and state != State.COMBAT:
		suspicion = maxf(suspicion - 0.02, 0.0)
	# Phase 4: the diplomat seen away from the holding spot - never shot (the gang wants him alive),
	# but this gunman raises his radio for reinforcements (HostageOps.vip_spotted)
	if state != State.FLEE and lv != null and lv.get("utils") != null:
		for vh in get_tree().get_nodes_in_group("vip_hostages"):
			if not vh.vip_visible():
				continue
			var vp: Vector3 = vh.sight_point()
			var tv := vp - eye
			var dv := tv.length()
			if dv > view * 0.9 or dv < 0.01:
				continue
			if fwd.dot(tv / dv) <= 0.42 and dv > 3.0:
				continue
			if Ballistics.has_line_of_sight(get_world_3d(), eye, vp, [get_rid()]):
				lv.utils.vip_spotted(self, vh)
				break
	# corpses
	if state != State.COMBAT and state != State.FLEE:
		for c in get_tree().get_nodes_in_group("corpses"):
			var cn := c as Node3D
			if cn == null or _seen_corpses.has(cn.get_instance_id()):
				continue
			var d2 := cn.global_position.distance_to(global_position)
			if d2 < 14.0 * vis_mul + 4.0 and Ballistics.has_line_of_sight(get_world_3d(), eye, cn.global_position + Vector3(0, 0.4, 0), [get_rid()]):
				_seen_corpses[cn.get_instance_id()] = true
				_go_alert(cn.global_position, 25.0)
				if Game.level != null and Game.level.has_method("raise_alarm"):
					Game.level.raise_alarm(self, cn.global_position)
				break


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if not alive:
		if not is_on_floor():
			velocity.y -= _gravity * delta
			move_and_slide()
		return
	if Game.level != null and not bool(Game.level.get("running")):
		return
	# Off-screen actors sleep: with 180+ NPCs, animating everyone every physics
	# tick is what freezes weak laptops. Only nearby fighters stay live.
	if state != State.COMBAT and Game.player != null \
			and global_position.distance_to((Game.player as Node3D).global_position) > 95.0:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= _gravity * delta if not is_on_floor() else 0.0
		move_and_slide()
		return
	if Game.level != null and global_position.y < float(Game.level.get("kill_y")) - 2.0:
		_die(null, global_position)
		return
	if surrendered:
		_do_prisoner(delta)
		return
	_combat_t = _combat_t + delta if state == State.COMBAT else 0.0
	if leader:
		_check_surrender()
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.35
		_think()
	_desired_v = Vector3.ZERO
	var aiming := false
	if abductor and _do_abduct(delta):
		velocity.x = move_toward(velocity.x, _desired_v.x, 20.0 * delta)
		velocity.z = move_toward(velocity.z, _desired_v.z, 20.0 * delta)
		velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
		move_and_slide()
		model.animate(delta, Vector2(velocity.x, velocity.z).length(), false, false)
		return
	if _resupply:
		_do_resupply(delta)
		if surrendered:
			return
	else:
		match state:
			State.IDLE:
				_do_idle(delta)
			State.PATROL:
				_do_patrol(delta)
			State.ALERT:
				_do_alert(delta)
			State.COMBAT:
				aiming = _do_combat(delta)
			State.FLEE:
				_do_flee(delta)
	velocity.x = move_toward(velocity.x, _desired_v.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, _desired_v.z, 20.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	model.animate(delta, hs, crouching, aiming)
	_update_indicator()
	# stuck detection
	if _desired_v.length() > 0.5:
		_stuck_t += delta
		if _stuck_t > 2.0:
			if global_position.distance_to(_last_pos) < 0.4:
				_on_stuck()
			_stuck_t = 0.0
			_last_pos = global_position
	else:
		_stuck_t = 0.0
		_last_pos = global_position


func _update_indicator() -> void:
	if state == State.COMBAT:
		_indicator.visible = true
		_indicator.text = "!"
		_indicator.modulate = Color(1, 0.15, 0.1)
	elif state == State.ALERT or suspicion > 0.15:
		_indicator.visible = true
		_indicator.text = "?"
		_indicator.modulate = Color(1, 0.85, 0.2).lerp(Color(1, 0.4, 0.1), suspicion)
	else:
		_indicator.visible = false


func _on_stuck() -> void:
	if state == State.PATROL and patrol.size() > 0:
		_patrol_i = (_patrol_i + 1) % patrol.size()
	elif state == State.COMBAT:
		_release_cover()
		_cover_search_t = 2.5
	elif state == State.ALERT:
		_wait_t = 3.0


func _face_dir(dir: Vector3, delta: float, speed: float = 8.0) -> void:
	if dir.length() < 0.01:
		return
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * speed, 0.0, 1.0))


## Moves along the navmesh. Returns true when arrived.
func _nav_move(point: Vector3, speed: float, delta: float, face: bool = true) -> bool:
	# ordinary gunmen stay out of houses; red-bandana villains go inside
	if not abductor and Game.level != null and Game.level.has_method("house_block"):
		point = Game.level.house_block(point, global_position)
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() < 1.0:
		return true
	var dir := flat.normalized()
	var nav_ok: bool = Game.level != null and bool(Game.level.get("nav_ready"))
	if nav_ok:
		if agent.target_position.distance_to(point) > 0.8:
			agent.target_position = point
		if agent.is_navigation_finished():
			return true
		var nxt := agent.get_next_path_position()
		var d2 := nxt - global_position
		d2.y = 0.0
		if d2.length() > 0.05:
			dir = d2.normalized()
	_desired_v = dir * speed
	if face:
		_face_dir(dir, delta)
	return false


func _do_idle(delta: float) -> void:
	crouching = false
	if _shift_move(delta):
		return
	_wait_t -= delta
	if _wait_t <= 0.0:
		_wait_t = _rng.randf_range(3.0, 6.0)
		_spec["look"] = _rng.randf_range(-PI, PI)
	if _spec.has("look"):
		rotation.y = lerp_angle(rotation.y, float(_spec["look"]), delta * 1.2)
	if not stationary and patrol.size() == 1 and global_position.distance_to(patrol[0]) > 2.0:
		_nav_move(patrol[0], float(_k["walk"]), delta)


func _do_patrol(delta: float) -> void:
	crouching = false
	if _shift_move(delta):
		return
	if patrol.is_empty():
		state = State.IDLE
		return
	if _wait_t > 0.0:
		_wait_t -= delta
		return
	var p: Vector3 = patrol[_patrol_i]
	if _nav_move(p, float(_k["walk"]), delta):
		_patrol_i = (_patrol_i + 1) % patrol.size()
		_wait_t = _rng.randf_range(1.0, 3.5)


func _do_alert(delta: float) -> void:
	crouching = false
	_alert_t -= delta
	if _alert_t <= 0.0:
		state = State.PATROL if patrol.size() > 1 and not stationary else State.IDLE
		suspicion = 0.0
		# anger was pushed to the face shader when combat started; clear it on
		# standing down or the guard keeps an angry scowl for the rest of the mission
		if model != null and model.has_method("set_expression"):
			model.set_expression(0.0, 0.0, 0.0, 0.0)
		return
	if stationary:
		var to := last_known - global_position
		_face_dir(to, delta, 3.0)
		return
	if _wait_t > 0.0:
		_wait_t -= delta
		rotation.y += sin(_alert_t * 1.3) * delta * 1.5
		return
	var goal := last_known
	if _search_points.size() > 0:
		goal = _search_points[0]
	if _nav_move(goal, float(_k["run"]) * 0.7, delta):
		_wait_t = _rng.randf_range(1.5, 3.0)
		if _search_points.size() > 0:
			_search_points.remove_at(0)
		elif _alert_t > 6.0:
			for i in 2:
				var off := Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
				_search_points.append(last_known + off)


func _target_valid() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_alive") and not target.is_alive():
		return false
	return true


func _do_combat(delta: float) -> bool:
	if not _target_valid():
		target = null
		target_visible = false
	if target_visible and target != null:
		_lost_t = 0.0
		var tp: Vector3 = target.chest_position()
		var to := tp - global_position
		to.y = 0.0
		if kind == "sniper":
			return _sniper_combat(delta, tp)
		_face_dir(to, delta, 10.0)
		_combat_move(delta, tp)
		if _reaction > 0.0:
			_reaction -= delta
			return true
		if _peeking or _cover.is_empty():
			_fire_logic(delta, tp)
		return true
	# lost sight
	if _laser != null:
		_laser.visible = false
	_lost_t += delta
	crouching = false
	_release_cover()
	if stationary:
		_face_dir(last_known - global_position, delta, 3.0)
		if _lost_t > 10.0:
			_go_alert(last_known, 10.0)
		return false
	var arrived := _nav_move(last_known, float(_k["run"]), delta)
	if arrived or _lost_t > 12.0:
		_go_alert(last_known, 18.0)
	return false


func _combat_move(delta: float, tp: Vector3) -> void:
	if stationary:
		crouching = false
		return
	var dist := global_position.distance_to(tp)
	if _cover.is_empty():
		_cover_search_t -= delta
		if _cover_search_t <= 0.0:
			_cover_search_t = 3.0
			_find_cover(tp)
	if not _cover.is_empty():
		var cp: Vector3 = _cover["pos"]
		if global_position.distance_to(cp) > 0.9:
			crouching = false
			_peeking = true
			_nav_move(cp, float(_k["run"]), delta, false)
			return
		_cover_t -= delta
		if _cover_t <= 0.0:
			_peeking = not _peeking
			_cover_t = _rng.randf_range(1.4, 2.6) if _peeking else _rng.randf_range(0.9, 1.8)
			if kind == "boss" and _rng.randf() < 0.3:
				_release_cover()
				_cover_search_t = 0.5
		crouching = not _peeking
		return
	# no cover: strafe and keep a fighting distance
	crouching = false
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = _rng.randf_range(1.0, 2.5)
		_strafe_dir = -_strafe_dir if _rng.randf() < 0.6 else _strafe_dir
	var to := (tp - global_position)
	to.y = 0.0
	var side := to.normalized().cross(Vector3.UP) * _strafe_dir
	var adv := Vector3.ZERO
	if dist > 26.0:
		adv = to.normalized()
	elif dist < 6.0:
		adv = -to.normalized()
	_desired_v = (side * 0.8 + adv).normalized() * float(_k["walk"])


func _find_cover(threat: Vector3) -> void:
	if Game.level == null:
		return
	var pts: Array = Game.level.get("cover_points")
	var best: Dictionary = {}
	var best_s := 1e9
	for cp in pts:
		var c: Dictionary = cp
		if c.get("taken") != null and c.get("taken") != self:
			continue
		var pos: Vector3 = c["pos"]
		var d := pos.distance_to(global_position)
		if d > 16.0:
			continue
		var to_threat := threat - pos
		to_threat.y = 0.0
		if to_threat.length() < 5.0:
			continue
		var cdir: Vector3 = c["dir"]
		if cdir.dot(to_threat.normalized()) < 0.45:
			continue
		var s := d + _rng.randf_range(0.0, 3.0)
		if s < best_s:
			best_s = s
			best = c
	if not best.is_empty():
		best["taken"] = self
		_cover = best
		_cover_t = _rng.randf_range(0.8, 1.5)
		_peeking = false


func _release_cover() -> void:
	if not _cover.is_empty():
		if _cover.get("taken") == self:
			_cover["taken"] = null
		_cover = {}


func _fire_logic(delta: float, tp: Vector3) -> void:
	_fire_cd -= delta
	_bomb_cd -= delta
	if bomb_thrower and _bomb_cd <= 0.0 and target != null and is_instance_valid(target):
		var from := eye_position()
		var aim_dir: Vector3 = (tp - from).normalized()
		Throwable.spawn(get_tree().root, "bomb", from, aim_dir * 15.0 + Vector3.UP * 9.0, self)
		Game.noise(tp, 60.0, "neutral_commando")
		_bomb_cd = 8.0
		_fire_cd = 1.2
		if Game.level != null and Game.level.get("hud") != null:
			Game.level.hud.notify("কমান্ডো বোমা নিক্ষেপ!", Color(1.0, 0.5, 0.3))
		return
	if kind == "kishor":
		# Knife gang: close in and stab anyone, no firearm involved.
		if target != null and is_instance_valid(target) and target is Node3D:
			var d: float = global_position.distance_to((target as Node3D).global_position)
			if d < 2.4 and _fire_cd <= 0.0 and target.has_method("take_damage"):
				target.call("take_damage", 22.0 * Game.difficulty_damage_scale(), global_position, self)
				AudioManager.play_3d("sfx_hit", global_position, -3.0, 1.0, 90.0)
				_fire_cd = 0.9
		else:
			_fire_cd = 0.2
		return
	if _fire_cd > 0.0:
		return
	var w: Dictionary = WeaponData.WEAPONS[weapon_id]
	if _burst_left <= 0:
		_burst_left = _rng.randi_range(2, 5) if bool(w["auto"]) else 1
		if kind == "boss":
			_burst_left += 3
	_shoot(tp, w)
	_burst_left -= 1
	# a senior guard in a long firefight can collapse from the strain
	if senior and _burst_left <= 0 and _combat_t > 20.0 and _rng.randf() < 0.04:
		_faint()
		return
	if _burst_left <= 0:
		_fire_cd = _rng.randf_range(0.6, 1.3) if bool(w["auto"]) else _rng.randf_range(0.7, 1.4)
	else:
		_fire_cd = 60.0 / float(w["rpm"])


func _shoot(tp: Vector3, w: Dictionary) -> void:
	if ammo == 0:
		_out_of_ammo()
		return
	if ammo > 0:
		ammo -= 1
		if ammo == 0:
			_out_of_ammo()
	var from := eye_position() - global_transform.basis.z * 0.3
	var aim := tp
	var dist := from.distance_to(aim)
	var spread: float = float(_k["spread"]) * Game.difficulty_accuracy_scale()
	if kind != "sniper":
		spread += dist * 0.025
	if Vector2(velocity.x, velocity.z).length() > 1.0:
		spread *= 1.5
	if target != null:
		if target.is_in_group("player"):
			if bool(target.get("prone")):
				spread *= 1.5
			elif bool(target.get("crouching")):
				spread *= 1.2
			if bool(target.get("sprinting")):
				spread *= 1.4
	var dir := Ballistics.spread_dir((aim - from).normalized(), spread)
	var ex: Array = []
	if Game.level != null:
		ex = Game.level.call("enemy_rids")
	if neutral:
		for other in get_tree().get_nodes_in_group("neutrals"):
			if other is CollisionObject3D and other != self:
				ex.append((other as CollisionObject3D).get_rid())
	var dmg: float = float(w["damage"]) * float(_k["dmg"])
	Ballistics.fire(get_world_3d(), from, dir, dmg, float(w["range"]), int(w["pen"]), self, ex, true)
	var mp: Vector3 = model.muzzle_position()
	AudioManager.play_3d(str(w["sound"]), mp, 2.0, _rng.randf_range(0.92, 1.08), 160.0)
	if _rng.randf() < 0.5:
		AudioManager.play_3d("sfx_tail_city", mp, -4.0, _rng.randf_range(0.9, 1.05), 220.0)
	if Game.level != null and Game.level.get("fx") != null:
		Game.level.fx.muzzle_light(mp)
	Game.noise(aim, 40.0, "enemy")


func _sniper_combat(delta: float, tp: Vector3) -> bool:
	var to := tp - global_position
	to.y = 0.0
	_face_dir(to, delta, 6.0)
	crouching = false
	var from := eye_position()
	_aim_t += delta
	if _laser != null:
		var d := tp - from
		var length := d.length()
		var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD
		_laser.global_transform = Transform3D(Basis.looking_at(d.normalized(), up) * Basis.from_scale(Vector3(1, 1, length)), from + d * 0.5)
		_laser.visible = true
	if _aim_t >= 2.0:
		_aim_t = 0.0
		_shoot(tp, WeaponData.WEAPONS["sniper"])
		_aim_t = -1.2
	return true


func _do_flee(delta: float) -> void:
	crouching = false
	if _flee_i >= flee_path.size():
		_desired_v = Vector3.ZERO
		if Game.level != null and Game.level.has_method("on_courier_escaped"):
			Game.level.on_courier_escaped(self)
		state = State.IDLE
		stationary = true
		return
	var p: Vector3 = flee_path[_flee_i]
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.8:
		_flee_i += 1
		return
	var dir := to.normalized()
	_desired_v = dir * float(_k["run"])
	_face_dir(dir, delta, 10.0)


## Off duty (shift change, or a false radio order): walk to the spot and wait; then back to the post.
func _shift_move(delta: float) -> bool:
	if shift_point != Vector3.INF:
		if global_position.distance_to(shift_point) > 1.5:
			_nav_move(shift_point, float(_k["walk"]) * 1.2, delta)
		return true
	if post != Vector3.INF and global_position.distance_to(post) > 1.2:
		_nav_move(post, float(_k["walk"]) * 1.2, delta)
		return true
	return false
