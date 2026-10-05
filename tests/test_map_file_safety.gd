extends Node

const MainScript = preload("res://scripts/main.gd")
const CatalogScript = preload("res://scripts/cast_props_library.gd")

func _ready() -> void:
	var main: Control = MainScript.new()
	add_child(main)
	var canvas: BattleMapCanvas = main.map_canvas
	var folder := "user://map-file-safety-%d" % Time.get_ticks_usec()
	var absolute_folder := ProjectSettings.globalize_path(folder)
	if DirAccess.make_dir_recursive_absolute(absolute_folder) != OK:
		_fail("Could not create map test folder")
		return
	var path := folder.path_join("saved.battlemap")
	var original := FileAccess.open(path, FileAccess.WRITE)
	original.store_string("old bytes")
	original = null
	main._save_to_path(path)
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	var saved_state = JSON.parse_string(saved_bytes.get_string_from_utf8())
	if main.current_path != path or not saved_state is Dictionary or saved_state.get("version") != 3 or main.error_dialog.visible:
		_fail("Successful save did not replace the map")
		return
	var blocked_path := folder.path_join("blocked.battlemap")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked_path))
	main._save_to_path(blocked_path)
	if main.current_path != path or FileAccess.get_file_as_bytes(path) != saved_bytes or not _dismiss_error(main, "Could not save"):
		_fail("Failed replacement changed the previous map or did not display its error")
		return
	main._save_to_path(folder.path_join("missing").path_join("unwritable.battlemap"))
	if main.current_path != path or FileAccess.get_file_as_bytes(path) != saved_bytes or not _dismiss_error(main, "Could not save"):
		_fail("Failed temporary write changed the previous map or did not display its error")
		return
	var entry := {"id": "knight", "name": "Knight", "group_id": "cast", "footprint": Vector2i.ONE, "image_path": ""}
	canvas.pieces = [{"instance_id": 1, "entry": entry, "cell": Vector2i(2, 2), "rotation": 0, "mirrored": false, "layer": 0}]
	canvas.selected_id = 1
	canvas.undo_stack = [{"pieces": [], "selected_id": -1, "next_id": 1}]
	canvas.redo_stack = [{"pieces": [], "selected_id": -1, "next_id": 1}]
	var retained_pieces := canvas.pieces.duplicate(true)
	var retained_undo := canvas.undo_stack.duplicate(true)
	var retained_redo := canvas.redo_stack.duplicate(true)
	var retained_grid := canvas.manual_grid_cells
	var retained_grid_mode := canvas.grid_mode
	var retained_next_id := canvas.next_id
	var save_result := canvas.serialize_state()
	if save_result.has("error"):
		_fail("Could not serialize the current map: %s" % save_result["error"])
		return
	var valid: Dictionary = save_result["data"]
	var invalid_maps := [
		{},
		{"version": 3, "pieces": []},
		{"version": 3, "pieces": "wrong", "images": {}},
		{"version": 3, "pieces": [{}], "images": {}},
		{"version": 3, "pieces": [valid["pieces"][0], valid["pieces"][0]], "images": {}},
		{"version": 3, "pieces": [valid["pieces"][0].duplicate(true)], "images": {}},
		{"version": 3, "pieces": [valid["pieces"][0].duplicate(true), valid["pieces"][0].duplicate(true)], "images": {}},
		{"version": 3, "pieces": [valid["pieces"][0].duplicate(true)], "images": {}},
		{"version": 3, "manual_grid_columns": "wide", "pieces": [], "images": {}},
		{"version": 1, "pieces": []},
		{"version": 1, "pieces": [{"instance_id": 1, "asset_id": "table", "cell_x": 0, "cell_y": 0}]},
		{"version": 2, "pieces": []},
		{"version": 2, "pieces": [valid["pieces"][0]]}
	]
	invalid_maps[5]["pieces"][0]["cell_x"] = 1000
	invalid_maps[6]["pieces"][1]["instance_id"] = 2
	invalid_maps[7]["pieces"][0]["entry"]["footprint_width"] = 0
	for index in range(invalid_maps.size()):
		var invalid_path := folder.path_join("invalid-%d.battlemap" % index)
		var fixture := FileAccess.open(invalid_path, FileAccess.WRITE)
		fixture.store_string(JSON.stringify(invalid_maps[index]))
		fixture = null
		main._load_from_path(invalid_path)
		var expected_error := "Unsupported map version." if invalid_maps[index].get("version") in [1, 2] else "battle map"
		if not _dismiss_error(main, expected_error):
			_fail("Rejected map did not display its error")
			return
		if main.current_path != path or canvas.pieces != retained_pieces or canvas.selected_id != 1 \
				or canvas.manual_grid_cells != retained_grid or canvas.grid_mode != retained_grid_mode \
				or canvas.next_id != retained_next_id or canvas.undo_stack != retained_undo or canvas.redo_stack != retained_redo:
			_fail("Rejected map %d changed the open stage" % index)
			return
		DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	if not canvas.load_state({"version": 3, "pieces": [], "images": {}}).is_empty() or not canvas.pieces.is_empty():
		_fail("Valid empty map was rejected")
		return
	if not canvas.load_state(valid).is_empty() or canvas.pieces != retained_pieces:
		_fail("Valid map was rejected")
		return
	var image_path := absolute_folder.path_join("piece.png")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	if image.save_png(image_path) != OK:
		_fail("Could not create portable map image")
		return
	entry["image_path"] = image_path
	canvas.pieces = [
		{"instance_id": 1, "entry": entry, "cell": Vector2i(2, 2), "rotation": 0, "mirrored": false, "layer": 0},
		{"instance_id": 2, "entry": entry, "cell": Vector2i(3, 2), "rotation": 0, "mirrored": false, "layer": 1}
	]
	main._save_to_path(path)
	var portable = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not portable is Dictionary or portable.get("version") != 3 or portable["images"].size() != 1:
		_fail("Save did not embed the shared image once")
		return
	# The image currently displayed must win over a changed source file.
	canvas._texture_for_entry(canvas.pieces[0]["entry"])
	image.fill(Color.BLUE)
	image.save_png(image_path)
	main._save_to_path(path)
	var shown_image := Image.new()
	shown_image.load_png_from_buffer(Marshalls.base64_to_raw(JSON.parse_string(FileAccess.get_file_as_string(path))["images"][image_path]))
	if shown_image.get_pixel(0, 0) != Color.RED:
		_fail("Save captured a changed source instead of the displayed image")
		return
	var portable_bytes := FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(image_path)
	canvas.pieces[1]["cell"] = Vector2i(4, 2)
	main._save_to_path(path)
	if main.error_dialog.visible or FileAccess.get_file_as_bytes(path) == portable_bytes:
		_fail("Second save without reopening lost the committed image")
		return
	main._load_from_path(path)
	var restored_texture := canvas._texture_for_entry(canvas.pieces[0]["entry"])
	if canvas.pieces.size() != 2 or canvas.pieces[1]["cell"] != Vector2i(4, 2) or restored_texture == null or restored_texture.get_image().get_pixel(0, 0) != Color.RED:
		_fail("Map did not restore its image after the PNG was removed")
		return
	canvas.pieces[0]["cell"] = Vector2i(1, 2)
	main._save_to_path(path)
	var resaved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if main.error_dialog.visible or not resaved is Dictionary or resaved["pieces"][0]["cell_x"] != 1:
		_fail("Map could not be saved again after the PNG was removed")
		return
	var new_image_path := absolute_folder.path_join("missing.png")
	canvas.pieces[0]["entry"]["image_path"] = new_image_path
	var intact_bytes := FileAccess.get_file_as_bytes(path)
	main._save_to_path(path)
	if not _dismiss_error(main, "Could not save") or FileAccess.get_file_as_bytes(path) != intact_bytes:
		_fail("Unrecoverable image replaced the previous map")
		return
	canvas.pieces[0]["entry"]["image_path"] = image_path
	portable["images"].erase(image_path)
	if canvas.load_state(portable).is_empty() or canvas.pieces.size() != 2:
		_fail("Invalid embedded image changed the open map")
		return
	var large_dir := folder.path_join("large-catalog")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(large_dir.path_join("images")))
	var large_path := large_dir.path_join("images").path_join("large.png")
	var pixels := PackedByteArray()
	pixels.resize(1024 * 1024 * 4)
	var random := RandomNumberGenerator.new()
	random.seed = 12345
	for index in range(pixels.size()):
		pixels[index] = 255 if index % 4 == 3 else random.randi_range(0, 255)
	var large_image := Image.create_from_data(1024, 1024, false, Image.FORMAT_RGBA8, pixels)
	if large_image.save_png(large_path) != OK or FileAccess.get_file_as_bytes(large_path).size() <= BattleMapCanvas.MAX_EMBEDDED_IMAGE_BYTES:
		_fail("Could not create oversized PNG fixture")
		return
	var original_large_bytes := FileAccess.get_file_as_bytes(large_path)
	var limit_image := Image.create_from_data(700, 700, false, Image.FORMAT_RGBA8, pixels.slice(0, 700 * 700 * 4))
	var limit_bytes := limit_image.save_png_to_buffer()
	var oversized_collection := {"version": 3, "pieces": [], "images": {}}
	for index in range(24):
		oversized_collection["images"]["image-%d" % index] = Marshalls.raw_to_base64(limit_bytes)
	if limit_bytes.size() <= 0 or limit_bytes.size() > BattleMapCanvas.MAX_EMBEDDED_IMAGE_BYTES or canvas.load_state(oversized_collection).is_empty():
		_fail("Map accepted more than 32 MiB of embedded images")
		return
	var catalog_path := large_dir.path_join("catalog.json")
	var catalog_file := FileAccess.open(catalog_path, FileAccess.WRITE)
	catalog_file.store_string(JSON.stringify({"version": 1, "groups": [{"id": "props", "name": "Props"}], "entries": [{"id": "large", "name": "Large", "group_id": "props", "footprint": [1, 1], "image": "images/large.png"}]}))
	catalog_file = null
	var catalog: CastPropsLibrary = CatalogScript.new()
	add_child(catalog)
	if not catalog.initialize(catalog_path)["ok"]:
		_fail("Catalog rejected a PNG between 2 and 20 MiB")
		return
	canvas.pieces = [{"instance_id": 1, "entry": {"id": "large", "name": "Large", "group_id": "props", "footprint": Vector2i.ONE, "image_path": ProjectSettings.globalize_path(large_path)}, "cell": Vector2i.ZERO, "rotation": 0, "mirrored": false, "layer": 0}]
	main._save_to_path(path)
	var reduced = JSON.parse_string(FileAccess.get_file_as_string(path))
	var reduced_bytes := Marshalls.base64_to_raw(reduced["images"][ProjectSettings.globalize_path(large_path)])
	if main.error_dialog.visible or reduced_bytes.size() > BattleMapCanvas.MAX_EMBEDDED_IMAGE_BYTES or FileAccess.get_file_as_bytes(large_path) != original_large_bytes:
		_fail("Oversized catalog PNG was not safely reduced for the map")
		return
	catalog.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(catalog_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(large_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(large_dir.path_join("images")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(large_dir))
	canvas.undo_stack = [{"pieces": [], "selected_id": -1, "next_id": 1}]
	canvas.redo_stack = [{"pieces": [], "selected_id": -1, "next_id": 1}]
	main._confirm_new_map()
	if not canvas.pieces.is_empty() or not canvas.embedded_images.is_empty() or not canvas.piece_textures.is_empty() or canvas.can_undo() or canvas.can_redo():
		_fail("New Map retained pieces, images, or history")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(absolute_folder)
	print("Map file safety tests passed")
	get_tree().quit(0)

func _dismiss_error(main: Control, expected_message: String) -> bool:
	var reported: bool = main.error_dialog.visible and expected_message in main.error_dialog.dialog_text
	main.error_dialog.hide()
	return reported

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
