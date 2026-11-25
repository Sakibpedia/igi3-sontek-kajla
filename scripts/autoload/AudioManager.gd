extends Node
## 3D spatial + 2D audio and the dialogue boxes (text only).
## Cox's Bazar update:
##  * No environmental sound at all: no rain, wind, traffic, crowd, birds, thunder or call to prayer
##    (set_ambience / set_rain / set_wind are kept as silent no-ops), and no voices - say() only shows
##    the line in the dialogue box.
##  * Built-in gameplay sounds (guns, steps, doors, alarms, music) play unless Settings switches
##    "গেমের নিজস্ব শব্দ" off. Built-in files are NEVER used for the tape, rope and carry moments or for
##    the hostages' breathing / gasps / cries (CUE_NAMES), nor for environmental sound (ENV_NAMES):
##    those play only when you put your own file of that name in (Sounds tab / "sounds" folder).
##  * Your signal clips (SIGNAL_SLOTS) - tape on / off, the lift onto the shoulder and the put-down,
##    the yes / no head signals of gagged hostages - play on their own "Signals" bus.
##  * Any other game sound can still be replaced by a file of the same name (custom sounds).
## Headphone mode (N) and the under-water low-pass while diving are unchanged.

signal subtitle(speaker: String, text: String, duration: float)

const AUDIO_DIR := "res://assets/audio/"
const POOL_3D := 24
const POOL_2D := 10

var _streams := {}
var _pool3d: Array = []
var _pool2d: Array = []
var _next3d := 0
var _next2d := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _bn_voice_player: AudioStreamPlayer = null
var _ambience := {}
var _rain: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _azan: AudioStreamPlayer3D
var _bn_voice := ""
var _tts_checked := false
var headphones := false
var _rain_tin: AudioStreamPlayer
var _rain_level := 0.0
var _thunder_t := 20.0
var _underwater := false
var _uw_fx: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 140.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool2d.append(p2)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_rain = _make_loop_player("amb_rain", "Ambience")
	_wind = _make_loop_player("amb_wind", "Ambience")
	_rain_tin = _make_loop_player("amb_rain_tin", "Ambience")
	_uw_fx = AudioEffectLowPassFilter.new()
	_uw_fx.cutoff_hz = 650.0
	AudioServer.add_bus_effect(0, _uw_fx)
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, false)
	_azan = AudioStreamPlayer3D.new()
	_azan.bus = "Ambience"
	_azan.unit_size = 60.0
	_azan.max_distance = 2000.0
	add_child(_azan)


func get_stream(sname: String) -> AudioStream:
	if _streams.has(sname):
		return _streams[sname]
	var s: AudioStream = custom_stream(sname)
	if s != null:
		_streams[sname] = s
		return s
	if not builtin_on() or never_builtin(sname):
		# only your own sounds play (Settings: "গেমের নিজস্ব শব্দ"); tape / carry / hostage sounds and
		# environmental sound never use the built-in files
		_streams[sname] = null
		return null
	for ext in [".wav", ".ogg", ".mp3"]:
		var path: String = AUDIO_DIR + sname + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_streams[sname] = s
	return s


func builtin_on() -> bool:
	return bool(Game.settings.get("builtin_sounds", true))


## Tape on/off, rope, lift/put-down, breathing and cries:
## only your own files (the signal slots), never the built-in recordings.
const CUE_NAMES := ["sfx_tape_on", "sfx_tape_rip", "sfx_lift_cry", "sfx_gasp_", "sfx_relief_", "sfx_breath_f", "sfx_breath_m",
	"sfx_breath_nose", "sfx_sigh_", "sfx_cough_", "sfx_effort_", "sfx_rope", "sfx_cloth"]
## Environmental sound: none at all (ambience beds, rain, wind, thunder, horns, engines, sirens).
const ENV_NAMES := ["amb_", "sfx_thunder", "sfx_car_horn", "sfx_rickshaw_bell", "sfx_ship_horn", "sfx_plane_pass", "sfx_engine"]


static func never_builtin(sname: String) -> bool:
	for pre in CUE_NAMES:
		if sname.begins_with(str(pre)):
			return true
	for pre in ENV_NAMES:
		if sname.begins_with(str(pre)):
			return true
	return false


func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _make_loop_player(sname: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	var s := get_stream(sname)
	if s != null:
		_loop(s)
		p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p


func play_3d(sname: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 140.0) -> void:
	var s := get_stream(sname)
	if s == null:
		return
	var p: AudioStreamPlayer3D = _pool3d[_next3d]
	_next3d = (_next3d + 1) % POOL_3D
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.play()


func play_2d(sname: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := get_stream(sname)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool2d[_next2d]
	_next2d = (_next2d + 1) % POOL_2D
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(sname: String, volume_db: float = -6.0) -> void:
	if _music_name == sname and _music.playing:
		return
	var s := get_stream(sname)
	if s == null:
		return
	_loop(s)
	_music_name = sname
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", volume_db, 1.5)


func stop_music(fade: float = 1.5) -> void:
	_music_name = ""
	if not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -60.0, fade)
	tw.tween_callback(_music.stop)


func play_once_music(sname: String) -> void:
	var s := get_stream(sname)
	if s == null:
		return
	_music_name = ""
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_music.stream = s
	_music.volume_db = -4.0
	_music.play()


## No environmental sound in this game: kept so old callers still work, but nothing is started.
func set_ambience(_names: Array) -> void:
	stop_ambience()


func stop_ambience() -> void:
	for k in _ambience.keys():
		var p: AudioStreamPlayer = _ambience[k]
		p.stop()
		p.queue_free()
	_ambience.clear()
	set_rain(0.0)
	set_wind(0.0)


func set_rain(_intensity: float) -> void:
	# rain is only seen, never heard (no environmental sound)
	_set_loop_level(_rain, 0.0, -4.0)
	_set_loop_level(_rain_tin, 0.0, -8.0)
	_rain_level = 0.0


## Volume offset (dB) a bus gets from the headphone mode (Game applies it with the volume settings).
func bus_offset(bus_name: String) -> float:
	if not headphones:
		return 0.0
	if bus_name == "Ambience":
		return -6.0
	if bus_name == "SFX":
		return -3.0
	return 0.0


func toggle_headphones() -> void:
	headphones = not headphones
	play_2d("sfx_headphones", -4.0, 1.0 if headphones else 0.8)
	Game.apply_audio_settings()
	say("", "হেডফোন চালু — শব্দ প্রভাব ৩ ডেসিবেল কম" if headphones else "হেডফোন বন্ধ", 1.8)


func set_underwater(on: bool) -> void:
	if on == _underwater:
		return
	_underwater = on
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _uw_fx:
			AudioServer.set_bus_effect_enabled(0, i, on)


func _process(delta: float) -> void:
	# thunder rolls now and then in heavy rain
	if _rain_level > 0.55:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(18.0, 45.0)
			play_2d("sfx_thunder", lerpf(-14.0, -4.0, randf()) + (-6.0 if headphones else 0.0), randf_range(0.85, 1.1))


func set_wind(_intensity: float) -> void:
	_set_loop_level(_wind, 0.0, -8.0)


func _set_loop_level(p: AudioStreamPlayer, intensity: float, max_db: float) -> void:
	if p.stream == null:
		return
	if intensity <= 0.01:
		p.volume_db = -80.0
		if p.playing:
			p.stop()
		return
	p.volume_db = lerpf(-30.0, max_db, clampf(intensity, 0.0, 1.0))
	if not p.playing:
		p.play()


## Distant call to prayer. Plays assets/audio/azan.(ogg|wav|mp3) if the user supplied a recording.
func play_azan(from_pos: Vector3) -> bool:
	if from_pos != Vector3.INF:
		return false   # no environmental sound in this game
	var s := get_stream("azan")
	if s == null:
		return false
	_azan.stream = s
	_azan.global_position = from_pos
	_azan.volume_db = -6.0
	_azan.play()
	return true


func stop_all_world_audio() -> void:
	set_underwater(false)
	for p in _pool3d:
		(p as AudioStreamPlayer3D).stop()
	_azan.stop()
	stop_ambience()


# ---------------------------------------------------------------- voice / subtitles
## Dialogue box: speaker + line, text only (no voice). pitch / rate are kept for old callers.
func say(speaker: String, text: String, duration: float = 4.0, _pitch: float = 1.0, _rate: float = 1.0) -> void:
	subtitle.emit(speaker, text, duration)
	# synced subtitle + real Bengali voice (TauntONomics Speech mechanism)
	if DisplayServer.get_name() != "headless" and bool(Game.settings.get("tts", true)):
		if _bn_voice_player == null:
			_bn_voice_player = AudioStreamPlayer.new()
			_bn_voice_player.name = "BengaliVoice"
			_bn_voice_player.bus = "Voice"
			add_child(_bn_voice_player)
			Speech.bind(_bn_voice_player)
		Speech.speak(text, _pitch, _rate)


# ---------------------------------------------------------------- recorded Bengali voices
## Recorded lines: <key>.ogg / .wav / .mp3 where key = "line_" + the first 10 hex digits of the MD5 of
## the exact Bengali text (UTF-8). Outside the project (next to the .exe / user://) use .ogg or .mp3. tools/list_voice_lines.py writes voice_lines.csv with every key,
## its text and where it is used, for a voice actor. Optional gendered takes: <key>_f / <key>_m
## (picked by the speaker's voice pitch). Searched in a "voice_bn" folder next to the .exe,
## user://voice_bn and res://assets/audio/voice_bn. Lines built at run time (with names or numbers
## in them) have no fixed key and stay on text-to-speech.
var _voice_player: AudioStreamPlayer
var _voice_cache := {}


static func voice_key(text: String) -> String:
	return "line_" + text.md5_text().substr(0, 10)


func _voice_dirs() -> Array:
	var d: Array = []
	if not OS.has_feature("editor"):
		d.append(OS.get_executable_path().get_base_dir().path_join("voice_bn"))
	d.append(ProjectSettings.globalize_path("user://voice_bn"))
	d.append("res://assets/audio/voice_bn")
	return d


func _find_voice(key: String, pitch: float) -> AudioStream:
	var tries: Array = [key + ("_f" if pitch >= 1.05 else "_m"), key]
	for t in tries:
		var ck: String = str(t)
		if _voice_cache.has(ck):
			if _voice_cache[ck] != null:
				return _voice_cache[ck]
			continue
		var found: AudioStream = null
		for d in _voice_dirs():
			for ext in ["ogg", "wav", "mp3"]:
				var p: String = str(d).path_join("%s.%s" % [ck, ext])
				if p.begins_with("res://"):
					if ResourceLoader.exists(p):
						found = load(p)
				elif FileAccess.file_exists(p):
					if ext == "ogg":
						found = AudioStreamOggVorbis.load_from_file(p)
					elif ext == "mp3":
						var mp := AudioStreamMP3.new()
						mp.data = FileAccess.get_file_as_bytes(p)
						found = mp
					# .wav next to the exe is not loaded at run time in Godot 4.3: use .ogg or .mp3 there
				if found != null:
					break
			if found != null:
				break
		_voice_cache[ck] = found
		if found != null:
			return found
	return null


func _play_voice_file(text: String, pitch: float) -> bool:
	var s := _find_voice(voice_key(text), pitch)
	if s == null:
		return false
	if _voice_player == null:
		_voice_player = AudioStreamPlayer.new()
		_voice_player.bus = "Voice"
		add_child(_voice_player)
	_voice_player.stream = s
	_voice_player.play()
	return true


func _speak(text: String, pitch: float = 1.0, rate: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)):
		return
	if not _tts_checked:
		_tts_checked = true
		var voices := DisplayServer.tts_get_voices_for_language("bn")
		if voices.size() > 0:
			_bn_voice = voices[0]
	if _bn_voice == "":
		return
	DisplayServer.tts_speak(text, _bn_voice, 80, clampf(pitch, 0.5, 2.0), clampf(rate, 0.5, 2.0), 0, false)


# ---------------------------------------------------------------- custom sounds
## Any game sound can be replaced with your own file of the same name (.mp3, .ogg or 16-bit .wav) in
## a "sounds" folder next to the exe, or in user://sounds (the in-game Sounds tab copies files there).
## Hostage moments have their own names, one per gender; they play from the hostage's head and move
## with the body. Nothing is in these slots by default: the built-in sound plays instead.
## Your signal clips: [file name, when it plays, what plays when the slot is empty]. Each event has a
## common slot plus "_f" / "_m" (the woman's / the man's version wins when it is there). They play from
## the person's head (moving with the body while carried) on the "Signals" bus. Nothing is in these
## slots by default; the carry / nod slots now ship with subtle built-in cues.
const SIGNAL_SLOTS := [
	["sfx_tape_on", "টেপ লাগানো (মুখে টেপ লাগার মুহূর্তে) — নারী ও পুরুষ", "নীরব"],
	["sfx_tape_on_f", "টেপ লাগানো — শুধু নারী", "ওপরের সাধারণ ঘর"],
	["sfx_tape_on_m", "টেপ লাগানো — শুধু পুরুষ", "ওপরের সাধারণ ঘর"],
	["sfx_tape_off", "টেপ খোলা (টেপ উঠে আসার মুহূর্তে) — নারী ও পুরুষ", "নীরব"],
	["sfx_tape_off_f", "টেপ খোলা — শুধু নারী", "ওপরের সাধারণ ঘর"],
	["sfx_tape_off_m", "টেপ খোলা — শুধু পুরুষ", "ওপরের সাধারণ ঘর"],
	["sfx_carry_start", "কাঁধে তোলা (তোলা শুরুর মুহূর্তে) — নারী ও পুরুষ", "নীরব"],
	["sfx_carry_start_f", "কাঁধে তোলা — শুধু নারী", "ওপরের সাধারণ ঘর"],
	["sfx_carry_start_m", "কাঁধে তোলা — শুধু পুরুষ", "ওপরের সাধারণ ঘর"],
	["sfx_carry_down", "কাঁধ থেকে নামানো — নারী ও পুরুষ", "নীরব"],
	["sfx_carry_down_f", "কাঁধ থেকে নামানো — শুধু নারী", "ওপরের সাধারণ ঘর"],
	["sfx_carry_down_m", "কাঁধ থেকে নামানো — শুধু পুরুষ", "ওপরের সাধারণ ঘর"],
	["sfx_nod_yes", "মাথা নেড়ে 'হ্যাঁ' (মুখ-বাঁধা জিম্মি) — নারী ও পুরুষ", "নীরব"],
	["sfx_nod_yes_f", "মাথা নেড়ে 'হ্যাঁ' — শুধু নারী", "ওপরের সাধারণ ঘর"],
	["sfx_nod_yes_m", "মাথা নেড়ে 'হ্যাঁ' — শুধু পুরুষ", "ওপরের সাধারণ ঘর"],
	["sfx_nod_no", "মাথা নেড়ে 'না' (মুখ-বাঁধা জিম্মি) — নারী ও পুরুষ", "নীরব"],
	["sfx_nod_no_f", "মাথা নেড়ে 'না' — শুধু নারী", "ওপরের সাধারণ ঘর"],
	["sfx_nod_no_m", "মাথা নেড়ে 'না' — শুধু পুরুষ", "ওপরের সাধারণ ঘর"],
	["sfx_new_info", "নতুন তথ্য মনে পড়লে (কাঁধে থেকে ইশারা)", "নীরব — শুধু পিঠে টোকা"],
	["sfx_intel_signal", "তথ্য-সংকেত (শত্রুরাও শোনে)", "নীরব"],
]
## kept for old callers (the Sounds tab used to read this name)
const EVENT_SLOTS := SIGNAL_SLOTS
const SOUND_EXTS := ["mp3", "ogg", "wav"]

var _custom := {}


func sound_dirs() -> Array:
	var d: Array = []
	if not OS.has_feature("editor"):
		d.append(OS.get_executable_path().get_base_dir().path_join("sounds"))
	d.append(ProjectSettings.globalize_path("user://sounds"))
	return d


func user_sound_dir() -> String:
	var d := ProjectSettings.globalize_path("user://sounds")
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Path of your file for this sound name, or "" (first match: exe folder, then user://sounds).
func custom_path(sname: String) -> String:
	for d in sound_dirs():
		for ext in SOUND_EXTS:
			var p: String = str(d).path_join("%s.%s" % [sname, ext])
			if FileAccess.file_exists(p):
				return p
	return ""


func custom_stream(sname: String) -> AudioStream:
	if _custom.has(sname):
		return _custom[sname]
	var s: AudioStream = null
	var p := custom_path(sname)
	if p != "":
		s = load_audio_file(p)
		if s == null:
			push_warning("[AudioManager] could not read %s (use .mp3, .ogg or 16-bit PCM .wav)" % p)
	_custom[sname] = s
	return s


func has_custom(sname: String) -> bool:
	return custom_stream(sname) != null


## Is this file name one of the signal slots (plays on the Signals bus)?
static func is_signal(sname: String) -> bool:
	for sl in SIGNAL_SLOTS:
		if str(sl[0]) == sname:
			return true
	return false


## The custom sound for a hostage moment: "<base>_f" / "<base>_m", then "<base>" for both; "" if none.
func custom_event(base: String, g: String) -> String:
	for n in [base + "_" + g, base]:
		var sname := str(n)
		# user overrides first, then the built-in cue shipped with the game
		if has_custom(sname) or get_stream(sname) != null:
			return sname
	return ""


## Forget loaded files (after adding or removing one). Ambience loops pick changes up on the next start.
func reload_custom() -> void:
	_custom.clear()
	_streams.clear()


## Every built-in sound name (for the Sounds tab list).
func builtin_names() -> PackedStringArray:
	var out := {}
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return PackedStringArray()
	for f in dir.get_files():
		var n: String = f.trim_suffix(".import").trim_suffix(".remap")
		var e := n.get_extension()
		if e in ["wav", "ogg", "mp3"]:
			out[n.get_basename()] = true
	var arr := PackedStringArray(out.keys())
	arr.sort()
	return arr


static func load_audio_file(p: String) -> AudioStream:
	match p.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(p)
		"mp3":
			var bytes := FileAccess.get_file_as_bytes(p)
			if bytes.size() < 128:
				return null
			var mp := AudioStreamMP3.new()
			mp.data = bytes
			return mp if mp.get_length() > 0.0 else null
		"wav":
			return _load_wav(p)
	return null


## Plain PCM .wav (8 or 16 bit, mono or stereo); Godot 4.3 cannot import .wav at run time by itself.
static func _load_wav(p: String) -> AudioStreamWAV:
	var b := FileAccess.get_file_as_bytes(p)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var pos := 12
	var fmt := 0
	var ch := 0
	var rate := 0
	var bits := 0
	var data := PackedByteArray()
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var n := int(b.decode_u32(pos + 4))
		var body := pos + 8
		if id == "fmt " and body + 16 <= b.size():
			fmt = b.decode_u16(body)
			ch = b.decode_u16(body + 2)
			rate = int(b.decode_u32(body + 4))
			bits = b.decode_u16(body + 14)
		elif id == "data":
			data = b.slice(body, mini(body + n, b.size()))
		pos = body + n + (n & 1)
	if fmt != 1 or (bits != 16 and bits != 8) or ch < 1 or ch > 2 or rate <= 0 or data.is_empty():
		return null
	var w := AudioStreamWAV.new()
	if bits == 8:
		for i in data.size():
			data[i] = data[i] ^ 0x80   # unsigned -> signed
		w.format = AudioStreamWAV.FORMAT_8_BITS
	else:
		w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = ch == 2
	w.data = data
	return w
