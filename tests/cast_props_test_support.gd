extends RefCounted

const CAST_NAMES := ["Fixture Knight", "Fixture Ranger", "Fixture Mage", "Fixture Rogue"]
const PROP_NAME := "Fixture Chest"

var _temporary_directories: Array[String] = []


func create_temporary_directory(prefix: String) -> String:
	var path := "user://%s-%d-%d" % [prefix, OS.get_process_id(), Time.get_ticks_usec()]
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		path += "-new"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) != OK:
		return ""
	_temporary_directories.append(path)
	return path


func create_catalog_fixture() -> Dictionary:
	var directory := create_temporary_directory("cast-props-fixture")
	if directory.is_empty():
		return {"ok": false, "errors": "Could not create fixture directory"}
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	if image.save_png(directory.path_join("shared.png")) != OK:
		return {"ok": false, "errors": "Could not write fixture PNG"}
	var entries: Array = []
	for index in range(CAST_NAMES.size()):
		entries.append({"id": "cast_%d" % index, "name": CAST_NAMES[index], "group_id": "cast", "footprint": [1, 1], "image": "shared.png"})
	entries.append({"id": "prop", "name": PROP_NAME, "group_id": "props", "footprint": [1, 1], "image": "shared.png"})
	var catalog := {
		"version": 1,
		"groups": [{"id": "cast", "name": "Cast"}, {"id": "props", "name": "Props"}, {"id": "empty", "name": "Empty"}],
		"entries": entries
	}
	var catalog_path := directory.path_join("catalog.json")
	var file := FileAccess.open(catalog_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": "Could not open fixture catalog"}
	file.store_string(JSON.stringify(catalog))
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		return {"ok": false, "errors": "Could not write fixture catalog"}
	return {"ok": true, "catalog_path": catalog_path}


func cleanup() -> void:
	for directory in _temporary_directories:
		_remove_directory(ProjectSettings.globalize_path(directory))
	_temporary_directories.clear()


func _remove_directory(path: String) -> void:
	for directory in DirAccess.get_directories_at(path):
		_remove_directory(path.path_join(directory))
	for file in DirAccess.get_files_at(path):
		if DirAccess.remove_absolute(path.path_join(file)) != OK:
			push_error("Could not remove test fixture file: %s" % path.path_join(file))
	if DirAccess.remove_absolute(path) != OK:
		push_error("Could not remove test fixture directory: %s" % path)


static func find_control_by_text(root: Node, type_name: String, text: String, visible_only := false) -> Control:
	for node in root.find_children("*", type_name, true, false):
		if node is Control and str(node.get("text")) == text and (not visible_only or node.is_visible_in_tree()):
			return node
	return null


static func find_control_by_tooltip(root: Node, type_name: String, tooltip_prefix: String) -> Control:
	for node in root.find_children("*", type_name, true, false):
		if node is Control and node.tooltip_text.begins_with(tooltip_prefix):
			return node
	return null
