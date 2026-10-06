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
- Scale the editor controls with a saved **UI Scale** choice in Stage Controls

`StageEditor` owns placed pieces, selection, occupancy, movement transactions, and the bounded undo/redo history. `BattleMapCanvas` adapts pointer gestures and coordinates, draws snapshots, and owns grid configuration, images, persistence, and export. Grid, landscape, and camera settings remain outside piece history.

Map files use version 3 with embedded piece images. Version 1 and version 2 prototype maps are no longer supported.

## Run

1. Install Godot 4.x.
2. Import `project.godot` from this folder.
3. Press **F5** or use **Run Project**.

Do not use **F6** while a test file is selected: F6 runs the current scene or script instead of the configured application. The application's main scene is `res://main.tscn`.

**UI Scale** offers Auto, 100%, 125%, 150%, and 200%. Auto uses the current monitor width on Windows. The editor may temporarily use a smaller scale when the window is too small to fit a 1280×720 workspace; your choice remains saved in `user://display_settings.cfg`.

## Tests

Run the editor interface tests with `Godot --headless --path . --quit-after 1800 res://tests/test_stage_editor.tscn`. They cover editing rules, movement transactions, history, and layout replacement without a canvas.

Run the occupancy test through its scene wrapper, `res://tests/test_occupancy.tscn`, rather than running `test_occupancy.gd` directly. The occupancy scene runs headlessly and checks that PNG export returns `ERR_UNAVAILABLE` there. Run `res://tests/test_export.tscn` with a renderer to verify successful PNG output and its dimensions.
The responsive layout and UI scale checks are `res://tests/test_responsive_layout.tscn` and `res://tests/test_ui_scale.tscn`.

## Shortcuts

Use **SHORTCUTS** in the top menu to open the keyboard and mouse reference. Close it with the cross button in the top-right corner or **Escape**. The workspace has no footer; failures appear in a dismissible dialog.

- Save — `Ctrl` + `S`
- Open — `Ctrl` + `O`
- Undo / redo — `Ctrl` + `Z` / `Ctrl` + `Y`
- Duplicate selected piece — `Ctrl` + `D`
- Rotate selected piece clockwise / counterclockwise — `R` / `Shift` + `R`
- Remove selected piece — `Delete`
- Zoom in — hold `Ctrl` and press the `+` key
- Zoom out — hold `Ctrl` and press the `-` key
- Fit the map to the stage — `Ctrl` + `0`
- Drag from Cast & Props to place a piece; left-click and drag pieces to select and move them
- Right-click a piece for its object menu; right-drag to pan; use the mouse wheel to zoom

The bundled library includes an original detailed fantasy pixel-art sprite set. Import a landscape through **LANDSCAPE**; custom pixel-asset importing is planned for a later iteration.

## Custom Cast & Props

The Cast & Props panel creates a user-owned `catalog.json` and image folder on first run. Use **OPEN FOLDER** to edit them and **RELOAD** to validate and apply changes. See [CATALOG.md](CATALOG.md) for the schema and limits.
