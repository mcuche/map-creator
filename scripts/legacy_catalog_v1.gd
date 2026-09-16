class_name LegacyCatalogV1
extends RefCounted

# Frozen definitions for maps saved before placed pieces carried entry snapshots.
const ENTRIES := {
	"hero": {"name": "Hero", "group_id": "cast", "footprint": Vector2i(1, 1)},
	"ranger": {"name": "Ranger", "group_id": "cast", "footprint": Vector2i(1, 1)},
	"mage": {"name": "Mage", "group_id": "cast", "footprint": Vector2i(1, 1)},
	"goblin": {"name": "Goblin", "group_id": "creatures", "footprint": Vector2i(1, 1)},
	"skeleton": {"name": "Skeleton", "group_id": "creatures", "footprint": Vector2i(1, 1)},
	"dire_wolf": {"name": "Dire wolf", "group_id": "creatures", "footprint": Vector2i(2, 1)},
	"chest": {"name": "Chest", "group_id": "props", "footprint": Vector2i(1, 1)},
	"campfire": {"name": "Campfire", "group_id": "props", "footprint": Vector2i(1, 1)},
	"table": {"name": "Long table", "group_id": "props", "footprint": Vector2i(2, 1)},
	"tree": {"name": "Ancient tree", "group_id": "scenery", "footprint": Vector2i(2, 2)},
	"rock": {"name": "Boulder", "group_id": "scenery", "footprint": Vector2i(1, 1)},
	"ruined_wall": {"name": "Ruined wall", "group_id": "scenery", "footprint": Vector2i(3, 1)}
}


static func entry_snapshot(entry_id: String) -> Dictionary:
	if not ENTRIES.has(entry_id):
		return {}
	var definition: Dictionary = ENTRIES[entry_id]
	return {
		"id": entry_id,
		"name": definition["name"],
		"group_id": definition["group_id"],
		"footprint": definition["footprint"],
		"image_path": "res://assets/sprites/%s.png" % entry_id
	}
