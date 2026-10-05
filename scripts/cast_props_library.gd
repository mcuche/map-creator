class_name CastPropsLibrary
extends PanelContainer

signal catalog_changed(entries_by_id: Dictionary)
signal status_message(message: String)

const AssetDragButtonScript = preload("res://scripts/asset_drag_button.gd")
const STARTER_CATALOG_PATH := "res://data/starter_catalog.json"
const STARTER_IMAGE_DIR := "res://assets/sprites"
const USER_CATALOG_DIR := "user://cast-and-props"
const USER_CATALOG_PATH := "user://cast-and-props/catalog.json"
const MAX_GROUPS := 100
const MAX_ENTRIES := 500
const MAX_CATALOG_BYTES := 5 * 1024 * 1024
const MAX_IMAGE_BYTES := 20 * 1024 * 1024
const MAX_IMAGE_DIMENSION := 4096
const MAX_FOOTPRINT := 100
const COMPACT_WIDTH := 280
const WIDE_WIDTH := 400
const VALID_ID_PATTERN := "^[a-z0-9_-]+$"
const CHEVRON_UP_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12' fill='none'><path d='M2 8L6 4L10 8' stroke='#F0C96B' stroke-width='1.75' stroke-linecap='round' stroke-linejoin='round'/></svg>"
const CHEVRON_DOWN_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12' fill='none'><path d='M2 4L6 8L10 4' stroke='#F0C96B' stroke-width='1.75' stroke-linecap='round' stroke-linejoin='round'/></svg>"
var _catalog_path := USER_CATALOG_PATH
var _image_base_override := ""
var _groups: Array = []
var _entries: Array = []
var _entries_by_id := {}
var _group_views := {}
var _entry_buttons := {}
var _has_valid_catalog := false
var _using_fallback := false
var _built := false
var _card_columns := 2

var _search: LineEdit
var _header: VBoxContainer
var _header_row: HBoxContainer
var _header_actions: HBoxContainer
var _scroll: ScrollContainer
var _scroll_content: MarginContainer
var _groups_container: VBoxContainer
var _empty_state: VBoxContainer
var _error_dialog: AcceptDialog
var _chevron_up_icon: Texture2D
var _chevron_down_icon: Texture2D


func _ready() -> void:
	_ensure_interface()


func initialize(catalog_path_override := "", image_base_override := "") -> Dictionary:
	_ensure_interface()
	if catalog_path_override.is_empty():
		_catalog_path = USER_CATALOG_PATH
		var bootstrap_error := _bootstrap_user_catalog()
		if not bootstrap_error.is_empty():
			return _activate_starter_fallback([bootstrap_error])
	else:
		_catalog_path = catalog_path_override
	_image_base_override = image_base_override
	return _load_and_apply(_catalog_path, _image_base_override)


func reload_catalog() -> Dictionary:
	return _load_and_apply(_catalog_path, _image_base_override)


func catalog_snapshot() -> Dictionary:
	return _entries_by_id.duplicate(true)


func set_filter(query: String) -> void:
	_ensure_interface()
	_search.set_text(query)
	_apply_filter(query)


func visible_group_ids() -> Array[String]:
	var result: Array[String] = []
	for group in _groups:
		var group_id := str(group["id"])
		if _group_views.has(group_id) and _group_views[group_id]["section"].visible:
			result.append(group_id)
	return result


func is_using_fallback() -> bool:
	return _using_fallback


func set_card_columns(columns: int) -> void:
	assert(columns == 2 or columns == 3)
	_ensure_interface()
	if columns == _card_columns:
		return
	_card_columns = columns
	_header_actions.get_parent().remove_child(_header_actions)
	if columns == 3:
		_header_row.add_child(_header_actions)
	else:
		_header.add_child(_header_actions)
	custom_minimum_size.x = WIDE_WIDTH if columns == 3 else COMPACT_WIDTH
	for controls in _group_views.values():
		controls["grid"].columns = columns


func _ensure_interface() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size.x = COMPACT_WIDTH
	add_theme_stylebox_override("panel", _panel_style(Color("182128"), 0, 1, 0, 0))
	_chevron_up_icon = _svg_icon(CHEVRON_UP_SVG)
	_chevron_down_icon = _svg_icon(CHEVRON_DOWN_SVG)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", 6)
	column.add_child(_header)
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 6)
	_header.add_child(_header_row)
	var title := Label.new()
	title.text = "CAST & PROPS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	_header_row.add_child(title)
	_header_actions = HBoxContainer.new()
	_header_actions.add_theme_constant_override("separation", 6)
	_header_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	_header.add_child(_header_actions)
	var open_button := Button.new()
	open_button.text = "OPEN FOLDER"
	open_button.tooltip_text = "Open the editable catalog and images"
	open_button.pressed.connect(_open_catalog_folder)
	_header_actions.add_child(open_button)
	var reload_button := Button.new()
	reload_button.text = "RELOAD"
	reload_button.tooltip_text = "Validate and reload catalog.json"
	reload_button.pressed.connect(_on_reload_pressed)
	_header_actions.add_child(reload_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Search cast and props"
	_search.text_changed.connect(_apply_filter)
	column.add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_scroll_content = MarginContainer.new()
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_scroll_content)
	_scroll.get_v_scroll_bar().visibility_changed.connect(_sync_gutter)

	_groups_container = VBoxContainer.new()
	_groups_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_container.add_theme_constant_override("separation", 14)
	_scroll_content.add_child(_groups_container)

	_empty_state = VBoxContainer.new()
	_empty_state.visible = false
	_empty_state.add_theme_constant_override("separation", 8)
	var empty_title := Label.new()
	empty_title.text = "Your catalog is empty"
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.add_theme_font_size_override("font_size", 16)
	_empty_state.add_child(empty_title)
	var empty_hint := Label.new()
	empty_hint.text = "Add groups and entries to catalog.json, then reload."
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_hint.add_theme_color_override("font_color", Color("a8b1b4"))
	_empty_state.add_child(empty_hint)
	_groups_container.add_child(_empty_state)

	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "Catalog could not be loaded"
	_error_dialog.min_size = Vector2i(680, 420)
	_error_dialog.add_button("Open Catalog Folder", true, "open_folder")
	_error_dialog.add_button("Copy Errors", true, "copy_errors")
	_error_dialog.add_button("Retry Reload", true, "retry")
	_error_dialog.custom_action.connect(_on_error_action)
	add_child(_error_dialog)
	_sync_gutter.call_deferred()


func _bootstrap_user_catalog(catalog_dir := USER_CATALOG_DIR) -> String:
	var absolute_dir := ProjectSettings.globalize_path(catalog_dir)
	var catalog_path := catalog_dir.path_join("catalog.json")
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir.path_join("images"))
	if error != OK:
		return "Could not create the catalog folder (error %d)." % error
	var first_run := not FileAccess.file_exists(catalog_path)
	if first_run:
		var starter := _read_catalog(STARTER_CATALOG_PATH, STARTER_IMAGE_DIR)
		if not starter["ok"]:
			return "Could not load starter catalog: %s" % "; ".join(PackedStringArray(starter["errors"]))
		for entry in starter["entries"]:
			var source := str(entry["image_path"])
			var file_name := source.get_file()
			var destination := catalog_dir.path_join("images").path_join(file_name)
			if FileAccess.file_exists(destination):
				continue
			error = _copy_starter_image(source, destination)
			if error != OK:
				return "Could not copy starter image %s (error %d)." % [file_name, error]
		error = _copy_file(STARTER_CATALOG_PATH, catalog_path)
		if error != OK:
			return "Could not create catalog.json (error %d)." % error
	return ""


func _copy_starter_image(source: String, destination: String) -> Error:
	var texture := load(source) as Texture2D
	if texture == null:
		return ERR_FILE_NOT_FOUND
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ERR_FILE_CORRUPT
	return image.save_png(destination)


func _copy_file(source: String, destination: String) -> Error:
	var source_file := FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()
	var temporary_path := ProjectSettings.globalize_path(destination + ".tmp")
	var destination_file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if destination_file == null:
		return FileAccess.get_open_error()
	destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	destination_file.flush()
	var write_error := destination_file.get_error()
	destination_file = null
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return write_error
	var rename_error := DirAccess.rename_absolute(temporary_path, ProjectSettings.globalize_path(destination))
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
	return rename_error


func _load_and_apply(path: String, image_base_override: String) -> Dictionary:
	var result := _read_catalog(path, image_base_override)
	if not result["ok"]:
		if not _has_valid_catalog and path == USER_CATALOG_PATH:
			return _activate_starter_fallback(result["errors"])
		_show_errors(result["errors"])
		status_message.emit("Catalog reload failed — previous catalog retained")
		return result
	var previous_groups := _groups.duplicate(true)
	var previous_entries := _entries_by_id.duplicate(true)
	_groups = result["groups"]
	_entries = result["entries"]
	_entries_by_id = result["entries_by_id"]
	_has_valid_catalog = true
	_using_fallback = false
	_rebuild_cards()
	catalog_changed.emit(catalog_snapshot())
	var summary := _change_summary(previous_groups, previous_entries)
	status_message.emit(summary)
	result["summary"] = summary
	return result


func _activate_starter_fallback(original_errors: Array) -> Dictionary:
	var starter := _read_catalog(STARTER_CATALOG_PATH, STARTER_IMAGE_DIR)
	if starter["ok"]:
		_groups = starter["groups"]
		_entries = starter["entries"]
		_entries_by_id = starter["entries_by_id"]
		_has_valid_catalog = true
		_using_fallback = true
		_rebuild_cards()
		catalog_changed.emit(catalog_snapshot())
	_show_errors(original_errors)
	status_message.emit("Using the starter catalog for this session — catalog.json needs attention")
	return {"ok": false, "errors": original_errors, "fallback": starter["ok"]}


func _read_catalog(path: String, image_base_override: String) -> Dictionary:
	var errors: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failed(["Could not open %s (error %d)." % [path, FileAccess.get_open_error()]])
	if file.get_length() > MAX_CATALOG_BYTES:
		return _failed(["catalog.json exceeds the 5 MiB limit."])
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return _failed(["JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()]])
	var document = parser.data
	if not document is Dictionary:
		return _failed(["The catalog root must be a JSON object."])
	_check_unknown_fields(document, ["version", "groups", "entries"], "catalog", errors)
	if not document.has("version") or not _is_integer(document["version"]) or int(document["version"]) != 1:
		errors.append("catalog.version must be the integer 1.")
	var raw_groups = document.get("groups", null)
	var raw_entries = document.get("entries", null)
	if not raw_groups is Array:
		errors.append("catalog.groups must be an array.")
		raw_groups = []
	if not raw_entries is Array:
		errors.append("catalog.entries must be an array.")
		raw_entries = []
	if raw_groups.size() > MAX_GROUPS:
		errors.append("catalog.groups exceeds the 100-group limit.")
	if raw_entries.size() > MAX_ENTRIES:
		errors.append("catalog.entries exceeds the 500-entry limit.")

	var id_regex := RegEx.new()
	id_regex.compile(VALID_ID_PATTERN)
	var groups: Array = []
	var group_ids := {}
	for index in range(raw_groups.size()):
		var raw_group = raw_groups[index]
		var location := "groups[%d]" % index
		if not raw_group is Dictionary:
			errors.append("%s must be an object." % location)
			continue
		_check_unknown_fields(raw_group, ["id", "name"], location, errors)
		var group_id := _validate_id(raw_group.get("id", null), "%s.id" % location, id_regex, errors)
		var group_name := _validate_name(raw_group.get("name", null), "%s.name" % location, errors)
		if not group_id.is_empty():
			if group_ids.has(group_id):
				errors.append("%s.id duplicates group ID '%s'." % [location, group_id])
			else:
				group_ids[group_id] = true
		if not group_id.is_empty() and not group_name.is_empty():
			groups.append({"id": group_id, "name": group_name})

	var entries: Array = []
	var entries_by_id := {}
	var catalog_base := ProjectSettings.globalize_path(path.get_base_dir())
	for index in range(raw_entries.size()):
		var raw_entry = raw_entries[index]
		var location := "entries[%d]" % index
		if not raw_entry is Dictionary:
			errors.append("%s must be an object." % location)
			continue
		_check_unknown_fields(raw_entry, ["id", "name", "group_id", "footprint", "image"], location, errors)
		var entry_id := _validate_id(raw_entry.get("id", null), "%s.id" % location, id_regex, errors)
		var entry_name := _validate_name(raw_entry.get("name", null), "%s.name" % location, errors)
		var group_id := _validate_id(raw_entry.get("group_id", null), "%s.group_id" % location, id_regex, errors)
		if not group_id.is_empty() and not group_ids.has(group_id):
			errors.append("%s.group_id refers to missing group '%s'." % [location, group_id])
		var footprint := _validate_footprint(raw_entry.get("footprint", null), location, errors)
		var image_result := _validate_image(raw_entry.get("image", null), location, catalog_base, image_base_override)
		errors.append_array(image_result["errors"])
		if not entry_id.is_empty():
			if entries_by_id.has(entry_id):
				errors.append("%s.id duplicates entry ID '%s'." % [location, entry_id])
			else:
				entries_by_id[entry_id] = true
		if not entry_id.is_empty() and not entry_name.is_empty() and not group_id.is_empty() and footprint != Vector2i.ZERO and image_result["ok"]:
			entries.append({
				"id": entry_id,
				"name": entry_name,
				"group_id": group_id,
				"footprint": footprint,
				"image_path": image_result["path"]
			})
	if not errors.is_empty():
		return _failed(errors)
	entries_by_id.clear()
	for entry in entries:
		entries_by_id[entry["id"]] = entry
	return {"ok": true, "errors": [], "groups": groups, "entries": entries, "entries_by_id": entries_by_id}


func _validate_id(value, location: String, regex: RegEx, errors: Array) -> String:
	if not value is String or value.is_empty():
		errors.append("%s must be a non-empty string." % location)
		return ""
	if regex.search(value) == null:
		errors.append("%s must use lowercase letters, numbers, hyphens, or underscores." % location)
		return ""
	return value


func _validate_name(value, location: String, errors: Array) -> String:
	if not value is String or value.strip_edges().is_empty():
		errors.append("%s must be a non-empty string." % location)
		return ""
	return value.strip_edges()


func _validate_footprint(value, location: String, errors: Array) -> Vector2i:
	if not value is Array or value.size() != 2 or not _is_integer(value[0]) or not _is_integer(value[1]):
		errors.append("%s.footprint must be [width, height] using whole numbers." % location)
		return Vector2i.ZERO
	var footprint := Vector2i(int(value[0]), int(value[1]))
	if footprint.x < 1 or footprint.y < 1 or footprint.x > MAX_FOOTPRINT or footprint.y > MAX_FOOTPRINT:
		errors.append("%s.footprint dimensions must be between 1 and 100." % location)
		return Vector2i.ZERO
	return footprint


func _validate_image(value, location: String, catalog_base: String, image_base_override: String) -> Dictionary:
	var errors: Array[String] = []
	if not value is String or value.is_empty():
		return {"ok": false, "path": "", "errors": ["%s.image must be a non-empty relative path." % location]}
	if value.is_absolute_path() or value.begins_with("res://") or value.begins_with("user://"):
		return {"ok": false, "path": "", "errors": ["%s.image must be relative to the catalog folder." % location]}
	if value.get_extension().to_lower() != "png":
		errors.append("%s.image must reference a PNG file." % location)
	var resolved := ""
	if not image_base_override.is_empty():
		resolved = image_base_override.path_join(value.get_file())
	else:
		resolved = catalog_base.path_join(value).simplify_path()
		var normalized_base := catalog_base.replace("\\", "/").trim_suffix("/").to_lower()
		var normalized_path := resolved.replace("\\", "/").to_lower()
		if not normalized_path.begins_with(normalized_base + "/"):
			errors.append("%s.image escapes the catalog folder." % location)
	if errors.is_empty():
		var image_file := FileAccess.open(resolved, FileAccess.READ)
		if image_file == null:
			errors.append("%s.image could not be opened: %s" % [location, value])
		elif image_file.get_length() > MAX_IMAGE_BYTES:
			errors.append("%s.image exceeds the 2 MiB limit." % location)
	if errors.is_empty():
		var image_size := Vector2i.ZERO
		if resolved.begins_with("res://") or resolved.begins_with("user://"):
			var texture := load(resolved) as Texture2D
			if texture != null:
				image_size = Vector2i(texture.get_size())
		else:
			var image := Image.load_from_file(resolved)
			if not image.is_empty():
				image_size = image.get_size()
		if image_size == Vector2i.ZERO:
			errors.append("%s.image is not a readable PNG." % location)
		elif image_size.x > MAX_IMAGE_DIMENSION or image_size.y > MAX_IMAGE_DIMENSION:
			errors.append("%s.image exceeds 4096×4096 pixels." % location)
	return {"ok": errors.is_empty(), "path": resolved, "errors": errors}


func _check_unknown_fields(value: Dictionary, allowed: Array, location: String, errors: Array) -> void:
	for key in value:
		if not allowed.has(str(key)):
			errors.append("%s has unknown field '%s'." % [location, key])


func _is_integer(value) -> bool:
	return (value is int) or (value is float and is_equal_approx(value, roundf(value)))


func _failed(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors}


func _rebuild_cards() -> void:
	for child in _groups_container.get_children():
		if child != _empty_state:
			_groups_container.remove_child(child)
			child.queue_free()
	_group_views.clear()
	_entry_buttons.clear()
	_empty_state.visible = _groups.is_empty() and _entries.is_empty()
	for group in _groups:
		var group_id := str(group["id"])
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 6)
		var heading := _category_heading(str(group["name"]))
		section.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = _card_columns
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		section.add_child(grid)
		var empty_hint := Label.new()
		empty_hint.text = "Nothing in this group yet."
		empty_hint.add_theme_color_override("font_color", Color("a8b1b4"))
		empty_hint.visible = false
		section.add_child(empty_hint)
		_group_views[group_id] = {"section": section, "heading": heading, "grid": grid, "empty_hint": empty_hint, "expanded": true, "has_matches": false}
		heading.pressed.connect(_toggle_group.bind(group_id))
		for entry in _entries:
			if entry["group_id"] != group_id:
				continue
			var button = AssetDragButtonScript.new()
			button.custom_minimum_size = Vector2(114, 116)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.configure(entry)
			grid.add_child(button)
			_entry_buttons[entry["id"]] = button
		_groups_container.add_child(section)
	_groups_container.move_child(_empty_state, _groups_container.get_child_count() - 1)
	_apply_filter(_search.text)
	_sync_gutter.call_deferred()


func _apply_filter(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	var matching_groups := {}
	for entry in _entries:
		var button: Button = _entry_buttons.get(entry["id"], null)
		if button == null:
			continue
		var group_name := _group_name(entry["group_id"])
		var matches := normalized.is_empty() or normalized in str(entry["name"]).to_lower() or normalized in group_name.to_lower()
		button.visible = matches
		if matches:
			matching_groups[entry["group_id"]] = true
	for group in _groups:
		var group_id := str(group["id"])
		var controls: Dictionary = _group_views[group_id]
		var group_matches := matching_groups.has(group_id)
		var group_empty := _entries_for_group(group_id) == 0
		controls["has_matches"] = group_matches
		controls["section"].visible = group_matches or (normalized.is_empty() and group_empty)
		controls["grid"].visible = group_matches and bool(controls["expanded"])
		controls["empty_hint"].visible = group_empty and normalized.is_empty() and bool(controls["expanded"])
	_empty_state.visible = _groups.is_empty() and _entries.is_empty()
	_sync_gutter.call_deferred()


func _group_name(group_id: String) -> String:
	for group in _groups:
		if group["id"] == group_id:
			return str(group["name"])
	return ""


func _entries_for_group(group_id: String) -> int:
	var count := 0
	for entry in _entries:
		if entry["group_id"] == group_id:
			count += 1
	return count


func _toggle_group(group_id: String) -> void:
	var controls: Dictionary = _group_views[group_id]
	var expanded := not bool(controls["expanded"])
	controls["expanded"] = expanded
	controls["heading"].icon = _chevron_up_icon if expanded else _chevron_down_icon
	controls["heading"].tooltip_text = ("Collapse %s" if expanded else "Expand %s") % str(controls["heading"].text).to_lower()
	controls["grid"].visible = expanded and bool(controls["has_matches"])
	controls["empty_hint"].visible = expanded and _entries_for_group(group_id) == 0 and _search.text.strip_edges().is_empty()
	_sync_gutter.call_deferred()


func _sync_gutter() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_scroll_content):
		return
	_scroll_content.add_theme_constant_override("margin_right", 12 if _scroll.get_v_scroll_bar().visible else 0)


func _category_heading(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = _chevron_up_icon
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 26
	button.tooltip_text = "Collapse %s" % text.to_lower()
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("f0c96b"))
	button.add_theme_color_override("font_hover_color", Color("f7f2e8"))
	return button


func _change_summary(previous_groups: Array, previous_entries: Dictionary) -> String:
	if previous_groups.is_empty() and previous_entries.is_empty():
		return "Catalog loaded — %d groups, %d entries" % [_groups.size(), _entries.size()]
	var current_group_ids := {}
	var previous_group_ids := {}
	for group in _groups: current_group_ids[group["id"]] = group
	for group in previous_groups: previous_group_ids[group["id"]] = group
	var added := 0
	var changed := 0
	var removed := 0
	for entry_id in _entries_by_id:
		if not previous_entries.has(entry_id): added += 1
		elif previous_entries[entry_id] != _entries_by_id[entry_id]: changed += 1
	for entry_id in previous_entries:
		if not _entries_by_id.has(entry_id): removed += 1
	return "Catalog reloaded — %d added, %d changed, %d removed; %d groups" % [added, changed, removed, current_group_ids.size()]


func _on_reload_pressed() -> void:
	reload_catalog()


func _open_catalog_folder() -> void:
	_bootstrap_user_catalog()
	OS.shell_open(ProjectSettings.globalize_path(USER_CATALOG_DIR))


func _show_errors(errors: Array) -> void:
	_error_dialog.dialog_text = "The catalog was not changed:\n\n• " + "\n• ".join(errors)
	_error_dialog.set_meta("errors", "\n".join(errors))
	_error_dialog.popup_centered_ratio(0.65)


func _on_error_action(action: StringName) -> void:
	match str(action):
		"open_folder": _open_catalog_folder()
		"copy_errors": DisplayServer.clipboard_set(str(_error_dialog.get_meta("errors", "")))
		"retry": reload_catalog()


func _svg_icon(source: String) -> Texture2D:
	var image := Image.new()
	if image.load_svg_from_string(source) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _panel_style(color: Color, top: int, right: int, bottom: int, left: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("344550")
	style.border_width_top = top
	style.border_width_right = right
	style.border_width_bottom = bottom
	style.border_width_left = left
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style
