class_name BattleMapCanvas
extends Control

signal selection_changed(piece)
signal state_changed
signal placement_finished
signal grid_detection_finished(result)
signal action_rejected(message)
signal zoom_changed(value)

const DEFAULT_MAP_CELLS := Vector2i(14, 10)
const MIN_MANUAL_GRID_SIZE := 4
const MAX_MANUAL_GRID_SIZE := 100
const IDEAL_CELL_RATIO_MIN := 0.95
const IDEAL_CELL_RATIO_MAX := 1.05
const GRID_SQUARE := 0
const GRID_DETECTED := 1
const GRID_HIDDEN := 2
# The fitted full-map view is presented as 25%; 100% is 4× magnification.
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.0
const ZOOM_FACTOR := 1.15
const PAN_DRAG_THRESHOLD := 6.0
const CONTEXT_MENU_SIZE := Vector2i(168, 136)
const CONTEXT_MIRROR := 0
const CONTEXT_ROTATE := 1
const CONTEXT_REMOVE := 2
const MAP_FILE_VERSION := 3
const MAX_EMBEDDED_IMAGE_BYTES := 2 * 1024 * 1024
const MAX_EMBEDDED_IMAGES_BYTES := 32 * 1024 * 1024
const MAX_EMBEDDED_IMAGE_DIMENSION := 4096
const GridDetectorScript = preload("res://scripts/grid_detector.gd")

var piece_textures := {}
var embedded_images := {}
var pieces: Array = []
var selected_id := -1
var next_id := 1
var grid_mode := GRID_SQUARE
var grid_opacity := 0.30
var grid_color := Color(0.95, 0.91, 0.76, 1.0)
var manual_grid_cells := DEFAULT_MAP_CELLS
var background_texture: Texture2D
var background_path := ""
var detected_grid_origin := Vector2.ZERO
var detected_grid_spacing := Vector2.ZERO
var detected_grid_end := Vector2.ZERO
var detected_grid_cells := Vector2i.ZERO
var detected_grid_confidence := 0.0
var zoom_level := 1.0
var view_offset := Vector2.ZERO

var undo_stack: Array = []
var redo_stack: Array = []
var dragging := false
var drag_offset := Vector2i.ZERO
var drag_start_position := Vector2i.ZERO
var drag_before: Dictionary = {}
var panning := false
var right_press_position := Vector2.ZERO
var right_pan_moved := false
var context_menu: PopupPanel
var context_menu_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(720, 480)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	context_menu = PopupPanel.new()
	context_menu.size = CONTEXT_MENU_SIZE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	context_menu.add_child(margin)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	margin.add_child(actions)
	_add_context_action(actions, "Mirror", CONTEXT_MIRROR)
	_add_context_action(actions, "Rotate", CONTEXT_ROTATE)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(separator)
	_add_context_action(actions, "Remove", CONTEXT_REMOVE, Color("d67a73"))
	add_child(context_menu)
	queue_redraw()

func _add_context_action(parent: VBoxContainer, label: String, action_id: int, color := Color.WHITE) -> void:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = label
	button.custom_minimum_size = Vector2(160, 34)
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("hover", _context_row_style(Color("293844"), Color("42617a")))
	button.add_theme_stylebox_override("pressed", _context_row_style(Color("26375b"), Color("3557a8")))
	button.add_theme_stylebox_override("focus", _context_row_style(Color("293844"), Color("f0c96b")))
	button.pressed.connect(_on_context_action.bind(action_id))
	parent.add_child(button)
	context_menu_buttons.append(button)

func _context_row_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func set_background(path: String) -> Dictionary:
	var loaded := Image.load_from_file(path)
	if not loaded.is_empty():
		reset_zoom()
		background_texture = ImageTexture.create_from_image(loaded)
		background_path = path
		var detection: Dictionary = GridDetectorScript.detect(loaded)
		if detection.get("found", false):
			detected_grid_origin = detection["origin"]
			detected_grid_spacing = detection["spacing"]
			detected_grid_cells = detection["cells"]
			detected_grid_end = detection.get("end", detected_grid_origin + detected_grid_spacing * Vector2(detected_grid_cells))
			detected_grid_confidence = float(detection["confidence"])
			grid_mode = GRID_DETECTED
		else:
			_clear_detected_grid()
			grid_mode = GRID_SQUARE
		queue_redraw()
		state_changed.emit()
		grid_detection_finished.emit(detection)
		return detection.merged({"loaded": true})
	return {"loaded": false, "found": false, "reason": "Image could not be loaded"}

func set_builtin_background(path: String) -> bool:
	if path.is_empty():
		reset_zoom()
		background_texture = null
		background_path = ""
		_clear_detected_grid()
		grid_mode = GRID_SQUARE
		queue_redraw()
		state_changed.emit()
		return true
	var texture := load(path) as Texture2D
	if texture == null:
		return false
	reset_zoom()
	background_texture = texture
	background_path = path
	_clear_detected_grid()
	grid_mode = GRID_SQUARE
	queue_redraw()
	state_changed.emit()
	return true

func set_grid_mode(mode: int) -> void:
	if has_detected_grid():
		grid_mode = GRID_DETECTED
	else:
		grid_mode = GRID_HIDDEN if mode == GRID_HIDDEN else GRID_SQUARE
	queue_redraw()
	state_changed.emit()

func set_grid_opacity(value: float) -> void:
	grid_opacity = clampf(value, 0.05, 0.75)
	queue_redraw()

func set_grid_color(value: Color) -> void:
	grid_color = Color(value.r, value.g, value.b, 1.0)
	queue_redraw()
	state_changed.emit()

func set_manual_grid_size(columns: int, rows: int) -> bool:
	if has_detected_grid():
		return false
	var requested := Vector2i(
		clampi(columns, MIN_MANUAL_GRID_SIZE, MAX_MANUAL_GRID_SIZE),
		clampi(rows, MIN_MANUAL_GRID_SIZE, MAX_MANUAL_GRID_SIZE)
	)
	for piece in pieces:
		var footprint := _piece_footprint(piece)
		var cell: Vector2i = piece["cell"]
		if cell.x + footprint.x > requested.x or cell.y + footprint.y > requested.y:
			action_rejected.emit("Grid cannot be reduced because an object would fall outside it")
			return false
	manual_grid_cells = requested
	queue_redraw()
	state_changed.emit()
	return true

func manual_cell_aspect_ratio() -> float:
	var map_rect := _landscape_rect()
	var cell_size := Vector2(map_rect.size.x / manual_grid_cells.x, map_rect.size.y / manual_grid_cells.y)
	return cell_size.x / maxf(cell_size.y, 0.001)

func selection_outline_width() -> float:
	var cell_size := _cell_size()
	return clampf(minf(cell_size.x, cell_size.y) * 0.06, 1.0, 3.0)

func closest_ideal_manual_grid(direction: int) -> Vector2i:
	var step_direction := signi(direction)
	if step_direction == 0:
		return manual_grid_cells
	var minimum := Vector2i(MIN_MANUAL_GRID_SIZE, MIN_MANUAL_GRID_SIZE)
	for piece in pieces:
		var footprint := _piece_footprint(piece)
		var cell: Vector2i = piece["cell"]
		minimum.x = maxi(minimum.x, cell.x + footprint.x)
		minimum.y = maxi(minimum.y, cell.y + footprint.y)
	var column_start := manual_grid_cells.x + step_direction
	var row_start := manual_grid_cells.y + step_direction
	var column_end := MAX_MANUAL_GRID_SIZE if step_direction > 0 else minimum.x
	var row_end := MAX_MANUAL_GRID_SIZE if step_direction > 0 else minimum.y
	if column_start < minimum.x or row_start < minimum.y \
			or column_start > MAX_MANUAL_GRID_SIZE or row_start > MAX_MANUAL_GRID_SIZE:
		return manual_grid_cells
	var map_rect := _landscape_rect()
	var map_aspect := map_rect.size.x / maxf(map_rect.size.y, 0.001)
	var best := manual_grid_cells
	var best_distance := INF
	var best_error := INF
	for columns in range(column_start, column_end + step_direction, step_direction):
		for rows in range(row_start, row_end + step_direction, step_direction):
			var cell_ratio := map_aspect * float(rows) / float(columns)
			if cell_ratio < IDEAL_CELL_RATIO_MIN or cell_ratio > IDEAL_CELL_RATIO_MAX:
				continue
			var distance := absi(columns - manual_grid_cells.x) + absi(rows - manual_grid_cells.y)
			var error := absf(cell_ratio - 1.0)
			if distance < best_distance or (distance == best_distance and error < best_error):
				best = Vector2i(columns, rows)
				best_distance = distance
				best_error = error
	return best

func adjust_manual_grid(direction: int) -> bool:
	var target := closest_ideal_manual_grid(direction)
	if target == manual_grid_cells:
		action_rejected.emit("No closer ideal grid size is available")
		return false
	return set_manual_grid_size(target.x, target.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(event.position, zoom_level * ZOOM_FACTOR)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(event.position, zoom_level / ZOOM_FACTOR)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				panning = true
				right_pan_moved = false
				right_press_position = event.position
			else:
				panning = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				if not right_pan_moved:
					_open_object_context_menu(right_press_position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _local_to_cell(event.position)
			if event.pressed:
				var hit = _piece_at(cell)
				if hit != null:
					selected_id = hit["instance_id"]
					dragging = true
					drag_offset = cell - hit["cell"]
					drag_start_position = hit["cell"]
					drag_before = _snapshot()
					selection_changed.emit(hit)
				else:
					selected_id = -1
					selection_changed.emit(null)
				queue_redraw()
			else:
				if dragging:
					var selected = get_selected_piece()
					if selected != null and selected["cell"] != drag_start_position:
						if _can_occupy(selected["cell"], _piece_footprint(selected), selected_id):
							undo_stack.append(drag_before)
							redo_stack.clear()
							state_changed.emit()
						else:
							selected["cell"] = drag_start_position
							selection_changed.emit(selected)
							action_rejected.emit("That space is already occupied")
				dragging = false
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		if panning:
			if not right_pan_moved and event.position.distance_to(right_press_position) >= PAN_DRAG_THRESHOLD:
				right_pan_moved = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			if right_pan_moved:
				view_offset += event.relative
				_clamp_view_offset()
				queue_redraw()
			accept_event()
		elif dragging:
			var selected = get_selected_piece()
			if selected != null:
				var target := _clamp_cell(_local_to_cell(event.position) - drag_offset, _piece_footprint(selected))
				if _can_occupy(target, _piece_footprint(selected), selected_id):
					selected["cell"] = target
					selection_changed.emit(selected)
					queue_redraw()
			accept_event()

func _open_object_context_menu(local_position: Vector2) -> void:
	var hit = _piece_at(_local_to_cell(local_position))
	if hit == null:
		return
	selected_id = int(hit["instance_id"])
	selection_changed.emit(hit)
	queue_redraw()
	context_menu.position = Vector2i(get_screen_position() + local_position)
	context_menu.size = CONTEXT_MENU_SIZE
	context_menu.popup()

func _on_context_action(action_id: int) -> void:
	context_menu.hide()
	match action_id:
		CONTEXT_MIRROR:
			mirror_selected()
		CONTEXT_ROTATE:
			rotate_selected(1)
		CONTEXT_REMOVE:
			delete_selected()

func zoom_at(screen_position: Vector2, requested_zoom: float) -> void:
	var next_zoom := clampf(requested_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom_level):
		return
	var map_position := (screen_position - view_offset) / zoom_level
	zoom_level = next_zoom
	view_offset = screen_position - map_position * zoom_level
	_clamp_view_offset()
	zoom_changed.emit(zoom_level)
	queue_redraw()

func set_zoom(requested_zoom: float) -> void:
	zoom_at(size * 0.5, requested_zoom)

func reset_zoom() -> void:
	zoom_level = 1.0
	view_offset = Vector2.ZERO
	zoom_changed.emit(zoom_level)
	queue_redraw()

func _clamp_view_offset() -> void:
	if zoom_level <= 1.0:
		view_offset = (size - size * zoom_level) * 0.5
		return
	view_offset.x = clampf(view_offset.x, size.x * (1.0 - zoom_level), 0.0)
	view_offset.y = clampf(view_offset.y, size.y * (1.0 - zoom_level), 0.0)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("type", "") != "catalog_entry":
		return false
	var entry = data.get("entry", null)
	if not entry is Dictionary or not entry.get("footprint", null) is Vector2i:
		return false
	var footprint: Vector2i = entry["footprint"]
	if footprint.x > _active_map_cells().x or footprint.y > _active_map_cells().y:
		return false
	var target := _drop_target_cell(at_position, footprint)
	return _can_occupy(target, footprint)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var entry = data.get("entry", null)
	if not entry is Dictionary or not entry.get("footprint", null) is Vector2i:
		return
	var footprint: Vector2i = entry["footprint"]
	if footprint.x > _active_map_cells().x or footprint.y > _active_map_cells().y:
		action_rejected.emit("That piece is larger than the current grid")
		return
	var cell := _drop_target_cell(at_position, footprint)
	_place_piece(entry, cell)

func _drop_target_cell(at_position: Vector2, footprint: Vector2i) -> Vector2i:
	var centered := _local_to_cell(at_position) - Vector2i(floori(footprint.x / 2.0), floori(footprint.y / 2.0))
	return _clamp_cell(centered, footprint)

func _place_piece(entry: Dictionary, cell: Vector2i) -> void:
	var snapshot := _normalized_entry_snapshot(entry)
	var footprint: Vector2i = snapshot["footprint"]
	var target_cell := _clamp_cell(cell, footprint)
	if not _can_occupy(target_cell, footprint):
		action_rejected.emit("That space is already occupied")
		return
	_push_undo()
	var piece := {
		"instance_id": next_id,
		"entry": snapshot,
		"cell": target_cell,
		"rotation": 0,
		"mirrored": false,
		"layer": pieces.size()
	}
	next_id += 1
	pieces.append(piece)
	selected_id = piece["instance_id"]
	selection_changed.emit(piece)
	placement_finished.emit()
	state_changed.emit()
	queue_redraw()

func delete_selected() -> void:
	if selected_id < 0:
		return
	_push_undo()
	for index in range(pieces.size() - 1, -1, -1):
		if pieces[index]["instance_id"] == selected_id:
			pieces.remove_at(index)
			break
	selected_id = -1
	selection_changed.emit(null)
	state_changed.emit()
	queue_redraw()

func duplicate_selected() -> void:
	var selected = get_selected_piece()
	if selected == null:
		return
	var copy = selected.duplicate(true)
	copy["instance_id"] = next_id
	var target_cell := _find_nearest_free_cell(copy["cell"] + Vector2i.ONE, _piece_footprint(copy))
	if target_cell.x < 0:
		action_rejected.emit("No free space is available for a duplicate")
		return
	_push_undo()
	next_id += 1
	copy["cell"] = target_cell
	copy["layer"] = pieces.size()
	pieces.append(copy)
	selected_id = copy["instance_id"]
	selection_changed.emit(copy)
	state_changed.emit()
	queue_redraw()

func rotate_selected(direction: int = 1) -> void:
	var selected = get_selected_piece()
	if selected == null:
		return
	var previous_rotation := int(selected["rotation"])
	var next_rotation := posmod(previous_rotation + 90 * signi(direction), 360)
	var footprint: Vector2i = selected["entry"].get("footprint", Vector2i.ONE)
	if next_rotation % 180 != 0:
		footprint = Vector2i(footprint.y, footprint.x)
	if footprint.x > _active_map_cells().x or footprint.y > _active_map_cells().y:
		action_rejected.emit("The rotated object would fall outside the grid")
		return
	var target_cell := _clamp_cell(selected["cell"], footprint)
	if not _can_occupy(target_cell, footprint, selected_id):
		action_rejected.emit("The rotated object would overlap another object")
		return
	_push_undo()
	selected["rotation"] = next_rotation
	selected["cell"] = target_cell
	selection_changed.emit(selected)
	state_changed.emit()
	queue_redraw()

func mirror_selected() -> void:
	var selected = get_selected_piece()
	if selected == null:
		return
	_push_undo()
	selected["mirrored"] = not bool(selected.get("mirrored", false))
	selection_changed.emit(selected)
	state_changed.emit()
	queue_redraw()

func get_selected_piece():
	for piece in pieces:
		if piece["instance_id"] == selected_id:
			return piece
	return null

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot())
	_restore_snapshot(undo_stack.pop_back())

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot())
	_restore_snapshot(redo_stack.pop_back())

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func clear_map() -> void:
	pieces.clear()
	embedded_images.clear()
	piece_textures.clear()
	undo_stack.clear()
	redo_stack.clear()
	selected_id = -1
	next_id = 1
	selection_changed.emit(null)
	state_changed.emit()
	queue_redraw()

func _serialize_layout() -> Dictionary:
	var serialized: Array = []
	for piece in pieces:
		var entry: Dictionary = piece.get("entry", _missing_entry_snapshot("missing"))
		var footprint: Vector2i = entry.get("footprint", Vector2i.ONE)
		serialized.append({
			"instance_id": piece["instance_id"],
			"entry": {
				"id": str(entry.get("id", "missing")),
				"name": str(entry.get("name", "Missing catalog entry")),
				"group_id": str(entry.get("group_id", "")),
				"footprint_width": footprint.x,
				"footprint_height": footprint.y,
				"image_path": str(entry.get("image_path", ""))
			},
			"cell_x": piece["cell"].x,
			"cell_y": piece["cell"].y,
			"rotation": piece["rotation"],
			"mirrored": piece.get("mirrored", false),
			"layer": piece["layer"]
		})
	return {
		"grid_mode": grid_mode,
		"grid_opacity": grid_opacity,
		"grid_color": grid_color.to_html(false),
		"manual_grid_columns": manual_grid_cells.x,
		"manual_grid_rows": manual_grid_cells.y,
		"background_path": background_path,
		"detected_grid_origin_x": detected_grid_origin.x,
		"detected_grid_origin_y": detected_grid_origin.y,
		"detected_grid_spacing_x": detected_grid_spacing.x,
		"detected_grid_spacing_y": detected_grid_spacing.y,
		"detected_grid_end_x": detected_grid_end.x,
		"detected_grid_end_y": detected_grid_end.y,
		"detected_grid_cells_x": detected_grid_cells.x,
		"detected_grid_cells_y": detected_grid_cells.y,
		"detected_grid_confidence": detected_grid_confidence,
		"pieces": serialized
	}

func serialize_state() -> Dictionary:
	var data := _serialize_layout()
	var images := {}
	var snapshots := {}
	var total_bytes := 0
	for piece in pieces:
		var entry: Dictionary = piece.get("entry", {})
		var path := str(entry.get("image_path", ""))
		if path.is_empty() or images.has(path):
			continue
		var bytes := PackedByteArray()
		if piece_textures.has(path) and piece_textures[path] != null:
			bytes = (piece_textures[path] as Texture2D).get_image().save_png_to_buffer()
		if bytes.is_empty():
			bytes = embedded_images.get(path, PackedByteArray())
		if bytes.is_empty():
			if path.begins_with("res://"):
				var texture := load(path) as Texture2D
				if texture != null:
					bytes = texture.get_image().save_png_to_buffer()
			elif FileAccess.file_exists(path):
				bytes = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return {"error": "Could not include image: %s" % path}
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_width() > MAX_EMBEDDED_IMAGE_DIMENSION or image.get_height() > MAX_EMBEDDED_IMAGE_DIMENSION:
			return {"error": "Image is not a readable PNG within 4096×4096 pixels: %s" % path}
		while bytes.size() > MAX_EMBEDDED_IMAGE_BYTES:
			if image.get_width() == 1 and image.get_height() == 1:
				return {"error": "Image exceeds the 2 MiB map limit: %s" % path}
			image.resize(maxi(1, image.get_width() / 2), maxi(1, image.get_height() / 2), Image.INTERPOLATE_NEAREST)
			bytes = image.save_png_to_buffer()
			if bytes.is_empty():
				return {"error": "Could not reduce image: %s" % path}
		total_bytes += bytes.size()
		if total_bytes > MAX_EMBEDDED_IMAGES_BYTES:
			return {"error": "Images exceed the 32 MiB map limit."}
		snapshots[path] = bytes
		images[path] = Marshalls.raw_to_base64(bytes)
	data["version"] = MAP_FILE_VERSION
	data["images"] = images
	return {"data": data, "images": snapshots}

func commit_saved_images(images: Dictionary) -> void:
	embedded_images = images.duplicate(true)
	piece_textures.clear()
	queue_redraw()

func load_state(data: Dictionary) -> String:
	var validation_error := _validate_saved_state(data)
	if not validation_error.is_empty():
		return validation_error
	var images := {}
	for path in data["images"]:
		images[path] = Marshalls.base64_to_raw(data["images"][path])
	_restore_layout(data, images)
	return ""

func _restore_layout(data: Dictionary, images: Dictionary) -> void:
	reset_zoom()
	embedded_images = images.duplicate(true)
	piece_textures.clear()
	pieces.clear()
	selected_id = -1
	next_id = 1
	var saved_grid_mode := int(data.get("grid_mode", GRID_SQUARE))
	grid_mode = saved_grid_mode if saved_grid_mode in [GRID_SQUARE, GRID_DETECTED, GRID_HIDDEN] else GRID_SQUARE
	grid_opacity = float(data.get("grid_opacity", 0.30))
	grid_color = Color.from_string(str(data.get("grid_color", "f2e8c2")), Color(0.95, 0.91, 0.76, 1.0))
	grid_color.a = 1.0
	manual_grid_cells = Vector2i(
		clampi(int(data.get("manual_grid_columns", DEFAULT_MAP_CELLS.x)), MIN_MANUAL_GRID_SIZE, MAX_MANUAL_GRID_SIZE),
		clampi(int(data.get("manual_grid_rows", DEFAULT_MAP_CELLS.y)), MIN_MANUAL_GRID_SIZE, MAX_MANUAL_GRID_SIZE)
	)
	background_path = str(data.get("background_path", ""))
	background_texture = null
	detected_grid_origin = Vector2(float(data.get("detected_grid_origin_x", 0.0)), float(data.get("detected_grid_origin_y", 0.0)))
	detected_grid_spacing = Vector2(float(data.get("detected_grid_spacing_x", 0.0)), float(data.get("detected_grid_spacing_y", 0.0)))
	detected_grid_end = Vector2(float(data.get("detected_grid_end_x", 0.0)), float(data.get("detected_grid_end_y", 0.0)))
	detected_grid_cells = Vector2i(int(data.get("detected_grid_cells_x", 0)), int(data.get("detected_grid_cells_y", 0)))
	if detected_grid_end == Vector2.ZERO and detected_grid_cells.x > 0 and detected_grid_cells.y > 0:
		detected_grid_end = detected_grid_origin + detected_grid_spacing * Vector2(detected_grid_cells)
	detected_grid_confidence = float(data.get("detected_grid_confidence", 0.0))
	if not background_path.is_empty():
		if background_path.begins_with("res://"):
			background_texture = load(background_path) as Texture2D
		else:
			var loaded := Image.load_from_file(background_path)
			if not loaded.is_empty():
				background_texture = ImageTexture.create_from_image(loaded)
	if has_detected_grid():
		grid_mode = GRID_DETECTED
	elif grid_mode == GRID_DETECTED:
		grid_mode = GRID_SQUARE
	for item in data.get("pieces", []):
		if not item is Dictionary:
			continue
		var entry := _entry_snapshot_from_saved_piece(item)
		var piece := {
			"instance_id": int(item.get("instance_id", next_id)),
			"entry": entry,
			"cell": Vector2i(int(item.get("cell_x", 0)), int(item.get("cell_y", 0))),
			"rotation": int(item.get("rotation", 0)),
			"mirrored": bool(item.get("mirrored", false)),
			"layer": int(item.get("layer", pieces.size()))
		}
		pieces.append(piece)
		next_id = maxi(next_id, int(piece["instance_id"]) + 1)
	undo_stack.clear()
	redo_stack.clear()
	selection_changed.emit(null)
	state_changed.emit()
	queue_redraw()

func _validate_saved_state(data: Dictionary) -> String:
	if not data.has("version") or not _saved_integer(data["version"]) or int(data["version"]) != MAP_FILE_VERSION:
		return "Unsupported map version."
	if not data.get("pieces") is Array:
		return "pieces must be an array."
	if not data.get("images") is Dictionary:
		return "images must be an object."
	var total_bytes := 0
	for path in data["images"]:
		if not path is String or not data["images"][path] is String:
			return "images must map paths to PNG data."
		var encoded: String = data["images"][path]
		if encoded.length() > ceili(float(MAX_EMBEDDED_IMAGE_BYTES) / 3.0) * 4:
			return "Embedded image exceeds the 2 MiB limit."
		var bytes := Marshalls.base64_to_raw(encoded)
		if bytes.is_empty() or bytes.size() > MAX_EMBEDDED_IMAGE_BYTES or Marshalls.raw_to_base64(bytes) != encoded:
			return "Embedded image data is invalid."
		total_bytes += bytes.size()
		if total_bytes > MAX_EMBEDDED_IMAGES_BYTES:
			return "Embedded images exceed the 32 MiB limit."
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_width() > MAX_EMBEDDED_IMAGE_DIMENSION or image.get_height() > MAX_EMBEDDED_IMAGE_DIMENSION:
			return "Embedded image is not a readable PNG within 4096×4096 pixels."
	for key in ["grid_mode", "manual_grid_columns", "manual_grid_rows", "detected_grid_cells_x", "detected_grid_cells_y"]:
		if data.has(key) and not _saved_integer(data[key]):
			return "%s must be a whole number." % key
	for key in ["grid_opacity", "detected_grid_origin_x", "detected_grid_origin_y", "detected_grid_spacing_x", "detected_grid_spacing_y", "detected_grid_end_x", "detected_grid_end_y", "detected_grid_confidence"]:
		if data.has(key) and not _saved_number(data[key]):
			return "%s must be a finite number." % key
	if data.has("grid_color") and not data["grid_color"] is String:
		return "grid_color must be a string."
	if data.has("background_path") and not data["background_path"] is String:
		return "background_path must be a string."
	var columns := clampi(int(data.get("manual_grid_columns", DEFAULT_MAP_CELLS.x)), MIN_MANUAL_GRID_SIZE, MAX_MANUAL_GRID_SIZE)
	var rows := clampi(int(data.get("manual_grid_rows", DEFAULT_MAP_CELLS.y)), MIN_MANUAL_GRID_SIZE, MAX_MANUAL_GRID_SIZE)
	var detected_columns := int(data.get("detected_grid_cells_x", 0))
	var detected_rows := int(data.get("detected_grid_cells_y", 0))
	var detected_valid := detected_columns > 0 and detected_rows > 0 \
		and float(data.get("detected_grid_spacing_x", 0.0)) > 0.0 \
		and float(data.get("detected_grid_spacing_y", 0.0)) > 0.0
	var bounds := Vector2i(detected_columns, detected_rows) if detected_valid else Vector2i(columns, rows)
	var used_ids := {}
	var occupied: Array[Rect2i] = []
	for index in range(data["pieces"].size()):
		var item = data["pieces"][index]
		var location := "pieces[%d]" % index
		if not item is Dictionary:
			return "%s must be an object." % location
		for key in ["instance_id", "cell_x", "cell_y"]:
			if not item.has(key) or not _saved_integer(item[key]):
				return "%s.%s must be a whole number." % [location, key]
		var instance_id := int(item["instance_id"])
		if instance_id < 1 or used_ids.has(instance_id):
			return "%s.instance_id must be positive and unique." % location
		used_ids[instance_id] = true
		for key in ["rotation", "layer"]:
			if item.has(key) and not _saved_integer(item[key]):
				return "%s.%s must be a whole number." % [location, key]
		if item.has("mirrored") and not item["mirrored"] is bool:
			return "%s.mirrored must be a boolean." % location
		var entry = item.get("entry", null)
		if not entry is Dictionary:
			return "%s.entry must be an object." % location
		for key in ["id", "name", "group_id", "image_path"]:
			if not entry.has(key) or not entry[key] is String:
				return "%s.entry.%s must be a string." % [location, key]
		if not entry["image_path"].is_empty() and not data["images"].has(entry["image_path"]):
			return "%s.entry image is missing from the map." % location
		for key in ["footprint_width", "footprint_height"]:
			if not entry.has(key) or not _saved_integer(entry[key]):
				return "%s.entry.%s must be a whole number." % [location, key]
		var footprint := Vector2i(int(entry["footprint_width"]), int(entry["footprint_height"]))
		if footprint.x < 1 or footprint.y < 1 or footprint.x > MAX_MANUAL_GRID_SIZE or footprint.y > MAX_MANUAL_GRID_SIZE:
			return "%s.entry footprint must be between 1 and 100." % location
		if int(item.get("rotation", 0)) % 180 != 0:
			footprint = Vector2i(footprint.y, footprint.x)
		var cell := Vector2i(int(item["cell_x"]), int(item["cell_y"]))
		if cell.x < 0 or cell.y < 0 or cell.x + footprint.x > bounds.x or cell.y + footprint.y > bounds.y:
			return "%s is outside the grid." % location
		var rectangle := Rect2i(cell, footprint)
		for previous in occupied:
			if rectangle.intersects(previous):
				return "%s overlaps another piece." % location
		occupied.append(rectangle)
	return ""

func _saved_integer(value) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value))

func _saved_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func export_visible_png(path: String) -> Error:
	if DisplayServer.get_name() == "headless":
		return ERR_UNAVAILABLE
	var export_size := Vector2i(size)
	if background_texture != null:
		export_size = Vector2i(background_texture.get_size())
	if export_size.x <= 0 or export_size.y <= 0:
		return ERR_INVALID_DATA
	var export_viewport := SubViewport.new()
	export_viewport.size = export_size
	export_viewport.disable_3d = true
	export_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(export_viewport)
	var export_canvas := BattleMapCanvas.new()
	export_canvas.custom_minimum_size = Vector2.ZERO
	export_canvas.size = Vector2(export_size)
	export_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	export_viewport.add_child(export_canvas)
	export_canvas.custom_minimum_size = Vector2.ZERO
	export_canvas.size = Vector2(export_size)
	export_canvas._restore_layout(_serialize_layout(), embedded_images)
	# Match the images currently displayed, even if their source files changed.
	export_canvas.piece_textures = piece_textures.duplicate()
	export_canvas.background_texture = background_texture
	export_canvas.selected_id = -1
	export_canvas.zoom_level = 1.0
	export_canvas.view_offset = Vector2.ZERO
	export_canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	var image := export_viewport.get_texture().get_image()
	var error := image.save_png(path)
	export_viewport.queue_free()
	return error

func _push_undo() -> void:
	undo_stack.append(_snapshot())
	if undo_stack.size() > 50:
		undo_stack.pop_front()
	redo_stack.clear()

func _snapshot() -> Dictionary:
	return {
		"pieces": pieces.duplicate(true),
		"selected_id": selected_id,
		"next_id": next_id
	}

func _restore_snapshot(snapshot: Dictionary) -> void:
	pieces = snapshot.get("pieces", []).duplicate(true)
	selected_id = int(snapshot.get("selected_id", -1))
	next_id = int(snapshot.get("next_id", 1))
	selection_changed.emit(get_selected_piece())
	state_changed.emit()
	queue_redraw()

func _piece_at(cell: Vector2i):
	for index in range(pieces.size() - 1, -1, -1):
		var piece = pieces[index]
		var footprint := _piece_footprint(piece)
		var rect := Rect2i(piece["cell"], footprint)
		if rect.has_point(cell):
			return piece
	return null

func _can_occupy(cell: Vector2i, footprint: Vector2i, ignored_instance_id: int = -1) -> bool:
	var map_cells := _active_map_cells()
	if footprint.x < 1 or footprint.y < 1 or cell.x < 0 or cell.y < 0 \
			or cell.x + footprint.x > map_cells.x or cell.y + footprint.y > map_cells.y:
		return false
	var target := Rect2i(cell, footprint)
	for piece in pieces:
		if int(piece["instance_id"]) == ignored_instance_id:
			continue
		var occupied := Rect2i(piece["cell"], _piece_footprint(piece))
		if target.intersects(occupied):
			return false
	return true

func _find_nearest_free_cell(preferred: Vector2i, footprint: Vector2i, ignored_instance_id: int = -1) -> Vector2i:
	var map_cells := _active_map_cells()
	var maximum_radius := maxi(map_cells.x, map_cells.y)
	for radius in range(maximum_radius + 1):
		for y in range(preferred.y - radius, preferred.y + radius + 1):
			for x in range(preferred.x - radius, preferred.x + radius + 1):
				if radius > 0 and abs(x - preferred.x) < radius and abs(y - preferred.y) < radius:
					continue
				var candidate := Vector2i(x, y)
				if candidate.x < 0 or candidate.y < 0 or candidate.x + footprint.x > map_cells.x or candidate.y + footprint.y > map_cells.y:
					continue
				if _can_occupy(candidate, footprint, ignored_instance_id):
					return candidate
	return Vector2i(-1, -1)


func _entry_snapshot_from_saved_piece(item: Dictionary) -> Dictionary:
	var saved_entry: Dictionary = item["entry"]
	var footprint := Vector2i(
		clampi(int(saved_entry.get("footprint_width", 1)), 1, MAX_MANUAL_GRID_SIZE),
		clampi(int(saved_entry.get("footprint_height", 1)), 1, MAX_MANUAL_GRID_SIZE)
	)
	return {
		"id": str(saved_entry.get("id", "missing")),
		"name": str(saved_entry.get("name", "Missing catalog entry")),
		"group_id": str(saved_entry.get("group_id", "")),
		"footprint": footprint,
		"image_path": str(saved_entry.get("image_path", ""))
	}


func _normalized_entry_snapshot(entry: Dictionary) -> Dictionary:
	return {
		"id": str(entry.get("id", "missing")),
		"name": str(entry.get("name", "Missing catalog entry")),
		"group_id": str(entry.get("group_id", "")),
		"footprint": entry.get("footprint", Vector2i.ONE),
		"image_path": str(entry.get("image_path", ""))
	}


func _missing_entry_snapshot(entry_id: String) -> Dictionary:
	return {
		"id": entry_id,
		"name": "Missing catalog entry",
		"group_id": "",
		"footprint": Vector2i.ONE,
		"image_path": ""
	}


func _piece_footprint(piece) -> Vector2i:
	var entry = piece.get("entry", null)
	if not entry is Dictionary:
		return Vector2i.ONE
	var footprint: Vector2i = entry.get("footprint", Vector2i.ONE)
	if int(piece.get("rotation", 0)) % 180 != 0:
		return Vector2i(footprint.y, footprint.x)
	return footprint

func _clamp_cell(cell: Vector2i, footprint: Vector2i) -> Vector2i:
	var map_cells := _active_map_cells()
	return Vector2i(
		clampi(cell.x, 0, map_cells.x - footprint.x),
		clampi(cell.y, 0, map_cells.y - footprint.y)
	)

func _local_to_cell(local_position: Vector2) -> Vector2i:
	local_position = (local_position - view_offset) / zoom_level
	var cell_size := _cell_size()
	var origin := _grid_origin_pixels()
	return Vector2i(floori((local_position.x - origin.x) / cell_size.x), floori((local_position.y - origin.y) / cell_size.y))

func _cell_size() -> Vector2:
	var map_rect := _landscape_rect()
	if grid_mode == GRID_DETECTED and has_detected_grid():
		return detected_grid_spacing * map_rect.size
	return Vector2(map_rect.size.x / manual_grid_cells.x, map_rect.size.y / manual_grid_cells.y)

func _grid_origin_pixels() -> Vector2:
	var map_rect := _landscape_rect()
	if grid_mode == GRID_DETECTED and has_detected_grid():
		return map_rect.position + detected_grid_origin * map_rect.size
	return map_rect.position

func _landscape_rect() -> Rect2:
	var canvas_rect := Rect2(Vector2.ZERO, size)
	if background_texture == null:
		return canvas_rect
	var texture_size := background_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return canvas_rect
	var fit_scale := minf(size.x / texture_size.x, size.y / texture_size.y)
	var fitted_size := texture_size * fit_scale
	return Rect2((size - fitted_size) * 0.5, fitted_size)

func _active_map_cells() -> Vector2i:
	if grid_mode == GRID_DETECTED and has_detected_grid():
		return detected_grid_cells
	return manual_grid_cells

func has_detected_grid() -> bool:
	return detected_grid_cells.x > 0 and detected_grid_cells.y > 0 \
		and detected_grid_spacing.x > 0.0 and detected_grid_spacing.y > 0.0

func _clear_detected_grid() -> void:
	detected_grid_origin = Vector2.ZERO
	detected_grid_spacing = Vector2.ZERO
	detected_grid_end = Vector2.ZERO
	detected_grid_cells = Vector2i.ZERO
	detected_grid_confidence = 0.0

func _draw() -> void:
	draw_set_transform(view_offset, 0.0, Vector2.ONE * zoom_level)
	_draw_stage()
	if grid_mode == GRID_SQUARE:
		_draw_square_grid()
	for piece in pieces:
		_draw_piece(piece)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_stage() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	if background_texture != null:
		# Preserve the imported landscape's aspect ratio and letterbox the remainder.
		draw_rect(map_rect, Color("111827"))
		draw_texture_rect(background_texture, _landscape_rect(), false)
		return
	draw_rect(map_rect, Color("263d2c"))
	var path := PackedVector2Array([
		Vector2(size.x * 0.43, 0), Vector2(size.x * 0.56, 0),
		Vector2(size.x * 0.63, size.y), Vector2(size.x * 0.48, size.y)
	])
	draw_colored_polygon(path, Color("756d4d"))
	var foliage := [
		[0.08, 0.10, 0.14, "365f3c"], [0.20, 0.18, 0.10, "416f42"],
		[0.86, 0.12, 0.15, "315638"], [0.73, 0.28, 0.11, "466f42"],
		[0.10, 0.78, 0.16, "31563b"], [0.28, 0.88, 0.12, "446b40"],
		[0.88, 0.82, 0.17, "365d39"], [0.70, 0.72, 0.10, "4b7445"]
	]
	for item in foliage:
		var center := Vector2(size.x * float(item[0]), size.y * float(item[1]))
		var radius: float = minf(size.x, size.y) * float(item[2])
		draw_circle(center + Vector2(5, 8), radius, Color(0.03, 0.05, 0.04, 0.22))
		draw_circle(center, radius, Color(item[3]))
		draw_circle(center - Vector2(radius * 0.22, radius * 0.18), radius * 0.62, Color("537c48"))
	for stone in [Vector2(0.33, 0.35), Vector2(0.77, 0.56), Vector2(0.18, 0.58), Vector2(0.63, 0.84)]:
		var point := Vector2(size.x * stone.x, size.y * stone.y)
		draw_circle(point + Vector2(3, 5), 22, Color(0.03, 0.05, 0.04, 0.3))
		draw_circle(point, 20, Color("727a6d"))
		draw_circle(point - Vector2(5, 6), 10, Color("909688"))

func _draw_square_grid() -> void:
	var color := Color(grid_color.r, grid_color.g, grid_color.b, grid_opacity)
	var line_width := 2.0
	var map_rect := _landscape_rect()
	for x in range(manual_grid_cells.x + 1):
		# Filled strips survive viewport scaling more reliably than one-pixel strokes.
		var px: float = roundf(map_rect.position.x + float(x) * map_rect.size.x / float(manual_grid_cells.x))
		px = clampf(px - line_width * 0.5, map_rect.position.x, maxf(map_rect.position.x, map_rect.end.x - line_width))
		draw_rect(Rect2(px, map_rect.position.y, line_width, map_rect.size.y), color, true)
	for y in range(manual_grid_cells.y + 1):
		var py: float = roundf(map_rect.position.y + float(y) * map_rect.size.y / float(manual_grid_cells.y))
		py = clampf(py - line_width * 0.5, map_rect.position.y, maxf(map_rect.position.y, map_rect.end.y - line_width))
		draw_rect(Rect2(map_rect.position.x, py, map_rect.size.x, line_width), color, true)

func _draw_piece(piece) -> void:
	var entry = piece.get("entry", null)
	if not entry is Dictionary:
		return
	var cell_size := _cell_size()
	var footprint := _piece_footprint(piece)
	var rect := Rect2(_grid_origin_pixels() + Vector2(piece["cell"]) * cell_size, Vector2(footprint) * cell_size)
	var inset := minf(cell_size.x, cell_size.y) * 0.025
	var icon_rect := rect.grow(-inset)
	var texture := _texture_for_entry(entry)
	if texture != null:
		_draw_sprite_texture(icon_rect, texture, int(piece["rotation"]), bool(piece.get("mirrored", false)))
	else:
		_draw_missing_image(icon_rect)
	if piece["instance_id"] == selected_id:
		var outline_width := selection_outline_width()
		draw_rect(rect.grow(-outline_width * 0.67), Color("f0c96b"), false, outline_width)

func _draw_sprite_texture(rect: Rect2, texture: Texture2D, piece_rotation: int, mirrored: bool) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var rotated_size := texture_size
	if piece_rotation % 180 != 0:
		rotated_size = Vector2(texture_size.y, texture_size.x)
	var scale_factor := minf(rect.size.x / rotated_size.x, rect.size.y / rotated_size.y)
	var draw_size := texture_size * scale_factor
	var mirror_scale := Vector2(-1.0, 1.0) if mirrored else Vector2.ONE
	draw_set_transform(view_offset + rect.get_center() * zoom_level, deg_to_rad(float(piece_rotation)), mirror_scale * zoom_level)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false)
	draw_set_transform(view_offset, 0.0, Vector2.ONE * zoom_level)

func _texture_for_entry(entry: Dictionary) -> Texture2D:
	var path := str(entry.get("image_path", ""))
	if path.is_empty():
		return null
	if piece_textures.has(path):
		return piece_textures[path]
	var texture: Texture2D
	if embedded_images.has(path):
		var image := Image.new()
		if image.load_png_from_buffer(embedded_images[path]) == OK:
			texture = ImageTexture.create_from_image(image)
	elif path.begins_with("res://") or path.begins_with("user://"):
		texture = load(path) as Texture2D
	else:
		var image := Image.load_from_file(path)
		if not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	piece_textures[path] = texture
	return texture


func refresh_piece_images() -> void:
	piece_textures.clear()
	queue_redraw()


func _draw_missing_image(rect: Rect2) -> void:
	draw_rect(rect, Color("352f3b"))
	var stroke := maxf(2.0, minf(rect.size.x, rect.size.y) * 0.05)
	draw_line(rect.position, rect.end, Color("d67a73"), stroke)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("d67a73"), stroke)
