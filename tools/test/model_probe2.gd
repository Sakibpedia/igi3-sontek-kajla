extends SceneTree

func _init():
	for f in ["car", "pickup"]:
		var ps := load("res://assets/models/%s.glb" % f) as PackedScene
		var n := ps.instantiate()
		print("[P] ", f, " root=", n.name)
		for c in n.find_children("*", "", true, false):
			var extra := ""
			if c is MeshInstance3D:
				var mi := c as MeshInstance3D
				extra = " mesh=" + str(mi.mesh) + (" aabb=" + str(mi.mesh.get_aabb().size) if mi.mesh != null else "")
			print("   ", c.name, " [", c.get_class(), "]", extra)
	quit()
