extends SceneTree

const PixelAssetPreviewScript = preload("res://scripts/pixel_asset_preview.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(80, 80)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var preview: PixelAssetPreview = PixelAssetPreviewScript.new()
	preview.size = Vector2(80, 80)
	preview.content_inset = 0.0
	preview.entry = {"image_path": "test"}
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.BLACK)
	image.set_pixel(0, 1, Color.BLACK)
	image.set_pixel(1, 0, Color.WHITE)
	image.set_pixel(1, 1, Color.WHITE)
	preview.sprite_texture = ImageTexture.create_from_image(image)
	viewport.add_child(preview)
	await process_frame
	await process_frame
	var rendered := viewport.get_texture().get_image()
	var left := rendered.get_pixel(39, 40)
	var right := rendered.get_pixel(40, 40)
	if left.r > 0.05 or right.r < 0.95:
		push_error("Sprite preview has blended edge pixels: %s, %s" % [left, right])
		quit(1)
		return
	preview.queue_free()
	await process_frame

	var canvas := BattleMapCanvas.new()
	canvas.size = Vector2(80, 80)
	canvas.grid_mode = BattleMapCanvas.GRID_HIDDEN
	canvas.manual_grid_cells = Vector2i.ONE
	canvas.piece_textures["test"] = ImageTexture.create_from_image(image)
	canvas.place_piece({"image_path": "test", "footprint": Vector2i.ONE}, Vector2i.ZERO)
	canvas.select_at(Vector2i(-1, -1))
	viewport.add_child(canvas)
	canvas.custom_minimum_size = Vector2.ZERO
	canvas.size = Vector2(80, 80)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	rendered = viewport.get_texture().get_image()
	left = rendered.get_pixel(39, 40)
	right = rendered.get_pixel(40, 40)
	if left.r > 0.05 or right.r < 0.95:
		push_error("Map piece has blended edge pixels: %s, %s" % [left, right])
		quit(1)
		return
	print("Catalog preview and map piece edges remain sharp")
	quit()
