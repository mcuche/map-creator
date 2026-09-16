class_name PixelAssetPreview
extends Control

var entry: Dictionary = {}
var sprite_texture: Texture2D
var content_inset := 4.0

func configure(value: Dictionary) -> void:
	entry = value.duplicate(true)
	sprite_texture = null
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if entry.is_empty():
		return
	var preview_rect := Rect2(Vector2.ZERO, size).grow(-content_inset)
	if sprite_texture == null:
		var image_path := str(entry.get("image_path", ""))
		if image_path.begins_with("res://") or image_path.begins_with("user://"):
			sprite_texture = load(image_path) as Texture2D
		elif not image_path.is_empty():
			var image := Image.load_from_file(image_path)
			if not image.is_empty():
				sprite_texture = ImageTexture.create_from_image(image)
	if sprite_texture != null:
		_draw_sprite(preview_rect)
		return
	_draw_missing_image(preview_rect)

func _draw_sprite(rect: Rect2) -> void:
	var texture_size := sprite_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_factor := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	var destination := Rect2(rect.get_center() - draw_size * 0.5, draw_size)
	draw_texture_rect(sprite_texture, destination, false)

func _draw_missing_image(rect: Rect2) -> void:
	draw_rect(rect, Color("352f3b"))
	draw_line(rect.position, rect.end, Color("d67a73"), 3.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("d67a73"), 3.0)
