@tool
extends VBoxContainer
## The GenMagic dock: a mode picker (Image, Speech, Music), a prompt, a model list with
## prices, a Generate button and the result. Results are saved under res://genmagic/ and the
## project is rescanned so they appear in the FileSystem dock.
##
## Nothing is requested from the network until this dock is first shown, and nothing is
## spent until the Generate button is pressed.

const Core = preload("core.gd")
const Client = preload("client.gd")

const DEFAULT_MODEL_TEXT := "Recommended default (GenMagic picks)"
const PLACEHOLDERS := [
	"A pixel-art treasure chest, three-quarter view, bright colors, plain background",
	"Welcome to Brightwater, traveler. The inn is just past the bridge.",
	"Upbeat chiptune boss battle, 160 bpm, driving bass line, short intro",
]
const PROMPT_LABELS := ["Describe the image", "Line of dialogue to speak", "Describe the track"]

## Emitted when a model list load finishes, whether it worked or not.
signal models_loaded

var client: Node = null
var last_saved_path: String = ""
var last_result: Dictionary = {}

var _mode: int = Core.Mode.IMAGE
var _prompts: Array[String] = ["", "", ""]
var _models: Dictionary = {} # mode -> Array of model dictionaries
var _chosen_model: Dictionary = {} # mode -> model id
var _models_state: Dictionary = {} # "image" / "audio" -> "loading" | "ok" | "failed"
var _first_shown: bool = false
var _loading_models: bool = false
var _elapsed: float = 0.0
var _stage_text: String = ""
var _preview_texture: Texture2D = null

var _balance_label: Label
var _balance_refresh: Button
var _key_saved_box: HBoxContainer
var _key_saved_label: Label
var _key_edit_box: VBoxContainer
var _key_edit: LineEdit
var _mode_bar: TabBar
var _prompt_title: Label
var _prompt_edit: TextEdit
var _model_option: OptionButton
var _price_label: Label
var _models_note: Label
var _size_box: HBoxContainer
var _size_option: OptionButton
var _reference_box: VBoxContainer
var _reference_edit: LineEdit
var _reference_dialog: FileDialog
var _voice_box: HBoxContainer
var _voice_edit: LineEdit
var _generate_button: Button
var _cancel_button: Button
var _stage_label: Label
var _progress: ProgressBar
var _status_label: Label
var _result_box: VBoxContainer
var _preview: TextureRect
var _play_button: Button
var _player: AudioStreamPlayer
var _path_edit: LineEdit
var _cost_label: Label
var _ticker: Timer


func _init() -> void:
	name = "GenMagicDock"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(260, 320)


func _ready() -> void:
	client = Client.new()
	client.name = "Client"
	add_child(client)
	client.stage_changed.connect(_on_stage_changed)
	_build_ui()
	client.api_key = _read_key()
	_refresh_key_ui()
	_apply_mode()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and not _first_shown:
		_first_shown = true
		refresh_models()
		refresh_balance()


# ----------------------------------------------------------------------------------------
# UI
# ----------------------------------------------------------------------------------------

func _label(text: String, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _link(text: String, url: String) -> LinkButton:
	var b := LinkButton.new()
	b.text = text
	b.uri = url
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	# Balance and key
	var top := HBoxContainer.new()
	body.add_child(top)
	_balance_label = _label("Balance: add your API key", false)
	top.add_child(_balance_label)
	_balance_refresh = Button.new()
	_balance_refresh.text = "Refresh"
	_balance_refresh.tooltip_text = "Reload the balance and the model list"
	_balance_refresh.pressed.connect(func() -> void:
		refresh_balance()
		refresh_models()
	)
	top.add_child(_balance_refresh)

	_key_saved_box = HBoxContainer.new()
	body.add_child(_key_saved_box)
	_key_saved_label = _label("", true)
	_key_saved_box.add_child(_key_saved_label)
	var change := Button.new()
	change.text = "Change key"
	change.pressed.connect(func() -> void:
		_key_saved_box.visible = false
		_key_edit_box.visible = true
		_key_edit.grab_focus()
	)
	_key_saved_box.add_child(change)

	_key_edit_box = VBoxContainer.new()
	body.add_child(_key_edit_box)
	_key_edit_box.add_child(_label("Paste your GenMagic API key. It is kept in your Editor Settings on this computer, never in the project."))
	_key_edit = LineEdit.new()
	_key_edit.secret = true
	_key_edit.placeholder_text = "API key"
	_key_edit.text_submitted.connect(func(_t: String) -> void: _on_save_key())
	_key_edit_box.add_child(_key_edit)
	var key_row := HBoxContainer.new()
	_key_edit_box.add_child(key_row)
	var save := Button.new()
	save.text = "Save key"
	save.pressed.connect(_on_save_key)
	key_row.add_child(save)
	key_row.add_child(_link("Get an API key", Core.KEY_URL))

	body.add_child(HSeparator.new())

	# Mode picker
	_mode_bar = TabBar.new()
	_mode_bar.add_tab("Image")
	_mode_bar.add_tab("Speech")
	_mode_bar.add_tab("Music")
	_mode_bar.tab_changed.connect(_on_mode_changed)
	body.add_child(_mode_bar)

	_prompt_title = _label("", true)
	body.add_child(_prompt_title)
	_prompt_edit = TextEdit.new()
	_prompt_edit.custom_minimum_size = Vector2(0, 90)
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_edit.text_changed.connect(func() -> void: _prompts[_mode] = _prompt_edit.text)
	body.add_child(_prompt_edit)

	# Model
	body.add_child(_label("Model"))
	_model_option = OptionButton.new()
	_model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_option.fit_to_longest_item = false
	_model_option.item_selected.connect(_on_model_selected)
	body.add_child(_model_option)
	_price_label = _label("")
	body.add_child(_price_label)
	_models_note = _label("")
	body.add_child(_models_note)

	# Image options
	_size_box = HBoxContainer.new()
	body.add_child(_size_box)
	_size_box.add_child(_label("Size", false))
	_size_option = OptionButton.new()
	_size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in Core.IMAGE_SIZES:
		_size_option.add_item(str(s["label"]))
		_size_option.set_item_metadata(_size_option.item_count - 1, str(s["value"]))
	_size_box.add_child(_size_option)

	_reference_box = VBoxContainer.new()
	body.add_child(_reference_box)
	_reference_box.add_child(_label("Reference image (optional): transform this image instead of starting from scratch"))
	var ref_row := HBoxContainer.new()
	_reference_box.add_child(ref_row)
	_reference_edit = LineEdit.new()
	_reference_edit.placeholder_text = "res://... or https://..."
	_reference_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ref_row.add_child(_reference_edit)
	var browse := Button.new()
	browse.text = "Browse"
	browse.pressed.connect(func() -> void: _reference_dialog.popup_centered_ratio(0.6))
	ref_row.add_child(browse)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(func() -> void: _reference_edit.text = "")
	ref_row.add_child(clear)
	_reference_dialog = FileDialog.new()
	_reference_dialog.access = FileDialog.ACCESS_RESOURCES
	_reference_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_reference_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	_reference_dialog.title = "Choose a reference image"
	_reference_dialog.file_selected.connect(func(path: String) -> void: _reference_edit.text = path)
	add_child(_reference_dialog)

	# Speech options
	_voice_box = HBoxContainer.new()
	body.add_child(_voice_box)
	_voice_box.add_child(_label("Voice", false))
	_voice_edit = LineEdit.new()
	_voice_edit.placeholder_text = "optional, for example alloy"
	_voice_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_box.add_child(_voice_edit)

	# Generate
	var action := HBoxContainer.new()
	body.add_child(action)
	_generate_button = Button.new()
	_generate_button.text = "Generate"
	_generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_button.pressed.connect(func() -> void: generate())
	action.add_child(_generate_button)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.visible = false
	_cancel_button.pressed.connect(func() -> void: client.cancel())
	action.add_child(_cancel_button)

	_stage_label = _label("")
	_stage_label.visible = false
	body.add_child(_stage_label)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.visible = false
	body.add_child(_progress)
	_status_label = _label("")
	_status_label.visible = false
	body.add_child(_status_label)

	# Result
	_result_box = VBoxContainer.new()
	_result_box.visible = false
	body.add_child(_result_box)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(0, 160)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_box.add_child(_preview)
	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.pressed.connect(_on_play_pressed)
	_result_box.add_child(_play_button)
	_player = AudioStreamPlayer.new()
	_player.finished.connect(func() -> void: _play_button.text = "Play")
	add_child(_player)
	_path_edit = LineEdit.new()
	_path_edit.editable = false
	_result_box.add_child(_path_edit)
	var result_actions := HBoxContainer.new()
	_result_box.add_child(result_actions)
	var show := Button.new()
	show.text = "Show in FileSystem"
	show.pressed.connect(_show_in_filesystem)
	result_actions.add_child(show)
	var copy := Button.new()
	copy.text = "Copy path"
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(last_saved_path))
	result_actions.add_child(copy)
	_cost_label = _label("")
	_result_box.add_child(_cost_label)

	body.add_child(HSeparator.new())
	body.add_child(_label("GenMagic is a paid, pay-as-you-go service. Your prompt, and any reference image, is sent to GenMagic and the provider of the model you choose."))
	var links := HFlowContainer.new()
	body.add_child(links)
	links.add_child(_link("Prices", Core.MODELS_URL))
	links.add_child(_link("Add credit", Core.PRICING_URL))
	links.add_child(_link("Privacy", Core.PRIVACY_URL))

	_ticker = Timer.new()
	_ticker.wait_time = 0.5
	_ticker.timeout.connect(_on_tick)
	add_child(_ticker)


# ----------------------------------------------------------------------------------------
# Key
# ----------------------------------------------------------------------------------------

func _read_key() -> String:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(Core.SETTING_API_KEY):
		var value: Variant = settings.get_setting(Core.SETTING_API_KEY)
		if typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty():
			return (value as String).strip_edges()
	return OS.get_environment(Core.ENV_API_KEY).strip_edges()


func _key_from_environment() -> bool:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(Core.SETTING_API_KEY):
		var value: Variant = settings.get_setting(Core.SETTING_API_KEY)
		if typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty():
			return false
	return not OS.get_environment(Core.ENV_API_KEY).strip_edges().is_empty()


## Saves the key in the per-user Editor Settings and uses it from now on.
func set_api_key(key: String) -> void:
	var clean := key.strip_edges()
	EditorInterface.get_editor_settings().set_setting(Core.SETTING_API_KEY, clean)
	client.api_key = _read_key()
	_refresh_key_ui()


func _on_save_key() -> void:
	var key := _key_edit.text.strip_edges()
	if key.is_empty():
		_show_status("Paste your API key first.", true)
		return
	set_api_key(key)
	_key_edit.text = ""
	_clear_status()
	refresh_balance()


func _refresh_key_ui() -> void:
	var key: String = client.api_key
	var has_key := not key.is_empty()
	_key_saved_box.visible = has_key
	_key_edit_box.visible = not has_key
	if has_key:
		if _key_from_environment():
			_key_saved_label.text = "Using the %s environment variable (%s)." % [Core.ENV_API_KEY, Core.mask_key(key)]
		else:
			_key_saved_label.text = "API key saved in Editor Settings (%s)." % Core.mask_key(key)
	else:
		_balance_label.text = "Balance: add your API key"


# ----------------------------------------------------------------------------------------
# Balance and models
# ----------------------------------------------------------------------------------------

func refresh_balance() -> Dictionary:
	if client.api_key.is_empty():
		_balance_label.text = "Balance: add your API key"
		return {"ok": false, "code": "missing_api_key"}
	_balance_label.text = "Balance: checking..."
	var r: Dictionary = await client.fetch_usage()
	if not bool(r["ok"]):
		if str(r.get("code", "")) == "cancelled":
			return r # the dock is closing
		_balance_label.text = "Balance: unavailable"
		if int(r.get("status", 0)) == 401:
			_show_status(str(r["error"]), true)
		return r
	_set_balance(float(r["balance_cents"]))
	return r


func _set_balance(cents: float) -> void:
	_balance_label.text = "Balance: %s" % Core.format_balance(cents)


## Loads the public model lists (no key needed) and fills the dropdown.
func refresh_models() -> void:
	if _loading_models:
		await models_loaded # one load at a time: join the one in progress
		return
	_loading_models = true
	_models_state = {"image": "loading", "audio": "loading"}
	_models_note.text = "Loading models..."
	for category in ["image", "audio"]:
		var r: Dictionary = await client.fetch_models(category)
		if bool(r["ok"]):
			_models_state[category] = "ok"
			if category == "image":
				_models[Core.Mode.IMAGE] = Core.parse_models(r["payload"], Core.Mode.IMAGE)
			else:
				_models[Core.Mode.SPEECH] = Core.parse_models(r["payload"], Core.Mode.SPEECH)
				_models[Core.Mode.MUSIC] = Core.parse_models(r["payload"], Core.Mode.MUSIC)
		else:
			if str(r.get("code", "")) == "cancelled":
				_loading_models = false
				models_loaded.emit()
				return # the dock is closing
			_models_state[category] = "failed"
			_models_note.text = "Could not load the model list: %s The recommended default still works." % str(r["error"])
	_loading_models = false
	_apply_models()
	models_loaded.emit()


func _apply_models() -> void:
	var kind := "image" if _mode == Core.Mode.IMAGE else "audio"
	var list: Array = _models.get(_mode, [])
	_model_option.clear()
	_model_option.add_item(DEFAULT_MODEL_TEXT)
	_model_option.set_item_metadata(0, "")
	var select_index := 0
	var wanted := str(_chosen_model.get(_mode, ""))
	for m in list:
		_model_option.add_item(Core.model_label(m))
		var idx := _model_option.item_count - 1
		_model_option.set_item_metadata(idx, str(m["id"]))
		_model_option.set_item_tooltip(idx, "%s\n%s" % [m["id"], Core.price_phrase(m)])
		if str(m["id"]) == wanted:
			select_index = idx
	_model_option.select(select_index)
	if _models_state.get(kind, "") == "ok":
		_models_note.text = "%d models. Newest first." % list.size()
	_update_price()


func _on_model_selected(index: int) -> void:
	_chosen_model[_mode] = str(_model_option.get_item_metadata(index))
	_update_price()


func _selected_model() -> Dictionary:
	var id := ""
	if _model_option.selected >= 0:
		id = str(_model_option.get_item_metadata(_model_option.selected))
	if id.is_empty():
		return {}
	for m in _models.get(_mode, []):
		if str(m["id"]) == id:
			return m
	return {"id": id, "name": id, "price_usd": -1.0, "unit": ""}


func _update_price() -> void:
	var m := _selected_model()
	if m.is_empty():
		_price_label.text = "GenMagic picks its recommended model. The price depends on the model it uses; it is shown after the result."
	else:
		_price_label.text = "Estimated price: %s" % Core.price_phrase(m)


# ----------------------------------------------------------------------------------------
# Mode
# ----------------------------------------------------------------------------------------

func set_mode(mode: int) -> void:
	_mode_bar.current_tab = mode


func _on_mode_changed(tab: int) -> void:
	_prompts[_mode] = _prompt_edit.text
	_mode = tab
	_apply_mode()


func _apply_mode() -> void:
	_prompt_title.text = PROMPT_LABELS[_mode]
	_prompt_edit.placeholder_text = PLACEHOLDERS[_mode]
	_prompt_edit.text = _prompts[_mode]
	_size_box.visible = _mode == Core.Mode.IMAGE
	_reference_box.visible = _mode == Core.Mode.IMAGE
	_voice_box.visible = _mode == Core.Mode.SPEECH
	_apply_models()


func set_prompt(text: String) -> void:
	_prompt_edit.text = text
	_prompts[_mode] = text


## Picks a model by id (as in the API). An id that is not in the list is still sent.
func select_model(id: String) -> void:
	_chosen_model[_mode] = id
	_apply_models()
	if id.is_empty():
		return
	for i in _model_option.item_count:
		if str(_model_option.get_item_metadata(i)) == id:
			_model_option.select(i)
			_on_model_selected(i)
			return
	_model_option.add_item(id)
	var idx := _model_option.item_count - 1
	_model_option.set_item_metadata(idx, id)
	_model_option.select(idx)
	_on_model_selected(idx)


# ----------------------------------------------------------------------------------------
# Generate
# ----------------------------------------------------------------------------------------

func _collect_params() -> Dictionary:
	var params := {"prompt": _prompt_edit.text, "model": str(_chosen_model.get(_mode, ""))}
	if _mode == Core.Mode.IMAGE:
		params["size"] = str(_size_option.get_item_metadata(maxi(_size_option.selected, 0)))
		params["reference_text"] = _reference_edit.text
	elif _mode == Core.Mode.SPEECH:
		params["voice"] = _voice_edit.text
	return params


## Makes one result, saves it into the project and shows it. Returns the client's result
## dictionary, with "path" added on success.
func generate() -> Dictionary:
	if client.busy:
		return {"ok": false, "code": "busy"}
	var params := _collect_params()
	var mode := _mode
	_clear_status()
	if mode == Core.Mode.IMAGE:
		var ref := Core.resolve_reference(str(params["reference_text"]))
		if not bool(ref["ok"]):
			_show_status(str(ref["error"]), true)
			return {"ok": false, "code": "invalid_input", "error": ref["error"]}
		params["reference"] = ref["value"]
		params.erase("reference_text")
	_set_busy(true)
	var r: Dictionary = await client.generate(mode, params)
	_set_busy(false)
	if not bool(r["ok"]):
		if float(r.get("balance_cents", -1.0)) >= 0.0:
			_set_balance(float(r["balance_cents"]))
		_show_status(str(r["error"]), str(r.get("code", "")) != "cancelled")
		return r

	var stamp := Core.timestamp_stamp(Time.get_datetime_dict_from_system())
	var path := Core.unique_path("%s/%s" % [Core.output_dir(mode), Core.build_file_name(mode, str(params["prompt"]), str(r["ext"]), stamp)])
	var err := Core.save_bytes(path, r["bytes"])
	if err != OK:
		_show_status(Core.save_error_message(err, path), true)
		r["ok"] = false
		r["error"] = Core.save_error_message(err, path)
		return r
	r["path"] = path
	last_saved_path = path
	last_result = r
	request_rescan()
	_show_result(r)
	return r


func _set_busy(busy: bool) -> void:
	_generate_button.disabled = busy
	_cancel_button.visible = busy
	_mode_bar.visible = not busy
	_stage_label.visible = busy
	_progress.visible = busy
	if busy:
		_elapsed = 0.0
		_stage_text = "Starting."
		_progress.max_value = 3
		_progress.value = 0
		_ticker.start()
		_on_tick()
	else:
		_ticker.stop()


func _on_stage_changed(text: String, step: int, steps: int) -> void:
	_stage_text = "Step %d of %d. %s" % [step, steps, text]
	_progress.max_value = steps
	_progress.value = step - 1


func _on_tick() -> void:
	_elapsed += 0.5
	_stage_label.text = "%s (%d s)" % [_stage_text, int(_elapsed)]


func _show_result(r: Dictionary) -> void:
	_result_box.visible = true
	_path_edit.text = last_saved_path
	_cost_label.text = Core.cost_line(float(r["cost_cents"]), float(r["balance_cents"]))
	if float(r["balance_cents"]) >= 0.0:
		_set_balance(float(r["balance_cents"]))
	var is_image := int(r["mode"]) == Core.Mode.IMAGE
	_preview.visible = is_image
	_play_button.visible = not is_image
	_player.stop()
	_play_button.text = "Play"
	var note := ""
	if is_image:
		_preview_texture = _texture_from_bytes(r["bytes"], str(r["ext"]))
		_preview.texture = _preview_texture
	else:
		_player.stream = _stream_from_bytes(r["bytes"], str(r["ext"]))
		_play_button.disabled = _player.stream == null
		if _player.stream == null:
			note = " This format cannot be previewed here; find it in the FileSystem dock."
		note += Core.audio_format_note(str(r["ext"]))
	_show_status("Saved to %s.%s" % [last_saved_path, note], false)


func _texture_from_bytes(bytes: PackedByteArray, ext: String) -> Texture2D:
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match ext:
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _stream_from_bytes(bytes: PackedByteArray, ext: String) -> AudioStream:
	if ext == "mp3":
		var mp3 := AudioStreamMP3.new()
		mp3.data = bytes
		return mp3
	if ext == "wav":
		var wav := Core.parse_wav(bytes)
		if bool(wav["ok"]):
			var s := AudioStreamWAV.new()
			s.format = AudioStreamWAV.FORMAT_16_BITS
			s.mix_rate = int(wav["rate"])
			s.stereo = int(wav["channels"]) == 2
			s.data = wav["data"]
			return s
	return null


func _on_play_pressed() -> void:
	if _player.playing:
		_player.stop()
		_play_button.text = "Play"
	elif _player.stream != null:
		_player.play()
		_play_button.text = "Stop"


# ----------------------------------------------------------------------------------------
# Project
# ----------------------------------------------------------------------------------------

## Asks the editor to scan the project so a new file appears in the FileSystem dock. A scan
## already in progress would ignore the request, so it is repeated once that one finishes.
func request_rescan() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs == null:
		return
	if fs.is_scanning():
		if not fs.filesystem_changed.is_connected(_scan_again):
			fs.filesystem_changed.connect(_scan_again, CONNECT_ONE_SHOT)
	else:
		fs.scan()


func _scan_again() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null and not fs.is_scanning():
		fs.scan()


func _show_in_filesystem() -> void:
	if last_saved_path.is_empty():
		return
	if EditorInterface.has_method("select_file"):
		EditorInterface.call("select_file", last_saved_path)
	var fs_dock := EditorInterface.get_file_system_dock()
	if fs_dock != null and fs_dock.has_method("navigate_to_path"):
		fs_dock.call("navigate_to_path", last_saved_path)


# ----------------------------------------------------------------------------------------
# Messages
# ----------------------------------------------------------------------------------------

func _clear_status() -> void:
	_status_label.visible = false
	_status_label.text = ""


func _show_status(text: String, is_error: bool) -> void:
	_status_label.visible = true
	_status_label.text = text
	var color_name := "error_color" if is_error else "success_color"
	if has_theme_color(color_name, "Editor"):
		_status_label.add_theme_color_override("font_color", get_theme_color(color_name, "Editor"))
