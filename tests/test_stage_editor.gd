extends Node

const Editor = preload("res://scripts/stage_editor.gd")
const BOUNDS := Vector2i(8, 8)
var failed := false

func _ready() -> void:
	_test_geometry()
	_test_history()
	_test_movement()
	_test_history_limit()
	_test_replacement_and_copies()
	if not failed:
		print("Stage editor tests passed")
	get_tree().quit(1 if failed else 0)

func _entry(footprint := Vector2i.ONE) -> Dictionary:
	return {"id": "fixture", "name": "Fixture", "group_id": "props", "footprint": footprint, "image_path": ""}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _selected(editor: StageEditor) -> Dictionary:
	return editor.view()["selected_piece"]

func _test_geometry() -> void:
	var editor: StageEditor = Editor.new()
	_check(not editor.place(_entry(Vector2i.ZERO), Vector2i.ZERO, BOUNDS)["message"].is_empty(), "Invalid footprint accepted")
	_check(not editor.place({"footprint": [1, 1]}, Vector2i.ZERO, BOUNDS)["message"].is_empty(), "Wrong footprint type accepted")
	_check(not editor.place(_entry(Vector2i(101, 1)), Vector2i.ZERO, BOUNDS)["message"].is_empty(), "Footprint limit ignored")
	_check(not editor.place(_entry(Vector2i(9, 1)), Vector2i.ZERO, BOUNDS)["message"].is_empty(), "Oversized placement accepted")
	editor.place(_entry(Vector2i(2, 1)), Vector2i(100, -1), BOUNDS)
	_check(_selected(editor)["cell"] == Vector2i(6, 0) and _selected(editor)["instance_id"] == 1, "Placement clamping or rejected ID allocation changed")
	_check(not editor.preview_placement(_entry(), Vector2i(7, 0), BOUNDS)["valid"], "Multi-cell occupancy not exclusive")
	_check(editor.preview_placement(_entry(), Vector2i(5, 0), BOUNDS)["valid"], "Adjacent footprint rejected")
	editor.rotate_selected(1, BOUNDS)
	_check(_selected(editor)["rotation"] == 90 and _selected(editor)["occupied_footprint"] == Vector2i(1, 2), "Clockwise rotation footprint incorrect")
	_check(not editor.preview_placement(_entry(), Vector2i(6, 1), BOUNDS)["valid"], "Rotated occupancy not exclusive")
	editor.rotate_selected(-1, BOUNDS)
	_check(_selected(editor)["rotation"] == 0, "Counterclockwise rotation incorrect")
	editor.clear()
	editor.place(_entry(Vector2i(1, 2)), Vector2i(7, 6), BOUNDS)
	editor.rotate_selected(1, BOUNDS)
	_check(_selected(editor)["cell"] == Vector2i(6, 6), "Edge rotation did not clamp")
	editor.clear()
	editor.place(_entry(Vector2i(2, 1)), Vector2i(2, 2), BOUNDS)
	editor.place(_entry(), Vector2i(2, 3), BOUNDS)
	editor.select_at(Vector2i(2, 2))
	var before := editor.view()
	_check(not editor.rotate_selected(1, BOUNDS)["message"].is_empty() and editor.view() == before, "Blocked rotation changed state")
	editor.clear()
	editor.place(_entry(Vector2i(4, 5)), Vector2i.ZERO, Vector2i(4, 5))
	before = editor.view()
	_check(not editor.rotate_selected(1, Vector2i(4, 5))["message"].is_empty() and editor.view() == before, "Out-of-grid rotation changed state")
	_check(not editor.duplicate_selected(Vector2i(4, 5))["message"].is_empty() and editor.view() == before, "Full-grid duplication changed state")
	editor.place(_entry(), Vector2i(5, 0), BOUNDS)
	_check(_selected(editor)["instance_id"] == 2, "Rejected duplication consumed an ID")
	editor.clear()
	editor.place(_entry(Vector2i(2, 2)), Vector2i(1, 1), BOUNDS)
	_check(not editor.preview_placement(_entry(), Vector2i(2, 2), BOUNDS)["valid"], "Square occupancy not exclusive")
	editor.rotate_selected(1, BOUNDS)
	editor.mirror_selected()
	editor.duplicate_selected(BOUNDS)
	_check(_selected(editor)["cell"] == Vector2i(3, 1), "Duplicate ring order changed")
	_check(_selected(editor)["rotation"] == 90 and _selected(editor)["mirrored"] and _selected(editor)["entry"] == _entry(Vector2i(2, 2)), "Duplicate lost piece metadata")

func _test_history() -> void:
	var editor: StageEditor = Editor.new()
	editor.place(_entry(), Vector2i(1, 1), BOUNDS)
	editor.mirror_selected()
	editor.undo()
	_check(not _selected(editor)["mirrored"] and editor.view()["can_redo"], "Mirror undo failed")
	var before := editor.view()
	editor.rotate_selected(0, BOUNDS)
	_check(editor.view() == before, "Zero rotation changed history")
	editor.place(_entry(), Vector2i(1, 1), BOUNDS)
	editor.select_at(Vector2i.ZERO)
	_check(editor.view()["can_redo"], "Rejection or selection cleared redo")
	editor.redo()
	_check(_selected(editor)["mirrored"], "Mirror redo failed to restore selection")
	editor.delete_selected()
	_check(editor.view()["pieces"].is_empty() and editor.view()["selected_piece"] == null, "Removal failed")
	editor.undo()
	_check(_selected(editor)["mirrored"], "Removal undo lost selection")
	editor.redo()
	_check(editor.view()["pieces"].is_empty(), "Removal redo failed")
	editor.undo()
	editor.place(_entry(), Vector2i(2, 2), BOUNDS)
	_check(not editor.view()["can_redo"], "New edit did not clear redo")

func _test_movement() -> void:
	var editor: StageEditor = Editor.new()
	editor.place(_entry(Vector2i(2, 2)), Vector2i(1, 1), BOUNDS)
	editor.place(_entry(), Vector2i(5, 5), BOUNDS)
	editor.begin_move(Vector2i(2, 2))
	_check(not editor.update_move(Vector2i(4, 4), BOUNDS)["document_changed"], "Preview committed history")
	_check(_selected(editor)["cell"] == Vector2i(3, 3), "Grab offset lost")
	editor.update_move(Vector2i(5, 5), BOUNDS)
	_check(_selected(editor)["cell"] == Vector2i(3, 3), "Blocked move did not retain last valid position")
	editor.update_move(Vector2i(4, 3), BOUNDS)
	editor.finish_move()
	editor.undo()
	_check(_selected(editor)["cell"] == Vector2i(1, 1), "Previews did not form one undo step")
	editor.redo()
	editor.begin_move(Vector2i(3, 2))
	editor.update_move(Vector2i(2, 2), BOUNDS)
	editor.mirror_selected()
	editor.undo()
	_check(not _selected(editor)["mirrored"] and _selected(editor)["cell"] == Vector2i(2, 2), "Interrupted drag and edit were not separate transactions")
	editor.undo()
	_check(_selected(editor)["cell"] == Vector2i(3, 2), "Interrupted drag undo failed")
	editor.begin_move(Vector2i(3, 2))
	editor.update_move(Vector2i(1, 1), BOUNDS)
	editor.undo()
	_check(_selected(editor)["cell"] == Vector2i(3, 2) and not editor.view()["moving"], "Undo during movement failed")
	editor.begin_move(Vector2i(3, 2))
	editor.update_move(Vector2i(1, 1), BOUNDS)
	var result := editor.place(_entry(), Vector2i(5, 5), BOUNDS)
	_check(result["document_changed"] and not result["message"].is_empty(), "Rejected interruption failed to commit drag")
	editor.undo()
	_check(_selected(editor)["cell"] == Vector2i(3, 2), "Rejected edit added history after drag")
	editor.clear()
	editor.place(_entry(), Vector2i.ONE, BOUNDS)
	editor.undo()
	editor.redo()
	editor.mirror_selected()
	editor.undo()
	editor.begin_move(Vector2i.ONE)
	editor.update_move(Vector2i(2, 2), BOUNDS)
	editor.update_move(Vector2i.ONE, BOUNDS)
	_check(not editor.finish_move()["document_changed"], "Returned-to-start movement committed")
	editor.begin_move(Vector2i.ONE)
	_check(not editor.finish_move()["document_changed"], "Unchanged movement committed")
	_check(editor.view()["can_redo"], "No-op movement cleared redo")
	editor.undo()
	_check(editor.view()["pieces"].is_empty(), "No-op movement added an undo step")

func _test_history_limit() -> void:
	var editor: StageEditor = Editor.new()
	editor.place(_entry(), Vector2i.ZERO, BOUNDS)
	for index in range(60):
		if index % 2 == 0:
			editor.begin_move(_selected(editor)["cell"])
			editor.update_move(Vector2i(1, 0) if _selected(editor)["cell"] == Vector2i.ZERO else Vector2i.ZERO, BOUNDS)
			editor.finish_move()
		else:
			editor.mirror_selected()
	var count := 0
	while editor.view()["can_undo"]:
		editor.undo()
		count += 1
	_check(count == 50 and editor.view()["pieces"].size() == 1, "Edits and drags did not share the 50-entry history limit")
	for index in range(50):
		editor.redo()
	_check(not editor.view()["can_redo"], "Bounded history redo failed")

func _test_replacement_and_copies() -> void:
	var editor: StageEditor = Editor.new()
	var entry := _entry()
	editor.place(entry, Vector2i.ONE, BOUNDS)
	entry["footprint"] = Vector2i(8, 8)
	var exposed := editor.view()
	exposed["pieces"][0]["entry"]["name"] = "Changed"
	exposed["selected_piece"]["cell"] = Vector2i.ZERO
	_check(_selected(editor)["entry"] == _entry() and _selected(editor)["cell"] == Vector2i.ONE, "Caller dictionaries mutate live state")
	editor.begin_move(Vector2i.ONE)
	editor.update_move(Vector2i(2, 2), BOUNDS)
	var before := editor.view()
	var invalid: Array = before["pieces"].duplicate(true)
	invalid[0]["cell"] = Vector2i(-1, 0)
	_check(editor.replace_layout(invalid, BOUNDS)["message"] == "pieces[0] is outside the grid." and editor.view() == before, "Rejected replacement was not atomic")
	invalid = before["pieces"].duplicate(true)
	invalid.append(invalid[0].duplicate(true))
	_check(not editor.replace_layout(invalid, BOUNDS)["message"].is_empty() and editor.view() == before, "Duplicate IDs accepted")
	invalid[1]["instance_id"] = 10
	_check(not editor.replace_layout(invalid, BOUNDS)["message"].is_empty() and editor.view() == before, "Overlapping replacement accepted")
	invalid.resize(1)
	invalid[0]["entry"]["footprint"] = Vector2i(0, 1)
	_check(not editor.replace_layout(invalid, BOUNDS)["message"].is_empty() and editor.view() == before, "Replacement footprint was clamped")
	var render := editor.copy_for_render()
	_check(render.view()["pieces"] == before["pieces"] and render.view()["selected_piece"] == null and not render.view()["moving"] and not render.view()["can_undo"] and not render.view()["can_redo"], "Rendering copy retained editing state")
	render.select_at(Vector2i(2, 2))
	render.delete_selected()
	_check(editor.view() == before, "Rendering copy mutated live editor")
	var native: Array = before["pieces"].duplicate(true)
	native[0]["instance_id"] = 41
	native[0]["rotation"] = 45
	native[0]["layer"] = 7
	editor.replace_layout(native, BOUNDS)
	native[0]["entry"]["name"] = "Changed"
	_check(not editor.view()["moving"] and not editor.view()["can_undo"] and not editor.view()["can_redo"] and editor.view()["selected_piece"] == null, "Successful replacement retained editing state")
	_check(editor.view()["pieces"][0]["entry"]["name"] == "Fixture" and editor.view()["pieces"][0]["rotation"] == 45 and editor.view()["pieces"][0]["layer"] == 7, "Replacement lost compatibility or retained caller dictionary")
	editor.place(_entry(), Vector2i(4, 4), BOUNDS)
	_check(_selected(editor)["instance_id"] == 42, "Loaded IDs did not resume above largest ID")
	editor.clear()
	_check(editor.view()["required_cells"] == Vector2i.ZERO and not editor.view()["can_undo"], "Clear retained state")
	editor.place(_entry(), Vector2i.ZERO, BOUNDS)
	_check(_selected(editor)["instance_id"] == 1, "Clear did not reset IDs")
