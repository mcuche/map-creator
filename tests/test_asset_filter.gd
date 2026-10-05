extends Node

const CastPropsLibraryScript = preload("res://scripts/cast_props_library.gd")
const TestSupport = preload("res://tests/cast_props_test_support.gd")

var _support := TestSupport.new()


func _ready() -> void:
	var library: CastPropsLibrary = CastPropsLibraryScript.new()
	library.size = Vector2(276, 700)
	add_child(library)
	var loaded := library.initialize(CastPropsLibrary.STARTER_CATALOG_PATH, CastPropsLibrary.STARTER_IMAGE_DIR)
	if not loaded["ok"]:
		_fail("Starter catalog did not load: %s" % loaded["errors"])
		return
	var bootstrap_dir := _support.create_temporary_directory("catalog-bootstrap-test")
	if bootstrap_dir.is_empty():
		_fail("Could not create bootstrap fixture")
		return
	var bootstrap_error := library._bootstrap_user_catalog(bootstrap_dir)
	if not bootstrap_error.is_empty():
		_fail("First-run catalog bootstrap failed: %s" % bootstrap_error)
		return
	if not FileAccess.file_exists(bootstrap_dir.path_join("catalog.json")):
		_fail("First-run bootstrap did not create catalog.json")
		return
	for entry in library.catalog_snapshot().values():
		var file_name := str(entry["image_path"]).get_file()
		var image_path := bootstrap_dir.path_join("images").path_join(file_name)
		if Image.load_from_file(image_path).is_empty():
			_fail("First-run bootstrap did not create a readable PNG: %s" % file_name)
			return
	var recovery_dir := _support.create_temporary_directory("catalog-recovery-test")
	if recovery_dir.is_empty():
		_fail("Could not create recovery fixture directory")
		return
	var images_dir := recovery_dir.path_join("images")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(images_dir)) != OK:
		_fail("Could not create recovery fixture")
		return
	var knight_path := images_dir.path_join("knight.png")
	var custom_knight := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	custom_knight.fill(Color.BLUE)
	if custom_knight.save_png(knight_path) != OK:
		_fail("Could not write custom knight fixture")
		return
	var original_bytes := FileAccess.get_file_as_bytes(knight_path)
	bootstrap_error = library._bootstrap_user_catalog(recovery_dir)
	if not bootstrap_error.is_empty() or FileAccess.get_file_as_bytes(knight_path) != original_bytes:
		_fail("Catalog recovery replaced a user image: %s" % bootstrap_error)
		return
	var recovery_library: CastPropsLibrary = CastPropsLibraryScript.new()
	add_child(recovery_library)
	if not recovery_library.initialize(recovery_dir.path_join("catalog.json"))["ok"]:
		_fail("Recovered catalog could not be loaded")
		return
	for entry in library.catalog_snapshot().values():
		var file_name := str(entry["image_path"]).get_file()
		if not FileAccess.file_exists(images_dir.path_join(file_name)):
			_fail("Catalog recovery omitted %s" % file_name)
			return
	recovery_library.queue_free()
	await get_tree().process_frame
	var fixture := _support.create_catalog_fixture()
	if not fixture["ok"]:
		_fail("Could not create catalog fixture: %s" % fixture["errors"])
		return
	loaded = library.initialize(fixture["catalog_path"])
	if not loaded["ok"]:
		_fail("Fixture catalog did not load: %s" % loaded["errors"])
		return

	library.set_filter("cast")
	if library.visible_group_ids() != ["cast"]:
		_fail("Filtering by group did not isolate CAST")
		return
	library.set_filter("no matching entry")
	if not library.visible_group_ids().is_empty():
		_fail("Groups remained visible without matching entries")
		return
	library.set_filter("props")
	if library.visible_group_ids() != ["props"]:
		_fail("Filtering by group did not isolate Props")
		return
	library.set_filter(TestSupport.CAST_NAMES[0].to_lower())
	if library.visible_group_ids() != ["cast"]:
		_fail("Filtering by entry name did not isolate its group")
		return
	for entry_name in TestSupport.CAST_NAMES + [TestSupport.PROP_NAME]:
		var card := TestSupport.find_control_by_tooltip(library, "Button", "Drag %s onto the map" % entry_name)
		if card == null or card.is_visible_in_tree() != (entry_name == TestSupport.CAST_NAMES[0]):
			_fail("Filtering by entry name showed the wrong cards")
			return
	library.set_filter("")
	if library.visible_group_ids() != ["cast", "props", "empty"]:
		_fail("Clearing the filter did not restore ordered groups")
		return
	var empty_heading := TestSupport.find_control_by_text(library, "Button", "Empty", true) as Button
	var empty_hint := TestSupport.find_control_by_text(library, "Label", "Nothing in this group yet.", true) as Label
	if empty_heading == null or empty_hint == null:
		_fail("Empty group did not explain why it has no cards")
		return
	empty_heading.pressed.emit()
	if empty_hint.is_visible_in_tree() or not empty_heading.is_visible_in_tree():
		_fail("Collapsed group kept its empty message visible")
		return
	empty_heading.pressed.emit()
	if not empty_hint.is_visible_in_tree():
		_fail("Expanding the empty group did not restore its message")
		return
	library.set_filter("cast")
	if "empty" in library.visible_group_ids() or empty_heading.is_visible_in_tree() or empty_hint.is_visible_in_tree():
		_fail("Empty group appeared in filtered results")
		return

	var invalid_dir := _support.create_temporary_directory("invalid-catalog-test")
	if invalid_dir.is_empty():
		_fail("Could not create invalid catalog fixture directory")
		return
	var invalid_path := invalid_dir.path_join("catalog.json")
	var starter_file := FileAccess.open(CastPropsLibrary.STARTER_CATALOG_PATH, FileAccess.READ)
	var catalog_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	catalog_file.store_string(starter_file.get_as_text())
	catalog_file = null
	var reload_library: CastPropsLibrary = CastPropsLibraryScript.new()
	add_child(reload_library)
	var initial_result := reload_library.initialize(invalid_path, CastPropsLibrary.STARTER_IMAGE_DIR)
	var retained_snapshot := reload_library.catalog_snapshot()
	catalog_file = FileAccess.open(invalid_path, FileAccess.WRITE)
	catalog_file.store_string('{"version":1,"groups":[],"entries":[],"unexpected":true}')
	catalog_file = null
	var invalid_result := reload_library.reload_catalog()
	if not initial_result["ok"] or invalid_result["ok"] or "unknown field" not in str(invalid_result["errors"]):
		_fail("Unknown catalog fields did not reject the load")
		return
	if reload_library.catalog_snapshot() != retained_snapshot:
		_fail("A rejected reload did not retain the previous catalog")
		return

	print("Cast & Props catalog tests passed")
	get_tree().quit(0)


func _exit_tree() -> void:
	# Pending draw calls may still need the fixture PNGs after quit() is requested.
	_support.cleanup()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
