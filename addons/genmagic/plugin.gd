@tool
extends EditorPlugin
## GenMagic for Godot: adds the GenMagic dock to the editor.
##
## Godot 4.6 and later add docks with EditorDock and add_dock(); older 4.x versions use
## add_control_to_dock(). Both are supported here, chosen at run time, so one copy of the
## plugin works from Godot 4.2 on.

const Core = preload("core.gd")
const Dock = preload("dock.gd")

## The right-hand side, upper left slot (where the Inspector lives). The same number in both APIs.
const SLOT_RIGHT_UL := 4

var _content: Control = null
var _editor_dock: Control = null


func _enter_tree() -> void:
	_register_settings()
	_content = Dock.new()
	if ClassDB.class_exists("EditorDock") and has_method("add_dock"):
		_editor_dock = ClassDB.instantiate("EditorDock") as Control
		_editor_dock.set("title", "GenMagic")
		_editor_dock.set("default_slot", SLOT_RIGHT_UL)
		var icon := _dock_icon()
		if icon != null:
			_editor_dock.set("dock_icon", icon)
		_editor_dock.add_child(_content)
		call("add_dock", _editor_dock)
	else:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _content)


func _exit_tree() -> void:
	if _editor_dock != null:
		call("remove_dock", _editor_dock)
		_editor_dock.queue_free()
		_editor_dock = null
		_content = null
	elif _content != null:
		remove_control_from_docks(_content)
		_content.queue_free()
		_content = null


## Describes the key setting so the Editor Settings window lists it with the characters hidden.
## The key itself is never put in the project.
func _register_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(Core.SETTING_API_KEY):
		settings.set_setting(Core.SETTING_API_KEY, "")
	settings.set_initial_value(Core.SETTING_API_KEY, "", false)
	settings.add_property_info({"name": Core.SETTING_API_KEY, "type": TYPE_STRING, "hint": PROPERTY_HINT_PASSWORD})


## The brand mark at the size of a dock tab icon, or null if it cannot be read. The PNG is
## decoded from its bytes, so it works before Godot has imported the file.
func _dock_icon() -> Texture2D:
	var script: Script = get_script()
	var path: String = script.resource_path.get_base_dir() + "/icon.png"
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK or img.is_empty():
		return null
	var size := int(round(16.0 * EditorInterface.get_editor_scale()))
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)
