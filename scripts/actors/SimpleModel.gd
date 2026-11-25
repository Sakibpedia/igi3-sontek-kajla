extends Node3D
## Lightweight visual for neutral/gang actors: a few meshes instead of the
## ~40-node CharacterModel. Implements the same duck-typed methods EnemyAI uses.

var body: MeshInstance3D
var legs: Array = []
var arms: Array = []
var phase := 0.0
var base_color := Color(0.3, 0.35, 0.3)


func setup(_role: String, o: Dictionary = {}) -> void:
	base_color = Color(o.get("shirt", Color(0.3, 0.35, 0.3)))
	body = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.1
	body.mesh = cap
	body.position.y = 0.95
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.9
	body.material_override = mat
	add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.36
	head.mesh = sph
	head.position.y = 1.72
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.68, 0.52, 0.4)
	head.material_override = hmat
	add_child(head)
	for sx in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.12, 0.7, 0.13)
		leg.mesh = lb
		leg.position = Vector3(0.14 * sx, 0.42, 0)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.14, 0.16, 0.18)
		leg.material_override = lm
		add_child(leg)
		legs.append(leg)
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.1, 0.6, 0.1)
		arm.mesh = ab
		arm.position = Vector3(0.4 * sx, 1.2, 0)
		arm.material_override = lm
		add_child(arm)
		arms.append(arm)


func flash_hit() -> void:
	if body != null and body.material_override != null:
		(body.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.4, 0.35)


func set_tied(_v: bool) -> void:
	pass


func animate(d: float, s: float, _c: bool, _a: bool) -> void:
	if s < 0.2:
		return
	phase += d * 7.0
	var sw: float = sin(phase) * 0.5
	if legs.size() >= 2:
		(legs[0] as MeshInstance3D).rotation.x = sw
		(legs[1] as MeshInstance3D).rotation.x = -sw
	if arms.size() >= 2:
		(arms[0] as MeshInstance3D).rotation.x = -sw * 0.7
		(arms[1] as MeshInstance3D).rotation.x = sw * 0.7


func set_expression(_a: float, _b: float, _c: float, _d: float) -> void:
	pass


func muzzle_position() -> Vector3:
	return global_position + Vector3(0.3, 1.2, -0.4)


func die(_dir: Vector3) -> void:
	if body != null:
		body.rotation.x = PI * 0.5
		body.position.y = 0.35
