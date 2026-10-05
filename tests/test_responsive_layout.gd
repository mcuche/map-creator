extends Node

const MainScene = preload("res://main.tscn")
const TestSupport = preload("res://tests/cast_props_test_support.gd")

var _support := TestSupport.new()


func _ready() -> void:
	if ProjectSettings.get_setting("display/window/stretch/mode") != "disabled":
		_fail("The editor must use the available window width")
		return
	var editor := MainScene.instantiate()
	get_tree().root.add_child.call_deferred(editor)
	await get_tree().process_frame
	var fixture := _support.create_catalog_fixture()
	if not fixture["ok"]:
		_fail("Could not create catalog fixture: %s" % fixture["errors"])
		return
	var loaded: Dictionary = editor.cast_props_library.initialize(fixture["catalog_path"])
	if not loaded["ok"]:
		_fail("Fixture catalog did not load: %s" % loaded["errors"])
		return
	editor.preferred_ui_scale = 100
	editor._update_ui_scale()
	if not await _check_layout(editor, Vector2i(1280, 720), 2, 280):
		return
	editor.selection_name.text = "A very long imported character name that should wrap inside Stage Controls"
	await get_tree().process_frame
	if editor.selection_name.get_line_count() < 2 or editor.stage_controls.size.x > 260:
		_fail("Long selection names do not wrap inside the compact rail")
		return
	editor.stage_controls_scroll.ensure_control_visible(editor.ui_scale_select)
	await get_tree().process_frame
	if editor.ui_scale_select.get_global_rect().end.y > editor.stage_controls_scroll.get_global_rect().end.y + 1.0:
		_fail("UI Scale cannot be reached by scrolling at 720px height")
		return
	if not await _check_layout(editor, Vector2i(1600, 900), 3, 400):
		return
	if not await _check_layout(editor, Vector2i(1366, 768), 2, 280):
		return
	if not await _check_layout(editor, Vector2i(1440, 900), 3, 400):
		return
	var wide_threshold := ceili(CastPropsLibrary.WIDE_WIDTH + editor.stage_controls.get_combined_minimum_size().x + editor.map_canvas.get_combined_minimum_size().x + 18)
	if not await _check_layout(editor, Vector2i(wide_threshold - 1, 900), 2, 280):
		return
	if not await _check_layout(editor, Vector2i(wide_threshold, 900), 3, 400):
		return
	if not await _check_layout(editor, Vector2i(1920, 1080), 3, 400):
		return
	if not await _check_layout(editor, Vector2i(2560, 1440), 3, 400):
		return
	if not await _check_layout(editor, Vector2i(3840, 2160), 3, 400):
		return
	print("Responsive layout tests passed")
	get_tree().quit()


func _check_layout(editor: Control, window_size: Vector2i, columns: int, rail_width: int) -> bool:
	get_tree().root.size = window_size
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var library: CastPropsLibrary = editor.cast_props_library
	if editor.size.x != window_size.x:
		_fail("Editor does not fill the %dpx window" % window_size.x)
		return false
	if library.size.x != rail_width:
		_fail("Cast & Props width is %dpx at %dpx, expected %dpx" % [library.size.x, window_size.x, rail_width])
		return false
	for action in ["OPEN FOLDER", "RELOAD"]:
		var button := TestSupport.find_control_by_text(library, "Button", action)
		if button == null or not button.is_visible_in_tree():
			_fail("Cast & Props header action %s is missing at %dpx" % [action, window_size.x])
			return false
		if not library.get_global_rect().grow(1.0).encloses(button.get_global_rect()):
			_fail("Cast & Props header actions overflow at %dpx" % window_size.x)
			return false
	var commands: HBoxContainer = editor.get_child(0).get_child(0).get_child(0)
	if commands.get_global_rect().end.x > editor.get_global_rect().end.x + 1.0:
		_fail("Command bar overflows at %dpx" % window_size.x)
		return false
	var cards: Array[Control] = []
	for entry_name in TestSupport.CAST_NAMES:
		var card := TestSupport.find_control_by_tooltip(library, "Button", "Drag %s onto the map" % entry_name)
		if card == null or not card.is_visible_in_tree():
			_fail("Fixture card %s is missing at %dpx" % [entry_name, window_size.x])
			return false
		cards.append(card)
	var first_rect := cards[0].get_global_rect()
	for index in range(cards.size()):
		var card_rect := cards[index].get_global_rect()
		if index < columns:
			if not is_equal_approx(card_rect.position.y, first_rect.position.y) \
					or (index > 0 and card_rect.position.x < cards[index - 1].get_global_rect().end.x):
				_fail("Cards did not share a row of %d columns at %dpx" % [columns, window_size.x])
				return false
		else:
			var previous_row_rect := cards[index - columns].get_global_rect()
			if card_rect.position.y < previous_row_rect.end.y \
					or not is_equal_approx(card_rect.position.x, previous_row_rect.position.x):
				_fail("Cards did not wrap after %d columns at %dpx" % [columns, window_size.x])
				return false
	if editor.map_canvas.size.x < 720:
		_fail("Stage became narrower than its 720px minimum at %dpx" % window_size.x)
		return false
	if editor.stage_controls.size.x > 260 or editor.stage_controls.get_global_rect().end.x > editor.get_global_rect().end.x + 1.0:
		_fail("Stage Controls exceeds its 260px rail at %dpx" % window_size.x)
		return false
	if editor.stage_controls_scroll.get_v_scroll_bar().max_value <= editor.stage_controls_scroll.size.y and window_size.y == 720:
		_fail("Stage Controls cannot scroll at 720px height")
		return false
	return true


func _exit_tree() -> void:
	# Pending draw calls may still need the fixture PNGs after quit() is requested.
	_support.cleanup()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
