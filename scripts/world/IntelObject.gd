extends Node3D
## An IGI-style mission object: reconnaissance photo point, document cache,
## security terminal or demolition charge.  No hostages, no rescues.

var obj_id := ""
var label := ""
var kind := "photo"
var done := false
var _label: Label3D
var _mesh: MeshInstance3D
var _t := 0.0


func setup(p_id: String, p_kind: String, p_label: String, pos: Vector3) -> void:
	obj_id = p_id
	kind = p_kind
	label = p_label
	global_position = pos
	add_to_group("interactables")
	add_to_group("igi_objects")


func _ready() -> void:
	var body := BoxMesh.new()
	body.size = Vector3(0.55, 0.55, 0.35) if kind != "charge" else Vector3(0.4, 0.6, 0.25)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = body
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.45, 0.55) if kind == "photo" else (Color(0.8, 0.55, 0.1) if kind == "docs" else Color(0.75, 0.15, 0.12))
	if kind == "charge":
		mat.albedo_color = Color(0.85, 0.2, 0.12)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.9
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 0.85, 0)
	add_child(_mesh)

	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 24
	_label.pixel_size = 0.0025
	_label.outline_size = 8
	_label.position = Vector3(0, 1.6, 0)
	_label.modulate = Color(1.0, 0.88, 0.4)
	add_child(_label)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _mesh != null and not done:
		_mesh.rotation.y += delta * 0.8
		_mesh.position.y = 0.85 + sin(_t * 2.0) * 0.05


func _refresh() -> void:
	if _label == null:
		return
	_label.text = ("✓ " if done else "[E] ") + label
	_label.modulate = Color(0.4, 1.0, 0.55) if done else Color(1.0, 0.88, 0.4)


func can_interact() -> bool:
	return not done


func prompt_text() -> String:
	return ("✔ " if done else "[E] ") + label


func on_interact_pressed(_player: Node) -> void:
	if done:
		return
	done = true
	_refresh()
	if _mesh != null:
		var mat := _mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = 0.05
			mat.albedo_color = Color(0.25, 0.45, 0.3)
	AudioManager.play_3d("sfx_ui" if kind != "charge" else "sfx_switch", global_position, -4.0, 1.0, 20.0)
	if Game.level != null and Game.level.has_method("on_objective_action"):
		Game.level.call("on_objective_action", obj_id)
