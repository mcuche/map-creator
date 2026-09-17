extends Node

const MainScene = preload("res://main.tscn")
const SETTINGS_PATH := "user://display_settings.cfg"

var _had_settings := false
var _original_settings := ""


func _ready() -> void:
	_had_settings = FileAccess.file_exists(SETTINGS_PATH)
	if _had_settings:
		_original_settings = FileAccess.get_file_as_string(SETTINGS_PATH)
	var editor := MainScene.instantiate()
	get_tree().root.add_child.call_deferred(editor)
	await get_tree().process_frame
	for choice in [100, 125, 150, 200]:
		if editor._effective_ui_scale(choice, Vector2i(3840, 2160), 3840) != choice:
			_fail("Manual %d%% was not available in a 4K window" % choice)
			return
	if editor._effective_ui_scale(200, Vector2i(1280, 720), 3840) != 100 or editor._effective_ui_scale(200, Vector2i(2560, 1440), 3840) != 200:
		_fail("Manual scale did not respect the 1280x720 logical minimum")
		return
	if editor._effective_ui_scale(150, Vector2i(1920, 1080), 3840) != 150 or editor._effective_ui_scale(150, Vector2i(1600, 900), 3840) != 125:
		_fail("Manual scale did not step down to the largest fitting value")
		return
	if OS.get_name() == "Windows":
		for width in [2559, 2560, 3199, 3200, 3839, 3840]:
			var expected := 100 if width < 2560 else 125 if width < 3200 else 150 if width < 3840 else 200
			if editor._auto_ui_scale(width) != expected:
				_fail("Auto scale threshold failed at %dpx" % width)
				return
	get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	editor._on_ui_scale_selected(4)
	if editor.preferred_ui_scale != 200 or editor.effective_ui_scale != 100 or not editor.ui_scale_effective.visible:
		_fail("The scale preference was not retained when the window limits it")
		return
	var reloaded := MainScene.instantiate()
	get_tree().root.add_child.call_deferred(reloaded)
	await get_tree().process_frame
	if reloaded.preferred_ui_scale != 200 or reloaded.effective_ui_scale != 100:
		_fail("The saved preference did not reload")
		return
	var config := ConfigFile.new()
	config.set_value("display", "ui_scale", "invalid")
	if config.save(SETTINGS_PATH) != OK:
		_fail("Could not write invalid-settings fixture")
		return
	reloaded._load_display_settings()
	if reloaded.preferred_ui_scale != 0 or reloaded.ui_scale_select.selected != 0:
		_fail("An invalid setting did not fall back to Auto")
		return
	_restore_settings()
	print("UI scale tests passed")
	get_tree().quit()


func _restore_settings() -> void:
	if _had_settings:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(_original_settings)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _fail(message: String) -> void:
	_restore_settings()
	push_error(message)
	get_tree().quit(1)
