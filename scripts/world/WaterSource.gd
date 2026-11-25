extends Node3D
## Public water point - a green hand-pump tube-well on a concrete apron, the kind found on every
## Dhaka street corner. Hold E to fill the Freelancer's bottle (3 drinks).
## Two-person job (Phase 3): one pumps the handle, the other holds the bottle under the spout. With an
## Alpha member within 25 m she / he comes over and pumps (1.5 s); alone it takes much longer (5 s).

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")
const FILL_TIME := 1.5
const SOLO_TIME := 5.0
var _helper: Node3D = null
var _hint_t := 0.0

var _progress := 0.0
var _label: Label3D
var _handle: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("water_sources")
	var concrete := CharacterModel.mat(Color(0.55, 0.54, 0.5), 0.95)
	var green := CharacterModel.mat(Color(0.12, 0.34, 0.2), 0.45)
	var iron := CharacterModel.mat(Color(0.16, 0.17, 0.17), 0.4)
	_mesh(BoxMesh.new(), Vector3(1.3, 0.1, 1.3), Vector3(0, 0.05, 0), concrete)
	_mesh(BoxMesh.new(), Vector3(0.5, 0.06, 0.5), Vector3(0, 0.13, 0.25), CharacterModel.mat(Color(0.4, 0.4, 0.38), 0.9))
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.09
	post.height = 0.9
	_mesh(post, Vector3.ONE, Vector3(0, 0.55, 0), green)
	var head := CylinderMesh.new()
	head.top_radius = 0.1
	head.bottom_radius = 0.1
	head.height = 0.22
	_mesh(head, Vector3.ONE, Vector3(0, 1.08, 0), green)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.025
	spout.bottom_radius = 0.03
	spout.height = 0.28
	var sp := _mesh(spout, Vector3.ONE, Vector3(0, 0.82, 0.16), green)
	sp.rotation.x = PI * 0.5
	_handle = Node3D.new()
	_handle.position = Vector3(0, 1.15, -0.08)
	add_child(_handle)
	var arm := _mesh(BoxMesh.new(), Vector3(0.04, 0.04, 0.75), Vector3(0, 0, -0.36), iron)
	_handle.add_child(arm)
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "টিউবওয়েল — পানি"
	_label.font_size = 36
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.modulate = Color(0.5, 0.85, 1.0)
	_label.position = Vector3(0, 1.6, 0)
	_label.visibility_range_end = 28.0
	add_child(_label)
	var col := StaticBody3D.new()
	col.collision_layer = Game.L_WORLD
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.12
	cy.height = 1.2
	cs.shape = cy
	cs.position = Vector3(0, 0.6, 0)
	col.add_child(cs)
	add_child(col)


func _mesh(m: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if m is BoxMesh:
		(m as BoxMesh).size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func can_interact() -> bool:
	var p := Game.player
	return p != null and int(p.get("water")) < 3


func prompt_text() -> String:
	var p := Game.player
	return "[E] চেপে ধরে রাখুন — বোতলে পানি ভরুন (%s/৩)" % Game.bn(int(p.get("water")) if p != null else 0)


func progress() -> float:
	return _progress / (FILL_TIME if _helper_ready() else SOLO_TIME)


func _helper_ready() -> bool:
	return _helper != null and is_instance_valid(_helper) and _helper.global_position.distance_to(global_position) < 2.4


func on_interact_pressed(_player: Node) -> void:
	pass


func on_interact_held(player: Node, holding: bool, delta: float) -> void:
	_hint_t -= delta
	if holding:
		if _helper == null or not is_instance_valid(_helper):
			_call_helper()
		var helped := _helper_ready()
		if helped:
			_helper.velocity = Vector3.ZERO
			_helper.set("crouching", false)
			var to := global_position - _helper.global_position
			_helper.rotation.y = atan2(-to.x, -to.z)
		_progress += delta
		_t += delta * (9.0 if helped else 4.5)
		_handle.rotation.x = sin(_t) * 0.35
		if int(_t / PI) != int((_t - delta * (9.0 if helped else 4.5)) / PI):
			AudioManager.play_3d("sfx_pump", global_position + Vector3(0, 1.0, 0), -10.0, randf_range(0.9, 1.1), 18.0)
		if not helped and _hint_t <= 0.0:
			_hint_t = 6.0
			AudioManager.say("", "একা চাপতে সময় লাগে — একজন হাতল চাপলে আরেকজন বোতল ধরে। কাছে কোনো আলফা সদস্য থাকলে তিনি আসবেন।", 3.2)
		if _progress >= (FILL_TIME if helped else SOLO_TIME):
			_progress = 0.0
			if helped:
				_release_helper()
			if player.has_method("refill_water"):
				player.refill_water()
			AudioManager.play_3d("sfx_water_fill", global_position + Vector3(0, 0.8, 0), -2.0)
			if Game.level != null and Game.level.get("hud") != null:
				Game.level.hud.notify("বোতল ভর্তি — ৩ বার পানি দেওয়া যাবে", Color(0.5, 0.85, 1.0))
	else:
		_progress = maxf(_progress - delta * 2.0, 0.0)


## The nearest free Alpha member walks over to work the handle.
func _call_helper() -> void:
	var best: Node3D = null
	var bd := 25.0
	for a in get_tree().get_nodes_in_group("allies"):
		if not a.is_alive() or a.get("role") != "ally" or a.get("carrying") != null or a.get("attend_target") != null:
			continue
		var d := (a as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = a
	# Phase 3h: a companion walking with the Freelancer can work the handle too
	for h in get_tree().get_nodes_in_group("hostages"):
		if not h.is_alive() or int(h.get("state")) != 8:   # Hostage.State.FOLLOW
			continue
		var dh := (h as Node3D).global_position.distance_to(global_position)
		if dh < bd:
			bd = dh
			best = h
	if best == null:
		return
	_helper = best
	best.set("hold_pos", global_position + global_transform.basis.x * 0.7)
	best.set("holding", true)
	if best.is_in_group("hostages"):
		AudioManager.say(str(best.get("name_bn")), "আমি হাতল চাপছি — আপনি বোতল ধরুন।", 2.2, float(best.get("voice_pitch")))
		Game.stats["well_helper"] = int(Game.stats.get("well_helper", 0)) + 1
	else:
		AudioManager.say(str(best.get("callsign")), "আমি হাতল চাপছি, স্যার — আপনি বোতল ধরুন।", 2.4, 1.25 if bool(best.get("female")) else 0.9)


func _release_helper() -> void:
	if _helper != null and is_instance_valid(_helper):
		_helper.set("holding", false if _helper.is_in_group("hostages") else (bool(Game.level.get("team_hold")) if Game.level != null else false))
	_helper = null
