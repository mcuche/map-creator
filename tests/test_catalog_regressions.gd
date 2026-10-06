extends Node

const MapCanvasScript = preload("res://scripts/map_canvas.gd")


func _ready() -> void:
	var canvas: BattleMapCanvas = MapCanvasScript.new()
	add_child(canvas)
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
