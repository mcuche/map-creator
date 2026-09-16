# Battle Map Creator

A personal Windows desktop map-building tool for fantasy tabletop sessions, built with Godot 4 and GDScript.

## Current foundation

- Wide top-down map stage with a square grid that can be shown or hidden
- Permanent Cast & Props library
- Fixed asset footprints such as 1×1, 2×1, 2×2, and 3×1
- Drag pieces from Cast & Props onto the map, then move, rotate, mirror, duplicate, delete, undo, and redo
- Reserve every occupied grid cell so object footprints cannot overlap
- Import a painted background image
- Preserve imported landscape proportions with centered side or top/bottom borders
- Detect regular square grids in imported landscapes and snap to them without drawing a second grid
- Save and load editable `.battlemap` files with the PNGs used by placed pieces embedded once per image
- Export the visible map stage as PNG

## Run

1. Install Godot 4.x.
2. Import `project.godot` from this folder.
3. Press **F5** or use **Run Project**.

Do not use **F6** while a test file is selected: F6 runs the current scene or script instead of the configured application. The application's main scene is `res://main.tscn`.

## Tests

Run the occupancy test through its scene wrapper, `res://tests/test_occupancy.tscn`, rather than running `test_occupancy.gd` directly. The occupancy scene runs headlessly and checks that PNG export returns `ERR_UNAVAILABLE` there. Run `res://tests/test_export.tscn` with a renderer to verify successful PNG output and its dimensions.

## Shortcuts

- `Ctrl+S` — save
- `Ctrl+O` — open
- `Ctrl+Z` / `Ctrl+Y` — undo / redo
- `Ctrl+D` — duplicate selected piece
- `R` — rotate selected piece
- `Delete` — remove selected piece

The bundled library includes an original detailed fantasy pixel-art sprite set. Import a landscape through **LANDSCAPE**; custom pixel-asset importing is planned for a later iteration.

## Custom Cast & Props

The Cast & Props panel creates a user-owned `catalog.json` and image folder on first run. Use **OPEN FOLDER** to edit them and **RELOAD** to validate and apply changes. See [CATALOG.md](CATALOG.md) for the schema and limits.
