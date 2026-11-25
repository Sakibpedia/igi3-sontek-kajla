extends CharacterBody3D
## PUBG-style drivable street vehicle: car, CNG, pickup or rickshaw.
## E to enter / exit, WASD to drive, Space handbrake.  Collides with the real
## Kajla buildings, so it can be used for patrols, getaways and road blocks.

var kind := "car"
var display_name := "Car"
var driver: Node = null
var speed := 0.0
var max_speed := 16.0
var _label: Label3D
var _cam: Camera3D
var _wheels: Array = []
var _t := 0.0


func setup(p_kind: String, pos: Vector3, yaw: float) -> void:
	kind = p_kind
	display_name = {"car": "Sedan", "cng": "CNG", "pickup": "Pickup", "rickshaw": "Rickshaw"}.get(kind, "Car")
	global_position = pos + Vector3(0, 0.1, 0)
	rotation.y = yaw
	add_to_group("interactables")
	add_to_group("vehicles")


func _ready() -> void:
	var sizes := {"car": Vector3(1.9, 1.35, 4.2), "cng": Vector3(1.8, 1.7, 3.9),
		"pickup": Vector3(2.1, 1.8, 5.0), "rickshaw": Vector3(1.5, 1.6, 2.6)}
	var sz: Vector3 = sizes.get(kind, sizes["car"])
	var cols := {"car": Color(0.75, 0.78, 0.8), "cng": Color(0.15, 0.55, 0.25),
		"pickup": Color(0.8, 0.3, 0.12), "rickshaw": Color(0.85, 0.65, 0.1)}
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	cs.position = Vector3(0, sz.y * 0.5, 0)
	add_child(cs)

	# Real CC0 3D vehicle models, scaled onto the collision box.
	var model_file: String = str({"car": "car.glb", "pickup": "pickup.glb", "cng": "cng.glb", "rickshaw": "rickshaw.glb"}.get(kind, "car.glb"))
	var ps := load("res://assets/models/" + str(model_file)) as PackedScene
	if ps != null:
		var vis := ps.instantiate() as Node3D
		var ab := AABB()
		var first := true
		for c in vis.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			var b := mi.mesh.get_aabb()
			b.position += mi.transform.origin
			if first:
				ab = b
				first = false
			else:
				ab = ab.merge(b)
		if first:
			ab.size = sz
		var scl := Vector3(sz.x / maxf(ab.size.x, 0.01), sz.y / maxf(ab.size.y, 0.01), sz.z / maxf(ab.size.z, 0.01))
		vis.scale = scl
		vis.position = -ab.position * scl + Vector3(0, 0.06, 0)
		add_child(vis)
	else:
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		body.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cols.get(kind, Color(0.7, 0.7, 0.7))
		body.material_override = mat
		body.position = Vector3(0, sz.y * 0.5, 0)
		add_child(body)

	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 22
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.position = Vector3(0, sz.y + 0.7, 0)
	_label.modulate = Color(0.5, 0.9, 1.0)
	add_child(_label)
	_refresh()

	_cam = Camera3D.new()
	_cam.name = "VehicleCamera"
	_cam.position = Vector3(0, sz.y * 0.9 + 0.4, -sz.z * 0.15)
	_cam.fov = 74.0
	_cam.current = false
	add_child(_cam)


func _refresh() -> void:
	if _label != null:
		_label.text = ("[E] Drive " + display_name) if driver == null else (display_name + " — [E] exit, WASD drive")


func can_interact() -> bool:
	return driver == null


func prompt_text() -> String:
	return "[E] " + ("Drive " + display_name if driver == null else "Exit vehicle")


func on_interact_pressed(p: Node) -> void:
	if driver == null:
		enter(p)
	else:
		exit()


func enter(p: Node) -> void:
	if driver != null or p == null:
		return
	driver = p
	speed = 0.0
	p.set("input_enabled", false)
	p.visible = false
	var pcam = p.get("camera")
	if pcam != null and is_instance_valid(pcam):
		pcam.current = false
	_cam.current = true
	_refresh()
	AudioManager.play_3d("sfx_engine_start", global_position, -6.0, 1.0, 20.0) if AudioManager.get_stream("sfx_engine_start") != null else AudioManager.play_3d("sfx_switch", global_position, -6.0, 0.8, 20.0)


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	speed = 0.0
	_cam.current = false
	var off := global_transform.basis * Vector3(1.7, 0, 0)
	p.global_position = global_position + off + Vector3(0, 0.2, 0)
	p.rotation.y = rotation.y
	p.visible = true
	p.set("input_enabled", true)
	var pcam = p.get("camera")
	if pcam != null and is_instance_valid(pcam):
		pcam.current = true
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if driver == null or not (event is InputEventKey):
		return
	if (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_E:
		exit()


func _physics_process(delta: float) -> void:
	_t += delta
	if driver == null:
		velocity = Vector3.ZERO
		return
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var brake := Input.is_action_pressed("crouch")
	var target := -inp.y * max_speed
	if brake:
		target = 0.0
	speed = move_toward(speed, target, delta * (10.0 if brake else 6.0))
	rotation.y -= inp.x * delta * 1.5 * clampf(absf(speed) / 4.0, 0.0, 1.0)
	var fwd := -global_transform.basis.z
	velocity = fwd * speed
	velocity.y -= 12.0 * delta
	move_and_slide()
	for w in _wheels:
		(w as Node3D).rotate_x(speed * delta * 3.0)
	if Game.level != null and Game.level.has_method("on_vehicle_noise") and absf(speed) > 3.0:
		Game.level.call("on_vehicle_noise", global_position, absf(speed))
