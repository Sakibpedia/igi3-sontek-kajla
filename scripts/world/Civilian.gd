extends CharacterBody3D
## An ordinary Sontek resident. Walks the lanes, can be wounded or killed by
## the hero's bullets/grenades and by enemy fire. Civilians are not enemies and
## cannot be targeted by AI, but they are damageable "actors".

const MAX_HEALTH := 70.0

var health := MAX_HEALTH
var alive := true
var patrol: Array = []
var target_index := 0
var wait_time := 0.0
var body_mesh: MeshInstance3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var arm_l: MeshInstance3D
var arm_r: MeshInstance3D
var walk_phase := 0.0
var tick := 0


func setup(pos: Vector3, yaw: float, p_patrol: Array) -> void:
	position = pos
	rotation.y = yaw
	patrol = p_patrol.duplicate(true)


func _ready() -> void:
	add_to_group("civilians")
	add_to_group("actors")
	collision_layer = Game.L_FRIEND
	collision_mask = Game.L_WORLD
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.85
	add_child(col)

	body_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.05
	body_mesh.mesh = cap
	body_mesh.position.y = 0.95
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55 + randf() * 0.35, 0.38 + randf() * 0.3, 0.3 + randf() * 0.3)
	mat.roughness = 0.95
	body_mesh.material_override = mat
	add_child(body_mesh)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.19
	sph.height = 0.38
	head.mesh = sph
	head.position.y = 1.72
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.72, 0.55, 0.42)
	head.material_override = hmat
	add_child(head)
	# Simple 3D limbs + a face so the population reads as people, not capsules.
	leg_l = _limb(Vector3(-0.14, 0.42, 0), Vector3(0.12, 0.72, 0.13), Color(0.18, 0.2, 0.26))
	leg_r = _limb(Vector3(0.14, 0.42, 0), Vector3(0.12, 0.72, 0.13), Color(0.18, 0.2, 0.26))
	arm_l = _limb(Vector3(-0.4, 1.22, 0), Vector3(0.1, 0.6, 0.1), mat.albedo_color)
	arm_r = _limb(Vector3(0.4, 1.22, 0), Vector3(0.1, 0.6, 0.1), mat.albedo_color)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.03
		eye.mesh = es
		eye.position = Vector3(0.07 * sx, 1.75, -0.17)
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.08, 0.06, 0.05)
		eye.material_override = em
		add_child(eye)
	if patrol.is_empty():
		patrol = [position, position + Vector3(4, 0, 2)]


func _limb(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	var lm := StandardMaterial3D.new()
	lm.albedo_color = col
	m.material_override = lm
	add_child(m)
	return m


func _animate(delta: float) -> void:
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.2
	if moving:
		walk_phase += delta * 7.0
	var sw: float = sin(walk_phase) * 0.5 if moving else 0.0
	if leg_l != null:
		leg_l.rotation.x = sw
		leg_r.rotation.x = -sw
		arm_l.rotation.x = -sw * 0.7
		arm_r.rotation.x = sw * 0.7
	if body_mesh != null and moving:
		body_mesh.position.y = 0.95 + absf(sin(walk_phase)) * 0.04


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# Half-rate updates: 200 civilians must not eat the frame budget.
	tick += 1
	if tick % 2 == 1:
		return
	delta *= 2.0
	_animate(delta)
	if Game.player == null:
		return
	if Game.player.global_position.distance_to(global_position) > 90.0:
		return
	if wait_time > 0.0:
		wait_time -= delta
		velocity = Vector3.ZERO
		return
	var dst: Vector3 = patrol[target_index % patrol.size()]
	var flat := Vector3(dst.x - global_position.x, 0.0, dst.z - global_position.z)
	if flat.length() < 1.2:
		target_index += 1
		wait_time = randf_range(1.0, 3.0)
		return
	var dir := flat.normalized()
	velocity.x = dir.x * 1.25
	velocity.z = dir.z * 1.25
	rotation.y = atan2(-dir.x, -dir.z)
	move_and_slide()


func take_damage(amount: float, from: Vector3, attacker: Node) -> void:
	if not alive:
		return
	health -= amount
	if Game.level != null and Game.level.has_method("on_civilian_attacked"):
		Game.level.call("on_civilian_attacked", self, attacker)
	if body_mesh != null:
		body_mesh.material_override.albedo_color = Color(1.0, 0.35, 0.3)
	health = maxf(health, -1.0)
	if health <= 0.0:
		die(attacker)


func is_alive() -> bool:
	return alive


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.1, 0)


func is_headshot(pos: Vector3) -> bool:
	return pos.y > global_position.y + 1.45


func die(killer: Node) -> void:
	if not alive:
		return
	alive = false
	remove_from_group("actors")
	remove_from_group("civilians")
	var player_killed: bool = killer != null and killer.is_in_group("player")
	if player_killed:
		Game.add_score(-200, "বেসামরিক নিহত")
		if Game.level != null and Game.level.get("hud") != null:
			Game.level.hud.notify("বেসামরিক নিহত! অ্যালার্ম বাড়তে পারে।", Color(1.0, 0.4, 0.35))
	elif Game.level != null and Game.level.has_method("on_civilian_died"):
		Game.level.call("on_civilian_died", self)
	if body_mesh != null:
		body_mesh.rotation.x = PI * 0.5
		body_mesh.position.y = 0.35
	set_physics_process(false)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 20.0
	t.timeout.connect(queue_free)
	add_child(t)
	t.start()
