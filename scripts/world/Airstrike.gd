extends Node3D
## Retaliatory air strike: a plane flies over the attacker and drops two bombs.
## A hero standing under a roof is sheltered and takes no bomb damage.

const Throwable := preload("res://scripts/weapons/Throwable.gd")

var target := Vector3.ZERO
var bombs_left := 2
var dropped := false
var silent := false
var plane: Node3D


static func make(at: Vector3, count: int) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/Airstrike.gd"))
	n.target = at
	n.bombs_left = count
	return n


func _ready() -> void:
	plane = Node3D.new()
	add_child(plane)
	_fuselage(Vector3(0, 0, 0), Vector3(9.0, 1.0, 1.1))
	_fuselage(Vector3(-0.4, 0.1, 0), Vector3(1.2, 0.2, 7.5))
	_fuselage(Vector3(-3.8, 0.7, 0), Vector3(1.0, 2.2, 0.16))
	_fuselage(Vector3(-3.9, 0, 0), Vector3(0.9, 0.14, 2.6))
	global_position = target + Vector3(-170.0, 58.0, 0.0)
	if not silent and Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("বिमান আসছে! আশ্রয় নিন!", Color(1.0, 0.55, 0.35))


func _fuselage(pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.2)
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	plane.add_child(mi)


func _process(delta: float) -> void:
	global_position.x += 46.0 * delta
	if not dropped and global_position.x >= target.x - 8.0:
		dropped = true
		_drop_bombs()
	if global_position.x > target.x + 150.0:
		queue_free()


func _has_roof(at: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, 0), at + Vector3(0, 7.0, 0), 1 | 32)
	return not world.direct_space_state.intersect_ray(q).is_empty()


func _drop_bombs() -> void:
	if bombs_left <= 0:
		return
	if _has_roof(target):
		if Game.level != null and Game.level.get("hud") != null:
			Game.level.hud.notify("বোমা এড়ালেন — আপনি আশ্রয়ে ছিলেন!", Color(0.5, 1.0, 0.6))
		return
	for i in bombs_left:
		var p: Vector3 = target + Vector3((float(i) - float(bombs_left - 1) * 0.5) * 3.5, 0.0, 0.0)
		Throwable.spawn(get_tree().root, "bomb", p + Vector3(0.0, 34.0, 0.0), Vector3(0.0, -6.0, 0.0), self)
		Game.noise(p, 80.0, "airforce")
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("বোমা পড়ল! দ্রুত সরে যান!", Color(1.0, 0.4, 0.3))
