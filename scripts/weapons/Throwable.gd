extends RigidBody3D
## Thrown / planted explosives (Phase 3).
##   grenade - frag grenade, 3.2 s fuse after the throw, 7 m blast.
##   molotov - glass bottle of fuel with a burning rag: shatters on impact and leaves a pool of fire
##             (3.5 m, 9 s) that burns anyone standing in it and lights up the area.
##   bomb    - time bomb planted on the ground (key 6): 10 s countdown with beeps, 9 m blast.
## All of them are loud: every gunman within earshot comes to look.

var kind := "grenade"
var source: Node = null
var _fuse := 3.2
var _armed := true
var _beep_t := 0.0
var _fire_t := -1.0
var _fire_pos := Vector3.ZERO
var _fire_light: OmniLight3D
var _fire_fx: CPUParticles3D
var _burn_tick := 0.0
var _mesh: MeshInstance3D
var _hit := false


static func spawn(parent: Node, p_kind: String, pos: Vector3, vel: Vector3, p_source: Node) -> Node:
	var t: RigidBody3D = load("res://scripts/weapons/Throwable.gd").new()
	t.kind = p_kind
	t.source = p_source
	parent.add_child(t)
	t.global_position = pos
	t.linear_velocity = vel
	t.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)) if p_kind != "bomb" else Vector3.ZERO
	return t


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.L_WORLD
	mass = 0.5 if kind != "bomb" else 3.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.06 if kind == "grenade" else (0.07 if kind == "molotov" else 0.12)
	cs.shape = sh
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35 if kind == "grenade" else 0.05
	pm.friction = 0.8
	physics_material_override = pm
	_mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	match kind:
		"grenade":
			var sm := SphereMesh.new()
			sm.radius = 0.055
			sm.height = 0.13
			_mesh.mesh = sm
			m.albedo_color = Color(0.22, 0.26, 0.16)
			m.roughness = 0.6
			_fuse = 3.2
		"molotov":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.045
			cm.height = 0.24
			_mesh.mesh = cm
			m.albedo_color = Color(0.35, 0.55, 0.3, 0.75)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			_fuse = 12.0
			# burning rag at the neck
			var rag := OmniLight3D.new()
			rag.light_color = Color(1.0, 0.55, 0.2)
			rag.light_energy = 1.4
			rag.omni_range = 4.0
			rag.position = Vector3(0, 0.14, 0)
			add_child(rag)
		"bomb":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.26, 0.12, 0.18)
			_mesh.mesh = bm
			m.albedo_color = Color(0.15, 0.14, 0.12)
			_fuse = 10.0
			var led := OmniLight3D.new()
			led.light_color = Color(1, 0.1, 0.05)
			led.light_energy = 0.8
			led.omni_range = 1.5
			led.position = Vector3(0, 0.1, 0)
			add_child(led)
	_mesh.material_override = m
	add_child(_mesh)
	body_entered.connect(_on_body)


func _on_body(_b: Node) -> void:
	if kind == "molotov" and _armed and not _hit:
		_hit = true
		call_deferred("_shatter")
	elif kind == "grenade" and linear_velocity.length() > 2.0:
		AudioManager.play_3d("sfx_grenade_bounce", global_position, -8.0, randf_range(0.9, 1.1), 25.0)


func _physics_process(delta: float) -> void:
	if _fire_t >= 0.0:
		_burn(delta)
		return
	if not _armed:
		return
	_fuse -= delta
	if kind == "bomb":
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 1.0 if _fuse > 4.0 else (0.45 if _fuse > 1.5 else 0.15)
			AudioManager.play_3d("sfx_bomb_beep", global_position, -4.0, 1.0, 30.0)
	if _fuse <= 0.0:
		if kind == "molotov":
			_shatter()
		else:
			_explode()


func _explode() -> void:
	_armed = false
	var r := 7.0 if kind == "grenade" else 9.0
	var dmg := 160.0 if kind == "grenade" else 320.0
	if Game.level != null and Game.level.get("fx") != null:
		Game.level.fx.explosion(global_position + Vector3(0, 0.2, 0), r, dmg, source)
	Game.noise(global_position, 60.0, "player")
	queue_free()


func _shatter() -> void:
	if not _armed:
		return
	_armed = false
	freeze = true
	_fire_pos = global_position
	_mesh.visible = false
	for c in get_children():
		if c is OmniLight3D:
			c.queue_free()
	AudioManager.play_3d("sfx_glass_break", _fire_pos, 0.0, randf_range(0.9, 1.1), 40.0)
	AudioManager.play_3d("sfx_fire_whoosh", _fire_pos, 2.0, 1.0, 60.0)
	Game.noise(_fire_pos, 30.0, "player")
	_fire_t = 9.0
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.5, 0.15)
	_fire_light.light_energy = 3.5
	_fire_light.omni_range = 9.0
	add_child(_fire_light)
	_fire_light.position = Vector3(0, 1.0, 0)
	_fire_fx = CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.9)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = fm
	_fire_fx.mesh = qm
	_fire_fx.amount = 70
	_fire_fx.lifetime = 0.9
	_fire_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire_fx.emission_sphere_radius = 1.8
	_fire_fx.direction = Vector3.UP
	_fire_fx.spread = 15.0
	_fire_fx.initial_velocity_min = 1.0
	_fire_fx.initial_velocity_max = 2.6
	_fire_fx.gravity = Vector3(0, 1.5, 0)
	_fire_fx.scale_amount_min = 0.6
	_fire_fx.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.3, 0.9))
	g.set_color(1, Color(0.4, 0.05, 0.0, 0.0))
	_fire_fx.color_ramp = g
	add_child(_fire_fx)
	_fire_fx.position = Vector3(0, 0.3, 0)
	_fire_fx.emitting = true
	AudioManager.play_3d("sfx_fire_loop", _fire_pos, 0.0, 1.0, 35.0)


func _burn(delta: float) -> void:
	_fire_t -= delta
	if _fire_light != null:
		_fire_light.light_energy = 3.0 + sin(Time.get_ticks_msec() * 0.023) * 0.6 + randf() * 0.4
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		for n in get_tree().get_nodes_in_group("actors"):
			var a := n as Node3D
			if a == null or not a.has_method("take_damage"):
				continue
			var d := a.global_position.distance_to(_fire_pos)
			if d < 3.5:
				a.take_damage(14.0, _fire_pos, source)
				if a.is_in_group("enemies") and a.has_method("alert_to"):
					a.alert_to(_fire_pos)
	if _fire_t <= 0.0:
		queue_free()
