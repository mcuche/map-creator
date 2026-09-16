extends Node

const MapCanvasScript = preload("res://scripts/map_canvas.gd")


func _ready() -> void:
	var canvas: BattleMapCanvas = MapCanvasScript.new()
	add_child(canvas)
	canvas.manual_grid_cells = Vector2i(4, 5)
	var entry := {
		"id": "custom", "name": "Custom", "group_id": "props",
		"footprint": Vector2i(4, 5), "image_path": ""
	}
	canvas.pieces = [{
		"instance_id": 1, "entry": entry, "cell": Vector2i.ZERO,
		"rotation": 0, "mirrored": false, "layer": 0
	}]
	canvas.selected_id = 1
	canvas.rotate_selected()
	if canvas.pieces[0]["rotation"] != 0 or canvas.pieces[0]["cell"] != Vector2i.ZERO or canvas.can_undo():
		_fail("Out-of-grid rotation changed the piece or undo history")
		return
	if canvas._can_occupy(Vector2i(-1, 0), Vector2i.ONE) or canvas._can_occupy(Vector2i(4, 0), Vector2i.ONE):
		_fail("Occupancy accepted a rectangle outside the grid")
		return
	entry["footprint"] = Vector2i(3, 2)
	canvas.pieces[0]["entry"] = entry
	canvas.rotate_selected()
	if canvas.pieces[0]["rotation"] != 90 or not canvas.can_undo():
		_fail("Valid rotation was rejected")
		return

	var legacy := {"version": 1, "manual_grid_columns": 14, "manual_grid_rows": 10,
		"pieces": [{"instance_id": 1, "asset_id": "table", "cell_x": 0, "cell_y": 0}]}
	canvas.load_state(legacy)
	var restored: Dictionary = canvas.pieces[0]["entry"]
	if restored["name"] != "Long table" or restored["footprint"] != Vector2i(2, 1) \
			or restored["image_path"] != "res://assets/sprites/table.png":
		_fail("Legacy map did not restore the frozen v1 definition")
		return
	legacy["pieces"] = [{"instance_id": 1, "asset_id": "unknown", "cell_x": 0, "cell_y": 0}]
	canvas.load_state(legacy)
	if canvas.pieces[0]["entry"]["name"] != "Missing catalog entry":
		_fail("Unknown legacy ID did not use a placeholder")
		return

	var user_path := "user://piece-image-refresh-test-%d.png" % Time.get_ticks_usec()
	var image_path := ProjectSettings.globalize_path(user_path)
	var image_entry := {"image_path": image_path}
	var first_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	first_image.fill(Color.RED)
	if first_image.save_png(image_path) != OK:
		_fail("Could not create the image-reload fixture")
		return
	var first_texture := canvas._texture_for_entry(image_entry)
	var second_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	second_image.fill(Color.BLUE)
	if second_image.save_png(image_path) != OK:
		_fail("Could not replace the image-reload fixture")
		return
	canvas.refresh_piece_images()
	var refreshed_texture := canvas._texture_for_entry(image_entry)
	DirAccess.remove_absolute(image_path)
	if first_texture == refreshed_texture or refreshed_texture.get_image().get_pixel(0, 0) != Color.BLUE:
		_fail("Image reload retained the old pixels")
		return
	print("Catalog canvas regression tests passed")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
