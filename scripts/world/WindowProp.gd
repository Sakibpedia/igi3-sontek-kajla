extends Node3D
## A traversable window. Bullets already pass through the opening; E vaults the
## hero between the street side and the room side of the same window.

var outside := Vector3.ZERO
var inside := Vector3.ZERO


static func make(out_pos: Vector3, in_pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/WindowProp.gd"))
	n.position = out_pos
	n.outside = out_pos
	n.inside = in_pos
	return n


func _ready() -> void:
	add_to_group("interactables")
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.1, 0.1)
	frame.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.2, 0.14)
	frame.material_override = mat
	frame.position.y = 1.15
	add_child(frame)


func can_interact() -> bool:
	return true


func prompt_text() -> String:
	return "[E] জানালা দিয়ে ঝাঁপ দিন / climb through window"


func on_interact_pressed(player: Node) -> void:
	if player == null:
		return
	var pp: Vector3 = (player as Node3D).global_position
	var to_inside: bool = pp.distance_to(outside) <= pp.distance_to(inside)
	(player as Node3D).global_position = inside if to_inside else outside
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	AudioManager.play_2d("sfx_step1", -6.0, 1.2)
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("জানালা: " + ("ভেতরে" if to_inside else "বাইরে"), Color(0.8, 0.9, 0.7))
