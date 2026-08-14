extends Node

const MainScript = preload("res://scripts/main.gd")

func _ready() -> void:
	var main: Control = MainScript.new()
	main.size = Vector2(1600, 900)
	add_child(main)

	main._filter_assets("cast")
	await get_tree().process_frame
	await get_tree().process_frame
	if not main.asset_group_controls["CAST"]["section"].visible:
		_fail("CAST title was hidden despite containing a matching asset")
		return
	for group_name in ["CREATURES", "PROPS", "SCENERY"]:
		if main.asset_group_controls[group_name]["section"].visible:
			_fail("%s title remained visible without a matching asset" % group_name)
			return
	if main.asset_scroll_content.get_theme_constant("margin_right") != 0:
		_fail("Asset library kept a scrollbar gutter when no scrollbar was visible")
		return
	var cast_section: VBoxContainer = main.asset_group_controls["CAST"]["section"]
	var cast_grid: GridContainer = main.asset_group_controls["CAST"]["grid"]
	if not is_equal_approx(cast_section.size.x, main.asset_search.size.x):
		_fail("Category title width did not match the search input without a scrollbar")
		return
	if not is_equal_approx(cast_grid.size.x, main.asset_search.size.x):
		_fail("Object grid width did not match the search input without a scrollbar")
		return
	var ranger_button: Button = main.asset_buttons["ranger"]
	var object_row_width := ranger_button.position.x + ranger_button.size.x
	if not is_equal_approx(object_row_width, main.asset_search.size.x):
		_fail("Object cards did not fill the search input width without a scrollbar")
		return
	var hero_contents: VBoxContainer = main.asset_buttons["hero"].get_child(0)
	if not is_equal_approx(hero_contents.offset_bottom, -2.0):
		_fail("Object size label did not retain its bottom inset")
		return

	main._filter_assets("no matching object")
	for group_name in main.asset_group_controls:
		if main.asset_group_controls[group_name]["section"].visible:
			_fail("%s title remained visible for an empty result set" % group_name)
			return

	main._filter_assets("")
	await get_tree().process_frame
	await get_tree().process_frame
	for group_name in main.asset_group_controls:
		if not main.asset_group_controls[group_name]["section"].visible:
			_fail("%s title did not return after clearing the filter" % group_name)
			return
	if not main.asset_library_scroll.get_v_scroll_bar().visible:
		_fail("Full asset library did not restore its scrollbar")
		return
	if main.asset_scroll_content.get_theme_constant("margin_right") != 12:
		_fail("Asset library did not restore its scrollbar gutter")
		return

	var cast_heading: Button = main.asset_group_controls["CAST"]["heading"]
	cast_heading.pressed.emit()
	if main.asset_group_controls["CAST"]["grid"].visible:
		_fail("CAST objects remained visible after collapsing the category")
		return
	if cast_heading.icon != main.chevron_down_icon:
		_fail("Collapsed CAST category did not show the down chevron")
		return
	cast_heading.pressed.emit()
	if not main.asset_group_controls["CAST"]["grid"].visible:
		_fail("CAST objects did not return after expanding the category")
		return
	if cast_heading.icon != main.chevron_up_icon:
		_fail("Expanded CAST category did not show the up chevron")
		return

	print("Asset filter tests passed")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
