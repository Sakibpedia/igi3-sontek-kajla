extends Node3D
## Pooled visual effects: bullet impacts, bullet holes, tracers, muzzle lights, explosions.

const IMPACT_POOL := 14
const HOLE_POOL := 60
const TRACER_POOL := 18
const LIGHT_POOL := 4

const MAT_COLORS := {
	"concrete": Color(0.75, 0.72, 0.66), "brick": Color(0.7, 0.4, 0.3), "metal": Color(1.0, 0.85, 0.4),
	"wood": Color(0.55, 0.38, 0.2), "glass": Color(0.8, 0.9, 1.0), "cloth": Color(0.7, 0.7, 0.6),
	"flesh": Color(0.45, 0.02, 0.02), "water": Color(0.85, 0.9, 0.95),
}

var _impacts: Array = []
var _holes: Array = []
var _tracers: Array = []
var _tracer_until: Array = []
var _lights: Array = []
var _light_until: Array = []
var _ni := 0
var _nh := 0
var _nt := 0
var _nl := 0
var _clock := 0.0


func _ready() -> void:
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.vertex_color_use_as_albedo = true
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.035, 0.035, 0.035)
	pmesh.material = pmat
	for i in IMPACT_POOL:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 10
		p.lifetime = 0.45
		p.explosiveness = 1.0
		p.spread = 40.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 4.5
		p.gravity = Vector3(0, -9.8, 0)
		p.mesh = pmesh
		p.local_coords = false
		add_child(p)
		_impacts.append(p)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.03, 0.03, 0.03)
	hmat.roughness = 1.0
	var hmesh := QuadMesh.new()
	hmesh.size = Vector2(0.09, 0.09)
	hmesh.material = hmat
	for i in HOLE_POOL:
		var h := MeshInstance3D.new()
		h.mesh = hmesh
		h.visible = false
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h)
		_holes.append(h)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(1.0, 0.85, 0.45)
	var tmesh := BoxMesh.new()
	tmesh.size = Vector3(0.018, 0.018, 1.0)
	tmesh.material = tmat
	for i in TRACER_POOL:
		var tr := MeshInstance3D.new()
		tr.mesh = tmesh
		tr.visible = false
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tr)
		_tracers.append(tr)
		_tracer_until.append(0.0)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.omni_range = 5.0
		l.light_energy = 2.5
		l.light_color = Color(1.0, 0.75, 0.4)
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
		_light_until.append(0.0)


func _process(delta: float) -> void:
	_clock += delta
	for i in TRACER_POOL:
		var tr: MeshInstance3D = _tracers[i]
		if tr.visible and _clock > float(_tracer_until[i]):
			tr.visible = false
	for i in LIGHT_POOL:
		var l: OmniLight3D = _lights[i]
		if l.visible and _clock > float(_light_until[i]):
			l.visible = false


func impact(pos: Vector3, normal: Vector3, mat: String) -> void:
	var p: CPUParticles3D = _impacts[_ni]
	_ni = (_ni + 1) % IMPACT_POOL
	p.global_position = pos + normal * 0.03
	p.direction = normal if normal.length() > 0.1 else Vector3.UP
	p.color = MAT_COLORS.get(mat, Color(0.7, 0.7, 0.7))
	p.restart()
	if mat != "flesh" and mat != "water" and normal.length() > 0.1:
		var h: MeshInstance3D = _holes[_nh]
		_nh = (_nh + 1) % HOLE_POOL
		var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
		h.global_transform = Transform3D(Basis.looking_at(-normal, up), pos + normal * 0.012)
		h.visible = true
	var snd := "sfx_hit" if mat == "flesh" else ("sfx_ricochet" if mat == "metal" and randf() < 0.4 else "sfx_impact")
	AudioManager.play_3d(snd, pos, -8.0, randf_range(0.85, 1.15), 40.0)


func tracer(from: Vector3, to: Vector3) -> void:
	var d := to - from
	var length := d.length()
	if length < 1.0:
		return
	var tr: MeshInstance3D = _tracers[_nt]
	_tracer_until[_nt] = _clock + 0.06
	_nt = (_nt + 1) % TRACER_POOL
	var dir := d / length
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
	var b := Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0, 1.0, minf(length, 60.0)))
	var mid := from + dir * minf(length, 60.0) * 0.5
	tr.global_transform = Transform3D(b, mid)
	tr.visible = true


func muzzle_light(pos: Vector3) -> void:
	var l: OmniLight3D = _lights[_nl]
	_light_until[_nl] = _clock + 0.05
	_nl = (_nl + 1) % LIGHT_POOL
	l.global_position = pos
	l.visible = true


func explosion(pos: Vector3, radius: float, damage: float, source: Node) -> void:
	var p := CPUParticles3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.4, 0.4)
	mesh.material = m
	p.mesh = mesh
	p.amount = 60
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 2.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3))
	grad.set_color(1, Color(0.1, 0.1, 0.1))
	p.color_ramp = grad
	add_child(p)
	p.global_position = pos
	p.emitting = true
	var l := OmniLight3D.new()
	l.omni_range = radius * 3.0
	l.light_energy = 8.0
	l.light_color = Color(1.0, 0.6, 0.2)
	add_child(l)
	l.global_position = pos + Vector3(0, 2, 0)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 1.2)
	tw.tween_callback(l.queue_free)
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
	AudioManager.play_3d("sfx_explosion", pos, 6.0, randf_range(0.9, 1.05), 400.0)
	AudioManager.play_3d("sfx_explosion_tail", pos, 0.0, randf_range(0.9, 1.05), 500.0)
	for n in get_tree().get_nodes_in_group("actors"):
		var a: Node3D = n as Node3D
		if a == null or not a.has_method("take_damage"):
			continue
		var dist := a.global_position.distance_to(pos)
		if dist < radius:
			a.take_damage(damage * (1.0 - dist / radius), pos, source)
	if Game.player != null and Game.player.has_method("shake"):
		var pd: float = (Game.player as Node3D).global_position.distance_to(pos)
		Game.player.shake(clampf(1.0 - pd / (radius * 6.0), 0.0, 1.0))
