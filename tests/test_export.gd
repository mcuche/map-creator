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
	canvas.pieces = [{"instance_id": 1, "entry": entry, "cell": Vector2i(2, 2), "rotation": 0, "mirrored": false, "layer": 0}]
	canvas.grid_mode = BattleMapCanvas.GRID_HIDDEN
	if canvas._texture_for_entry(entry) == null:
		_fail("Could not cache displayed prop")
		return
	prop_image.fill(Color.BLUE)
	prop_image.save_png(source_path)
	for source_state in ["replaced", "deleted"]:
		if source_state == "deleted":
			DirAccess.remove_absolute(source_absolute)
		error = await canvas.export_visible_png(path)
		if error != OK:
			_fail("Export failed with %s source: %d" % [source_state, error])
			return
		exported = Image.load_from_file(path)
		var prop_pixel := exported.get_pixel(228, 240)
		if prop_pixel.r < 0.9 or prop_pixel.g > 0.1 or prop_pixel.b > 0.1:
			_fail("Export did not retain displayed prop with %s source: %s" % [source_state, prop_pixel])
			return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Export test passed")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
