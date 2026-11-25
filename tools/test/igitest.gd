extends Node
## Headless smoke test for all three IGI Sontek Kajla missions.
var mission: Node
var t := 0.0
var idx := 1
var reported := false
var fails := 0

func _ready() -> void:
	idx = int(OS.get_environment("MISSION") if OS.get_environment("MISSION") != "" else "6")
	Game.settings["tts"] = false
	# real Bengali voice bank adopts the proven TauntONomics raw-MP3 mechanism
	Speech.speak("অপারেশন সনটেক কাজলা শুরু। অপারেটিভ, কাজলা এলাকায় প্রবেশ করুন। শত্রুদের চোখ এড়িয়ে চলুন।")
	_ck(Speech.clip_count() > 0, "Bengali voice clip loads")
	mission = (load("res://scenes/missions/M%02d.tscn" % idx) as PackedScene).instantiate()
	add_child(mission)

func _ck(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("[IGI] FAIL M%d %s" % [idx, what])

func _process(delta: float) -> void:
	t += delta
	if t > 180.0:
		print("[IGI] FAIL M%d never started" % idx)
		get_tree().quit(1)
	if mission == null or not bool(mission.get("running")):
		return
	if reported or t < 2.0:
		return
	reported = true
	var lay: Dictionary = mission.get("layout")
	_ck(not (lay.is_empty()), "map loaded")
	_ck(int(lay.get("buildings", 0)) > 80, "OSM buildings present (%d)" % int(lay.get("buildings", 0)))
	_ck(get_tree().get_nodes_in_group("hostages").is_empty(), "no hostages in the game")
	_ck(get_tree().get_nodes_in_group("allies").is_empty(), "no Alpha team / allies")
	_ck(get_tree().get_nodes_in_group("enemies").size() >= 8, "guards spawned")
	_ck((mission.get("objectives") as Array).size() >= 2, "objectives present")
	_ck(mission.get("hud") != null, "HUD present")
	_ck(bool(mission.get("is_igi_mode")), "IGI mode")
	# houses must be reachable by hero and guards: inside, upper floor and roof
	var map: RID = (mission as Node3D).get_world_3d().navigation_map
	var house_list: Array = lay.get("houses", [])
	_ck(house_list.size() >= 4, "multi-floor houses built (%d)" % house_list.size())
	var spawn: Vector3 = lay.get("spawn", Vector3.ZERO)
	for h in house_list:
		for key in ["inside", "up", "roof"]:
			var target: Vector3 = (h as Dictionary).get(key, spawn)
			var q: Vector3 = NavigationServer3D.map_get_closest_point(map, target)
			_ck(q.distance_to(target) < 3.5, "%s navmesh reachable (%.1f m)" % [key, q.distance_to(target)])
			if key == "roof" and house_list.size() > 0 and h == house_list[0]:
				var path: PackedVector3Array = NavigationServer3D.map_get_path(map, spawn, target, false)
				_ck(path.size() > 1, "walking path from spawn to roof (%d pts)" % path.size())
	# complete every objective through the real objective hook
	var objs: Array = mission.get("objectives")
	for oi in objs.size():
		var o: Dictionary = objs[oi]
		var ty := str(o.get("type", ""))
		if ty in ["photo", "collect", "sabotage", "wiretap", "disable_alarm", "bcs_gate"]:
			for i in int(o.get("count", 1)):
				mission.call("on_objective_action", "o%d_%d" % [oi, i])
		elif ty == "eliminate":
			var tag := str(o.get("tag", "commander"))
			var killed := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if killed >= int(o.get("count", 1)):
					break
				if str(e.get("tag")) == tag and e.is_alive():
					mission.call("on_enemy_died", e, null)
					killed += 1
		elif ty in ["reach", "extract", "infiltrate", "survive"]:
			var p: Node3D = mission.get("player") as Node3D
			p.global_position = mission.call("_resolve_pos", o)
			if ty == "survive":
				mission.call("_update_objective", float(o.get("time", 25.0)) + 1.0)
		# let the objective machinery advance on the next frames
		for k in 3:
			mission.call("_update_objective", 0.016)
	_ck(mission.get("ended") == true or int(mission.get("obj_index")) >= objs.size() - 1,
		"final objective reached (idx=%d/%d progress=%s ended=%s)" % [int(mission.get("obj_index")), objs.size(), str(mission.get("_progress")), str(mission.get("ended"))])
	if fails == 0:
		print("[IGI] PASS M%d - %d buildings, %d objectives, no hostages" % [idx, int(lay.get("buildings", 0)), objs.size()])
		get_tree().quit(0)
	else:
		print("[IGI] %d failure(s)" % fails)
		get_tree().quit(1)
