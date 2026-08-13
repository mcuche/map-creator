# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Delegated: Godot 4 with GDScript, chosen for a lightweight Windows desktop application with native 2D tooling and text-based project files.

## Users

The initial user is the creator of this project, preparing fantasy tabletop battle maps for personal Dragonbane RPG sessions.

## Product Purpose

Create top-down fantasy battle maps quickly by combining painted landscapes with pixel-art characters, enemies, objects, and terrain. Success means producing a polished map without needing an image editor, then saving it for later changes or exporting it as a PNG.

## Positioning

The tool combines an approachable drag-and-drop map canvas with a deliberately mixed-media look: crisp pixel-art pieces placed over atmospheric painted fantasy terrain.

## Operating Context

The application runs locally on Windows desktop. The user selects or imports a landscape, arranges pieces on a top-down canvas, configures a grid, saves an editable local project, and exports a clean image for use in a tabletop session.

## Capabilities and Constraints

- First release creates and exports maps only; it does not run encounters.
- Supports a square grid that can be shown or hidden.
- Detects regular square grids in imported landscapes and can use them for snapping without drawing an additional overlay.
- Pieces can be placed, moved, rotated, mirrored, duplicated, and deleted.
- Object footprints cannot overlap; each grid cell belongs to at most one placed object.
- Pieces use predefined grid footprints such as 1×1, 1×2, or 2×2 and snap to grid cells; users do not resize pieces manually.
- Supports bundled placeholder assets and custom PNG imports.
- Imported landscapes retain their original aspect ratio; unused canvas space becomes centered borders rather than stretching the image.
- Saves editable projects locally and exports PNG images.
- No accounts, cloud sync, marketplace, multiplayer, combat rules, initiative, health tracking, or fog of war in the initial scope.
- The UI should remain responsive at common Windows desktop sizes. The initial export-size presets are still undecided.

## Brand Commitments

Pixel-art characters and objects must remain crisp over painted fantasy backgrounds. The editor uses a theatre scene-and-cue visual language: the map is the stage, the asset library is Cast & Props, and scene controls use restrained cue terminology. The application name is undecided.

## Evidence on Hand

No production artwork, logo, font, or existing application is present. Initial content must use original placeholder assets and must not reproduce copyrighted Dragonbane artwork or rules text.

## Product Principles

- Keep the map—not application chrome—at the center of attention.
- Make common placement and editing actions immediately discoverable.
- Preserve a coherent mixed-media result without restricting user imports.
- Prefer dependable local files and reversible edits over account-based features.
- Keep rules-specific content out of the editor core.

## Accessibility & Inclusion

Core editing must work with clear labels, high-contrast controls, visible focus, and keyboard shortcuts in addition to pointer input.
