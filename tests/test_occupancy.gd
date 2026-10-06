extends Node

const MapCanvasScript = preload("res://scripts/map_canvas.gd")

const KNIGHT := {"id": "knight", "name": "Knight", "group_id": "cast", "footprint": Vector2i(1, 1), "image_path": "res://assets/sprites/knight.png"}
const TABLE := {"id": "table", "name": "Long table", "group_id": "props", "footprint": Vector2i(2, 1), "image_path": "res://assets/sprites/table.png"}

func _ready() -> void:
	if not _test_context_selection():
		return
	if not _test_adapter():
		return
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
	canvas.place_piece(KNIGHT, Vector2i(2, 2))
	canvas.place_piece(TABLE, Vector2i(5, 4))
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
	canvas.select_at(Vector2i(5, 4))
	canvas.mirror_selected()
	if not bool(canvas.get_selected_piece()["mirrored"]):
		_fail("Mirror did not update the selected piece")
		return
	var save_result := canvas.serialize_state()
	if save_result.has("error"):
		_fail("Could not serialize placed pieces: %s" % save_result["error"])
		return
	var saved: Dictionary = save_result["data"]
	if int(saved["manual_grid_columns"]) != 18 or int(saved["manual_grid_rows"]) != 12:
		_fail("Manual grid dimensions were not serialized")
		return
	var restored: BattleMapCanvas = MapCanvasScript.new()
	add_child(restored)
	if not restored.load_state(saved).is_empty():
		_fail("Saved map was rejected")
		return
	if not restored.grid_color.is_equal_approx(custom_grid_color):
		_fail("Custom grid line color was not restored from the saved map")
		return
	if not bool(saved["pieces"][1]["mirrored"]) or saved["pieces"][1]["entry"]["id"] != "table":
		_fail("Mirror state was not serialized")
		return
	canvas.context_menu_buttons[0].pressed.emit()
	if bool(canvas.get_selected_piece()["mirrored"]):
		_fail("Context menu Mirror did not invoke the selected-object action")
		return
	canvas.context_menu_buttons[1].pressed.emit()
	if int(canvas.get_selected_piece()["rotation"]) != 90:
		_fail("Context menu Rotate did not invoke the selected-object action")
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

func _test_context_selection() -> bool:
	var canvas: BattleMapCanvas = MapCanvasScript.new()
	add_child(canvas)
	canvas.size = Vector2(720, 480)
	var table := TABLE.duplicate(true)
	table["image_path"] = ""
	var knight := KNIGHT.duplicate(true)
	knight["image_path"] = ""
	canvas.place_piece(table, Vector2i(2, 2))
	canvas.place_piece(knight, Vector2i(6, 6))
	var retained := canvas.stage_view()
	var counts := {"selection": 0, "state": 0}
	canvas.selection_changed.connect(func(_piece): counts["selection"] += 1)
	canvas.state_changed.connect(func(): counts["state"] += 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.position = _cell_pointer(canvas, Vector2i.ZERO)
	press.pressed = true
	canvas._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 0)
	motion.position = press.position + motion.relative
	canvas._gui_input(motion)
	press.pressed = false
	canvas._gui_input(press)
	if canvas.stage_view() != retained or canvas.context_menu.visible or counts != {"selection": 0, "state": 0}:
		_fail("Right-dragging empty space changed selection or opened the object menu")
		return false
	press.pressed = true
	canvas._gui_input(press)
	press.pressed = false
	canvas._gui_input(press)
	if canvas.get_selected_piece() != null or canvas.context_menu.visible or counts != {"selection": 1, "state": 0} \
			or canvas.stage_view()["pieces"] != retained["pieces"] \
			or canvas.can_undo() != retained["can_undo"] or canvas.can_redo() != retained["can_redo"]:
		_fail("Right-clicking empty space did not clear selection without editing pieces or opening the object menu")
		return false
	# The second occupied cell of a table must still select it and open its menu.
	press.position = _cell_pointer(canvas, Vector2i(3, 2))
	press.pressed = true
	canvas._gui_input(press)
	press.pressed = false
	canvas._gui_input(press)
	if canvas.get_selected_piece() == null or canvas.get_selected_piece()["entry"]["id"] != "table" \
			or not canvas.context_menu.visible or counts != {"selection": 2, "state": 0}:
		_fail("Right-clicking a piece did not select it and open its menu once")
		return false
	canvas.context_menu.hide()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = _cell_pointer(canvas, Vector2i.ZERO)
	press.pressed = true
	canvas._gui_input(press)
	press.pressed = false
	canvas._gui_input(press)
	if canvas.get_selected_piece() != null or counts != {"selection": 3, "state": 0} \
			or canvas.stage_view()["pieces"] != retained["pieces"]:
		_fail("Left-clicking empty space did not clear selection without editing pieces")
		return false
	canvas.queue_free()
	return true

func _test_adapter() -> bool:
	var canvas: BattleMapCanvas = MapCanvasScript.new()
	add_child(canvas)
	canvas.size = Vector2(720, 480)
	var counts := {"selection": 0, "state": 0, "placement": 0, "rejected": 0}
	canvas.selection_changed.connect(func(_piece): counts["selection"] += 1)
	canvas.state_changed.connect(func(): counts["state"] += 1)
	canvas.placement_finished.connect(func(): counts["placement"] += 1)
	canvas.action_rejected.connect(func(_message): counts["rejected"] += 1)
	var entry := KNIGHT.duplicate(true)
	entry["image_path"] = ""
	var data := {"type": "catalog_entry", "entry": entry}
	var pointer := _cell_pointer(canvas, Vector2i(2, 2))
	if not canvas._can_drop_data(pointer, data):
		_fail("Drop preview rejected an empty target")
		return false
	canvas._drop_data(pointer, data)
	if counts != {"selection": 1, "state": 1, "placement": 1, "rejected": 0}:
		_fail("Placement did not publish each signal once")
		return false
	if canvas._can_drop_data(pointer, data):
		_fail("Drop preview accepted an occupied target")
		return false
	canvas._drop_data(pointer, data)
	if canvas.stage_view()["pieces"].size() != 1 or counts["state"] != 1 or counts["rejected"] != 1:
		_fail("Drop placement disagreed with its preview")
		return false
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	canvas._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = _cell_pointer(canvas, Vector2i(3, 3))
	canvas._gui_input(motion)
	if canvas.get_selected_piece()["cell"] != Vector2i(3, 3) or counts["state"] != 1:
		_fail("Pointer movement failed or emitted committed state during preview")
		return false
	press.pressed = false
	canvas._gui_input(press)
	if canvas.stage_view()["moving"] or counts["state"] != 2:
		_fail("Pointer release did not commit the drag once")
		return false
	canvas.begin_move(Vector2i(3, 3))
	canvas.update_move(Vector2i(4, 4))
	var before: int = counts["state"]
	var selection_before: int = counts["selection"]
	canvas.mirror_selected()
	if counts["state"] != before + 1 or counts["selection"] != selection_before + 1 or canvas.stage_view()["moving"]:
		_fail("Interrupted movement published intermediate state")
		return false
	canvas.begin_move(Vector2i(4, 4))
	canvas.update_move(Vector2i(5, 5))
	canvas.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if canvas.stage_view()["moving"] or counts["state"] != before + 2:
		_fail("Window focus loss did not finish movement")
		return false
	canvas.begin_move(Vector2i(5, 5))
	canvas.update_move(Vector2i(6, 6))
	var retained := canvas.stage_view()
	if canvas.set_manual_grid_size(4, 4) or canvas.stage_view() != retained:
		_fail("Rejected grid reduction changed pending movement")
		return false
	before = counts["state"]
	if not canvas.set_manual_grid_size(16, 12) or canvas.stage_view()["moving"] or counts["state"] != before + 1:
		_fail("Successful grid change did not finish movement once")
		return false
	canvas.begin_move(Vector2i(6, 6))
	canvas.update_move(Vector2i(7, 7))
	before = counts["state"]
	canvas.set_builtin_background("")
	if canvas.stage_view()["moving"] or counts["state"] != before + 1:
		_fail("Landscape change did not finish movement once")
		return false
	canvas.context_menu_buttons[2].pressed.emit()
	if not canvas.stage_view()["pieces"].is_empty() or canvas.get_selected_piece() != null:
		_fail("Context Remove did not reach editing interface")
		return false
	canvas.queue_free()
	return true

func _cell_pointer(canvas: BattleMapCanvas, cell: Vector2i) -> Vector2:
	return canvas._grid_origin_pixels() + (Vector2(cell) + Vector2(0.5, 0.5)) * canvas._cell_size()
