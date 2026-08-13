extends Control

# THESIS: The map is a stage, not a document inside generic editor chrome; the wide canvas owns the workspace.
# OWN-WORLD: Stage black panels, cobalt active states, cue-gold primary actions, dusty-rose warnings, hairline seams, and cast/scene language.
# STORY: Pick from Cast & Props, place fixed-footprint pieces on the stage, adjust order and grid, save locally, then export PNG.
# FIRST VIEWPORT: Permanent 276px Cast & Props rail left, dominant painted stage center, compact 260px Stage Controls right, Export PNG top-right.
# FORM: Combined Scene & Cue layout approved from scene-cue-layout-2.png; direction seed 700e5698.
# FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md

const AssetCatalogScript = preload("res://scripts/asset_catalog.gd")
const MapCanvasScript = preload("res://scripts/map_canvas.gd")
const AssetDragButtonScript = preload("res://scripts/asset_drag_button.gd")

var map_canvas: BattleMapCanvas
var assets: Array = []
var asset_buttons := {}
var selection_name: Label
var piece_action_buttons: Array[Button] = []
var grid_label: Label
var grid_select: OptionButton
var grid_cue_controls: Control
var grid_opacity: HSlider
var grid_color_picker: ColorPickerButton
var grid_columns: SpinBox
var grid_rows: SpinBox
var grid_shape_warning: Label
var landscape_select: OptionButton
var zoom_label: Label
var status_label: Label
var save_dialog: FileDialog
var open_dialog: FileDialog
var export_dialog: FileDialog
var background_dialog: FileDialog
var new_map_confirmation: PopupPanel
var new_map_cancel_button: Button
var current_path := ""

const IDEAL_CELL_RATIO_MIN := 0.95
const IDEAL_CELL_RATIO_MAX := 1.05
const ACCEPTABLE_CELL_RATIO_MIN := 0.80
const ACCEPTABLE_CELL_RATIO_MAX := 1.25

var palette := {
	"stage": Color("111827"),
	"panel": Color("182128"),
	"panel_raised": Color("202b33"),
	"line": Color("344550"),
	"cobalt": Color("3557a8"),
	"rose": Color("d67a73"),
	"gold": Color("f0c96b"),
	"paper": Color("f7f2e8"),
	"muted": Color("a8b1b4")
}

func _ready() -> void:
	assets = AssetCatalogScript.all_assets()
	theme = _build_theme()
	_build_interface()
	_build_dialogs()
	map_canvas.set_catalog(assets)
	map_canvas.selection_changed.connect(_on_selection_changed)
	map_canvas.state_changed.connect(_refresh_actions)
	map_canvas.placement_finished.connect(_on_asset_dropped)
	map_canvas.action_rejected.connect(_update_status)
	map_canvas.zoom_changed.connect(_on_zoom_changed)
	map_canvas.resized.connect(_update_grid_shape_warning)
	_sync_manual_grid_inputs()
	_update_status("Stage ready — drag an item from Cast & Props onto the map")

func _build_interface() -> void:
	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)

	var command_bar := PanelContainer.new()
	command_bar.custom_minimum_size.y = 54
	command_bar.add_theme_stylebox_override("panel", _panel_style(palette.stage, 0, 0, 0, 1))
	shell.add_child(command_bar)
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation", 6)
	command_bar.add_child(commands)
	commands.add_child(_title_label("BATTLE MAP CREATOR"))
	_add_spacer(commands, 18)
	_add_button(commands, "NEW", _new_map, "Clear the current stage")
	_add_button(commands, "OPEN", _show_open, "Open an editable battle map")
	_add_button(commands, "SAVE", _save, "Save the editable battle map")
	_add_button(commands, "LANDSCAPE", _show_background, "Import a painted background")
	_add_spacer(commands, 12)
	_add_button(commands, "UNDO", _undo, "Undo the last change")
	_add_button(commands, "REDO", _redo, "Redo the last undone change")
	_add_spacer(commands, 12)
	_add_button(commands, "−", _zoom_out, "Zoom out (Ctrl+-)")
	zoom_label = Label.new()
	zoom_label.text = "25%"
	zoom_label.custom_minimum_size.x = 48
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.add_theme_color_override("font_color", palette.muted)
	commands.add_child(zoom_label)
	_add_button(commands, "+", _zoom_in, "Zoom in (Ctrl++)")
	_add_button(commands, "FIT", _zoom_reset, "Reset the map view (Ctrl+0)")
	_add_spacer(commands, 12)
	grid_label = Label.new()
	grid_label.text = "GRID"
	grid_label.add_theme_color_override("font_color", palette.muted)
	commands.add_child(grid_label)
	grid_select = OptionButton.new()
	grid_select.add_item("Overlay")
	grid_select.add_item("Detected", BattleMapCanvas.GRID_DETECTED)
	grid_select.set_item_disabled(1, true)
	grid_select.add_item("Hidden")
	grid_select.item_selected.connect(_on_grid_selected)
	commands.add_child(grid_select)
	var flexible := Control.new()
	flexible.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.add_child(flexible)
	var export_button := _add_button(commands, "EXPORT PNG", _show_export, "Export the stage as a PNG image")
	export_button.add_theme_stylebox_override("normal", _button_style(palette.gold, palette.gold.darkened(0.18)))
	export_button.add_theme_color_override("font_color", Color("1b2429"))
	export_button.add_theme_color_override("font_hover_color", Color("111827"))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 1)
	shell.add_child(body)
	map_canvas = MapCanvasScript.new()
	body.add_child(_build_library())

	var stage_frame := MarginContainer.new()
	stage_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.add_theme_constant_override("margin_left", 8)
	stage_frame.add_theme_constant_override("margin_top", 8)
	stage_frame.add_theme_constant_override("margin_right", 8)
	stage_frame.add_theme_constant_override("margin_bottom", 8)
	body.add_child(stage_frame)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_frame.add_child(map_canvas)
	body.add_child(_build_cue_book())

	var status := PanelContainer.new()
	status.custom_minimum_size.y = 32
	status.add_theme_stylebox_override("panel", _panel_style(palette.stage, 1, 0, 0, 0))
	shell.add_child(status)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", palette.muted)
	status_label.add_theme_font_size_override("font_size", 12)
	status.add_child(status_label)

func _build_library() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 276
	panel.add_theme_stylebox_override("panel", _panel_style(palette.panel, 0, 1, 0, 0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_title("CAST & PROPS"))
	var search := LineEdit.new()
	search.placeholder_text = "Search cast and props"
	search.text_changed.connect(_filter_assets)
	column.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var groups := VBoxContainer.new()
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("separation", 14)
	scroll.add_child(groups)
	for group_name in ["CAST", "CREATURES", "PROPS", "SCENERY"]:
		groups.add_child(_small_heading(group_name))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		groups.add_child(grid)
		for asset in assets:
			if asset["group"] != group_name:
				continue
			var button: AssetDragButton = AssetDragButtonScript.new()
			button.custom_minimum_size = Vector2(120, 116)
			button.configure(asset, map_canvas.drag_preview_size_for_asset)
			grid.add_child(button)
			asset_buttons[asset["id"]] = button
	return panel

func _build_cue_book() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 260
	panel.add_theme_stylebox_override("panel", _panel_style(palette.panel, 0, 0, 0, 1))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_section_title("STAGE CONTROLS"))
	selection_name = _detail_label("Nothing selected", palette.muted)
	selection_name.add_theme_font_size_override("font_size", 16)
	column.add_child(selection_name)
	var rotate_row := HBoxContainer.new()
	rotate_row.add_theme_constant_override("separation", 6)
	column.add_child(rotate_row)
	_add_piece_action(rotate_row, "ROTATE LEFT", _rotate_left, "Rotate 90 degrees counterclockwise")
	_add_piece_action(rotate_row, "ROTATE RIGHT", _rotate_right, "Rotate 90 degrees clockwise")
	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 6)
	column.add_child(edit_row)
	_add_piece_action(edit_row, "MIRROR", _mirror, "Mirror the selected model horizontally")
	_add_piece_action(edit_row, "DUPLICATE", _duplicate, "Duplicate one cell down and right")
	var delete_button := _add_button(column, "REMOVE FROM STAGE", _delete, "Delete the selected piece")
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.add_theme_color_override("font_color", palette.rose)
	piece_action_buttons.append(delete_button)
	_set_piece_actions_enabled(false)
	grid_cue_controls = VBoxContainer.new()
	grid_cue_controls.add_theme_constant_override("separation", 10)
	column.add_child(grid_cue_controls)
	grid_cue_controls.add_child(HSeparator.new())
	grid_cue_controls.add_child(_small_heading("GRID CUE"))
	var dimensions := GridContainer.new()
	dimensions.columns = 2
	dimensions.add_theme_constant_override("h_separation", 8)
	dimensions.add_theme_constant_override("v_separation", 6)
	grid_cue_controls.add_child(dimensions)
	dimensions.add_child(_detail_label("Columns", palette.paper))
	grid_columns = _grid_dimension_input(BattleMapCanvas.DEFAULT_MAP_CELLS.x)
	dimensions.add_child(grid_columns)
	dimensions.add_child(_detail_label("Rows", palette.paper))
	grid_rows = _grid_dimension_input(BattleMapCanvas.DEFAULT_MAP_CELLS.y)
	dimensions.add_child(grid_rows)
	grid_columns.value_changed.connect(_on_manual_grid_changed)
	grid_rows.value_changed.connect(_on_manual_grid_changed)
	var dimension_actions := HBoxContainer.new()
	dimension_actions.add_theme_constant_override("separation", 6)
	grid_cue_controls.add_child(dimension_actions)
	var remove_grid := _add_button(dimension_actions, "BIGGER SQUARES", _remove_grid, "Use the next grid with larger square cells")
	remove_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var add_grid := _add_button(dimension_actions, "SMALLER SQUARES", _add_grid, "Use the next grid with smaller square cells")
	add_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_shape_warning = _detail_label("", palette.rose)
	grid_shape_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid_shape_warning.visible = false
	grid_cue_controls.add_child(grid_shape_warning)
	var color_label := Label.new()
	color_label.text = "Grid line color"
	grid_cue_controls.add_child(color_label)
	grid_color_picker = ColorPickerButton.new()
	grid_color_picker.color = map_canvas.grid_color
	grid_color_picker.edit_alpha = false
	grid_color_picker.custom_minimum_size.y = 34
	grid_color_picker.tooltip_text = "Choose the manual grid line color"
	grid_color_picker.color_changed.connect(_on_grid_color_changed)
	grid_cue_controls.add_child(grid_color_picker)
	var opacity_label := Label.new()
	opacity_label.text = "Grid visibility"
	grid_cue_controls.add_child(opacity_label)
	grid_opacity = HSlider.new()
	grid_opacity.min_value = 0.05
	grid_opacity.max_value = 0.70
	grid_opacity.step = 0.05
	grid_opacity.value = 0.30
	grid_opacity.value_changed.connect(_on_grid_opacity_changed)
	grid_cue_controls.add_child(grid_opacity)
	column.add_child(HSeparator.new())
	column.add_child(_small_heading("LANDSCAPES"))
	landscape_select = OptionButton.new()
	landscape_select.add_theme_constant_override("icon_max_width", 48)
	landscape_select.add_icon_item(_transparent_landscape_icon(), "Default")
	landscape_select.add_icon_item(load("res://assets/landscapes/forest.png"), "Forest")
	landscape_select.add_icon_item(load("res://assets/landscapes/desert.png"), "Desert")
	landscape_select.add_icon_item(load("res://assets/landscapes/grassland.png"), "Grassland")
	landscape_select.add_icon_item(load("res://assets/landscapes/snow.png"), "Snow")
	landscape_select.get_popup().add_theme_constant_override("icon_max_width", 72)
	landscape_select.item_selected.connect(_on_builtin_landscape_selected)
	column.add_child(landscape_select)
	var landscape_hint := _detail_label("Built-in landscapes use your manual grid settings.", palette.muted)
	landscape_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(landscape_hint)
	var guidance := Label.new()
	guidance.text = "Pieces snap to whole cells. Their footprint is defined by the asset and cannot be resized manually."
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance.add_theme_color_override("font_color", palette.muted)
	guidance.add_theme_font_size_override("font_size", 12)
	column.add_child(guidance)
	return panel

func _transparent_landscape_icon() -> Texture2D:
	var image := Image.create(96, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)

func _build_dialogs() -> void:
	new_map_confirmation = PopupPanel.new()
	new_map_confirmation.exclusive = true
	new_map_confirmation.wrap_controls = false
	new_map_confirmation.unresizable = true
	new_map_confirmation.about_to_popup.connect(_focus_new_map_cancel)
	add_child(new_map_confirmation)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	new_map_confirmation.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var title := Label.new()
	title.text = "Start a new map?"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", palette.paper)
	content.add_child(title)
	var warning := Label.new()
	warning.text = "Your current map progress will be discarded. This action cannot be undone."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", palette.muted)
	content.add_child(warning)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	new_map_cancel_button = _add_button(actions, "KEEP EDITING", new_map_confirmation.hide, "Return to the current map")
	new_map_cancel_button.add_theme_stylebox_override("focus", _button_style(palette.panel_raised, palette.line))
	new_map_cancel_button.add_theme_color_override("font_focus_color", palette.paper)
	var discard_button := _add_button(actions, "DISCARD AND START NEW", _confirm_new_map, "Discard the current map and start over")
	discard_button.add_theme_color_override("font_color", palette.rose)
	save_dialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE, ["*.battlemap ; Battle Map Creator project"])
	save_dialog.file_selected.connect(_save_to_path)
	open_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.battlemap ; Battle Map Creator project"])
	open_dialog.file_selected.connect(_load_from_path)
	export_dialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE, ["*.png ; PNG image"])
	export_dialog.file_selected.connect(_export_to_path)
	background_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.png,*.jpg,*.jpeg,*.webp ; Image files"])
	background_dialog.file_selected.connect(_import_background)

func _dialog(mode: FileDialog.FileMode, filters: Array[String]) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(filters)
	dialog.use_native_dialog = true
	add_child(dialog)
	return dialog

func _on_asset_dropped() -> void:
	_update_status("Piece placed — drag it between cells or drag another item onto the map")

func _filter_assets(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	for asset in assets:
		var button: Button = asset_buttons[asset["id"]]
		button.visible = normalized.is_empty() or normalized in str(asset["name"]).to_lower() or normalized in str(asset["group"]).to_lower()

func _on_selection_changed(piece) -> void:
	_set_piece_actions_enabled(piece != null)
	if piece == null:
		selection_name.text = "Nothing selected"
		selection_name.add_theme_color_override("font_color", palette.muted)
		return
	var asset = map_canvas.get_asset_for_piece(piece)
	if asset == null:
		selection_name.text = "Unknown object"
		selection_name.add_theme_color_override("font_color", palette.muted)
		return
	selection_name.text = str(asset.get("name", "Unknown object"))
	selection_name.add_theme_color_override("font_color", palette.gold)

func _on_grid_selected(index: int) -> void:
	var canvas_mode := BattleMapCanvas.GRID_SQUARE
	if index == 1:
		canvas_mode = BattleMapCanvas.GRID_DETECTED
	elif index == 2:
		canvas_mode = BattleMapCanvas.GRID_HIDDEN
	map_canvas.set_grid_mode(canvas_mode)
	_sync_grid_controls()
	_update_status("Grid cue: %s" % grid_select.get_item_text(index))

func _on_grid_opacity_changed(value: float) -> void:
	map_canvas.set_grid_opacity(value)

func _on_grid_color_changed(value: Color) -> void:
	map_canvas.set_grid_color(value)

func _on_builtin_landscape_selected(index: int) -> void:
	var paths := [
		"",
		"res://assets/landscapes/forest.png",
		"res://assets/landscapes/desert.png",
		"res://assets/landscapes/grassland.png",
		"res://assets/landscapes/snow.png"
	]
	if not map_canvas.set_builtin_background(paths[index]):
		_update_status("Could not load the selected built-in landscape")
		return
	_sync_grid_controls()
	_update_status("Landscape: %s" % landscape_select.get_item_text(index))

func _grid_dimension_input(initial_value: int) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = BattleMapCanvas.MIN_MANUAL_GRID_SIZE
	input.max_value = BattleMapCanvas.MAX_MANUAL_GRID_SIZE
	input.step = 1
	input.value = initial_value
	input.allow_greater = false
	input.allow_lesser = false
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return input

func _on_manual_grid_changed(_value: float) -> void:
	if map_canvas.set_manual_grid_size(roundi(grid_columns.value), roundi(grid_rows.value)):
		_update_grid_shape_warning()
		return
	_sync_manual_grid_inputs()

func _add_grid() -> void:
	if map_canvas.adjust_manual_grid(1):
		_sync_manual_grid_inputs()
		_update_status("Smaller squares: %d×%d grid" % [map_canvas.manual_grid_cells.x, map_canvas.manual_grid_cells.y])

func _remove_grid() -> void:
	if map_canvas.adjust_manual_grid(-1):
		_sync_manual_grid_inputs()
		_update_status("Bigger squares: %d×%d grid" % [map_canvas.manual_grid_cells.x, map_canvas.manual_grid_cells.y])

func _sync_manual_grid_inputs() -> void:
	grid_columns.set_value_no_signal(map_canvas.manual_grid_cells.x)
	grid_rows.set_value_no_signal(map_canvas.manual_grid_cells.y)
	grid_color_picker.color = map_canvas.grid_color
	_update_grid_shape_warning()

func _update_grid_shape_warning() -> void:
	var ratio := map_canvas.manual_cell_aspect_ratio()
	var is_ideal := ratio >= IDEAL_CELL_RATIO_MIN and ratio <= IDEAL_CELL_RATIO_MAX
	var too_rectangular := ratio < ACCEPTABLE_CELL_RATIO_MIN or ratio > ACCEPTABLE_CELL_RATIO_MAX
	grid_shape_warning.visible = (is_ideal or too_rectangular) and not map_canvas.has_detected_grid()
	if is_ideal:
		grid_shape_warning.text = "Ideal square size."
		grid_shape_warning.add_theme_color_override("font_color", palette.gold)
	elif ratio > ACCEPTABLE_CELL_RATIO_MAX:
		grid_shape_warning.text = "Warning: cells are too wide for models to fit naturally."
		grid_shape_warning.add_theme_color_override("font_color", palette.rose)
	elif ratio < ACCEPTABLE_CELL_RATIO_MIN:
		grid_shape_warning.text = "Warning: cells are too tall for models to fit naturally."
		grid_shape_warning.add_theme_color_override("font_color", palette.rose)
	else:
		grid_shape_warning.text = ""

func _zoom_in() -> void:
	map_canvas.set_zoom(map_canvas.zoom_level * BattleMapCanvas.ZOOM_FACTOR)

func _zoom_out() -> void:
	map_canvas.set_zoom(map_canvas.zoom_level / BattleMapCanvas.ZOOM_FACTOR)

func _zoom_reset() -> void:
	map_canvas.reset_zoom()

func _on_zoom_changed(value: float) -> void:
	zoom_label.text = "%d%%" % roundi(value * 25.0)

func _new_map() -> void:
	new_map_confirmation.size = Vector2i(460, 172)
	new_map_confirmation.popup_centered()

func _focus_new_map_cancel() -> void:
	new_map_cancel_button.grab_focus.call_deferred()

func _confirm_new_map() -> void:
	new_map_confirmation.hide()
	map_canvas.clear_map()
	_sync_grid_controls()
	current_path = ""
	_update_status("New empty stage")

func _show_open() -> void:
	open_dialog.popup_centered_ratio(0.72)

func _show_background() -> void:
	background_dialog.popup_centered_ratio(0.72)

func _show_export() -> void:
	export_dialog.current_file = "battle-map.png"
	export_dialog.popup_centered_ratio(0.72)

func _save() -> void:
	if current_path.is_empty():
		save_dialog.current_file = "my-map.battlemap"
		save_dialog.popup_centered_ratio(0.72)
	else:
		_save_to_path(current_path)

func _save_to_path(path: String) -> void:
	if not path.to_lower().ends_with(".battlemap"):
		path += ".battlemap"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_update_status("Could not save: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(map_canvas.serialize_state(), "\t"))
	current_path = path
	_update_status("Saved %s" % path.get_file())

func _load_from_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_update_status("Could not open: %s" % FileAccess.get_open_error())
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		_update_status("This file is not a valid battle map")
		return
	map_canvas.load_state(data)
	_sync_grid_controls()
	_sync_manual_grid_inputs()
	_sync_landscape_select()
	grid_opacity.value = map_canvas.grid_opacity
	current_path = path
	_update_status("Opened %s" % path.get_file())

func _import_background(path: String) -> void:
	var result := map_canvas.set_background(path)
	landscape_select.select(0)
	_sync_grid_controls()
	_sync_manual_grid_inputs()
	if result.get("loaded", false) and result.get("found", false):
		var cells: Vector2i = result["cells"]
		_update_status("Detected %d×%d landscape grid — snapping uses its existing lines" % [cells.x, cells.y])
	elif result.get("loaded", false):
		_update_status("No reliable grid detected — using the editor overlay")
	else:
		_update_status("Could not load that landscape image")

func _sync_grid_controls() -> void:
	var detected := map_canvas.has_detected_grid()
	grid_label.visible = not detected
	grid_select.visible = not detected
	grid_cue_controls.visible = not detected
	grid_select.set_item_disabled(1, not detected)
	if map_canvas.grid_mode == BattleMapCanvas.GRID_DETECTED and detected:
		grid_select.select(1)
	elif map_canvas.grid_mode == BattleMapCanvas.GRID_HIDDEN:
		grid_select.select(2)
	else:
		grid_select.select(0)
	grid_opacity.editable = map_canvas.grid_mode == BattleMapCanvas.GRID_SQUARE
	if not detected:
		_sync_manual_grid_inputs()

func _sync_landscape_select() -> void:
	var paths := [
		"",
		"res://assets/landscapes/forest.png",
		"res://assets/landscapes/desert.png",
		"res://assets/landscapes/grassland.png",
		"res://assets/landscapes/snow.png"
	]
	var selected_index := paths.find(map_canvas.background_path)
	landscape_select.select(maxi(0, selected_index))

func _export_to_path(path: String) -> void:
	if not path.to_lower().ends_with(".png"):
		path += ".png"
	var error := await map_canvas.export_visible_png(path)
	if error == OK:
		var export_size := Vector2i(map_canvas.background_texture.get_size()) if map_canvas.background_texture != null else Vector2i(map_canvas.size)
		_update_status("Exported %s at %d×%d" % [path.get_file(), export_size.x, export_size.y])
	else:
		_update_status("PNG export failed with error %d" % error)

func _undo() -> void:
	map_canvas.undo()
	_update_status("Undid last stage change")

func _redo() -> void:
	map_canvas.redo()
	_update_status("Redid stage change")

func _rotate_left() -> void:
	map_canvas.rotate_selected(-1)

func _rotate_right() -> void:
	map_canvas.rotate_selected(1)

func _duplicate() -> void:
	map_canvas.duplicate_selected()

func _delete() -> void:
	map_canvas.delete_selected()

func _mirror() -> void:
	map_canvas.mirror_selected()

func _refresh_actions() -> void:
	_set_piece_actions_enabled(map_canvas.get_selected_piece() != null)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_S:
		_save()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_O:
		_show_open()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		_undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_D:
		_duplicate()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		_zoom_in()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		_zoom_out()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_0:
		_zoom_reset()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DELETE:
		_delete()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R:
		if event.shift_pressed:
			_rotate_left()
		else:
			_rotate_right()
		get_viewport().set_input_as_handled()

func _asset_by_id(asset_id: String) -> Dictionary:
	for asset in assets:
		if asset["id"] == asset_id:
			return asset
	return {}

func _update_status(message: String) -> void:
	status_label.text = "  %s    |    Right-click Object Menu    Right-drag Pan    Wheel Zoom    Ctrl+0 Fit" % message

func _add_button(parent: Control, text: String, callback: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_piece_action(parent: Control, text: String, callback: Callable, tooltip: String) -> Button:
	var button := _add_button(parent, text, callback, tooltip)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	piece_action_buttons.append(button)
	return button

func _set_piece_actions_enabled(enabled: bool) -> void:
	for button in piece_action_buttons:
		button.disabled = not enabled

func _add_spacer(parent: Control, width: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	parent.add_child(spacer)

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 230
	label.add_theme_color_override("font_color", palette.paper)
	label.add_theme_font_size_override("font_size", 18)
	return label

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", palette.paper)
	label.add_theme_font_size_override("font_size", 17)
	return label

func _small_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", palette.gold)
	label.add_theme_font_size_override("font_size", 11)
	return label

func _detail_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label

func _build_theme() -> Theme:
	var app_theme := Theme.new()
	app_theme.default_font_size = 14
	app_theme.set_color("font_color", "Label", palette.paper)
	app_theme.set_color("font_color", "Button", palette.paper)
	app_theme.set_color("font_hover_color", "Button", Color.WHITE)
	app_theme.set_color("font_pressed_color", "Button", palette.gold)
	app_theme.set_color("font_color", "LineEdit", palette.paper)
	app_theme.set_color("font_placeholder_color", "LineEdit", palette.muted)
	app_theme.set_color("font_color", "OptionButton", palette.paper)
	app_theme.set_stylebox("normal", "Button", _button_style(palette.panel_raised, palette.line))
	app_theme.set_stylebox("hover", "Button", _button_style(Color("293844"), palette.cobalt.lightened(0.2)))
	app_theme.set_stylebox("pressed", "Button", _button_style(Color("26375b"), palette.cobalt))
	app_theme.set_stylebox("focus", "Button", _button_style(Color("26375b"), palette.gold))
	app_theme.set_stylebox("normal", "LineEdit", _button_style(palette.stage, palette.line))
	app_theme.set_stylebox("focus", "LineEdit", _button_style(palette.stage, palette.gold))
	app_theme.set_stylebox("normal", "OptionButton", _button_style(palette.panel_raised, palette.line))
	app_theme.set_stylebox("panel", "PopupPanel", _panel_style(palette.panel, 1, 1, 1, 1))
	app_theme.set_constant("outline_size", "Label", 0)
	return app_theme

func _panel_style(color: Color, top: int, right: int, bottom: int, left: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = palette.line
	style.border_width_top = top
	style.border_width_right = right
	style.border_width_bottom = bottom
	style.border_width_left = left
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
