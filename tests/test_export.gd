extends Node

func _ready() -> void:
	var canvas := BattleMapCanvas.new()
	add_child(canvas)
	canvas.size = Vector2(720, 480)
	var background := Image.create(1280, 960, false, Image.FORMAT_RGBA8)
	background.fill(Color("263d2c"))
	canvas.background_texture = ImageTexture.create_from_image(background)
	var path := "user://export-resolution-test.png"
	var error := await canvas.export_visible_png(path)
	if error != OK:
		_fail("High-resolution export failed with error %d" % error)
		return
	var exported := Image.load_from_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if exported.get_size() != Vector2i(1280, 960):
		_fail("Export used wrong dimensions: %s" % exported.get_size())
		return
	var source_path := "user://export-prop-source.png"
	var source_absolute := ProjectSettings.globalize_path(source_path)
	var prop_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	prop_image.fill(Color.RED)
	if prop_image.save_png(source_path) != OK:
		_fail("Could not create prop fixture")
		return
	var entry := {"id": "prop", "name": "Prop", "group_id": "props", "footprint": Vector2i.ONE, "image_path": source_absolute}
	canvas.place_piece(entry, Vector2i(2, 2))
	canvas.grid_mode = BattleMapCanvas.GRID_HIDDEN
	if canvas._texture_for_entry(entry) == null:
		_fail("Could not cache displayed prop")
		return
	prop_image.fill(Color.BLUE)
	prop_image.save_png(source_path)
	canvas.begin_move(Vector2i(2, 2))
	canvas.update_move(Vector2i(3, 2))
	canvas.set_zoom(2.0)
	var retained := canvas.stage_view()
	for source_state in ["replaced", "deleted"]:
		if source_state == "deleted":
			DirAccess.remove_absolute(source_absolute)
		error = await canvas.export_visible_png(path)
		if error != OK:
			_fail("Export failed with %s source: %d" % [source_state, error])
			return
		exported = Image.load_from_file(path)
		var prop_pixel := exported.get_pixel(320, 240)
		if prop_pixel.r < 0.9 or prop_pixel.g > 0.1 or prop_pixel.b > 0.1:
			_fail("Export did not retain displayed prop with %s source: %s" % [source_state, prop_pixel])
			return
		if canvas.stage_view() != retained or not is_equal_approx(canvas.zoom_level, 2.0):
			_fail("Export changed the live editing state or camera")
			return
		# This pixel lies on the live selection outline; export must omit it.
		var edge_pixel := exported.get_pixel(276, 195)
		if edge_pixel.r > 0.8 and edge_pixel.g > 0.6 and edge_pixel.b < 0.6:
			_fail("Export retained the selection outline")
			return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Export test passed")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
