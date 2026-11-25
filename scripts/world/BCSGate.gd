extends Node3D
## BCS-style gate (like the resident gates in SakibUnemployed): answer a general
## knowledge question correctly to fold the collapsible gate aside.

const BCSQuestions := preload("res://scripts/world/BCSQuestions.gd")

var gate_id := "gate"
var open := false
var _active := false
var _qidx := -1
var _q: Array = []
var _rng := RandomNumberGenerator.new()
var _bars: Node3D
var _body: StaticBody3D
var _prev_input := true


static func make(p_id: String, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/BCSGate.gd"))
	n.gate_id = p_id
	n.global_position = pos
	n.rotation.y = yaw
	return n


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("gates")
	_rng.randomize()
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.0, 2.6, 0.22)
	cs.shape = sh
	cs.position = Vector3(0, 1.3, 0)
	_body.add_child(cs)
	add_child(_body)
	_bars = Node3D.new()
	add_child(_bars)
	for i in 7:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 2.5, 0.09)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.44, 0.46)
		mat.metallic = 0.7
		mi.material_override = mat
		mi.position = Vector3(-1.35 + float(i) * 0.45, 1.25, 0)
		_bars.add_child(mi)
	for yy in [0.25, 2.35]:
		var mi2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(2.9, 0.09, 0.1)
		mi2.mesh = bm2
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(0.32, 0.34, 0.36)
		mat2.metallic = 0.7
		mi2.material_override = mat2
		mi2.position = Vector3(0, yy, 0)
		_bars.add_child(mi2)
	var lbl := Label3D.new()
	lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 22
	lbl.pixel_size = 0.0022
	lbl.outline_size = 8
	lbl.position = Vector3(0, 2.95, 0)
	lbl.modulate = Color(1.0, 0.85, 0.45)
	lbl.text = "[E] গেট — BCS প্রশ্ন"
	add_child(lbl)


func can_interact() -> bool:
	return not open and not _active


func prompt_text() -> String:
	return "[E] গেট খুলুন — BCS প্রশ্ন" if not open else "গেট খোলা আছে"


func on_interact_pressed(p: Node) -> void:
	if open or _active:
		return
	_prev_input = bool(p.get("input_enabled")) if p != null else true
	if p != null:
		p.set("input_enabled", false)
	_active = true
	_qidx = BCSQuestions.pick(_rng)
	_q = BCSQuestions.QUESTIONS[_qidx]
	if Game.level != null and Game.level.get("announcer") != null:
		Game.level.announcer.announce("bcs_gate")
	AudioManager.play_2d("sfx_mic_click", -8.0)
	_show_question()


func _show_question() -> void:
	if Game.level == null or Game.level.get("hud") == null:
		return
	var opts: Array = []
	for i in 4:
		opts.append([i + 1, str(_q[1][i])])
	Game.level.hud.show_orders("BCS গেট — " + str(_q[0]), opts)


func _input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var k := (event as InputEventKey).keycode
	var ans := -1
	if k == KEY_1:
		ans = 0
	elif k == KEY_2:
		ans = 1
	elif k == KEY_3:
		ans = 2
	elif k == KEY_4:
		ans = 3
	elif k == KEY_J:
		_cancel()
		return
	if ans < 0:
		return
	if ans == int(_q[2]):
		AudioManager.play_2d("sfx_mcq_right", -5.0)
		_correct()
	else:
		AudioManager.play_2d("sfx_mcq_wrong", -5.0)
		if Game.level != null and Game.level.hud != null:
			Game.level.hud.notify("ভুল উত্তর — আবার চেষ্টা করুন।", Color(1.0, 0.4, 0.35))
		var newq := BCSQuestions.pick(_rng, _qidx)
		_qidx = newq
		_q = BCSQuestions.QUESTIONS[newq]
		_show_question()


func _correct() -> void:
	_active = false
	open = true
	AudioManager.play_3d("sfx_door", global_position + Vector3(0, 1, 0), -2.0, 1.1, 28.0)
	if Game.level != null and Game.level.hud != null:
		Game.level.hud.hide_orders()
		Game.level.hud.notify("সঠিক উত্তর — গেট খুলে গেছে।", Color(0.5, 1.0, 0.6))
	if _body != null:
		_body.queue_free()
		_body = null
	var tw := create_tween()
	tw.tween_property(_bars, "scale:x", 0.16, 0.9)
	tw.parallel().tween_property(_bars, "position:x", -0.65, 0.9)
	if Game.level != null and Game.level.has_method("on_objective_action"):
		Game.level.call("on_objective_action", gate_id)
	_restore_input()


func _cancel() -> void:
	_active = false
	if Game.level != null and Game.level.hud != null:
		Game.level.hud.hide_orders()
	_restore_input()


func _restore_input() -> void:
	var p := Game.player
	if p != null:
		p.set("input_enabled", _prev_input)
