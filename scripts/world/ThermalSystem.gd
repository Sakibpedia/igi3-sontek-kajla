extends Node
## Thermal / x-ray vision: heat signatures remain visible THROUGH walls.
## PlayerController toggles it with T -> Game.level.on_thermal() -> this node.

var enabled := false
var _overlay: ColorRect = null
var _markers: Dictionary = {}


func set_on(on: bool) -> void:
	enabled = on
	RenderingServer.global_shader_parameter_set("thermal", 1.0 if on else 0.0)
	if not on:
		_clear_markers()
	if Game.level != null and Game.level.get("hud") != null:
		var hud = Game.level.get("hud")
		if hud.has_method("set_thermal"):
			hud.call("set_thermal", on)


func _clear_markers() -> void:
	for n in _markers.values():
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	_markers.clear()


func _process(_delta: float) -> void:
	if not enabled:
		return
	var p: Node3D = Game.player as Node3D
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var m: Label3D = _markers.get(e.get_instance_id(), null)
		if m == null or not is_instance_valid(m):
			m = Label3D.new()
			m.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
			m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			m.no_depth_test = true
			m.fixed_size = true
			m.pixel_size = 0.0024
			m.font_size = 36
			m.outline_size = 10
			m.text = "▲"
			(e as Node3D).add_child(m)
			_markers[e.get_instance_id()] = m
		m.position = Vector3(0, 1.9, 0)
		var hp := clampf(float(e.get("health")) / maxf(float(e.get("max_health")), 1.0), 0.0, 1.0)
		var angry := int(e.get("state")) == 3
		m.modulate = Color(1.0, 0.25, 0.2) if angry else Color(1.0 - hp * 0.7, 0.35 + hp * 0.65, 0.25)
		m.visible = p == null or (e as Node3D).global_position.distance_to(p.global_position) < 90.0
