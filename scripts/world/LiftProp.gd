extends Node3D
## Lift call panel for a walk-in tower. Every floor (and the roof platform) has
## a stop; E moves the hero to the next stop. Stairs remain available as well.

var stops: Array = []

static func make(pos: Vector3, positions: Array) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/LiftProp.gd"))
	n.position = pos
	n.stops = positions.duplicate(true)
	return n


func _ready() -> void:
	add_to_group("interactables")
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.7, 0.14)
	panel.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.16, 0.14)
	panel.material_override = mat
	panel.position.y = 1.25
	add_child(panel)
	var btn := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	btn.mesh = sm
	var bmat := StandardMaterial3D.new()
	bmat.emission = Color(0.4, 1.0, 0.5)
	bmat.albedo_color = Color(0.4, 1.0, 0.5)
	btn.material_override = bmat
	btn.position = Vector3(0, 1.4, -0.09)
	add_child(btn)
	var lbl := Label3D.new()
	lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 22
	lbl.pixel_size = 0.002
	lbl.modulate = Color(0.6, 1.0, 0.7)
	lbl.position = Vector3(0, 2.0, 0)
	lbl.text = "LIFT / লিফট"
	add_child(lbl)


func can_interact() -> bool:
	return stops.size() > 1


func prompt_text() -> String:
	return "[E] লিফট — পরবর্তী তলা"


func on_interact_pressed(player: Node) -> void:
	if stops.size() < 2 or player == null:
		return
	var py: float = (player as Node3D).global_position.y
	var nearest := 0
	var best := INF
	for i in stops.size():
		var d: float = absf(float((stops[i] as Vector3).y) - py)
		if d < best:
			best = d
			nearest = i
	var next_i: int = (nearest + 1) % stops.size()
	(player as Node3D).global_position = stops[next_i] as Vector3
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	AudioManager.play_2d("sfx_switch", -8.0, 1.0)
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("লিফট: তলা " + Game.bn(next_i + 1) + " / " + Game.bn(stops.size()), Color(0.6, 1.0, 0.7))
