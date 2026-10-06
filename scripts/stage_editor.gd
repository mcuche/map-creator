class_name StageEditor
extends RefCounted

const HISTORY_LIMIT := 50

var _pieces: Array = []
var _selected_id := -1
var _next_id := 1
var _undo: Array = []
var _redo: Array = []
var _move_before: Dictionary = {}
var _grab_offset := Vector2i.ZERO

func view() -> Dictionary:
	var copies := _pieces.duplicate(true)
	var required := Vector2i.ZERO
	var selected = null
	for piece in copies:
		piece["occupied_footprint"] = _footprint(piece)
		var extent: Vector2i = piece["cell"] + piece["occupied_footprint"]
		required = Vector2i(maxi(required.x, extent.x), maxi(required.y, extent.y))
		if piece["instance_id"] == _selected_id:
			selected = piece.duplicate(true)
	return {"pieces": copies, "selected_id": _selected_id, "selected_piece": selected,
		"can_undo": not _undo.is_empty(), "can_redo": not _redo.is_empty(),
		"moving": not _move_before.is_empty(), "required_cells": required}

# Queries never finish a pending movement. Placement and drop preview share this evaluator.
func preview_placement(entry: Dictionary, cell: Vector2i, bounds: Vector2i) -> Dictionary:
	var footprint = entry.get("footprint", null)
	if not _valid_footprint(footprint):
		return {"valid": false, "cell": cell, "message": "Entry footprint must be between 1 and 100."}
	if footprint.x > bounds.x or footprint.y > bounds.y:
		return {"valid": false, "cell": cell, "message": "That piece is larger than the current grid"}
	var target := _clamp_cell(cell, footprint, bounds)
	var valid := _can_occupy(target, footprint, bounds)
	return {"valid": valid, "cell": target, "message": "" if valid else "That space is already occupied"}

func place(entry: Dictionary, cell: Vector2i, bounds: Vector2i) -> Dictionary:
	var start := _prepare()
	var preview := preview_placement(entry, cell, bounds)
	if not preview["valid"]:
		return _outcome(start, false, preview["message"])
	_record(_snapshot())
	_pieces.append({"instance_id": _next_id, "entry": _normalize_entry(entry),
		"cell": preview["cell"], "rotation": 0, "mirrored": false, "layer": _pieces.size()})
	_selected_id = _next_id
	_next_id += 1
	var result := _outcome(start, true)
	result["placement_finished"] = true
	return result

func has_piece_at(cell: Vector2i) -> bool:
	return _piece_at(cell) != null

func select_at(cell: Vector2i) -> Dictionary:
	var start := _prepare()
	var hit = _piece_at(cell)
	_selected_id = -1 if hit == null else int(hit["instance_id"])
	return _outcome(start)

func begin_move(cell: Vector2i) -> Dictionary:
	var start := _prepare()
	var hit = _piece_at(cell)
	_selected_id = -1 if hit == null else int(hit["instance_id"])
	if hit != null:
		_grab_offset = cell - hit["cell"]
		# Select before capturing the transaction, as the canvas did before extraction.
		_move_before = _snapshot()
	return _outcome(start)

func update_move(cell: Vector2i, bounds: Vector2i) -> Dictionary:
	var start := {"selection": _selected_copy(), "committed": false}
	var selected = _selected()
	if not _move_before.is_empty() and selected != null:
		var footprint := _footprint(selected)
		var target := _clamp_cell(cell - _grab_offset, footprint, bounds)
		if _can_occupy(target, footprint, bounds, _selected_id):
			selected["cell"] = target
	return _outcome(start)

func finish_move() -> Dictionary:
	var changed := false
	if not _move_before.is_empty():
		changed = _pieces != _move_before["pieces"]
		if changed:
			_record(_move_before)
		_move_before = {}
	return _outcome({"selection": _selected_copy(), "committed": false}, changed)

func delete_selected() -> Dictionary:
	var start := _prepare()
	var selected = _selected()
	if selected == null:
		return _outcome(start)
	_record(_snapshot())
	_pieces.erase(selected)
	_selected_id = -1
	return _outcome(start, true)

func duplicate_selected(bounds: Vector2i) -> Dictionary:
	var start := _prepare()
	var selected = _selected()
	if selected == null:
		return _outcome(start)
	var target := _nearest_free(selected["cell"] + Vector2i.ONE, _footprint(selected), bounds)
	if target.x < 0:
		return _outcome(start, false, "No free space is available for a duplicate")
	_record(_snapshot())
	var copy: Dictionary = selected.duplicate(true)
	copy["instance_id"] = _next_id
	copy["cell"] = target
	copy["layer"] = _pieces.size()
	_pieces.append(copy)
	_selected_id = _next_id
	_next_id += 1
	return _outcome(start, true)

func rotate_selected(direction: int, bounds: Vector2i) -> Dictionary:
	var start := _prepare()
	var selected = _selected()
	if selected == null or direction == 0:
		return _outcome(start)
	var rotation := posmod(int(selected["rotation"]) + 90 * signi(direction), 360)
	var candidate: Dictionary = selected.duplicate(true)
	candidate["rotation"] = rotation
	var footprint := _footprint(candidate)
	if footprint.x > bounds.x or footprint.y > bounds.y:
		return _outcome(start, false, "The rotated object would fall outside the grid")
	var target := _clamp_cell(selected["cell"], footprint, bounds)
	if not _can_occupy(target, footprint, bounds, _selected_id):
		return _outcome(start, false, "The rotated object would overlap another object")
	_record(_snapshot())
	selected["rotation"] = rotation
	selected["cell"] = target
	return _outcome(start, true)

func mirror_selected() -> Dictionary:
	var start := _prepare()
	var selected = _selected()
	if selected == null:
		return _outcome(start)
	_record(_snapshot())
	selected["mirrored"] = not selected["mirrored"]
	return _outcome(start, true)

func undo() -> Dictionary:
	var start := _prepare()
	if _undo.is_empty():
		return _outcome(start)
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	return _outcome(start, true)

func redo() -> Dictionary:
	var start := _prepare()
	if _redo.is_empty():
		return _outcome(start)
	_insert_undo(_snapshot())
	_restore(_redo.pop_back())
	return _outcome(start, true)

func clear() -> Dictionary:
	var start := {"selection": _selected_copy(), "committed": false}
	var changed := not _pieces.is_empty()
	_pieces = []
	_selected_id = -1
	_next_id = 1
	_undo.clear()
	_redo.clear()
	_move_before = {}
	return _outcome(start, changed)

# Validate in isolation: a rejected load must preserve even a pending movement.
func replace_layout(native_pieces: Array, bounds: Vector2i) -> Dictionary:
	var start := {"selection": _selected_copy(), "committed": false}
	var candidate := StageEditor.new()
	var used_ids := {}
	for index in range(native_pieces.size()):
		var item = native_pieces[index]
		var location := "pieces[%d]" % index
		if not item is Dictionary or not item.get("instance_id") is int or int(item["instance_id"]) < 1 or used_ids.has(item["instance_id"]):
			return _outcome(start, false, "%s.instance_id must be positive and unique." % location)
		if not item.get("entry") is Dictionary or not _valid_footprint(item["entry"].get("footprint")):
			return _outcome(start, false, "%s.entry footprint must be between 1 and 100." % location)
		if not item.get("cell") is Vector2i or not item.get("rotation", 0) is int or not item.get("mirrored", false) is bool or not item.get("layer", index) is int:
			return _outcome(start, false, "%s has invalid native piece fields." % location)
		var piece := {"instance_id": item["instance_id"], "entry": _normalize_entry(item["entry"]),
			"cell": item["cell"], "rotation": item.get("rotation", 0),
			"mirrored": item.get("mirrored", false), "layer": item.get("layer", index)}
		var footprint := _footprint(piece)
		if not _inside(piece["cell"], footprint, bounds):
			return _outcome(start, false, "%s is outside the grid." % location)
		if not candidate._can_occupy(piece["cell"], footprint, bounds):
			return _outcome(start, false, "%s overlaps another piece." % location)
		used_ids[piece["instance_id"]] = true
		candidate._pieces.append(piece)
		candidate._next_id = maxi(candidate._next_id, piece["instance_id"] + 1)
	var changed := _pieces != candidate._pieces
	_pieces = candidate._pieces
	_next_id = candidate._next_id
	_selected_id = -1
	_undo.clear()
	_redo.clear()
	_move_before = {}
	return _outcome(start, changed)

func copy_for_render() -> StageEditor:
	var copy := StageEditor.new()
	copy._pieces = _pieces.duplicate(true)
	copy._next_id = _next_id
	return copy

func _prepare() -> Dictionary:
	var selection = _selected_copy()
	var result := finish_move()
	return {"selection": selection, "committed": result["document_changed"]}

func _outcome(start: Dictionary, changed := false, message := "") -> Dictionary:
	var selection_changed: bool = start["selection"] != _selected_copy()
	var document_changed: bool = changed or start["committed"]
	return {"document_changed": document_changed, "selection_changed": selection_changed,
		"redraw": document_changed or selection_changed, "placement_finished": false, "message": message}

func _selected():
	for piece in _pieces:
		if piece["instance_id"] == _selected_id:
			return piece
	return null

func _selected_copy():
	var selected = _selected()
	return null if selected == null else selected.duplicate(true)

func _piece_at(cell: Vector2i):
	for index in range(_pieces.size() - 1, -1, -1):
		var piece: Dictionary = _pieces[index]
		if Rect2i(piece["cell"], _footprint(piece)).has_point(cell):
			return piece
	return null

func _valid_footprint(footprint) -> bool:
	return footprint is Vector2i and footprint.x >= 1 and footprint.y >= 1 and footprint.x <= 100 and footprint.y <= 100

func _normalize_entry(entry: Dictionary) -> Dictionary:
	return {"id": str(entry.get("id", "missing")), "name": str(entry.get("name", "Missing catalog entry")),
		"group_id": str(entry.get("group_id", "")), "footprint": entry["footprint"],
		"image_path": str(entry.get("image_path", ""))}

func _footprint(piece: Dictionary) -> Vector2i:
	var footprint: Vector2i = piece["entry"]["footprint"]
	return Vector2i(footprint.y, footprint.x) if int(piece["rotation"]) % 180 != 0 else footprint

func _inside(cell: Vector2i, footprint: Vector2i, bounds: Vector2i) -> bool:
	return bounds.x > 0 and bounds.y > 0 and cell.x >= 0 and cell.y >= 0 and cell.x + footprint.x <= bounds.x and cell.y + footprint.y <= bounds.y

func _can_occupy(cell: Vector2i, footprint: Vector2i, bounds: Vector2i, ignored_id := -1) -> bool:
	if not _inside(cell, footprint, bounds):
		return false
	for piece in _pieces:
		if piece["instance_id"] != ignored_id and Rect2i(cell, footprint).intersects(Rect2i(piece["cell"], _footprint(piece))):
			return false
	return true

func _clamp_cell(cell: Vector2i, footprint: Vector2i, bounds: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, maxi(0, bounds.x - footprint.x)), clampi(cell.y, 0, maxi(0, bounds.y - footprint.y)))

func _nearest_free(preferred: Vector2i, footprint: Vector2i, bounds: Vector2i) -> Vector2i:
	for radius in range(maxi(bounds.x, bounds.y) + 1):
		for y in range(preferred.y - radius, preferred.y + radius + 1):
			for x in range(preferred.x - radius, preferred.x + radius + 1):
				if radius > 0 and absi(x - preferred.x) < radius and absi(y - preferred.y) < radius:
					continue
				var cell := Vector2i(x, y)
				if _can_occupy(cell, footprint, bounds):
					return cell
	return Vector2i(-1, -1)

func _snapshot() -> Dictionary:
	return {"pieces": _pieces.duplicate(true), "selected_id": _selected_id, "next_id": _next_id}

func _restore(snapshot: Dictionary) -> void:
	_pieces = snapshot["pieces"].duplicate(true)
	_selected_id = snapshot["selected_id"]
	_next_id = snapshot["next_id"]

func _insert_undo(snapshot: Dictionary) -> void:
	_undo.append(snapshot.duplicate(true))
	if _undo.size() > HISTORY_LIMIT:
		_undo.pop_front()

func _record(snapshot: Dictionary) -> void:
	_insert_undo(snapshot)
	_redo.clear()
