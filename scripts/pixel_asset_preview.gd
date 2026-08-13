class_name PixelAssetPreview
extends Control

var asset: Dictionary = {}
var sprite_texture: Texture2D
var content_inset := 4.0

func configure(value: Dictionary) -> void:
	asset = value
	var sprite_path := str(asset.get("sprite", ""))
	if not sprite_path.is_empty():
		sprite_texture = load(sprite_path) as Texture2D
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if asset.is_empty():
		return
	var preview_rect := Rect2(Vector2.ZERO, size).grow(-content_inset)
	if sprite_texture != null:
		_draw_sprite(preview_rect)
		return
	_draw_pixel_icon(preview_rect, asset)

func _draw_sprite(rect: Rect2) -> void:
	var texture_size := sprite_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_factor := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	var destination := Rect2(rect.get_center() - draw_size * 0.5, draw_size)
	draw_texture_rect(sprite_texture, destination, false)

func _draw_pixel_icon(rect: Rect2, item: Dictionary) -> void:
	var kind: String = item["kind"]
	var color: Color = item["color"]
	var unit := maxf(2.0, floorf(minf(rect.size.x, rect.size.y) / 10.0))
	var center := rect.get_center()
	if kind in ["hero", "goblin", "skeleton"]:
		var skin := Color("d9b07c")
		if kind == "goblin": skin = Color("85a84d")
		if kind == "skeleton": skin = Color("ddd7bd")
		draw_rect(Rect2(center + Vector2(-2 * unit, -4 * unit), Vector2(4, 3) * unit), skin)
		draw_rect(Rect2(center + Vector2(-2.5 * unit, -unit), Vector2(5, 4) * unit), color)
		draw_rect(Rect2(center + Vector2(-2.5 * unit, 3 * unit), Vector2(2, 2) * unit), Color("25282b"))
		draw_rect(Rect2(center + Vector2(0.5 * unit, 3 * unit), Vector2(2, 2) * unit), Color("25282b"))
		draw_rect(Rect2(center + Vector2(-3.5 * unit, -0.5 * unit), Vector2(unit, 3 * unit)), skin)
		draw_rect(Rect2(center + Vector2(2.5 * unit, -0.5 * unit), Vector2(unit, 3 * unit)), skin)
	elif kind == "wolf":
		draw_rect(Rect2(center + Vector2(-4 * unit, -2 * unit), Vector2(7, 4) * unit), color)
		draw_rect(Rect2(center + Vector2(2 * unit, -3 * unit), Vector2(3, 3) * unit), color.lightened(0.12))
		draw_rect(Rect2(center + Vector2(-3 * unit, 2 * unit), Vector2(unit, 2 * unit)), Color("2c2d2d"))
		draw_rect(Rect2(center + Vector2(2 * unit, 2 * unit), Vector2(unit, 2 * unit)), Color("2c2d2d"))
	elif kind == "tree":
		draw_rect(Rect2(center + Vector2(-unit, unit), Vector2(2, 4) * unit), Color("68462f"))
		for offset in [Vector2(-2, -2), Vector2(1, -3), Vector2(0, 0)]:
			var highlight := 0.08 if offset.x > 0 else 0.02
			draw_rect(Rect2(center + offset * unit, Vector2(4, 4) * unit), color.lightened(highlight))
	elif kind == "rock":
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-4, 3) * unit, center + Vector2(-3, -2) * unit,
			center + Vector2(0, -4) * unit, center + Vector2(4, -2) * unit,
			center + Vector2(4, 3) * unit
		]), color)
	elif kind == "chest":
		draw_rect(Rect2(center + Vector2(-4, -2) * unit, Vector2(8, 5) * unit), color)
		draw_rect(Rect2(center + Vector2(-4, -2) * unit, Vector2(8, unit)), Color("d3a34f"))
		draw_rect(Rect2(center + Vector2(-unit, -unit) * unit, Vector2(2, 3) * unit), Color("e0bd62"))
	elif kind == "fire":
		draw_rect(Rect2(center + Vector2(-4, 2) * unit, Vector2(8, unit)), Color("6c4631"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-2, 2) * unit, center + Vector2(0, -5) * unit, center + Vector2(3, 2) * unit]), Color("e56c2f"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-unit, 2 * unit), center + Vector2(unit, -2 * unit), center + Vector2(2 * unit, 2 * unit)]), Color("f0c96b"))
	else:
		draw_rect(rect.grow(-unit), color)
		draw_rect(rect.grow(-unit * 2.0), color.lightened(0.18), false, unit)
