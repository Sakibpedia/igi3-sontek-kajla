extends AnimatableBody3D
## Moving vehicle: escort police van (mission 5), extraction helicopter / speedboat props,
## and simple ambient traffic (rickshaws, buses) that loop along a path.

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")

signal destroyed(vehicle: Node)
signal arrived(vehicle: Node)

var kind := "van"
var path: Array = []
var speed := 5.0
var escort := false
var loop := false
var health := 1600.0
var max_health := 1600.0
var alive := true
var moving := false
var _i := 0
var _rotor: Node3D
var _t := 0.0


func setup(p_kind: String, p_path: Array, p_speed: float, p_escort: bool, p_loop: bool) -> void:
	kind = p_kind
	path = p_path
	speed = p_speed
	escort = p_escort
	loop = p_loop


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = CharacterModel.mat(color, 0.5)
	mi.position = pos
	mi.layers = 2
	(parent if parent != null else self).add_child(mi)
	return mi


func _ready() -> void:
	sync_to_physics = false
	collision_layer = Game.L_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	add_child(cs)
	cs.shape = bs
	match kind:
		"van":
			bs.size = Vector3(2.1, 2.3, 5.2)
			cs.position = Vector3(0, 1.25, 0)
			_box(Vector3(2.0, 1.5, 5.0), Vector3(0, 1.35, 0), Color(0.12, 0.2, 0.45))
			_box(Vector3(2.02, 0.35, 5.02), Vector3(0, 0.75, 0), Color(0.9, 0.9, 0.9))
			_box(Vector3(1.9, 0.6, 0.05), Vector3(0, 1.75, -2.51), Color(0.1, 0.12, 0.15))
			_box(Vector3(1.6, 0.15, 0.4), Vector3(0, 2.15, -1.2), Color(0.9, 0.1, 0.1))
			for x in [-0.95, 0.95]:
				for z in [-1.6, 1.6]:
					_box(Vector3(0.3, 0.7, 0.7), Vector3(x, 0.35, z), Color(0.05, 0.05, 0.05))
			var lbl := Label3D.new()
			lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
			lbl.text = "পুলিশ"
			lbl.font_size = 96
			lbl.pixel_size = 0.006
			lbl.position = Vector3(1.03, 1.45, 0)
			lbl.rotation.y = PI * 0.5
			lbl.modulate = Color(1, 1, 1)
			add_child(lbl)
			var lbl2: Label3D = lbl.duplicate()
			lbl2.position = Vector3(-1.03, 1.45, 0)
			lbl2.rotation.y = -PI * 0.5
			add_child(lbl2)
		"heli":
			bs.size = Vector3(2.4, 2.4, 9.0)
			cs.position = Vector3(0, 1.4, 0)
			_box(Vector3(2.2, 2.0, 4.2), Vector3(0, 1.4, 0), Color(0.15, 0.25, 0.18))
			_box(Vector3(0.5, 0.6, 4.5), Vector3(0, 1.8, 4.0), Color(0.15, 0.25, 0.18))
			_box(Vector3(0.12, 1.2, 0.8), Vector3(0, 2.4, 6.1), Color(0.15, 0.25, 0.18))
			_box(Vector3(2.0, 0.9, 0.05), Vector3(0, 1.8, -2.11), Color(0.2, 0.3, 0.4))
			_box(Vector3(0.12, 0.12, 3.6), Vector3(-0.9, 0.12, 0), Color(0.1, 0.1, 0.1))
			_box(Vector3(0.12, 0.12, 3.6), Vector3(0.9, 0.12, 0), Color(0.1, 0.1, 0.1))
			_rotor = Node3D.new()
			_rotor.position = Vector3(0, 2.55, 0)
			add_child(_rotor)
			_box(Vector3(11.0, 0.05, 0.35), Vector3.ZERO, Color(0.08, 0.08, 0.08), _rotor)
			_box(Vector3(0.35, 0.05, 11.0), Vector3.ZERO, Color(0.08, 0.08, 0.08), _rotor)
		"boat":
			bs.size = Vector3(2.4, 1.2, 7.0)
			cs.position = Vector3(0, 0.3, 0)
			_box(Vector3(2.4, 0.9, 7.0), Vector3(0, 0.2, 0), Color(0.9, 0.9, 0.92))
			_box(Vector3(2.45, 0.2, 7.05), Vector3(0, 0.55, 0), Color(0.1, 0.2, 0.55))
			_box(Vector3(1.8, 1.0, 1.8), Vector3(0, 1.1, 0.8), Color(0.85, 0.85, 0.85))
			_box(Vector3(1.6, 0.4, 0.05), Vector3(0, 1.35, -0.11), Color(0.15, 0.2, 0.3))
		"cng":
			bs.size = Vector3(1.4, 1.7, 2.4)
			cs.position = Vector3(0, 0.85, 0)
			var g := Color(0.12, 0.42, 0.2)
			_box(Vector3(1.4, 0.75, 2.2), Vector3(0, 0.62, 0.15), g)
			_box(Vector3(1.42, 0.08, 2.3), Vector3(0, 1.62, 0.2), g)
			for zx in [Vector3(-0.68, 1.2, 0.2), Vector3(0.68, 1.2, 0.2)]:
				_box(Vector3(0.05, 0.8, 0.05), zx + Vector3(0, 0, -0.9), Color(0.1, 0.1, 0.1))
				_box(Vector3(0.05, 0.8, 0.05), zx + Vector3(0, 0, 1.2), Color(0.1, 0.1, 0.1))
			_box(Vector3(1.2, 0.6, 0.05), Vector3(0, 1.25, -0.95), Color(0.55, 0.7, 0.75))
			_box(Vector3(0.5, 0.35, 0.45), Vector3(0, 0.45, -1.2), g)
			_box(Vector3(1.1, 0.14, 0.7), Vector3(0, 0.95, 0.75), Color(0.15, 0.12, 0.1))
			for wpos in [Vector3(-0.66, 0.24, 0.85), Vector3(0.66, 0.24, 0.85), Vector3(0, 0.24, -1.25)]:
				_box(Vector3(0.14, 0.48, 0.48), wpos, Color(0.05, 0.05, 0.05))
		"rickshaw":
			bs.size = Vector3(1.2, 1.8, 2.6)
			cs.position = Vector3(0, 0.9, 0)
			var hood: Array = [Color(0.85, 0.1, 0.25), Color(0.1, 0.45, 0.8), Color(0.95, 0.7, 0.1), Color(0.2, 0.6, 0.3)]
			var hc: Color = hood[randi() % hood.size()]
			_box(Vector3(1.1, 0.5, 0.9), Vector3(0, 0.75, 0.6), Color(0.15, 0.4, 0.6))
			_box(Vector3(1.15, 0.9, 0.9), Vector3(0, 1.4, 0.75), hc)
			_box(Vector3(0.08, 0.8, 0.8), Vector3(-0.55, 0.4, 0.6), Color(0.1, 0.1, 0.1))
			_box(Vector3(0.08, 0.8, 0.8), Vector3(0.55, 0.4, 0.6), Color(0.1, 0.1, 0.1))
			_box(Vector3(0.08, 0.6, 0.6), Vector3(0, 0.3, -0.9), Color(0.1, 0.1, 0.1))
			_box(Vector3(0.1, 0.1, 1.4), Vector3(0, 0.55, -0.3), Color(0.3, 0.3, 0.32))
			_box(Vector3(0.3, 0.1, 0.25), Vector3(0, 1.0, -0.8), Color(0.2, 0.15, 0.1))
		"bus":
			bs.size = Vector3(2.6, 3.0, 10.5)
			cs.position = Vector3(0, 1.6, 0)
			var bc: Array = [Color(0.75, 0.12, 0.1), Color(0.15, 0.45, 0.25), Color(0.85, 0.65, 0.12)]
			var c: Color = bc[randi() % bc.size()]
			_box(Vector3(2.5, 2.4, 10.4), Vector3(0, 1.75, 0), c)
			_box(Vector3(2.52, 0.8, 9.6), Vector3(0, 2.2, 0.2), Color(0.15, 0.2, 0.25))
			_box(Vector3(2.52, 0.3, 10.42), Vector3(0, 0.9, 0), Color(0.9, 0.9, 0.85))
			for z in [-3.5, 3.5]:
				for x in [-1.2, 1.2]:
					_box(Vector3(0.3, 0.9, 0.9), Vector3(x, 0.45, z), Color(0.05, 0.05, 0.05))
	if escort:
		add_to_group("escort_vehicle")
		max_health = 1600.0
		health = max_health
	if path.size() > 0:
		global_position = path[0]
		if path.size() > 1:
			_face(path[1])
		_i = 1


func _face(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		global_rotation.y = atan2(-d.x, -d.z)


func is_alive() -> bool:
	return alive


func is_targetable() -> bool:
	return alive and escort


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.4, 0)


func bullet_hit(dmg: float, _pos: Vector3, attacker: Node) -> void:
	if not escort or not alive:
		return
	if attacker != null and attacker.is_in_group("friendly"):
		return
	health -= dmg * 0.6
	if health <= 0.0:
		health = 0.0
		alive = false
		moving = false
		if Game.level != null and Game.level.get("fx") != null:
			Game.level.fx.explosion(global_position + Vector3(0, 1, 0), 5.0, 60.0, null)
		destroyed.emit(self)


func _physics_process(delta: float) -> void:
	_t += delta
	if _rotor != null:
		_rotor.rotation.y += delta * 18.0
	if not alive or path.size() < 2 or _i >= path.size():
		return
	if Game.level != null and not bool(Game.level.get("running")):
		return
	if escort:
		moving = _escort_can_move()
	else:
		moving = true
	if not moving:
		return
	var goal: Vector3 = path[_i]
	var to := goal - global_position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() < 0.6:
		_i += 1
		if _i >= path.size():
			if loop:
				_i = 0
				global_position = path[0]
			else:
				arrived.emit(self)
			return
		return
	var step := minf(speed * delta, flat.length())
	global_position += flat.normalized() * step
	global_position.y = lerpf(global_position.y, goal.y, clampf(delta * 2.0, 0.0, 1.0))
	var yaw := atan2(-flat.x, -flat.z)
	global_rotation.y = lerp_angle(global_rotation.y, yaw, clampf(delta * 3.0, 0.0, 1.0))


func _escort_can_move() -> bool:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p):
		return false
	if p.global_position.distance_to(global_position) > 24.0:
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if en != null and en.has_method("is_alive") and en.is_alive():
			if en.global_position.distance_to(global_position) < 20.0:
				return false
	return true
