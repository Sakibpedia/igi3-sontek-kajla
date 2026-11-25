extends SceneTree

func _init():
	for f in ["car", "cng", "rickshaw", "pickup"]:
		var path := "res://assets/models/%s.glb" % f
		var ps := load(path) as PackedScene
		if ps == null:
			print("[MODEL] ", f, " LOAD FAIL")
			continue
		var n := ps.instantiate() as Node3D
		root.add_child(n)
		var ab := AABB()
		var first := true
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var b := mi.mesh.get_aabb()
			b.position += mi.global_position
			if first:
				ab = b
				first = false
			else:
				ab = ab.merge(b)
		print("[MODEL] %s size=%s pos=%s" % [f, str(ab.size.round()), str(ab.position.round())])
	quit()
