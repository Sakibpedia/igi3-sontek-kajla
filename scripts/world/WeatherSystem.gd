extends Node3D
## Time of day + dynamic weather for Dhaka: monsoon rain, storms with lightning, winter fog,
## summer heat haze. Drives the environment, sun/moon, sky, shader fog globals, rain particles,
## wet surfaces, rain/wind audio and the AI visibility values on the mission.

const TIMES := {
	"night": {"sun_pitch": -48.0, "sun_yaw": 30.0, "sun": Color(0.6, 0.68, 0.95), "sun_e": 0.45, "amb": Color(0.3, 0.35, 0.48), "amb_e": 1.6,
		"top": Color(0.02, 0.03, 0.08), "hor": Color(0.1, 0.12, 0.18), "fog": Color(0.09, 0.1, 0.14), "baked": 2.2, "night": 1.0, "dark": 0.6},
	"storm_night": {"sun_pitch": -55.0, "sun_yaw": 10.0, "sun": Color(0.55, 0.6, 0.85), "sun_e": 0.3, "amb": Color(0.26, 0.3, 0.4), "amb_e": 1.5,
		"top": Color(0.03, 0.03, 0.05), "hor": Color(0.08, 0.09, 0.12), "fog": Color(0.08, 0.09, 0.11), "baked": 2.2, "night": 1.0, "dark": 0.5},
	"day": {"sun_pitch": -55.0, "sun_yaw": 35.0, "sun": Color(1.0, 0.96, 0.88), "sun_e": 1.25, "amb": Color(0.58, 0.6, 0.64), "amb_e": 0.55,
		"top": Color(0.28, 0.48, 0.78), "hor": Color(0.72, 0.76, 0.8), "fog": Color(0.72, 0.74, 0.76), "baked": 0.0, "night": 0.0, "dark": 1.0},
	"rush": {"sun_pitch": -32.0, "sun_yaw": -60.0, "sun": Color(1.0, 0.86, 0.66), "sun_e": 1.15, "amb": Color(0.6, 0.56, 0.5), "amb_e": 0.55,
		"top": Color(0.4, 0.5, 0.65), "hor": Color(0.85, 0.75, 0.6), "fog": Color(0.8, 0.72, 0.62), "baked": 0.0, "night": 0.0, "dark": 1.0},
	"fog_morning": {"sun_pitch": -14.0, "sun_yaw": 80.0, "sun": Color(1.0, 0.9, 0.76), "sun_e": 0.55, "amb": Color(0.62, 0.64, 0.67), "amb_e": 0.75,
		"top": Color(0.58, 0.62, 0.66), "hor": Color(0.66, 0.68, 0.7), "fog": Color(0.64, 0.66, 0.68), "baked": 0.2, "night": 0.0, "dark": 0.9},
	"sunset": {"sun_pitch": -7.0, "sun_yaw": -100.0, "sun": Color(1.0, 0.55, 0.3), "sun_e": 1.0, "amb": Color(0.5, 0.38, 0.38), "amb_e": 0.6,
		"top": Color(0.22, 0.28, 0.55), "hor": Color(0.98, 0.55, 0.3), "fog": Color(0.82, 0.55, 0.4), "baked": 0.4, "night": 0.35, "dark": 0.9},
	"dawn": {"sun_pitch": -6.0, "sun_yaw": 80.0, "sun": Color(1.0, 0.7, 0.55), "sun_e": 0.7, "amb": Color(0.42, 0.4, 0.48), "amb_e": 0.65,
		"top": Color(0.28, 0.33, 0.55), "hor": Color(0.95, 0.68, 0.6), "fog": Color(0.7, 0.62, 0.64), "baked": 0.7, "night": 0.5, "dark": 0.8},
	"evening": {"sun_pitch": -3.0, "sun_yaw": -110.0, "sun": Color(0.65, 0.5, 0.6), "sun_e": 0.35, "amb": Color(0.4, 0.38, 0.48), "amb_e": 1.2,
		"top": Color(0.07, 0.09, 0.24), "hor": Color(0.5, 0.33, 0.4), "fog": Color(0.3, 0.27, 0.35), "baked": 1.3, "night": 0.85, "dark": 0.8},
	"dusk": {"sun_pitch": -5.0, "sun_yaw": -115.0, "sun": Color(0.95, 0.5, 0.35), "sun_e": 0.65, "amb": Color(0.38, 0.32, 0.4), "amb_e": 0.7,
		"top": Color(0.14, 0.17, 0.38), "hor": Color(0.86, 0.46, 0.36), "fog": Color(0.55, 0.4, 0.42), "baked": 0.9, "night": 0.6, "dark": 0.8},
}

const STATES := {
	"clear": {"fog": 0.004, "start": 25.0, "rain": 0.0, "wet": 0.0, "vis": 1.0, "haze": 0.0, "wind": 0.0},
	"haze": {"fog": 0.009, "start": 18.0, "rain": 0.0, "wet": 0.0, "vis": 0.9, "haze": 1.0, "wind": 0.0},
	"mist": {"fog": 0.022, "start": 8.0, "rain": 0.0, "wet": 0.2, "vis": 0.72, "haze": 0.0, "wind": 0.1},
	"fog": {"fog": 0.055, "start": 3.0, "rain": 0.0, "wet": 0.3, "vis": 0.42, "haze": 0.0, "wind": 0.2},
	"light_rain": {"fog": 0.012, "start": 15.0, "rain": 0.35, "wet": 0.6, "vis": 0.85, "haze": 0.0, "wind": 0.2},
	"rain": {"fog": 0.02, "start": 10.0, "rain": 0.8, "wet": 1.0, "vis": 0.7, "haze": 0.0, "wind": 0.4},
	"storm": {"fog": 0.026, "start": 8.0, "rain": 1.0, "wet": 1.0, "vis": 0.6, "haze": 0.0, "wind": 1.0},
}

var mission: Node
var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var time_key := "day"
var schedule: Array = []
var _sched_i := 0
var _clock := 0.0
var _cur := {}
var _target := {}
var _rain: CPUParticles3D
var _rain_mat: StandardMaterial3D
var _lightning_t := 8.0
var _flash := 0.0
var haze := 0.0
var _tod: Dictionary = {}


func setup(p_mission: Node, p_time: String, p_schedule: Array) -> void:
	mission = p_mission
	time_key = p_time
	schedule = p_schedule
	_tod = TIMES.get(time_key, TIMES["day"])
	var first := "clear"
	if schedule.size() > 0:
		first = str(schedule[0][0])
	_cur = (STATES[first] as Dictionary).duplicate()
	_target = _cur.duplicate()
	_build()
	_apply(0.0)


func _build() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = _tod["top"]
	sky_mat.sky_horizon_color = _tod["hor"]
	sky_mat.ground_horizon_color = _tod["hor"]
	sky_mat.ground_bottom_color = (_tod["fog"] as Color).darkened(0.3)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sky_curve = 0.12
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _tod["amb"]
	env.ambient_light_energy = float(_tod["amb_e"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	# High-quality mode (SilentRescueDhaka_HQ.bat runs the Forward+ renderer): real SSAO and
	# volumetric fog. The default OpenGL renderer ignores these and keeps the shader fog / baked AO.
	if RenderingServer.get_rendering_device() != null:
		env.ssao_enabled = true
		env.ssao_radius = 1.4
		env.ssao_intensity = 1.6
		env.ssil_enabled = false
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = _tod["fog"]
		env.volumetric_fog_length = 90.0
		env.glow_enabled = true
		env.glow_intensity = 0.45
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(float(_tod["sun_pitch"]), float(_tod["sun_yaw"]), 0)
	sun.light_color = _tod["sun"]
	sun.light_energy = float(_tod["sun_e"])
	sun.shadow_enabled = Game.quality() >= 2 and float(_tod["sun_e"]) > 0.4
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)
	RenderingServer.global_shader_parameter_set("baked_strength", float(_tod["baked"]))
	RenderingServer.global_shader_parameter_set("night_factor", float(_tod["night"]))
	_rain = CPUParticles3D.new()
	_rain.top_level = true
	var counts := [700, 1400, 2400]
	_rain.amount = counts[clampi(Game.quality(), 0, 2)]
	_rain.lifetime = 0.8
	_rain.preprocess = 0.8
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16, 0.5, 16)
	_rain.direction = Vector3(0.08, -1, 0)
	_rain.spread = 2.0
	_rain.gravity = Vector3(0, -5, 0)
	_rain.initial_velocity_min = 20.0
	_rain.initial_velocity_max = 25.0
	_rain.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.7)
	_rain_mat = StandardMaterial3D.new()
	_rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_mat.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	_rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_rain_mat.billboard_keep_scale = true
	q.material = _rain_mat
	_rain.mesh = q
	_rain.emitting = false
	add_child(_rain)


func set_state(sname: String) -> void:
	if STATES.has(sname):
		_target = (STATES[sname] as Dictionary).duplicate()


func flash() -> float:
	return _flash


func _process(delta: float) -> void:
	_clock += delta
	if _sched_i + 1 < schedule.size() and _clock >= float(schedule[_sched_i + 1][1]):
		_sched_i += 1
		set_state(str(schedule[_sched_i][0]))
	var k := clampf(delta / 20.0, 0.0, 1.0)
	for key in _cur.keys():
		_cur[key] = lerpf(float(_cur[key]), float(_target[key]), k)
	_apply(delta)


func _apply(delta: float) -> void:
	var fog_c: Color = _tod["fog"]
	var rainv: float = float(_cur["rain"])
	if rainv > 0.2:
		fog_c = fog_c.darkened(0.15 * rainv)
	RenderingServer.global_shader_parameter_set("fog_color", fog_c)
	RenderingServer.global_shader_parameter_set("fog_density", float(_cur["fog"]))
	if env != null and env.volumetric_fog_enabled:
		env.volumetric_fog_density = float(_cur["fog"]) * 0.9
	RenderingServer.global_shader_parameter_set("fog_start", float(_cur["start"]))
	RenderingServer.global_shader_parameter_set("world_wetness", float(_cur["wet"]))
	var vis: float = float(_cur["vis"])
	sky_mat.sky_horizon_color = (_tod["hor"] as Color).lerp(fog_c, clampf(float(_cur["fog"]) * 18.0, 0.0, 1.0))
	sky_mat.sky_top_color = (_tod["top"] as Color).lerp(fog_c, clampf(float(_cur["fog"]) * 14.0 + rainv * 0.4, 0.0, 1.0))
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.background_energy_multiplier = 1.0 + _flash * 3.0
	env.ambient_light_energy = float(_tod["amb_e"]) * (1.0 - rainv * 0.25) + _flash * 2.5
	sun.light_energy = float(_tod["sun_e"]) * (1.0 - rainv * 0.5 - clampf(float(_cur["fog"]) * 6.0, 0.0, 0.5))
	haze = float(_cur["haze"])
	if mission != null:
		mission.set("visibility", vis)
		mission.set("darkness", float(_tod["dark"]))
		mission.set("wetness", float(_cur["wet"]))
	# rain follows the camera
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_rain.global_position = cam.global_position + Vector3(0, 9, 0) + cam.global_transform.basis.z * -4.0
	var want_rain := rainv > 0.05
	if _rain.emitting != want_rain:
		_rain.emitting = want_rain
	_rain_mat.albedo_color.a = 0.15 + rainv * 0.3
	AudioManager.set_rain(rainv)
	AudioManager.set_wind(float(_cur["wind"]))
	# lightning in storms
	_flash = maxf(_flash - delta * 4.0, 0.0)
	if float(_cur["wind"]) > 0.8:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(7.0, 16.0)
			_flash = 1.0
			var delay := randf_range(0.4, 2.0)
			get_tree().create_timer(delay).timeout.connect(func(): AudioManager.play_2d("sfx_thunder", -2.0, randf_range(0.85, 1.1)))
