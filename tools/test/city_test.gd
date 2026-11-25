extends Node
## Headless verification of the dense Sontek colony city.
var mission: Node
var t := 0.0
var reported := false

func _ready() -> void:
	Game.settings["tts"] = false
	mission = (load("res://scenes/missions/M01.tscn") as PackedScene).instantiate()
	add_child(mission)

func _process(delta: float) -> void:
	t += delta
	if t > 180.0:
		print("[CITY] FAIL timeout")
		get_tree().quit(1)
	if mission == null or not bool(mission.get("running")) or reported or t < 3.0:
		return
	reported = true
	var lay: Dictionary = mission.get("layout")
	var houses: Array = lay.get("houses", [])
	var max_floors := 0
	for h in houses:
		max_floors = maxi(max_floors, int((h as Dictionary).get("floors", 0)))
	var shops := get_tree().get_nodes_in_group("interactables").filter(func(n): return n is Node and n.has_method("prompt_text") and str(n.get("kind")) in ["shop", "pharmacy"])
	var civs := get_tree().get_nodes_in_group("civilians")
	var pharmacies := shops.filter(func(n): return str(n.get("kind")) == "pharmacy")
	var lifts := get_tree().get_nodes_in_group("interactables").filter(func(n): return n.has_method("prompt_text") and str(n.prompt_text()).begins_with("[E] লিফট"))
	var lift_stops := 0
	for h in houses:
		lift_stops += (h as Dictionary).get("lifts", []).size()
	print("[CITY] buildings=%d houses=%d max_floors=%d shops=%d pharmacies=%d civilians=%d lifts=%d lift_stops=%d" % [
		int(lay.get("buildings", 0)), houses.size(), max_floors, shops.size(), pharmacies.size(), civs.size(), lifts.size(), lift_stops])
	var wins := get_tree().get_nodes_in_group("interactables").filter(func(n): return n.has_method("prompt_text") and str(n.prompt_text()).begins_with("[E] জানালা"))
	print("[CITY] windows=%d" % wins.size())
	var mass: Array = lay.get("mass_walkins", [])
	var all_windows := wins.size()
	for m in mass:
		all_windows += (m as Dictionary).get("windows", []).size()
	print("[CITY] mass_walkins=%d all_windows=%d" % [mass.size(), all_windows])
	var ok := mass.size() >= 1400 and all_windows >= 1400 and houses.size() >= 6 and max_floors >= 15 and shops.size() >= 30 and civs.size() >= 24 and lifts.size() >= 6
	print("[CITY] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
