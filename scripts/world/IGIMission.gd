extends Node3D
## IGI-style infiltration mission in real Kajla, Dhaka.
## Recon / collect / sabotage / extract.  No hostages, no rescues, no medical system.

const LevelBuilder := preload("res://scripts/world/LevelBuilder.gd")
const KajlaMap := preload("res://scripts/world/KajlaMap.gd")
const Effects := preload("res://scripts/world/Effects.gd")
const WeatherSystem := preload("res://scripts/world/WeatherSystem.gd")
const PlayerScene := preload("res://scripts/actors/PlayerController.gd")
const EnemyScene := preload("res://scripts/actors/EnemyAI.gd")
const IntelObjectScene := preload("res://scripts/world/IntelObject.gd")
const DriveableVehicle := preload("res://scripts/world/DriveableVehicle.gd")
const ThermalSystem := preload("res://scripts/world/ThermalSystem.gd")
const BengaliAnnouncer := preload("res://scripts/world/BengaliAnnouncer.gd")
const PropagandaProp := preload("res://scripts/world/PropagandaProp.gd")
const BCSGate := preload("res://scripts/world/BCSGate.gd")
const ShopProp := preload("res://scripts/world/ShopProp.gd")
const Civilian := preload("res://scripts/world/Civilian.gd")
const LiftProp := preload("res://scripts/world/LiftProp.gd")
const WindowProp := preload("res://scripts/world/WindowProp.gd")
const AirstrikeScene := preload("res://scripts/world/Airstrike.gd")
const CityMeshScene := preload("res://scripts/world/CityMesh.gd")
const BuildingPortal := preload("res://scripts/world/BuildingPortal.gd")
const DoorProxy := preload("res://scripts/world/DoorProxy.gd")
const HUDScene := preload("res://scripts/ui/HUD.gd")

var mission_index: int = 1
var is_igi_mode := true

var data: Dictionary = {}
var layout: Dictionary = {}
var hud: CanvasLayer
var fx: Effects
var weather: WeatherSystem
var thermal: Node
var announcer: Node
var nav_region: NavigationRegion3D
var world_root: Node3D
var deco_root: Node3D
var actors_root: Node3D
var nav_ready := false
var running := false
var ended := false
var visibility := 1.0
var darkness := 1.0
var wetness := 0.0
var kill_y := -30.0
var map_rects: Array = []
var cover_points: Array = []
var safe_zone: Vector3
var safe_radius := 7.0
var objectives: Array = []
var obj_index := 0
var obj_timer := 0.0
var mission_time := 0.0
var alarm_raised := false
var alarm_deadline := -1.0
var team_hold := false
var utils: Node = null
var player: Node = null
var _marker: Label3D
var _obj_marker_pos := Vector3.INF
var _objects: Array = []
var _progress := {}
var _hud_wait := 0
var _combat_check := 0.0
var _in_combat := false
var _calm_t := 0.0
var _bg_mode := -1
var ammo_crates: Array = []
var killed_tags := {}
var alarms_raised := 0
var para_intro := false


func _ready() -> void:
	Game.level = self
	Game.current_mission = mission_index
	data = Game.mission_data(mission_index)
	hud = HUDScene.new()
	add_child(hud)
	hud.show_loading(Game.current_mission, data)
	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()


func _build_world() -> void:
	fx = Effects.new()
	add_child(fx)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	# Coarser cells bake far faster; still fine for 1.4 m stairs and 2 m doors.
	nm.cell_size = 0.5
	nm.cell_height = 0.4
	# Multiples of cell_height (0.4 m) avoid the engine's precision rounding.
	nm.agent_height = 2.0
	nm.agent_radius = 0.5
	nm.agent_max_climb = 0.4
	nm.region_min_size = 4.0
	nav_region.navigation_mesh = nm
	add_child(nav_region)

	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	deco_root = Node3D.new()
	deco_root.name = "Visuals"
	add_child(deco_root)
	actors_root = Node3D.new()
	actors_root.name = "Actors"
	add_child(actors_root)

	var b := LevelBuilder.new(nav_region, deco_root, Game.quality())
	layout = KajlaMap.build(b, mission_index)
	map_rects = layout.get("map_rects", [])
	cover_points = layout.get("cover_points", [])
	b.finalize()

	weather = WeatherSystem.new()
	add_child(weather)
	weather.setup(self, str(data.get("time", "night")), [["clear", 0.0]])
	thermal = ThermalSystem.new()
	add_child(thermal)
	announcer = BengaliAnnouncer.new()
	add_child(announcer)

	safe_zone = layout.get("extract", Vector3.ZERO)
	safe_radius = float(layout.get("safe_radius", 7.0))
	kill_y = float(layout.get("water_y", -30.0))

	_spawn_player()
	for spec in layout.get("enemies", []):
		spawn_enemy(spec)
	# Neutral forces: they never attack first, but return fire on whoever hits them.
	for n in layout.get("neutrals", []):
		spawn_enemy(n)
	# Kishor knife gangs: hostile to absolutely everyone, always in groups of three.
	for g in layout.get("gangs", []):
		spawn_enemy(g)
	for v in layout.get("vehicles", []):
		var veh := DriveableVehicle.new()
		veh.setup(str(v["kind"]), v["pos"], float(v["yaw"]))
		actors_root.add_child(veh)
	# IGI-style wanted posters and security leaflets around the real neighbourhood
	var sites: Array = layout.get("sites", [])
	for i in mini(10, sites.size()):
		var sp: Vector3 = (sites[i] as Dictionary).get("pos", safe_zone)
		actors_root.add_child(PropagandaProp.make("poster", sp + Vector3(1.6, 0, -0.4), randf_range(-0.4, 0.4)))
	for i in 6:
		var lp: Vector3 = layout.get("spawn", Vector3.ZERO) + Vector3(float(i) * 2.4 - 3.0, 0, -3.0 - float(i) * 1.5)
		actors_root.add_child(PropagandaProp.make("leaflet", lp, randf_range(-PI, PI)))
	# Colony ground-floor shops and pharmacies — safe, non-attackable storefronts.
	for s in layout.get("shops", []):
		var sd: Dictionary = s
		var sp := ShopProp.make(str(sd.get("kind", "shop")), sd.get("pos", safe_zone),
			float(sd.get("yaw", 0.0)), str(sd.get("name", "দোকান")))
		sp.set("shop_type", str(sd.get("type", sd.get("kind", "shop"))))
		actors_root.add_child(sp)
	# Lift call panels in every walk-in tower — all floors and the roof are stops.
	for h in layout.get("houses", []):
		var hd2: Dictionary = h
		var stops: Array = hd2.get("lifts", [])
		if stops.size() > 1:
			var lift := LiftProp.make((stops[0] as Vector3) + Vector3(0.0, -0.15, 0.0), stops)
			actors_root.add_child(lift)
	# Vaultable windows: shoot through them or climb in/out (first 3 per tower).
	var window_count := 0
	for h in layout.get("houses", []):
		var hd3: Dictionary = h
		var wins: Array = hd3.get("windows", [])
		for wi in mini(3, wins.size()):
			var wd: Dictionary = wins[wi]
			actors_root.add_child(WindowProp.make(wd.get("out", safe_zone), wd.get("in", safe_zone)))
			window_count += 1
	# Batched colony geometry: all 1,400+ buildings in one MultiMesh instance.
	deco_root.add_child(CityMeshScene.make(layout.get("mass_boxes", [])))
	# Door portals let the hero enter any colony building, climb its floors and
	# reach the roof; a limited set of windows is directly vaultable.
	var all_doors: Array = layout.get("mass_walkins", [])
	actors_root.add_child(DoorProxy.make(all_doors))
	var portal_count := 0
	for mh in all_doors:
		var mwd: Dictionary = mh
		portal_count += 1
		if portal_count <= 60:
			var mwins: Array = mwd.get("windows", [])
			if not mwins.is_empty():
				var mw: Dictionary = mwins[0]
				actors_root.add_child(WindowProp.make(mw.get("out", safe_zone), mw.get("in", safe_zone)))
	# Ordinary residents who can be hurt or killed by either side.
	for c in layout.get("civilians", []):
		var cd: Dictionary = c
		var civ := Civilian.new()
		civ.setup(cd.get("pos", safe_zone), float(cd.get("yaw", 0.0)), cd.get("patrol", []))
		actors_root.add_child(civ)
	objectives = (data.get("objectives", []) as Array).duplicate(true)
	_make_marker()
	hud.set_progress_text("/map/ loading Kajla…")
	nav_region.bake_finished.connect(_on_bake_finished)
	nav_region.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	_hud_wait = 3


func _start_mission() -> void:
	nav_ready = true
	running = true
	hud.hide_loading()
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.stop_music(0.5)
	AudioManager.play_music("mus_tension", -14.0)
	AudioManager.say(Game.t("hq"), str(data.get("brief", "মিশন শুরু। লক্ষ্য সম্পন্ন করে নির্ধারিত স্থানে ফিরে আসুন।")), 6.0)
	if announcer != null:
		announcer.announce("start")
	if para_intro:
		AudioManager.play_2d("sfx_parachute_open", -2.0)
		AudioManager.say(Game.t("hq"), "লাফ দিন, অপারেটিভ! Space চেপে প্যারাস্যুট খুলুন — কাজলার ওপর থেকে নামছি।", 5.0)
	# IGI-style checkpoint restore: resume from the objective reached last session.
	if Game.has_checkpoint() and int(Game.checkpoint.get("mission", 0)) == mission_index:
		var cp: Dictionary = Game.checkpoint
		obj_index = clampi(int(cp.get("obj", 0)), 0, maxi(objectives.size() - 1, 0))
		var pr: Variant = cp.get("progress", {})
		if pr is Dictionary:
			for k in pr.keys():
				_progress[int(k)] = int(pr[k])
		mission_time = float(cp.get("time", 0.0))
		Game.stats["score"] = int(cp.get("score", 0))
		var pa: Variant = cp.get("pos", [])
		if pa is Array and (pa as Array).size() == 3 and player != null:
			player.global_position = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		hud.notify("চেকপয়েন্ট পুনরুদ্ধার — লক্ষ্য %s" % Game.bn(obj_index + 1), Color(0.5, 0.9, 1.0))
		Game.clear_checkpoint()
	else:
		obj_index = 0
	_begin_objective()


func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Operative"
	actors_root.add_child(player)
	player.global_position = layout.get("spawn", Vector3.ZERO) + Vector3(0, 0.15, 0)
	player.rotation.y = float(layout.get("yaw", 0.0))
	# Every operation begins with a plane insertion and a HALO parachute jump.
	if true:  # plane + parachute insertion on every mission
		player.global_position += Vector3(0, 95.0, 0)
		player.begin_parachute()
		para_intro = true
		var carry := AirstrikeScene.make(layout.get("spawn", Vector3.ZERO), 0)
		carry.set("silent", true)
		actors_root.add_child(carry)


func spawn_enemy(spec: Dictionary) -> Node:
	var e := EnemyScene.new()
	e.setup(spec.duplicate())
	actors_root.add_child(e)
	e.global_position = (spec["pos"] as Vector3) + Vector3(0, 0.1, 0)
	e.rotation.y = randf_range(-PI, PI)
	return e


# ---------------------------------------------------------------- objectives
func current_objective() -> Dictionary:
	if obj_index < objectives.size():
		return objectives[obj_index]
	return {}


func _resolve_pos(o: Dictionary) -> Vector3:
	if o.has("pos") and o["pos"] is Vector3:
		return o["pos"]
	match int(o.get("pos_y", 0)):
		1:
			return safe_zone
		2:
			return Vector3(150.0, 0.0, -60.0)   # Kajla Park (real OSM landmark)
		3:
			return Vector3(-202.0, 0.0, 68.0)   # Kajla bus stop
		4:
			var houses: Array = layout.get("houses", [])
			if not houses.is_empty():
				return (houses[0] as Dictionary).get("inside", safe_zone)
			return safe_zone
		5:
			var houses2: Array = layout.get("houses", [])
			if not houses2.is_empty():
				return (houses2[0] as Dictionary).get("up", safe_zone)
			return safe_zone
		6:
			var houses3: Array = layout.get("houses", [])
			if not houses3.is_empty():
				return (houses3[0] as Dictionary).get("roof", safe_zone)
			return safe_zone
	return Vector3(-120.0, 0.0, 76.0)


func objective_text() -> String:
	var o := current_objective()
	var s := str(o.get("text", ""))
	var need := int(o.get("count", 0))
	if need > 0:
		s += " (%s/%s)" % [Game.bn(int(_progress.get(obj_index, 0))), Game.bn(need)]
	return s


func objective_count_text() -> String:
	var need := int(current_objective().get("count", 0))
	return " (%s/%s)" % [Game.bn(int(_progress.get(obj_index, 0))), Game.bn(need)] if need > 0 else ""


func _begin_objective() -> void:
	obj_timer = 0.0
	var o := current_objective()
	if o.is_empty():
		return
	if o.has("say"):
		AudioManager.say(str((o["say"] as Array)[0]), str((o["say"] as Array)[1]), 5.0)
	var ty := str(o.get("type", ""))
	if ty in ["photo", "collect", "sabotage", "wiretap", "disable_alarm", "bcs_gate"]:
		var n := int(o.get("count", 1))
		var sites: Array = layout.get("sites", [])
		for i in n:
			var site: Dictionary = sites[(obj_index * n + i) % sites.size()] if not sites.is_empty() else {"pos": safe_zone}
			var pos: Vector3 = site.get("pos", safe_zone)
			var oid := "o%d_%d" % [obj_index, i]
			if ty == "bcs_gate":
				var gate := BCSGate.make(oid, pos, randf_range(-0.3, 0.3))
				actors_root.add_child(gate)
				_objects.append(gate)
			else:
				var obj := IntelObjectScene.new()
				obj.setup(oid, ty, str(o.get("label", "লক্ষ্য")), pos + Vector3(randf_range(-1.0, 1.0), 0, 0))
				actors_root.add_child(obj)
				_objects.append(obj)
		_progress[obj_index] = 0
	elif ty == "eliminate":
		_progress[obj_index] = 0
		AudioManager.say(Game.t("hq"), str(o.get("say", ["HQ", "নিশানা চিহ্নিত কমান্ডারদের বাদ দিন।"])[1]), 4.0)
	_obj_marker_pos = _resolve_pos(o)
	hud.objective_started(o, obj_index, objectives.size())
	AudioManager.play_2d("sfx_ui", -6.0, 0.8)


func on_objective_action(obj_id: String) -> void:
	if not running or ended:
		return
	var parts := obj_id.split("_")
	if parts.size() < 2:
		return
	var oi := int(parts[0].trim_prefix("o"))
	if oi != obj_index:
		return
	_progress[oi] = int(_progress.get(oi, 0)) + 1
	Game.stats["objectives"] = int(Game.stats.get("objectives", 0)) + 1
	hud.notify("লক্ষ্য সম্পন্ন — %s/%s" % [Game.bn(int(_progress[oi])), Game.bn(int(current_objective().get("count", 1)))], Color(0.6, 1.0, 0.75))
	if int(_progress[oi]) >= int(current_objective().get("count", 1)):
		_complete_objective()


func _complete_objective() -> void:
	if obj_index < objectives.size() - 1:
		obj_index += 1
		if player != null:
			Game.save_checkpoint(mission_index, obj_index, _progress, (player as Node3D).global_position,
				mission_time, Game.score())
		hud.notify("লক্ষ্য সম্পন্ন — চেকপয়েন্ট সংরক্ষিত", Color(0.6, 1.0, 0.8))
		hud.notify("পরবর্তী লক্ষ্য: " + str(current_objective().get("text", "")), Color(0.6, 1.0, 0.8))
		_begin_objective()
	else:
		_success()


func _objective_pos() -> Vector3:
	var o := current_objective()
	var p: Node3D = Game.player as Node3D
	if p == null:
		return Vector3.INF
	match str(o.get("type", "")):
		"reach", "extract", "infiltrate", "survive":
			return _resolve_pos(o)
		"eliminate":
			var tag := str(o.get("tag", "commander"))
			var best := Vector3.ZERO
			var bd := 1e9
			for e in get_tree().get_nodes_in_group("enemies"):
				if not e.is_alive() or str(e.get("tag")) != tag:
					continue
				var d2: float = (e as Node3D).global_position.distance_to(p.global_position)
				if d2 < bd:
					bd = d2
					best = (e as Node3D).global_position + Vector3(0, 1.4, 0)
			return best if bd < 1e8 else safe_zone
		"photo", "collect", "sabotage", "wiretap", "disable_alarm", "bcs_gate":
			var best := Vector3.ZERO
			var bd := 1e9
			for obj in _objects:
				var n := obj as Node3D
				if n == null or not is_instance_valid(n) or bool(n.get("done")):
					continue
				var d: float = n.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = n.global_position + Vector3(0, 1.4, 0)
			return best
	return Vector3.INF


func _update_objective(delta: float) -> void:
	var o := current_objective()
	if o.is_empty():
		return
	obj_timer += delta
	var p: Vector3 = (player as Node3D).global_position
	var ty := str(o.get("type", ""))
	var done := false
	if ty in ["reach", "extract", "infiltrate"]:
		var target: Vector3 = _resolve_pos(o)
		var flat := Vector2(p.x - target.x, p.z - target.z).length()
		done = flat < float(o.get("radius", 7.0))
	elif ty == "survive":
		var target2: Vector3 = _resolve_pos(o)
		var flat2 := Vector2(p.x - target2.x, p.z - target2.z).length()
		if flat2 < float(o.get("radius", 12.0)):
			var need := float(o.get("time", 25.0))
			hud.set_timer(maxf(need - obj_timer, 0.0))
			done = obj_timer >= need
			if done:
				hud.set_timer(-1.0)
		else:
			hud.set_timer(-1.0)
	elif ty in ["photo", "collect", "sabotage", "wiretap", "disable_alarm"]:
		done = int(_progress.get(obj_index, 0)) >= int(o.get("count", 1))
	elif ty == "eliminate":
		done = int(killed_tags.get(str(o.get("tag", "commander")), 0)) >= int(o.get("count", 1))
	if done:
		_complete_objective()


func _process(delta: float) -> void:
	if _hud_wait > 0:
		_hud_wait -= 1
		if _hud_wait == 0:
			_start_mission()
		return
	if not running or ended:
		return
	mission_time += delta
	Game.stats["time"] = mission_time
	_update_objective(delta)
	_update_marker()
	if alarm_deadline > 0.0 and mission_time > alarm_deadline:
		fail("অ্যালার্ম বেজেছে — শত্রুদের নিরাপত্তা বাহিনী এসে গেছে। মিশন ব্যর্থ।")
	_combat_check -= delta
	if _combat_check <= 0.0:
		_combat_check = 1.0
		var combat := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and int(e.get("state")) == 3:
				combat = true
				break
		if combat:
			_calm_t = 0.0
			if not _in_combat:
				_in_combat = true
				AudioManager.play_music("mus_tension", -10.0)
		else:
			_calm_t += 1.0
			if _in_combat and _calm_t > 8.0:
				_in_combat = false
				AudioManager.stop_music(3.0)
	if weather != null:
		hud.set_screen_fx(weather.haze, weather.flash(), wetness)


func _update_marker() -> void:
	var pos := _objective_pos()
	_obj_marker_pos = pos
	if pos == Vector3.INF or ended:
		_marker.visible = false
		hud.set_objective_dir(Vector3.INF)
		return
	_marker.visible = true
	_marker.global_position = pos + Vector3(0, 1.2, 0)
	var d: float = pos.distance_to((player as Node3D).global_position)
	_marker.text = "◆\n%s মি" % Game.bn(int(d))
	hud.set_objective_dir(pos)


func _make_marker() -> void:
	_marker = Label3D.new()
	_marker.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.fixed_size = true
	_marker.pixel_size = 0.0012
	_marker.font_size = 30
	_marker.outline_size = 8
	_marker.modulate = Color(1.0, 0.85, 0.25)
	_marker.render_priority = 10
	_marker.visible = false
	add_child(_marker)


func _success() -> void:
	if ended:
		return
	ended = true
	Game.complete_mission(mission_index)
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_music(0.5)
	AudioManager.play_once_music("mus_victory")
	Game.add_score(int(data.get("reward", 500)), "মিশন সম্পন্ন")
	Game.record_mission_result(mission_index, objectives.size(), objectives.size(), alarms_raised, mission_time)
	hud.show_end(true, "", Game.current_mission)


func fail(reason: String) -> void:
	if ended:
		return
	ended = true
	if player != null:
		player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_music(1.0)
	hud.show_end(false, reason, Game.current_mission)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("thermal", 0.0)
	AudioManager.stop_all_world_audio()
	AudioManager.stop_music(0.3)
	if Game.level == self:
		Game.level = null


# ---------------------------------------------------------------- actor hooks
func raise_alarm(source: Node, pos: Vector3) -> void:
	var sp := (source as Node3D).global_position if source is Node3D else pos
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == source or not e.is_alive():
			continue
		if (e as Node3D).global_position.distance_to(sp) < 45.0:
			e.alert_to(pos)
	if alarm_raised:
		return
	alarm_raised = true
	alarms_raised += 1
	hud.notify("⚠ অ্যালার্ম! শত্রুরা সতর্ক হয়ে গেছে — দ্রুত লক্ষ্য শেষ করুন।", Color(1.0, 0.35, 0.25))
	AudioManager.play_2d("sfx_alarm", -5.0)
	for i in 2:
		var spec := {"pos": sp + Vector3(randf_range(-18, 18), 0, randf_range(-18, 18)), "kind": "rifle", "assault": pos}
		spawn_enemy(spec)
	if float(data.get("alarm_limit", 0.0)) > 0.0:
		alarm_deadline = mission_time + float(data["alarm_limit"])


func on_player_damaged(dmg: float, from_pos: Vector3) -> void:
	hud.damage(dmg, from_pos)

func on_player_died() -> void:
	get_tree().create_timer(2.0).timeout.connect(func(): fail("অপারেশন ব্যর্থ — অপারেটিভ নিহত।"))

func on_player_downed() -> void:
	hud.notify("আপনি আহত! দ্রুত নিরাপদ আশ্রয় নিন।", Color(1.0, 0.7, 0.4))

func on_enemy_died(enemy: Node, _killer: Node) -> void:
	var tag := str(enemy.get("tag"))
	if tag != "":
		killed_tags[tag] = int(killed_tags.get(tag, 0)) + 1
	var pos := (enemy as Node3D).global_position
	# Money is taken by the hero immediately. Ammunition and guns are loot that
	# can be sold back to any colony shopkeeper.
	var cash := 40 + randi() % 61
	if tag == "commander":
		cash += 150
	Game.add_money(cash, "শত্রুর অর্থ")
	var loot_rounds := 12 + randi() % 25
	var loot_gun := 1 if (tag == "commander" or randf() < 0.22) else 0
	Game.add_loot(loot_rounds, loot_gun)
	_spawn_drop("ammo", pos + Vector3(0.3, 0.3, 0.2))
	if loot_gun > 0:
		_spawn_drop("type56", pos + Vector3(-0.4, 0.3, 0.3))
	if randf() < 0.18:
		_spawn_drop("medkit", pos + Vector3(0.0, 0.3, -0.5))


func _spawn_drop(kind: String, pos: Vector3) -> void:
	var p := PickupScene.new()
	p.setup(kind)
	add_child(p)
	p.global_position = pos


func call_airstrike(at: Vector3, count: int) -> void:
	actors_root.add_child(AirstrikeScene.make(at, count))


func on_civilian_attacked(victim: Node, attacker: Node) -> void:
	# The white-clad protector only fights back when a civilian is harmed.
	if attacker == null or not is_instance_valid(attacker):
		return
	for p in get_tree().get_nodes_in_group("neutral_protector"):
		if not bool(p.get("alive")) or p.get("target") != null:
			continue
		p.set("target", attacker)
		p.set("last_known", (attacker as Node3D).global_position if attacker is Node3D else p.global_position)
		if p.has_method("_enter_combat"):
			p.call("_enter_combat")
	if hud != null:
		hud.notify("বেসামরিককে আক্রমণ! সাদা পোশাকীর রাগ পেল!", Color(1.0, 0.75, 0.4))


func on_civilian_died(victim: Node) -> void:
	# Enemies killing a resident raises the alarm — the hero is not blamed.
	if victim is Node3D:
		raise_alarm(victim, (victim as Node3D).global_position)
	if hud != null:
		hud.notify("বেসামরিক নিহত — শত্রুরা সতর্ক হয়েছে!", Color(1.0, 0.4, 0.35))

const PickupScene := preload("res://scripts/world/Pickup.gd")

func on_thermal(on: bool) -> void:
	RenderingServer.global_shader_parameter_set("thermal", 1.0 if on else 0.0)
	if thermal != null:
		thermal.set_on(on)
	if weather == null or weather.get("env") == null:
		return
	var env: Environment = weather.env
	if on:
		_bg_mode = env.background_mode
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.01, 0.01, 0.02)
	elif _bg_mode >= 0:
		env.background_mode = _bg_mode


func enemy_rids() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CollisionObject3D and e.is_alive():
			out.append((e as CollisionObject3D).get_rid())
	return out


func nearest_ammo(_pos: Vector3):
	return null

func house_block(point: Vector3, _from: Vector3) -> Vector3:
	return point

func water_surface_at(_pos: Vector3) -> float:
	return -INF

func on_vehicle_noise(pos: Vector3, speed: float) -> void:
	Game.noise(pos, 10.0 + speed * 1.5, "player")
