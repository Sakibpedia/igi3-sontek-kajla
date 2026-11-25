extends Node3D
## Door of a batched colony building. E moves the hero through the doorway to
## the next floor and finally to the roof; another press returns to the street.

var stops: Array = []
var door_street := Vector3.ZERO


static func make(at: Vector3, floor_points: Array, roof: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/BuildingPortal.gd"))
	n.door_street = at
	n.stops = floor_points.duplicate(true)
	n.stops.append(roof)
	return n


func _ready() -> void:
	# No per-door mesh/material: 1,500 portals stay cheap (the batched city mesh
	# already draws the doorway). They only need to be in the interactable group.
	add_to_group("interactables")


func can_interact() -> bool:
	return true


func prompt_text() -> String:
	return "[E] ভবনে প্রবেশ / পরবর্তী তলা / ছাদ"


func on_interact_pressed(player: Node) -> void:
	if player == null or stops.is_empty():
		return
	var pp: Vector3 = (player as Node3D).global_position
	var nearest := -1
	var best := 2.2
	for i in stops.size():
		var d: float = absf(float((stops[i] as Vector3).y) - pp.y)
		if d < best:
			best = d
			nearest = i
	var next_i: int = (nearest + 1) % (stops.size() + 1)
	if next_i == stops.size():
		(player as Node3D).global_position = door_street
		_notify("রাস্তায় ফিরে এলেন")
	else:
		(player as Node3D).global_position = stops[next_i] as Vector3
		_notify("তলা " + Game.bn(next_i + 1))
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


func _notify(msg: String) -> void:
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify(msg, Color(0.7, 0.95, 0.8))
