class_name AssetCatalog
extends RefCounted

static func all_assets() -> Array:
	return [
		{"id": "hero", "name": "Hero", "group": "CAST", "kind": "hero", "footprint": Vector2i(1, 1), "color": Color("4f78c9"), "sprite": "res://assets/sprites/hero.png"},
		{"id": "ranger", "name": "Ranger", "group": "CAST", "kind": "hero", "footprint": Vector2i(1, 1), "color": Color("4f8f60"), "sprite": "res://assets/sprites/ranger.png"},
		{"id": "mage", "name": "Mage", "group": "CAST", "kind": "hero", "footprint": Vector2i(1, 1), "color": Color("8368b8"), "sprite": "res://assets/sprites/mage.png"},
		{"id": "goblin", "name": "Goblin", "group": "CREATURES", "kind": "goblin", "footprint": Vector2i(1, 1), "color": Color("779a42"), "sprite": "res://assets/sprites/goblin.png"},
		{"id": "skeleton", "name": "Skeleton", "group": "CREATURES", "kind": "skeleton", "footprint": Vector2i(1, 1), "color": Color("d7d0b2"), "sprite": "res://assets/sprites/skeleton.png"},
		{"id": "dire_wolf", "name": "Dire wolf", "group": "CREATURES", "kind": "wolf", "footprint": Vector2i(2, 1), "color": Color("6d6257"), "sprite": "res://assets/sprites/dire_wolf.png"},
		{"id": "chest", "name": "Chest", "group": "PROPS", "kind": "chest", "footprint": Vector2i(1, 1), "color": Color("a66a34"), "sprite": "res://assets/sprites/chest.png"},
		{"id": "campfire", "name": "Campfire", "group": "PROPS", "kind": "fire", "footprint": Vector2i(1, 1), "color": Color("e78b31"), "sprite": "res://assets/sprites/campfire.png"},
		{"id": "table", "name": "Long table", "group": "PROPS", "kind": "table", "footprint": Vector2i(2, 1), "color": Color("805637"), "sprite": "res://assets/sprites/table.png"},
		{"id": "tree", "name": "Ancient tree", "group": "SCENERY", "kind": "tree", "footprint": Vector2i(2, 2), "color": Color("426b3c"), "sprite": "res://assets/sprites/tree.png"},
		{"id": "rock", "name": "Boulder", "group": "SCENERY", "kind": "rock", "footprint": Vector2i(1, 1), "color": Color("737a70"), "sprite": "res://assets/sprites/rock.png"},
		{"id": "ruined_wall", "name": "Ruined wall", "group": "SCENERY", "kind": "wall", "footprint": Vector2i(3, 1), "color": Color("77756b"), "sprite": "res://assets/sprites/ruined_wall.png"}
	]
