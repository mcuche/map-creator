extends Node

const MapCanvasScript = preload("res://scripts/map_canvas.gd")

const HERO := {"id": "hero", "name": "Hero", "group_id": "cast", "footprint": Vector2i(1, 1), "image_path": "res://assets/sprites/hero.png"}
const TABLE := {"id": "table", "name": "Long table", "group_id": "props", "footprint": Vector2i(2, 1), "image_path": "res://assets/sprites/table.png"}

func _ready() -> void:
	var canvas: BattleMapCanvas = MapCanvasScript.new()
	add_child(canvas)
	canvas.size = Vector2(720, 480)
	var default_outline_width := canvas.selection_outline_width()
	canvas.detected_grid_origin = Vector2.ZERO
	canvas.detected_grid_spacing = Vector2(1.0 / 28.0, 1.0 / 24.0)
	canvas.detected_grid_cells = Vector2i(28, 24)
	canvas.grid_mode = BattleMapCanvas.GRID_DETECTED
	if canvas.selection_outline_width() >= default_outline_width:
		_fail("Selection outline did not become thinner for smaller detected cells")
		return
	canvas._clear_detected_grid()
	canvas.grid_mode = BattleMapCanvas.GRID_SQUARE
	if canvas.manual_grid_cells != Vector2i(14, 10):
		_fail("Manual grid did not initialize with the 14×10 default")
		return
	if canvas.closest_ideal_manual_grid(1) != Vector2i(16, 11):
		_fail("Add Grid did not find the closest larger ideal 3:2 grid")
		return
	if canvas.closest_ideal_manual_grid(-1) != Vector2i(13, 9):
		_fail("Remove Grid did not find the closest smaller ideal 3:2 grid")
		return
	if not canvas.adjust_manual_grid(1) or canvas.manual_grid_cells != Vector2i(16, 11):
		_fail("Add Grid did not apply the closest larger ideal grid")
		return
	if not canvas.adjust_manual_grid(-1) or canvas.manual_grid_cells != Vector2i(15, 10):
		_fail("Remove Grid did not apply the next smaller ideal grid")
		return
	if not canvas.set_manual_grid_size(18, 12):
		_fail("Valid manual grid dimensions were rejected")
		return
	if canvas._active_map_cells() != Vector2i(18, 12):
		_fail("Manual grid dimensions do not drive snapping bounds")
		return
	if absf(canvas.manual_cell_aspect_ratio() - 1.0) > 0.001:
		_fail("An 18×12 grid on a 720×480 map was not recognized as square")
		return
	if not canvas.set_builtin_background("res://assets/landscapes/forest.png"):
		_fail("Built-in forest landscape could not be loaded")
		return
	if canvas.background_texture == null or canvas.background_path != "res://assets/landscapes/forest.png":
		_fail("Built-in landscape state was not applied")
		return
	if canvas.has_detected_grid() or canvas.grid_mode != BattleMapCanvas.GRID_SQUARE:
		_fail("Built-in landscape did not retain manual-grid mode")
		return
	canvas.pieces = [
		{"instance_id": 1, "entry": HERO.duplicate(true), "cell": Vector2i(2, 2), "rotation": 0, "mirrored": false, "layer": 0},
		{"instance_id": 2, "entry": TABLE.duplicate(true), "cell": Vector2i(5, 4), "rotation": 0, "mirrored": false, "layer": 1}
	]
	if canvas.context_menu == null or canvas.context_menu_buttons.size() != 3:
		_fail("Object context menu was not created with three actions")
		return
	if canvas.context_menu_buttons[0].text != "Mirror" or canvas.context_menu_buttons[1].text != "Rotate" or canvas.context_menu_buttons[2].text != "Remove":
		_fail("Object context menu actions are incorrect")
		return
	if canvas.context_menu_buttons[2].get_theme_color("font_color") != Color("d67a73"):
		_fail("Object context menu Remove action is not red")
		return
	var custom_grid_color := Color("4f8fd4")
	canvas.set_grid_color(custom_grid_color)
	if canvas.set_manual_grid_size(6, 4):
		_fail("Grid reduction allowed an existing object to fall outside its bounds")
		return
	if canvas._can_occupy(Vector2i(2, 2), Vector2i.ONE):
		_fail("Allowed a second object in an occupied 1×1 cell")
		return
	if canvas._can_occupy(Vector2i(6, 4), Vector2i.ONE):
		_fail("Allowed an object inside a table's 2×1 footprint")
		return
	if not canvas._can_occupy(Vector2i(7, 4), Vector2i.ONE):
		_fail("Rejected a free cell adjacent to a multi-cell footprint")
		return
	canvas.selected_id = 1
	var blocked_target := Vector2i(5, 4)
	if canvas._can_occupy(blocked_target, Vector2i.ONE, canvas.selected_id):
		_fail("An existing object could enter another object's footprint while dragging")
		return
	canvas.selected_id = 2
	canvas.mirror_selected()
	if not bool(canvas.get_selected_piece()["mirrored"]):
		_fail("Mirror did not update the selected piece")
		return
	var saved := canvas.serialize_state()
	if int(saved["manual_grid_columns"]) != 18 or int(saved["manual_grid_rows"]) != 12:
		_fail("Manual grid dimensions were not serialized")
		return
	var restored: BattleMapCanvas = MapCanvasScript.new()
	add_child(restored)
	restored.load_state(saved)
	if not restored.grid_color.is_equal_approx(custom_grid_color):
		_fail("Custom grid line color was not restored from the saved map")
		return
	if not bool(saved["pieces"][1]["mirrored"]) or saved["pieces"][1]["entry"]["id"] != "table":
		_fail("Mirror state was not serialized")
		return
	var legacy := saved.duplicate(true)
	legacy["version"] = 1
	legacy["pieces"] = [{"instance_id": 9, "asset_id": "hero", "cell_x": 1, "cell_y": 1, "rotation": 0, "mirrored": false, "layer": 0}]
	var legacy_restored: BattleMapCanvas = MapCanvasScript.new()
	add_child(legacy_restored)
	legacy_restored.load_state(legacy)
	var legacy_entry: Dictionary = legacy_restored.pieces[0]["entry"]
	if legacy_entry["name"] != "Hero" or legacy_entry["footprint"] != Vector2i.ONE \
			or legacy_entry["image_path"] != HERO["image_path"]:
		_fail("Legacy catalog ID did not restore its frozen v1 definition")
		return
	legacy["pieces"] = [{"instance_id": 10, "asset_id": "unknown", "cell_x": 1, "cell_y": 1}]
	legacy_restored.load_state(legacy)
	if legacy_restored.pieces[0]["entry"]["name"] != "Missing catalog entry":
		_fail("Unknown legacy ID did not use a missing-entry placeholder")
		return
	canvas._on_context_action(BattleMapCanvas.CONTEXT_MIRROR)
	if bool(canvas.get_selected_piece()["mirrored"]):
		_fail("Context menu Mirror did not invoke the selected-object action")
		return
	canvas.rotate_selected(-1)
	if int(canvas.get_selected_piece()["rotation"]) != 270:
		_fail("Rotate left did not turn the selected object counterclockwise")
		return
	canvas.rotate_selected(1)
	if int(canvas.get_selected_piece()["rotation"]) != 0:
		_fail("Rotate right did not turn the selected object clockwise")
		return
	canvas.detected_grid_origin = Vector2(0.1, 0.1)
	canvas.detected_grid_spacing = Vector2(0.05, 0.05)
	canvas.detected_grid_cells = Vector2i(16, 12)
	canvas.set_grid_mode(BattleMapCanvas.GRID_HIDDEN)
	if canvas.grid_mode != BattleMapCanvas.GRID_DETECTED:
		_fail("A detected grid could be replaced through grid settings")
		return
	canvas._clear_detected_grid()
	var pointer := Vector2(360, 240)
	var cell_before := canvas._local_to_cell(pointer)
	canvas.zoom_at(pointer, 2.0)
	if canvas._local_to_cell(pointer) != cell_before:
		_fail("Pointer-centered zoom changed the cell beneath the pointer")
		return
	if not is_equal_approx(canvas.zoom_level, 2.0):
		_fail("Zoom level was not applied")
		return
	canvas.zoom_at(pointer, 8.0)
	if not is_equal_approx(canvas.zoom_level, BattleMapCanvas.MAX_ZOOM):
		_fail("Zoom exceeded the displayed 100% maximum")
		return
	canvas.zoom_at(pointer, 0.1)
	if not is_equal_approx(canvas.zoom_level, BattleMapCanvas.MIN_ZOOM):
		_fail("Zoom went below the displayed 50% minimum")
		return
	canvas.reset_zoom()
	if not is_equal_approx(canvas.zoom_level, 1.0) or canvas.view_offset != Vector2.ZERO:
		_fail("Fit did not reset the map view")
		return
	var export_path := "user://export-resolution-test.png"
	var export_error := await canvas.export_visible_png(export_path)
	if export_error != ERR_UNAVAILABLE:
		_fail("Headless export should return ERR_UNAVAILABLE, got %d" % export_error)
		return
	print("Occupancy and mirror tests passed")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
