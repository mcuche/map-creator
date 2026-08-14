class_name AssetDragButton
extends Button

const PixelAssetPreviewScript = preload("res://scripts/pixel_asset_preview.gd")

var asset_id := ""
var asset_name := ""
var footprint := Vector2i.ONE
var asset_data: Dictionary = {}
var drag_size_provider: Callable
var preview_control: PixelAssetPreview
var name_label: Label
var footprint_label: Label

func configure(asset: Dictionary, preview_size_provider := Callable()) -> void:
	asset_data = asset
	drag_size_provider = preview_size_provider
	asset_id = str(asset["id"])
	asset_name = str(asset["name"])
	footprint = asset["footprint"]
	text = ""
	tooltip_text = "Drag %s onto the map — occupies %d × %d grid cells" % [asset_name, footprint.x, footprint.y]
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_build_contents()

func _build_contents() -> void:
	if get_child_count() > 0:
		return
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_bottom = -2
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	preview_control = PixelAssetPreviewScript.new()
	preview_control.custom_minimum_size = Vector2(76, 70)
	preview_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_control.configure(asset_data)
	column.add_child(preview_control)
	name_label = Label.new()
	name_label.text = asset_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	column.add_child(name_label)
	footprint_label = Label.new()
	footprint_label.text = "%d×%d" % [footprint.x, footprint.y]
	footprint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footprint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footprint_label.add_theme_font_size_override("font_size", 10)
	footprint_label.add_theme_color_override("font_color", Color("a8b1b4"))
	column.add_child(footprint_label)

func _get_drag_data(_at_position: Vector2):
	var preview_size := Vector2(96, 82)
	if drag_size_provider.is_valid():
		preview_size = drag_size_provider.call(asset_id)
	var preview := Control.new()
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.position = -preview_size * 0.5
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var model := PixelAssetPreviewScript.new()
	model.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	model.custom_minimum_size = preview_size
	model.content_inset = 0.0
	model.configure(asset_data)
	preview.add_child(model)
	set_drag_preview(preview)
	return {
		"type": "asset",
		"asset_id": asset_id
	}
