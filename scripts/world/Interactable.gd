extends Node3D
## Objective object the hero interacts with (E): laptops with intel, documents, fence cut points,
## tracker / explosive plant points. Hold-to-use when hold_time > 0.

signal completed(node: Node)

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")

var kind := "intel"
var prompt := "[E] তথ্য সংগ্রহ করুন"
var hold_time := 0.0
var done := false
var _progress := 0.0
var _glow: MeshInstance3D
var _label: Label3D
var _t := 0.0


func setup(p_kind: String, p_prompt: String, p_hold: float) -> void:
	kind = p_kind
	prompt = p_prompt
	hold_time = p_hold


func _ready() -> void:
	add_to_group("interactables")
	match kind:
		"intel":
			_box(Vector3(0.36, 0.025, 0.26), Vector3(0, 0.0125, 0), Color(0.15, 0.15, 0.17))
			var scr := _box(Vector3(0.36, 0.24, 0.02), Vector3(0, 0.13, 0.12), Color(0.1, 0.1, 0.12))
			scr.rotation.x = -0.25
			_glow = _box(Vector3(0.32, 0.2, 0.01), Vector3(0, 0.13, 0.108), Color(0.3, 0.8, 1.0))
			_glow.rotation.x = -0.25
		"documents":
			_box(Vector3(0.32, 0.05, 0.24), Vector3(0, 0.025, 0), Color(0.75, 0.6, 0.3))
			_glow = _box(Vector3(0.28, 0.01, 0.2), Vector3(0, 0.055, 0), Color(0.95, 0.95, 0.85))
		"fence":
			_glow = _box(Vector3(0.12, 0.6, 0.12), Vector3(0, 0.8, 0), Color(1.0, 0.6, 0.1))
		"device", "cache":
			_box(Vector3(0.9, 0.6, 0.6), Vector3(0, 0.3, 0), Color(0.25, 0.3, 0.18))
			_glow = _box(Vector3(0.2, 0.12, 0.1), Vector3(0, 0.66, 0), Color(1.0, 0.2, 0.1))
		_:
			_glow = _box(Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), Color(1.0, 0.8, 0.2))
	if _glow != null:
		var m: ShaderMaterial = (_glow.material_override as ShaderMaterial).duplicate()
		m.set_shader_parameter("emission_color", Color(1, 1, 1))
		m.set_shader_parameter("emission_energy", 0.6)
		_glow.material_override = m
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "◆"
	_label.font_size = 64
	_label.pixel_size = 0.005
	_label.modulate = Color(1.0, 0.85, 0.2)
	_label.outline_size = 8
	_label.position = Vector3(0, 0.9, 0)
	_label.no_depth_test = true
	_label.visibility_range_end = 18.0
	add_child(_label)


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = CharacterModel.mat(color, 0.5)
	mi.position = pos
	mi.layers = 2
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _label != null:
		_label.position.y = 0.9 + sin(_t * 3.0) * 0.06


func can_interact() -> bool:
	return not done and visible


func prompt_text() -> String:
	return prompt


func progress() -> float:
	return _progress / hold_time if hold_time > 0.0 else 0.0


func on_interact_pressed(_player: Node) -> void:
	if hold_time <= 0.0 and not done:
		_complete()


func on_interact_held(_player: Node, holding: bool, delta: float) -> void:
	if done or hold_time <= 0.0:
		return
	if holding:
		_progress += delta
		if _progress >= hold_time:
			_complete()
	else:
		_progress = maxf(_progress - delta * 2.0, 0.0)


func _complete() -> void:
	done = true
	remove_from_group("interactables")
	_label.visible = false
	AudioManager.play_2d("sfx_pickup", -3.0)
	completed.emit(self)
	if kind == "intel" or kind == "documents":
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tw.tween_callback(hide)
