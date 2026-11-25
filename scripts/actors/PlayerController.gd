extends CharacterBody3D
## I.G.I.-style first person controller (V toggles third person so you can see the hero's face).
## WASD move, Shift sprint, Ctrl crouch, hold C to lean (A/D picks side) or hold Q to lean left,
## LMB fire, RMB aim, 1/2/3 weapons, R reload, E interact, H team order, Space jump.
## Hostages: E reassure / F give water, G carry / put down (two at once = no weapon),
## X hold tie / untie, J call an Alpha member to the hostage and give orders (menu, keys 1-6).
## Phase 3: Z prone (IGI-style crawl), swimming in lakes / rivers / canals (Space up, Ctrl dive, swim
## into a low bank to climb out), 4 grenade, 5 Molotov, 6 time bomb, L call an Alpha by
## parachute, K send carriers to the extraction vehicle, N headphones. Mission 1 opens with a
## parachute jump (Space opens the canopy, WASD steers).
## Carrying: over-the-shoulder; how fast you walk depends on the load (hostage mass / your capacity);
## lifting and putting down take a moment (squat, then stand).
## Phase 4: M listens in on the gang's radio with the Freelancer's own walkie-talkie (patrol routes and
## the leader's position). First-aid kits are the shared stock in Game.medkits.
## Cox's Bazar: the opposite-gender rule applies (Game.can_handle) - an Alpha woman handles men,
## an Alpha man handles women. J on an unaware gunman sends a free Alpha woman to take him down
## from behind: half the time he dies, half the time he becomes a gagged, taped captive for the police.
## At 0 health the Freelancer goes down instead of dying while a teammate can carry them to safety
## and give medicine.

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")
const WeaponSystem := preload("res://scripts/weapons/WeaponSystem.gd")
const Throwable := preload("res://scripts/weapons/Throwable.gd")
const ParachuteScript := preload("res://scripts/world/Parachute.gd")
const HUDScript := preload("res://scripts/ui/HUD.gd")
const WALK_SPEED := 4.3
const SPRINT_SPEED := 7.2
const CROUCH_SPEED := 2.1
const AIM_SPEED := 2.8
const ACCEL := 11.0
const JUMP_VELOCITY := 5.2
const STAND_EYE := 1.62
const CROUCH_EYE := 1.0
const PRONE_EYE := 0.36
const PRONE_SPEED := 1.05
const SWIM_SPEED := 2.3
const MAX_HEALTH := 125.0   # Phase 3h: 25% more than before

var faction := "player"
var health := MAX_HEALTH
var alive := true
var crouching := false
var sprinting := false
var input_enabled := false
var third_person := false
var lean := 0.0
var noise_level := 0.0
var head: Node3D
var lean_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var weapon: WeaponSystem
var model: CharacterModel
var collider: CollisionShape3D
var capsule: CapsuleShape3D
var interact_target: Node = null
## first carried hostage (kept for older code) + the full list (max two, one per shoulder)
var carrying: Node = null
var carried: Array = []
## drinks left in the water bottle (refill at tube-wells / taps)
var water := 0
const WATER_MAX := 3
## B: binoculars with laser rangefinder; T: thermal vision
var binoculars := false
var thermal := false
var bino_range := -1.0
var bino_target := ""
var _pitch := 0.0
var _recoil_recover := 0.0
var _step_dist := 0.0
var _since_damage := 10.0
var _shake := 0.0
var _fall_speed := 0.0
var _gravity: float = 13.0
var _last_safe := Vector3.ZERO
## Phase 3 movement / gear
var prone := false
var swimming := false
var breath := 1.0
var parachuting := false
var chute_open := false
var _chute: Node3D = null
var snacks := 0
var max_health := MAX_HEALTH
## Phase 3h kit: first-aid boxes, the briefing hostage's phone, the cage key, the gang's walkie-talkie.
## Phase 4: first-aid kits are bought in the shop and kept between missions (Game.medkits); everything
## that read or wrote "first_aid" (residents, pickups, the HUD) goes through this property.
var first_aid: int:
	get:
		return Game.medkits
	set(value):
		Game.set_medkits(value)
## the Freelancer's own walkie-talkie (M: listen in on the gang); "radios" counts captured gang sets (O)
var walkie := true
var phones := 0
var keys := 0
var radios := 0
var grenades := 3
var molotovs := 2
var bombs := 2
## kg the Freelancer carries comfortably on one shoulder (build x training)
var capacity := 95.0
## the Freelancer's gender (customiser) and clothes - the opposite-gender rule and the downed body use them
var female := false
var outfit: Dictionary = {}
## Phase 7: after the bomb procedure the rescuer wears the hostage's bomb-rigged garment until the
## nurse defuses the device on them.
var bomb_worn := false
var _bomb_vest: Node3D = null
## 0 health with an Alpha of the other gender alive: lying down, carried to safety, then revived
var downed := false
var _tp_before := false
var _cam_squat := 0.0
var _stroke := 0.0
var _water_y := -INF
var _drown_t := 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("actors")
	add_to_group("friendly")
	Game.player = self
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 13.0))
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD | Game.L_ENEMY | Game.L_VEHICLE
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.4
	collider = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	collider.shape = capsule
	collider.position = Vector3(0, 0.9, 0)
	add_child(collider)
	head = Node3D.new()
	head.position = Vector3(0, STAND_EYE, 0)
	add_child(head)
	lean_pivot = Node3D.new()
	head.add_child(lean_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 0.0
	arm.collision_mask = Game.L_WORLD | Game.L_VEHICLE
	arm.margin = 0.15
	arm.add_excluded_object(get_rid())
	lean_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = float(Game.settings["fov"])
	camera.near = 0.04
	camera.far = 160.0 if Game.quality() > 0 else 110.0
	arm.add_child(camera)
	camera.make_current()
	weapon = WeaponSystem.new()
	camera.add_child(weapon)
	weapon.setup(self, camera)
	# full IGI-style loadout: assault, SMG, marksman, support, sidearm
	weapon.give_weapon("m4", 120)
	weapon.give_weapon("mp5", 90)
	weapon.give_weapon("awp", 30)
	weapon.give_weapon("lmg", 180)
	weapon.give_weapon("deagle", 42)
	weapon.select_slot(0)
	# Pharmacy health upgrades persist between missions
	max_health = MAX_HEALTH + float(Game.health_bonus)
	health = max_health
	model = CharacterModel.new()
	add_child(model)
	outfit = CharacterModel.outfit_for("hero", RandomNumberGenerator.new())
	female = bool(outfit.get("female", false))
	capacity = CharacterModel.carry_capacity(outfit, true)
	model.setup("hero", outfit)
	var hero_photo := AssetLoader.slot_face_key("hero", 1)
	if hero_photo != "":
		AssetLoader.apply_face(model, "hero", hero_photo)
	# slider face only (no photo): the Freelancer can be carried out at 0 health
	model.visible = false
	_last_safe = global_position


func is_alive() -> bool:
	return alive


func eye_position() -> Vector3:
	return head.global_position


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.0 if crouching else 1.35, 0)


func is_headshot(pos: Vector3) -> bool:
	return pos.y > global_position.y + (1.05 if crouching else 1.5)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	_pitch = clampf(_pitch + deg_to_rad(pitch_deg), deg_to_rad(-88.0), deg_to_rad(88.0))
	rotation.y += deg_to_rad(yaw_deg)
	_recoil_recover += deg_to_rad(pitch_deg) * 0.6


func _unhandled_input(event: InputEvent) -> void:
	if not alive or not input_enabled:
		return
	# order menu open: number keys pick an order instead of switching weapons
	if event is InputEventKey and event.pressed and not event.echo and Game.level != null and Game.level.has_method("order_menu_open") and Game.level.order_menu_open():
		var kc: int = (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_9:
			Game.level.choose_order(kc - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("jump") and parachuting and not chute_open:
		_open_chute()
		return
	if event.is_action_pressed("prone"):
		_toggle_prone()
		return
	# 8 toggles the hero's gun scope (enemies have no scope system at all).
	if event.is_action_pressed("scope"):
		weapon.toggle_scope()
		if Game.level != null and Game.level.get("hud") != null:
			Game.level.hud.notify("স্কোপ: " + ("চালু" if weapon.scope_toggle else "বন্ধ"), Color(0.6, 1.0, 0.8))
		return
	if event.is_action_pressed("throw_grenade"):
		_throw("grenade")
		return
	if event.is_action_pressed("throw_molotov"):
		_throw("molotov")
		return
	if event.is_action_pressed("plant_bomb"):
		_plant_bomb()
		return
	if event.is_action_pressed("call_alpha"):
		if Game.level != null and Game.level.has_method("call_alpha"):
			Game.level.call_alpha()
		return
	if event.is_action_pressed("send_extract"):
		if Game.level != null and Game.level.has_method("send_extract"):
			Game.level.send_extract()
		return
	if event.is_action_pressed("headphones"):
		AudioManager.toggle_headphones()
		return
	if event.is_action_pressed("give_food"):
		_food()
		return
	if event.is_action_pressed("companion"):
		if Game.level != null and Game.level.get("utils") != null:
			Game.level.utils.companion_key()
		return
	if event.is_action_pressed("radio"):
		if Game.level != null and Game.level.get("utils") != null:
			Game.level.utils.use_radio()
		return
	if event.is_action_pressed("skip_brief"):
		if Game.level != null and Game.level.get("utils") != null:
			Game.level.utils.skip_brief()
		return
	if event.is_action_pressed("cycle_tape"):
		var t := Game.cycle_tape()
		if Game.level != null and Game.level.get("hud") != null:
			var tc: Color = Game.tape_info(t)["color"]
			Game.level.hud.notify("টেপের ধরন: %s" % Game.tape_name(t), tc.lightened(0.3))
		AudioManager.play_2d("sfx_ui", -12.0, 1.0 + 0.05 * t)
		return
	if event.is_action_pressed("ask"):
		var at := interact_target
		if at != null and is_instance_valid(at) and at.has_method("can_answer") and at.can_answer() and Game.level != null:
			Game.level.open_questions(at)
		elif Game.level != null and Game.level.get("hud") != null:
			Game.level.hud.notify("I চাপে BCS গেট বা মিশন তথ্য দেখুন", Color(1, 0.8, 0.5))
		return
	if event.is_action_pressed("intercept"):
		if Game.level != null and Game.level.get("utils") != null:
			Game.level.utils.intercept_radio()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		var sens: float = float(Game.settings["mouse_sensitivity"])
		if weapon.aiming:
			sens *= 0.55
		var inv := -1.0 if bool(Game.settings["invert_y"]) else 1.0
		rotation.y -= deg_to_rad(rel.x * sens)
		_pitch = clampf(_pitch - deg_to_rad(rel.y * sens) * inv, deg_to_rad(-88.0), deg_to_rad(88.0))
		_recoil_recover = maxf(_recoil_recover - absf(deg_to_rad(rel.y * sens)), 0.0)
		weapon.add_sway(rel)
	elif event.is_action_pressed("binoculars"):
		binoculars = not binoculars
		AudioManager.play_2d("sfx_switch", -8.0, 1.4)
	elif event.is_action_pressed("thermal"):
		set_thermal(not thermal)
	elif event.is_action_pressed("carry"):
		_carry_pressed()
	elif event.is_action_pressed("give_water"):
		if interact_target != null and is_instance_valid(interact_target) and interact_target.has_method("on_water"):
			interact_target.on_water(self)
	elif event.is_action_pressed("ally_assist"):
		var foe := _enemy_in_view() if interact_target == null else null
		if interact_target != null and is_instance_valid(interact_target) and (interact_target.is_in_group("hostages") or interact_target.is_in_group("enemy_captives")) and Game.level != null and Game.level.has_method("request_ally_assist"):
			Game.level.request_ally_assist(interact_target)
		elif foe != null and Game.level != null and Game.level.has_method("request_takedown"):
			Game.level.request_takedown(foe)
		elif interact_target != null and is_instance_valid(interact_target) and interact_target.is_in_group("prisoners") and bool(interact_target.get("arrested")) and Game.level != null:
			Game.level.request_escort(interact_target)
		elif Game.level != null and Game.level.has_method("open_carrier_menu"):
			Game.level.open_carrier_menu()
	elif carrying != null and (event.is_action_pressed("weapon_1") or event.is_action_pressed("weapon_3") or event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev")):
		AudioManager.say("", "ভারী বোঝা নিয়ে শুধু পিস্তল চালানো যায়।", 2.0)
	elif event.is_action_pressed("weapon_1"):
		weapon.select_slot(0)
	elif event.is_action_pressed("weapon_2"):
		weapon.select_slot(1)
	elif event.is_action_pressed("weapon_3"):
		weapon.select_slot(2)
	elif event.is_action_pressed("weapon_next"):
		weapon.cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		weapon.cycle(-1)
	elif event.is_action_pressed("reload"):
		weapon.start_reload()
	elif event.is_action_pressed("toggle_camera"):
		third_person = not third_person
	elif event.is_action_pressed("crouch") and bool(Game.settings["crouch_toggle"]) and not swimming:
		if prone:
			_set_prone(false)
			if not prone:
				crouching = true
		else:
			_try_set_crouch(not crouching)
	
	elif event.is_action_pressed("interact"):
		if interact_target != null and is_instance_valid(interact_target) and interact_target.has_method("on_interact_pressed"):
			interact_target.on_interact_pressed(self)
	elif event.is_action_pressed("team_order"):
		if Game.level != null and Game.level.has_method("toggle_team_order"):
			Game.level.toggle_team_order()


func _try_set_crouch(want: bool) -> void:
	if want:
		crouching = true
		return
	# only stand up if there is head room
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0.95, 0), Game.L_WORLD)
	if space.intersect_ray(q).is_empty():
		crouching = false


func _physics_process(delta: float) -> void:
	if downed:
		_follow_downed()
		_update_head(delta)
		# the carried body is shown by the stand-in; the Freelancer's own model stays hidden
		model.visible = false
		weapon.visible = false
		return
	if parachuting:
		if Game.level != null and not bool(Game.level.get("running")):
			velocity = Vector3.ZERO
			return
		_do_parachute(delta)
		return
	_water_y = Game.level.water_surface_at(global_position) if Game.level != null and Game.level.has_method("water_surface_at") else -INF
	var was_swimming := swimming
	swimming = alive and _water_y > -INF and global_position.y < _water_y - 0.95
	if swimming and not was_swimming:
		_enter_water()
	elif was_swimming and not swimming:
		AudioManager.set_underwater(false)
	if swimming:
		_do_swim(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	else:
		if _fall_speed > 13.0 and alive:
			take_damage((_fall_speed - 13.0) * 9.0, global_position + Vector3.DOWN, null)
		_fall_speed = 0.0
		_last_safe = global_position
	var kill_y := -25.0
	if Game.level != null:
		kill_y = float(Game.level.get("kill_y"))
	if global_position.y < kill_y and _water_y == -INF:
		global_position = _last_safe + Vector3(0, 0.6, 0)
		velocity = Vector3.ZERO
		_fall_speed = 0.0
		take_damage(10.0, global_position, null)
		AudioManager.say("", "পানিতে পড়ে গিয়েছিলেন — আগের জায়গায় ফেরত।", 2.0)
	if not alive:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
		move_and_slide()
		return
	var can_input := input_enabled
	var input_dir := Vector2.ZERO
	var lean_target := 0.0
	if can_input:
		if not bool(Game.settings["crouch_toggle"]):
			_try_set_crouch(Input.is_action_pressed("crouch"))
		var lean_hold := Input.is_action_pressed("lean")
		if lean_hold:
			lean_target = -1.0 if Input.is_action_pressed("move_left") else 1.0
		elif Input.is_action_pressed("lean_left"):
			lean_target = -1.0
		if not lean_hold:
			input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
			velocity.y = JUMP_VELOCITY
	for c in carried.duplicate():
		if not is_instance_valid(c):
			carried.erase(c)
	carrying = carried[0] if not carried.is_empty() else null
	# lifting someone onto the shoulder / kneeling them down: stand still meanwhile
	var squat := 0.0
	var transferring := false
	for c in carried:
		if c.has_method("lift_squat"):
			squat = maxf(squat, c.lift_squat())
		if c.has_method("is_transferring") and c.is_transferring():
			transferring = true
	_cam_squat = lerpf(_cam_squat, squat, clampf(delta * 10.0, 0.0, 1.0))
	if transferring:
		input_dir = Vector2.ZERO
	if carrying != null and prone:
		_set_prone(false)
	if carrying != null and weapon.weapon_id() != "pistol":
		weapon.select_slot(weapon.slots.find("pistol"))
	# two hostages on the shoulders: both hands are busy, no weapon at all
	weapon.visible = alive and carried.size() < 2
	sprinting = can_input and carrying == null and Input.is_action_pressed("sprint") and input_dir.y < -0.2 and not crouching and not weapon.aiming and lean_target == 0.0
	var speed := WALK_SPEED
	if prone:
		speed = PRONE_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	elif weapon.aiming:
		speed = AIM_SPEED
	if carrying != null:
		# heavier load (hostage mass / capacity) -> slower, shorter steps
		speed = minf(speed, clampf(3.9 - 1.7 * carry_load(), 1.3, 3.8))
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target_v := wish * speed
	var accel := ACCEL if is_on_floor() else ACCEL * 0.3
	velocity.x = move_toward(velocity.x, target_v.x, accel * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, accel * delta * speed)
	move_and_slide()
	_update_lean(delta, lean_target if not prone else 0.0)
	_update_head(delta)
	_update_footsteps(delta)
	_update_interact()
	_regen(delta)
	if binoculars:
		weapon.visible = false
	if can_input:
		var hands_free := carried.size() < 2 and not binoculars
		weapon.process_weapon(delta, hands_free and Input.is_action_pressed("fire"), hands_free and Input.is_action_just_pressed("fire"), hands_free and Input.is_action_pressed("aim"))
	model.animate(delta, Vector2(velocity.x, velocity.z).length(), crouching or prone, weapon.aiming)


func _update_lean(delta: float, target: float) -> void:
	var max_off := 0.5
	if target != 0.0:
		var space := get_world_3d().direct_space_state
		var from := head.global_position
		var side := global_transform.basis.x * signf(target)
		var q := PhysicsRayQueryParameters3D.create(from, from + side * 0.7, Game.L_WORLD)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			max_off = maxf(from.distance_to(hit["position"]) - 0.2, 0.0)
	lean = move_toward(lean, target, delta * 4.5)
	lean_pivot.position.x = lean * minf(max_off, 0.5)
	lean_pivot.rotation.z = -lean * 0.22


func _update_head(delta: float) -> void:
	var eye := PRONE_EYE if prone else (CROUCH_EYE if crouching else STAND_EYE)
	if _cam_squat > 0.01:
		head.position.y = eye - 0.45 * _cam_squat
	else:
		head.position.y = move_toward(head.position.y, eye, delta * (2.2 if prone else 4.0))
	capsule.height = lerpf(capsule.height, 0.7 if prone else (1.25 if crouching else 1.8), clampf(delta * 10.0, 0.0, 1.0))
	collider.position.y = capsule.height * 0.5
	if _recoil_recover > 0.0:
		var r := minf(_recoil_recover, delta * 0.12)
		_recoil_recover -= r
		_pitch -= r
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02
	head.rotation.x = _pitch + sh.x
	head.rotation.z = sh.y
	var fov_base: float = float(Game.settings["fov"])
	var zoom: float = float(weapon.data()["zoom"]) if weapon.aiming else 1.0
	if binoculars:
		zoom = 0.09
		_update_rangefinder()
	camera.fov = lerpf(camera.fov, fov_base * zoom, clampf(delta * 12.0, 0.0, 1.0))
	if third_person:
		arm.spring_length = move_toward(arm.spring_length, 2.6, delta * 8.0)
		arm.position = arm.position.lerp(Vector3(0.6, 0.25, 0), clampf(delta * 8.0, 0.0, 1.0))
		model.visible = true
		weapon.visible = false
	else:
		arm.spring_length = 0.0
		arm.position = Vector3.ZERO
		model.visible = false
		weapon.visible = true


func _update_footsteps(delta: float) -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	noise_level = 0.0
	if not is_on_floor() or hv < 0.5:
		return
	_step_dist += hv * delta
	var stride := 1.9 if sprinting else (0.9 if prone else 1.5)
	if _step_dist >= stride:
		_step_dist = 0.0
		var wet: float = 0.0
		if Game.level != null:
			wet = float(Game.level.get("wetness"))
		var snd := "sfx_step_wet" if wet > 0.3 else ("sfx_step1" if randf() < 0.5 else "sfx_step2")
		if wet <= 0.3 and randf() < 0.6:
			snd = "sfx_step_c%d" % randi_range(1, 4)
		if prone:
			snd = "sfx_crawl"
		var vol := -10.0
		if prone:
			vol = -16.0
		elif crouching:
			vol = -22.0
		elif sprinting:
			vol = -4.0
		AudioManager.play_2d(snd, vol, randf_range(0.9, 1.1))
		if sprinting:
			Game.noise(global_position, 14.0, "player")
		elif not crouching and not prone:
			Game.noise(global_position, 5.0, "player")
	if sprinting:
		noise_level = 1.0
	elif not crouching and not prone:
		noise_level = 0.4


func _update_interact() -> void:
	interact_target = null
	var best := 2.4
	var fwd := -camera.global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Node3D
		if it == null or not it.visible or (it.has_method("can_interact") and not it.can_interact()):
			continue
		var to := it.global_position - head.global_position
		var d := to.length()
		if d < best and (d < 1.2 or fwd.dot(to / maxf(d, 0.01)) > 0.55):
			best = d
			interact_target = it
	# hands busy with tape / rope / cuffs: weapon lowered, the body model reaches (third person)
	model.reach_target = Vector3.INF
	if interact_target != null and input_enabled and (Input.is_action_pressed("interact") or Input.is_action_pressed("tie")) and (interact_target.is_in_group("hostages") or interact_target.is_in_group("prisoners")):
		var tm: Node3D = interact_target.get("model")
		if tm != null:
			model.reach_target = tm.head.global_transform * Vector3(0.0, 0.12, -0.11) if Input.is_action_pressed("interact") else (interact_target as Node3D).global_transform * Vector3(0.0, 0.7, 0.2)
			# gentle camera assist: the view drifts onto the mouth / wrists while the hands work
			var dt := get_physics_process_delta_time()
			var to: Vector3 = model.reach_target - camera.global_position
			var want_yaw := atan2(-to.x, -to.z)
			var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
			var dyaw := wrapf(want_yaw - rotation.y, -PI, PI)
			if absf(dyaw) < 1.2:
				rotation.y += dyaw * clampf(dt * 3.0, 0.0, 1.0)
				_pitch = lerpf(_pitch, clampf(want_pitch, deg_to_rad(-80.0), deg_to_rad(60.0)), clampf(dt * 3.0, 0.0, 1.0))
		weapon.visible = false
	if interact_target != null and interact_target.has_method("on_interact_held"):
		interact_target.on_interact_held(self, Input.is_action_pressed("interact") and input_enabled, get_physics_process_delta_time())
	if interact_target != null and interact_target.has_method("on_tie_held"):
		interact_target.on_tie_held(self, Input.is_action_pressed("tie") and input_enabled, get_physics_process_delta_time())


# ---------------------------------------------------------------- hostage carrying (max two)
func _carry_pressed() -> void:
	if swimming or parachuting:
		return
	var t := interact_target
	if t != null and is_instance_valid(t) and (t.is_in_group("hostages") or t.is_in_group("enemy_captives")) and t.has_method("can_be_picked") and t.can_be_picked():
		if carried.size() >= 2:
			AudioManager.say("", "দুই কাঁধে দুজন — আর নেওয়া যাবে না। G চাপলে একজনকে নামাবেন।", 2.2)
			return
		var m := float(t.get("mass"))
		var total := m
		for c in carried:
			total += float(c.get("mass"))
		if Game.can_handle(self, t) and (m > capacity * 1.25 or total > capacity * 1.7):
			AudioManager.say("", "খুব ভারী — একা তোলা যাবে না। J চেপে আলফা সদস্যকে ডাকুন।", 2.6)
			return
		if prone:
			_set_prone(false)
		if t.pick_up(self):
			AudioManager.play_2d("sfx_effort_f" if bool(model.get("_female")) else "sfx_effort_m", -8.0, randf_range(0.95, 1.05))
		return
	if not carried.is_empty():
		var h: Node = carried[carried.size() - 1]
		var fwd := -global_transform.basis.z
		var side: float = float(h.get("carry_side"))
		h.put_down(global_position + fwd * 0.9 + global_transform.basis.x * 0.45 * side, rotation.y + PI)


## Called by Hostage.pick_up: returns the shoulder (+1 right, -1 left) or 0 if both are taken.
func add_carried(h: Node) -> float:
	if carried.size() >= 2 or carried.has(h):
		return 0.0
	var right_taken := false
	for c in carried:
		if float(c.get("carry_side")) > 0.0:
			right_taken = true
	carried.append(h)
	carrying = carried[0]
	return -1.0 if right_taken else 1.0


func remove_carried(h: Node) -> void:
	carried.erase(h)
	carrying = carried[0] if not carried.is_empty() else null


func set_thermal(on: bool) -> void:
	thermal = on
	RenderingServer.global_shader_parameter_set("thermal", 1.0 if on else 0.0)
	AudioManager.play_2d("sfx_switch", -6.0, 0.7 if on else 0.9)
	if Game.level != null and Game.level.has_method("on_thermal"):
		Game.level.on_thermal(on)


## Laser rangefinder: distance + what is under the reticle (shown on the binocular overlay).
func _update_rangefinder() -> void:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 800.0
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD | Game.L_ENEMY | Game.L_FRIEND)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		bino_range = -1.0
		bino_target = ""
		return
	bino_range = from.distance_to(hit["position"])
	var c: Node = hit["collider"]
	bino_target = ""
	if c != null:
		if c.is_in_group("villains"):
			bino_target = "ভিলেন"
		elif c.is_in_group("enemies"):
			bino_target = "শত্রু"
		elif c.is_in_group("hostages"):
			bino_target = "জিম্মি"
		elif c.is_in_group("allies"):
			bino_target = "আলফা"
		elif c.is_in_group("civilians"):
			bino_target = "সাধারণ মানুষ"


func refill_water() -> void:
	water = WATER_MAX


func _regen(delta: float) -> void:
	_since_damage += delta
	if _since_damage > 6.0 and health < max_health * 0.4:
		health = minf(health + delta * 3.0, max_health * 0.4)


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)


func apply_health_bonus() -> void:
	max_health = MAX_HEALTH + float(Game.health_bonus)
	health = minf(health + 25.0, max_health)
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("স্বাস্থ্য উন্নত: %s HP" % Game.bn(int(max_health)), Color(0.5, 1.0, 0.6))


## Where the crosshair points (nav-snapped): "go there and stay" orders.
func aim_point() -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pt: Vector3 = hit["position"] if not hit.is_empty() else to
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pt)


func take_damage(amount: float, from_pos: Vector3, attacker: Node) -> void:
	if not alive:
		return
	if OS.get_environment("DBG_DMG") != "":
		print("[DMG] %.1f from %s at %s (me %s)" % [amount, str(attacker.name) + ":" + str(attacker.get("kind")) if attacker != null else "-", str(from_pos.round()), str(global_position.round())])
	var dmg := amount
	if attacker != null and attacker != self:
		if attacker.is_in_group("allies"):
			return
		dmg *= Game.difficulty_damage_scale()
	if downed:
		return
	health -= dmg
	_since_damage = 0.0
	shake(clampf(dmg / 40.0, 0.2, 1.0))
	if Game.level != null and Game.level.has_method("on_player_damaged"):
		Game.level.on_player_damaged(dmg, from_pos)
	if health <= 0.0:
		health = 0.0
		if not swimming and not parachuting and Game.level != null and Game.level.has_method("can_rescue_hero") and Game.level.can_rescue_hero():
			_go_down()
		else:
			_die()


func _die() -> void:
	alive = false
	input_enabled = false
	weapon.visible = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(head, "position:y", 0.35, 0.8)
	tw.tween_property(head, "rotation:z", 1.2, 0.8)
	if Game.level != null and Game.level.has_method("on_player_died"):
		Game.level.on_player_died()


## 0 health, but an Alpha of the other gender can come: the Freelancer lies where he / she fell (a
## carryable body takes his / her place), the camera goes third person and follows the body while
## the Alpha carries it to safety and gives medicine (Mission.on_player_downed / hero_revived).
func _go_down() -> void:
	downed = true
	input_enabled = false
	weapon.visible = false
	for c in carried.duplicate():
		if is_instance_valid(c) and c.has_method("carrier_lost"):
			c.carrier_lost()
	carried.clear()
	carrying = null
	_tp_before = third_person
	third_person = true
	_pitch = deg_to_rad(-28.0)
	collision_layer = 0
	remove_from_group("friendly")
	velocity = Vector3.ZERO
	Game.level.on_player_downed()


## Medicine given: stand up at the spot with some health back.
func revive(at: Vector3, yaw: float, hp: float) -> void:
	downed = false
	alive = true
	health = clampf(hp, 1.0, max_health)
	global_position = at + Vector3(0, 0.1, 0)
	rotation.y = yaw
	collision_layer = Game.L_PLAYER
	if not is_in_group("friendly"):
		add_to_group("friendly")
	third_person = _tp_before
	weapon.visible = true
	input_enabled = true
	_since_damage = 0.0


## The camera follows the body being carried (third person) while the Freelancer is down.
func _follow_downed() -> void:
	var body: Node3D = Game.level.get("hero_proxy") if Game.level != null else null
	if body != null and is_instance_valid(body):
		global_position = body.global_position + Vector3(0, -0.6, 0)
	velocity = Vector3.ZERO


## J with nobody in front: a gunman under the crosshair (within 35 m, in sight) for a silent takedown.
func _enemy_in_view() -> Node:
	var from := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var best: Node = null
	var bdot := 0.985
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.chest_position() - from
		var d := to.length()
		if d > 35.0 or d < 0.5:
			continue
		var dt := fwd.dot(to / d)
		if dt > bdot:
			var q := PhysicsRayQueryParameters3D.create(from, e.chest_position(), Game.L_WORLD)
			q.exclude = [get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				bdot = dt
				best = e
	return best


## Load on the shoulders relative to a comfortable carry (0 = nothing, 1 = at capacity).
func carry_load() -> float:
	var total := 0.0
	for c in carried:
		if is_instance_valid(c):
			total += float(c.get("mass"))
	return total / maxf(capacity, 1.0)


## Y: give a snack to the hostage in front (mouth untaped) or eat it yourself.
func _food() -> void:
	var tt := interact_target
	if tt != null and is_instance_valid(tt) and tt.is_in_group("hostages") and (bool(tt.get("downed")) or bool(tt.get("injured"))):
		# Y on a wounded / injured hostage: first aid from the kit
		if bool(tt.get("downed")) and bool(tt.get("stabilized")) or (not bool(tt.get("downed")) and not bool(tt.get("injured"))):
			return
		if first_aid <= 0:
			AudioManager.say("", "মেডকিট (প্রাথমিক চিকিৎসার বাক্স) নেই — নার্স / ডাক্তার / বাসিন্দার সাহায্য নিন।", 3.0)
			return
		first_aid -= 1
		AudioManager.play_2d("sfx_cloth", -6.0, 1.15)
		if bool(tt.get("downed")):
			tt.stabilize("ফ্রিল্যান্সার")
		else:
			tt.treat("ফ্রিল্যান্সার")
		return
	if snacks <= 0:
		AudioManager.say("", "খাবার নেই — বাড়ির দরজার পাশের খাবারের মেশিন থেকে নিন।", 2.0)
		return
	var t := interact_target
	if t != null and is_instance_valid(t) and t.has_method("eat"):
		if t.eat(self):
			snacks -= 1
		return
	snacks -= 1
	heal(25.0)
	AudioManager.play_2d("sfx_shift", -10.0, 1.4)
	AudioManager.say("", "একটা চকলেট খেলেন — শরীরে একটু জোর ফিরল।", 2.0)


# ---------------------------------------------------------------- prone (Z)
func _toggle_prone() -> void:
	if swimming or parachuting:
		return
	_set_prone(not prone)


func _set_prone(want: bool) -> void:
	if want:
		if carrying != null:
			AudioManager.say("", "কাঁধে জিম্মি নিয়ে শুয়ে পড়া যায় না।", 1.8)
			return
		prone = true
		crouching = false
		AudioManager.play_2d("sfx_crawl", -8.0, 0.8)
		return
	# stand up only with head room (or at least crouch)
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 1.4, 0), Game.L_WORLD)
	if space.intersect_ray(q).is_empty():
		prone = false
	else:
		var q2 := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0.75, 0), Game.L_WORLD)
		if space.intersect_ray(q2).is_empty():
			prone = false
			crouching = true


# ---------------------------------------------------------------- swimming
func _enter_water() -> void:
	prone = false
	crouching = false
	AudioManager.play_3d("sfx_splash", global_position + Vector3(0, 1.0, 0), 0.0, randf_range(0.9, 1.1), 40.0)
	Game.noise(global_position, 8.0, "player")
	if not carried.is_empty():
		# nobody is carried through water: they are set down on the bank you came from
		for h in carried.duplicate():
			h.carrier_lost()
			(h as Node3D).global_position = _last_safe
		AudioManager.say("", "জিম্মি কাঁধে নিয়ে সাঁতার কাটা যায় না — তাঁকে পাড়ে রেখে এসেছেন।", 2.6)


func _do_swim(delta: float) -> void:
	var float_y := _water_y - 1.48
	var input_dir := Vector2.ZERO
	var vy := 0.0
	if input_enabled and alive:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_pressed("crouch"):
			vy = -1.4
		elif Input.is_action_pressed("jump"):
			vy = 1.6
	if vy == 0.0:
		vy = clampf((float_y - global_position.y) * 2.5, -1.5, 1.8)
	if global_position.y < _water_y - 5.5 and vy < 0.0:
		vy = 0.0
	if global_position.y > float_y + 0.05 and vy > 0.0:
		vy = 0.0
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var wish := fwd * -input_dir.y + right * input_dir.x
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target_v := wish * SWIM_SPEED
	velocity.x = move_toward(velocity.x, target_v.x, delta * 6.0)
	velocity.z = move_toward(velocity.z, target_v.z, delta * 6.0)
	velocity.y = move_toward(velocity.y, vy, delta * 6.0)
	move_and_slide()
	weapon.visible = false
	# climbing out onto a low bank, quay or jetty
	if input_dir.y < -0.3 and is_on_wall():
		var probe := global_position + fwd * 0.75 + Vector3(0, _water_y - global_position.y + 1.7, 0)
		var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3(0, -3.0, 0), Game.L_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var hy: float = (hit["position"] as Vector3).y
			if hy < _water_y + 1.45 and hy > _water_y - 0.4:
				global_position = (hit["position"] as Vector3) + Vector3(0, 0.08, 0)
				velocity = Vector3.ZERO
				swimming = false
				AudioManager.set_underwater(false)
				AudioManager.play_3d("sfx_splash", global_position, -8.0, 1.3, 20.0)
				return
	# breath: head under water for more than ~25 s starts to hurt
	var under: bool = head.global_position.y < _water_y - 0.05
	AudioManager.set_underwater(under)
	if under:
		breath = maxf(breath - delta / 25.0, 0.0)
		if breath <= 0.0:
			_drown_t -= delta
			if _drown_t <= 0.0:
				_drown_t = 1.0
				take_damage(9.0, global_position, null)
	else:
		if breath < 0.5:
			AudioManager.play_2d("sfx_gasp_f" if bool(model.get("_female")) else "sfx_gasp_m", -6.0)
			breath = 0.5
		breath = minf(breath + delta / 3.5, 1.0)
	var hv := Vector2(velocity.x, velocity.z).length()
	_stroke += hv * delta
	if _stroke > 1.3:
		_stroke = 0.0
		AudioManager.play_3d("sfx_swim_stroke", global_position + Vector3(0, 1.4, 0), -6.0 if not under else -14.0, randf_range(0.9, 1.1), 18.0)
		Game.noise(global_position, 4.0, "player")
	head.position.y = move_toward(head.position.y, STAND_EYE, delta * 3.0)
	head.rotation.x = _pitch
	head.rotation.z = sin(Time.get_ticks_msec() * 0.0015) * 0.03
	_update_interact()
	model.animate(delta, hv, false, false)


# ---------------------------------------------------------------- parachute
func begin_parachute() -> void:
	parachuting = true
	chute_open = false
	velocity = Vector3.ZERO


func _open_chute() -> void:
	if chute_open:
		return
	chute_open = true
	_chute = ParachuteScript.make()
	add_child(_chute)
	_chute.position = Vector3(0, 1.8, 0)
	AudioManager.play_2d("sfx_parachute_open", 0.0)
	shake(0.5)


func _do_parachute(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -200, 0), Game.L_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var agl := global_position.distance_to(hit["position"]) if not hit.is_empty() else 200.0
	var fwd := -global_transform.basis.z
	if not chute_open:
		velocity.y = maxf(velocity.y - _gravity * delta, -38.0)
		var steer := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)) * 3.0
		velocity.x = move_toward(velocity.x, steer.x, delta * 4.0)
		velocity.z = move_toward(velocity.z, steer.z, delta * 4.0)
		if agl < 45.0:
			_open_chute()
	else:
		velocity.y = move_toward(velocity.y, -4.6, delta * 22.0)
		# a square canopy glides forward: W faster, S brakes, A / D turn
		var glide := 4.0 - input_dir.y * 2.0
		rotation.y -= input_dir.x * delta * 0.9
		velocity.x = move_toward(velocity.x, fwd.x * glide, delta * 3.0)
		velocity.z = move_toward(velocity.z, fwd.z * glide, delta * 3.0)
	move_and_slide()
	weapon.visible = false
	head.rotation.x = _pitch
	head.rotation.z = sin(Time.get_ticks_msec() * 0.001) * 0.04 if chute_open else 0.0
	var fov_base: float = float(Game.settings["fov"])
	camera.fov = lerpf(camera.fov, fov_base * (1.08 if not chute_open else 1.0), clampf(delta * 6.0, 0.0, 1.0))
	if is_on_floor():
		parachuting = false
		chute_open = false
		if _chute != null:
			var c := _chute
			_chute = null
			var gp := c.global_position
			remove_child.call_deferred(c)
			get_parent().add_child.call_deferred(c)
			c.global_position = gp
			var tw := c.create_tween()
			tw.tween_property(c, "position:y", gp.y - 3.2, 1.5)
			tw.tween_callback(c.queue_free)
		AudioManager.play_2d("sfx_land", -2.0)
		shake(0.35)
		head.position.y = CROUCH_EYE
		_fall_speed = 0.0
		_last_safe = global_position
		AudioManager.say(Game.t("hq"), "নিরাপদে নেমেছেন। দল আপনার আশপাশেই।", 2.5)


# ---------------------------------------------------------------- explosives (4 / 5 / 6)
func _throw(kind: String) -> void:
	if swimming or parachuting or carried.size() >= 2 or not alive:
		return
	var left := grenades if kind == "grenade" else molotovs
	if left <= 0:
		AudioManager.say("", "আর %s নেই।" % ("গ্রেনেড" if kind == "grenade" else "মলোটভ"), 1.5)
		return
	if kind == "grenade":
		grenades -= 1
	else:
		molotovs -= 1
	var dir := -camera.global_transform.basis.z
	var pos := camera.global_position + dir * 0.45 + camera.global_transform.basis.x * 0.18 - Vector3(0, 0.12, 0)
	var vel := dir * (14.0 if not prone else 9.0) + Vector3(0, 3.2, 0) + Vector3(velocity.x, 0, velocity.z) * 0.5
	Throwable.spawn(get_parent(), kind, pos, vel, self)
	AudioManager.play_2d("sfx_pin" if kind == "grenade" else "sfx_lighter", -6.0, randf_range(0.95, 1.05))
	AudioManager.play_2d("sfx_throw", -8.0, randf_range(0.9, 1.1))


func _plant_bomb() -> void:
	if swimming or parachuting or not alive or not is_on_floor():
		return
	if bombs <= 0:
		AudioManager.say("", "আর কোনো টাইম বোমা নেই।", 1.5)
		return
	var fwd := -global_transform.basis.z
	var from := global_position + fwd * 0.7 + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.0, 0), Game.L_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	bombs -= 1
	Throwable.spawn(get_parent(), "bomb", (hit["position"] as Vector3) + Vector3(0, 0.08, 0), Vector3.ZERO, self)
	AudioManager.play_2d("sfx_bomb_arm", -4.0)
	AudioManager.say("", "টাইম বোমা বসানো হলো — ১০ সেকেন্ড! সরে যান!", 2.5)
