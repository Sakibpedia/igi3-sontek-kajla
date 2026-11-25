extends Node3D
## ONE interactable for every door in Sontek. Each frame it moves to the door
## nearest the hero, so all 1,500 buildings stay enterable without 1,500 nodes.

var doors: Array = []
var current: Dictionary = {}
var climbing := false
var climb_from := Vector3.ZERO
var climb_to := Vector3.ZERO
var climb_t := 0.0
var climb_player: Node = null
var saved_input := true
var scan_t := 0.0


static func make(all_doors: Array) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/DoorProxy.gd"))
	n.doors = all_doors
	return n


func _ready() -> void:
	add_to_group("interactables")


func _process(delta: float) -> void:
	if climbing and climb_player != null:
		climb_t += delta / 1.1
		var f: float = clampf(climb_t, 0.0, 1.0)
		var smooth: float = f * f * (3.0 - 2.0 * f)
		var pos: Vector3 = climb_from.lerp(climb_to, smooth)
		pos.y += sin(f * PI) * 0.25
		(climb_player as Node3D).global_position = pos
		if f >= 1.0:
			climbing = false
			climb_player.set("input_enabled", saved_input)
			climb_player = null
		return
	scan_t -= delta
	if scan_t > 0.0:
		return
	scan_t = 0.2
	current = {}
	var p := Game.player
	if p == null or doors.is_empty():
		return
	var pp: Vector3 = (p as Node3D).global_position
	var best := 2.6
	for d in doors:
		var dd: Dictionary = d
		var dist: float = pp.distance_to(dd.get("pos", Vector3.ZERO) as Vector3)
		if dist < best:
			best = dist
			current = dd
	if not current.is_empty():
		global_position = current.get("pos", Vector3.ZERO) as Vector3


func can_interact() -> bool:
	return not current.is_empty()


func prompt_text() -> String:
	if current.is_empty():
		return ""
	return "[E] " + str(current.get("label", "ভবনে প্রবেশ"))


func on_interact_pressed(player: Node) -> void:
	if current.is_empty() or player == null:
		return
	var stops: Array = current.get("stops", [])
	if stops.is_empty():
		return
	var pp: float = (player as Node3D).global_position.y
	var nearest := -1
	var best := 2.5
	for i in stops.size():
		var d: float = absf(float((stops[i] as Vector3).y) - pp)
		if d < best:
			best = d
			nearest = i
	var next_i: int = (nearest + 1) % (stops.size() + 1)
	var dest: Vector3
	if next_i == stops.size():
		dest = current.get("pos", Vector3.ZERO) as Vector3
		_notify("সিঁড়ি দিয়ে নেমে রাস্তায় ফিরে এলেন / down the stairs")
	else:
		dest = stops[next_i] as Vector3
		_notify("সিঁড়ি দিয়ে তলা " + Game.bn(next_i + 1) + " / up the stairs")
	# Smooth stair climb instead of an instant teleport.
	climbing = true
	climb_t = 0.0
	climb_player = player
	climb_from = (player as Node3D).global_position
	climb_to = dest
	saved_input = bool(player.get("input_enabled"))
	player.set("input_enabled", false)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


func _notify(msg: String) -> void:
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify(msg, Color(0.7, 0.95, 0.8))
