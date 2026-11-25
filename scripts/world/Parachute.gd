extends Node3D
## Square ram-air style canopy with suspension lines, risers and a slight sway. Built from primitive
## meshes (no assets). Parachute.make() returns a node to put above a jumper's head (origin = harness).

const SPAN := 6.2
const CHORD := 2.6
const HEIGHT := 3.3

var _t := 0.0
var _canopy: Node3D


static func make() -> Node3D:
	var p: Node3D = load("res://scripts/world/Parachute.gd").new()
	p._build()
	return p


func _build() -> void:
	_canopy = Node3D.new()
	add_child(_canopy)
	_canopy.position = Vector3(0, HEIGHT, 0)
	var cells := 9
	var cols := [Color(0.85, 0.42, 0.12), Color(0.12, 0.2, 0.14), Color(0.85, 0.42, 0.12), Color(0.12, 0.2, 0.14), Color(0.9, 0.86, 0.75),
		Color(0.12, 0.2, 0.14), Color(0.85, 0.42, 0.12), Color(0.12, 0.2, 0.14), Color(0.85, 0.42, 0.12)]
	for i in cells:
		var u := (float(i) + 0.5) / float(cells) - 0.5
		# canopy arches down towards the wing tips
		var ang := u * 1.1
		var cell := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(SPAN / float(cells) * 1.02, 0.32, CHORD)
		cell.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i % cols.size()]
		m.roughness = 0.85
		cell.material_override = m
		cell.position = Vector3(sin(ang) * SPAN * 0.5 * 0.95, cos(ang) * 0.9 - 0.9, 0)
		cell.rotation = Vector3(0, 0, -ang)
		_canopy.add_child(cell)
		# two suspension lines per rib, front and back, gathering at the risers
		for z: float in [-CHORD * 0.4, CHORD * 0.35]:
			var top: Vector3 = _canopy.position + cell.position + Vector3(0, -0.16, z)
			var bottom := Vector3(signf(u) * 0.22, 1.05, 0.0)
			_line(bottom, top)
	# risers to the harness
	_line(Vector3(0.22, 1.05, 0), Vector3(0.2, 0.15, 0))
	_line(Vector3(-0.22, 1.05, 0), Vector3(-0.2, 0.15, 0))


func _line(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = a.distance_to(b)
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.8, 0.75)
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	var axis := Vector3.UP.cross(d)
	if axis.length() > 1e-4:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(d))
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	rotation.z = sin(_t * 0.9) * 0.05
	rotation.x = sin(_t * 0.7 + 1.0) * 0.04
	if _canopy != null:
		_canopy.scale = Vector3(1.0, 1.0 + sin(_t * 2.3) * 0.03, 1.0)
