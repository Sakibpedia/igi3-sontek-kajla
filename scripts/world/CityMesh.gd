extends Node3D
## One MultiMeshInstance3D for the whole dense colony: every wall segment,
## floor slab and roof is a box instance, so 30,000 boxes cost one draw call
## and one scene node instead of tens of thousands of MeshInstance3D nodes.

static func make(specs: Array) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/CityMesh.gd"))
	n.build(specs)
	return n


func build(specs: Array) -> void:
	if specs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = specs.size()
	var t := Transform3D.IDENTITY
	for i in specs.size():
		var s: Dictionary = specs[i]
		var p: Vector3 = s["p"]
		var sz: Vector3 = s["s"]
		t = Transform3D(Basis.IDENTITY.scaled(sz), p)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, s.get("c", Color(0.5, 0.45, 0.4)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)
