extends Node

const CastPropsLibraryScript = preload("res://scripts/cast_props_library.gd")


func _ready() -> void:
	var library: CastPropsLibrary = CastPropsLibraryScript.new()
	library.size = Vector2(276, 700)
	add_child(library)
	var loaded := library.initialize(CastPropsLibrary.STARTER_CATALOG_PATH, CastPropsLibrary.STARTER_IMAGE_DIR)
	if not loaded["ok"]:
		_fail("Starter catalog did not load: %s" % loaded["errors"])
		return
	if library.catalog_snapshot().size() != 12:
		_fail("Starter catalog did not expose twelve validated entries")
		return
	var bootstrap_dir := "user://catalog-bootstrap-test-%d" % Time.get_ticks_usec()
	var bootstrap_error := library._bootstrap_user_catalog(bootstrap_dir)
	if not bootstrap_error.is_empty():
		_fail("First-run catalog bootstrap failed: %s" % bootstrap_error)
		return
	if not FileAccess.file_exists(bootstrap_dir.path_join("catalog.json")):
		_fail("First-run bootstrap did not create catalog.json")
		return
	for file_name in CastPropsLibrary.STARTER_IMAGE_FILES:
		var image_path := bootstrap_dir.path_join("images").path_join(file_name)
		if Image.load_from_file(image_path).is_empty():
			_fail("First-run bootstrap did not create a readable PNG: %s" % file_name)
			return
		DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bootstrap_dir.path_join("catalog.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bootstrap_dir.path_join("images")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bootstrap_dir))
	var recovery_dir := "user://catalog-recovery-test-%d" % Time.get_ticks_usec()
	var images_dir := recovery_dir.path_join("images")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(images_dir)) != OK:
		_fail("Could not create recovery fixture")
		return
	var hero_path := images_dir.path_join("hero.png")
	var custom_hero := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	custom_hero.fill(Color.BLUE)
	if custom_hero.save_png(hero_path) != OK:
		_fail("Could not write custom hero fixture")
		return
	var original_bytes := FileAccess.get_file_as_bytes(hero_path)
	bootstrap_error = library._bootstrap_user_catalog(recovery_dir)
	if not bootstrap_error.is_empty() or FileAccess.get_file_as_bytes(hero_path) != original_bytes:
		_fail("Catalog recovery replaced a user image: %s" % bootstrap_error)
		return
	var recovery_library: CastPropsLibrary = CastPropsLibraryScript.new()
	add_child(recovery_library)
	if not recovery_library.initialize(recovery_dir.path_join("catalog.json"))["ok"]:
		_fail("Recovered catalog could not be loaded")
		return
	for file_name in CastPropsLibrary.STARTER_IMAGE_FILES:
		if not FileAccess.file_exists(images_dir.path_join(file_name)):
			_fail("Catalog recovery omitted %s" % file_name)
			return
	recovery_library.queue_free()
	await get_tree().process_frame
	for file_name in CastPropsLibrary.STARTER_IMAGE_FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(images_dir.path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_dir.path_join("catalog.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(images_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_dir))

	library.set_filter("cast")
	if library.visible_group_ids() != ["cast"]:
		_fail("Filtering by group did not isolate CAST")
		return
	library.set_filter("no matching entry")
	if not library.visible_group_ids().is_empty():
		_fail("Groups remained visible without matching entries")
		return
	library.set_filter("")
	if library.visible_group_ids() != ["cast", "creatures", "props", "scenery"]:
		_fail("Clearing the filter did not restore ordered groups")
		return
	library._groups.append({"id": "empty", "name": "Empty"})
	library._rebuild_cards()
	var empty_group: Dictionary = library._group_views["empty"]
	if not empty_group["section"].visible or not empty_group["empty_hint"].visible \
			or empty_group["empty_hint"].text != "Nothing in this group yet.":
		_fail("Empty group did not explain why it has no cards")
		return
	library._toggle_group("empty")
	if empty_group["empty_hint"].visible:
		_fail("Collapsed group kept its empty message visible")
		return
	library.set_filter("cast")
	if empty_group["section"].visible:
		_fail("Empty group appeared in filtered results")
		return

	var invalid_path := "user://invalid-catalog-test.json"
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	if not initial_result["ok"] or invalid_result["ok"] or "unknown field" not in str(invalid_result["errors"]):
		_fail("Unknown catalog fields did not reject the load")
		return
	if reload_library.catalog_snapshot() != retained_snapshot:
		_fail("A rejected reload did not retain the previous catalog")
		return

	print("Cast & Props catalog tests passed")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
