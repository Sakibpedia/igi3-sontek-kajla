class_name Speech
extends RefCounted
## Bengali spoken dialogue — mechanism adopted from the proven TauntONomics v3
## audio system. Authored lines are pre-generated as real Bengali voice clips
## (assets/voice/<md5-16>.mp3 by tools/generate_voice_bn.py) and loaded as raw
## bytes, so source and exported builds behave identically.  If no clip exists,
## it falls back to an installed OS Bengali voice.

const VOICE_DIR := "res://assets/voice/"
static var _player: AudioStreamPlayer
static var _clips: Dictionary = {}
static var _voice := ""
static var _checked := false
static var enabled := true

static func bind(player: AudioStreamPlayer) -> void:
	_player = player


static func available() -> bool:
	if not _checked:
		_checked = true
		if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			return false
		for lang in ["bn", "bn_BD", "bn-IN", "bn_BD.UTF-8"]:
			var voices := DisplayServer.tts_get_voices_for_language(lang)
			if voices.size() > 0:
				_voice = voices[0]
				return true
	return _voice != ""


static func _key(text: String) -> String:
	return text.md5_text().substr(0, 16)


static func speak(text: String, pitch: float = 1.0, rate: float = 1.0) -> void:
	if not enabled or text.strip_edges() == "":
		return
	var h := _key(text)
	if not _clips.has(h):
		var path := VOICE_DIR + h + ".mp3"
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			if bytes.size() > 256:
				var stream := AudioStreamMP3.new()
				stream.data = bytes
				_clips[h] = stream
	if _clips.has(h) and _player != null and is_instance_valid(_player):
		_player.stream = _clips[h]
		_player.pitch_scale = pitch * clampf(rate, 0.6, 1.8)
		_player.play()
		return
	if available():
		var clean := text.replace("'", "").replace("\"", "")
		DisplayServer.tts_speak(clean, _voice, 70, pitch, rate, 0, true)


static func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
	if _voice != "":
		DisplayServer.tts_stop()


static func clip_count() -> int:
	return _clips.size()
