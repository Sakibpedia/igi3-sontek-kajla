extends Node3D
## Police / RAB-style light helicopter for roof pickups (Phase 3 boss raids). Built from primitives:
## fuselage, cockpit glass, tail boom, fin, skids, a spinning two-blade main rotor and tail rotor.
## Flies in from far away, settles into a hover just above the pickup roof, waits, then leaves.

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")

signal arrived

var hover_point := Vector3.ZERO
var state := "approach"
var _rotor: Node3D
var _tail_rotor: Node3D
var _snd: AudioStreamPlayer3D
var _from := Vector3.ZERO
var _t := 0.0
var _leave_dir := Vector3.FORWARD


static func make() -> Node3D:
	return load("res://scripts/world/Helicopter.gd").new()


func _ready() -> void:
	var body := CharacterModel.mat(Color(0.12, 0.16, 0.14), 0.45)
	var stripe := CharacterModel.mat(Color(0.9, 0.85, 0.75), 0.5)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.35, 0.4, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	var dark := CharacterModel.mat(Color(0.05, 0.05, 0.05), 0.4)
	var fus := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.95
	cap.height = 4.4
	fus.mesh = cap
	fus.rotation.x = PI * 0.5
	fus.material_override = body
	add_child(fus)
	var cock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.5
	cock.mesh = sm
	cock.position = Vector3(0, 0.15, -1.75)
	cock.material_override = glass
	add_child(cock)
	_part(BoxMesh.new(), Vector3(0.25, 0.3, 4.6), Vector3(0, 0.25, 3.8), body)
	_part(BoxMesh.new(), Vector3(0.1, 1.2, 0.7), Vector3(0, 0.75, 5.9), body)
	_part(BoxMesh.new(), Vector3(1.94, 0.12, 2.2), Vector3(0, -0.1, 0.0), stripe)
	for sx: float in [-0.85, 0.85]:
		_part(BoxMesh.new(), Vector3(0.08, 0.08, 3.4), Vector3(sx, -1.3, 0.0), dark)
		for sz: float in [-0.9, 0.9]:
			_part(BoxMesh.new(), Vector3(0.06, 0.45, 0.06), Vector3(sx * 0.8, -1.05, sz), dark)
	_part(CylinderMesh.new(), Vector3(0.12, 0.5, 0.12), Vector3(0, 1.15, 0), dark)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.42, 0)
	add_child(_rotor)
	for a: float in [0.0, PI]:
		var blade := _part(BoxMesh.new(), Vector3(0.3, 0.04, 5.0), Vector3(0, 0, 2.5), dark, _rotor)
		blade.position = Vector3(sin(a) * 2.5, 0, cos(a) * 2.5)
		blade.rotation.y = a
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.18, 0.75, 6.1)
	add_child(_tail_rotor)
	_part(BoxMesh.new(), Vector3(0.03, 1.1, 0.12), Vector3.ZERO, dark, _tail_rotor)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 2.0
	light.omni_range = 14.0
	light.position = Vector3(0, -1.3, -1.5)
	add_child(light)
	_snd = AudioStreamPlayer3D.new()
	_snd.bus = "SFX"
	_snd.unit_size = 25.0
	_snd.max_distance = 400.0
	var s := AudioManager.get_stream("amb_heli")
	if s != null:
		AudioManager._loop(s)
		_snd.stream = s
	add_child(_snd)


func _part(m: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	if m is BoxMesh:
		(m as BoxMesh).size = size
	elif m is CylinderMesh:
		(m as CylinderMesh).top_radius = size.x
		(m as CylinderMesh).bottom_radius = size.x
		(m as CylinderMesh).height = size.y
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


## Comes in from `from` and hovers with its skids ~1.3 m above `point`.
func fly_in(from: Vector3, point: Vector3) -> void:
	_from = from
	hover_point = point + Vector3(0, 2.6, 0)
	global_position = from
	state = "approach"
	_t = 0.0
	if _snd.stream != null:
		_snd.play()


func leave() -> void:
	state = "leave"
	_t = 0.0
	_leave_dir = (_from - hover_point).normalized()


func _process(delta: float) -> void:
	_rotor.rotation.y += delta * 32.0
	_tail_rotor.rotation.x += delta * 60.0
	_t += delta
	match state:
		"approach":
			var to := hover_point - global_position
			var d := to.length()
			var flat := Vector3(to.x, 0, to.z)
			if flat.length() > 0.5:
				rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(delta * 1.5, 0.0, 1.0))
			global_position += to.normalized() * minf(d, clampf(d * 0.35, 3.0, 26.0) * delta)
			rotation.x = -clampf(d * 0.004, 0.0, 0.18)
			if d < 0.4:
				state = "hover"
				arrived.emit()
		"hover":
			rotation.x = lerpf(rotation.x, 0.0, delta * 2.0)
			global_position = hover_point + Vector3(sin(_t * 0.7) * 0.15, sin(_t * 1.1) * 0.12, cos(_t * 0.5) * 0.12)
		"leave":
			global_position += (_leave_dir * 18.0 + Vector3(0, 6.0, 0)) * delta
			rotation.x = lerpf(rotation.x, -0.2, delta)
			if _t > 14.0:
				queue_free()
