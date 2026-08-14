---
name: Battle Map Creator
description: A stage-first desktop editor for arranging crisp pixel-art pieces over atmospheric fantasy maps.
colors:
  stage-black: "#111827"
  panel: "#182128"
  panel-raised: "#202b33"
  hairline-seam: "#344550"
  cobalt-active: "#3557a8"
  dusty-rose-warning: "#d67a73"
  cue-gold: "#f0c96b"
  warm-paper: "#f7f2e8"
  muted-label: "#a8b1b4"
  map-forest: "#263d2c"
  map-earth: "#756d4d"
typography:
  display:
    fontFamily: "Godot default sans-serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.2
  body:
    fontFamily: "Godot default sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.3
  label:
    fontFamily: "Godot default sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.2
rounded:
  sm: "4px"
spacing:
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "14px"
components:
  button-default:
    backgroundColor: "{colors.panel-raised}"
    textColor: "{colors.warm-paper}"
    rounded: "{rounded.sm}"
    padding: "7px 10px"
  button-export:
    backgroundColor: "{colors.cue-gold}"
    textColor: "#1b2429"
    rounded: "{rounded.sm}"
    padding: "7px 10px"
  field:
    backgroundColor: "{colors.stage-black}"
    textColor: "{colors.warm-paper}"
    rounded: "{rounded.sm}"
    padding: "7px 10px"
---

# Design System: Battle Map Creator

## Overview

**Creative North Star: "The Map Is the Stage"**

This is a stage-first desktop tool: the painted map owns the center, while editor chrome is deliberately dark, quiet, and cue-like. The permanent left Cast & Props rail and compact right Stage Controls panel frame a wide central stage. Cobalt marks active states, cue gold marks the primary action and section cues, dusty rose is reserved for removal/warning language, and warm paper text keeps the dark shell legible.

The implemented surface uses Godot's default sans-serif at a compact desktop scale. Panels are flat tonal blocks joined by one-pixel seams; controls use small 4px corners and restrained internal padding. The canvas supports a painted/placeholder landscape, a regular square grid that can be detected from an imported image or drawn as an overlay, and crisp pixel-style pieces with a warm selection keyline.

**Key Characteristics:**
- Stage-black shell with panel tonal layering and hairline seams.
- Permanent 276px Cast & Props library, dominant center stage, 260px Stage Controls panel.
- Cobalt active controls; cue-gold Export PNG and section headings.
- Crisp pixel-art silhouettes over painted/placeholder terrain; no shadows in the UI chrome.

## Colors

The palette is a dark theatre shell with warm paper type and sparse, high-signal accents.

### Primary
- **Cobalt Active** (#3557a8): pressed/active control state and selection emphasis in the Godot theme.
- **Cue Gold** (#f0c96b): Export PNG primary action, small section headings, and selected-piece keylines.

### Secondary
- **Dusty Rose Warning** (#d67a73): the Remove From Stage action and warning-toned affordances.

### Neutral
- **Stage Black** (#111827): command/status bars, canvas-adjacent shell, and default field background.
- **Panel** (#182128): Cast & Props and Stage Controls surfaces.
- **Panel Raised** (#202b33): default button and option-control surfaces.
- **Hairline Seam** (#344550): one-pixel panel/control borders.
- **Warm Paper** (#f7f2e8): primary text and selected-piece corner markers.
- **Muted Label** (#a8b1b4): helper text, status copy, and placeholders.

### Named Rules
**The Cue-Gold Rule.** Reserve gold for primary action, cue headings, and selection feedback so it reads as a stage direction rather than decoration.

## Typography

**Display Font:** Godot default sans-serif (no custom font is configured)
**Body Font:** Godot default sans-serif
**Label/Mono Font:** none configured

**Character:** Compact, utilitarian sans-serif text keeps the editor scannable while uppercase cue labels provide theatrical hierarchy.

### Hierarchy
- **Display** (regular, 18px, approximately 1.2 line-height): application title “BATTLE MAP CREATOR”.
- **Title** (regular, 17px): panel titles such as “CAST & PROPS” and “STAGE CONTROLS”.
- **Body** (regular, 14px, approximately 1.3 line-height): buttons, fields, and primary editor copy.
- **Label** (regular, 11px): uppercase group headings and cue labels.
- **Detail** (regular, 12px): status/help text and selected-piece metadata.

## Layout

The root is a full-rect vertical shell: a 54px command bar, an expanding three-column body, and a 32px status bar. The body keeps a permanent 276px Cast & Props rail on the left, an expanding stage with 8px margins, and a compact 260px Stage Controls panel on the right. The canvas has a 720×480 minimum and uses a 24×16 logical cell map; cell size scales to the available stage.

The library uses two-column 114×116 asset cards with a large pixel-model preview and the name plus grid footprint underneath, separated by 6px gaps and 14px group spacing. A 12px end gutter keeps the vertical scrollbar clear of the cards. Panels use 12px horizontal and 10px vertical content margins. The configured desktop viewport is 1600×900 with a 1440×810 window override; no breakpoint behavior is established in code.

## Elevation & Depth

The editor is flat-by-default. Depth comes from tonal panel steps (`stage-black` → `panel` → `panel-raised`) and one-pixel seams, not drop shadows. The map itself draws small translucent grounding shadows beneath placeholder terrain and pieces; these belong to the stage rendering, not the UI chrome.

### Named Rules
**The Flat Stagecraft Rule.** Use tonal layering and hairline seams for editor structure; do not add generic card shadows to the shell.

## Shapes

Controls and fields use a consistent 4px radius with one-pixel borders. Panels are rectangular with selective seam borders. The stage is a clipped rectangular canvas. Pieces occupy predefined 1×1, 1×2, or 2×2-style footprints, snap to whole cells, and receive a clean 3px cue-gold selection outline.

## Components

### Buttons
- **Shape:** restrained 4px corners with one-pixel border and 7px × 10px internal padding.
- **Default:** panel-raised background with warm-paper text.
- **Hover / Focus:** hover lightens the background and uses a lightened cobalt border; focus uses cobalt fill with cue-gold border.
- **Primary:** Export PNG uses cue-gold fill and dark text.
- **Destructive:** Remove From Stage keeps the shared button shape but uses dusty-rose text.

### Cards / Containers
- **Corner Style:** rectangular panels; no corner radius.
- **Background:** panel for rails, stage-black for command/status bars, panel-raised for controls.
- **Shadow Strategy:** no UI shadows; rely on tonal layering and seams.
- **Border:** one-pixel hairline seam on panel edges where configured.
- **Internal Padding:** 12px horizontal and 10px vertical.

### Inputs / Fields
- **Style:** stage-black fill, hairline seam border, 4px radius, warm-paper text, muted placeholder.
- **Focus:** cue-gold border while retaining the stage-black fill.
- **Behavior:** the Cast & Props search filters by asset name or group.

### Navigation
- **Style:** a single command bar, not page navigation; 54px high with title, file actions, undo/redo, grid selector, and right-aligned Export PNG.
- **States:** command buttons use the shared default/hover/focus treatment; Export PNG is the gold primary.

### Stage Canvas
The central canvas renders a background (imported image or original placeholder landscape), a square grid that can be overlaid or hidden, and pixel-style cast/prop silhouettes. Imported landscapes are fitted without distortion and centered inside stage-black side or top/bottom borders. On landscape import, regular square lines are detected automatically; Detected mode transforms their origin and spacing into that fitted image rectangle and snaps without drawing a second grid. Pieces are dragged directly from Cast & Props onto the map, then use exclusive whole-cell occupancy, drag repositioning, rotation, horizontal mirroring, duplication, delete, and undo/redo. Dragged pieces stop at their last valid cell instead of entering occupied footprints, and library drops advertise occupied targets as invalid before release.

## Do's and Don'ts

### Do:
- **Do** keep the map visually dominant between the fixed 276px and 260px rails.
- **Do** preserve crisp pixel silhouettes over atmospheric/painted terrain.
- **Do** use cobalt for active state, cue gold for primary cues, and dusty rose for removal/warnings.
- **Do** keep labels clear and pair pointer actions with the implemented keyboard shortcuts (Ctrl+S/O/Z/Y/D, R, Delete).

### Don't:
- **Don't** introduce manual piece resizing; footprints are asset-defined and snap to whole cells.
- **Don't** turn the editor into an encounter tracker; encounter statistics are out of scope.
- **Don't** replace the flat, seam-led shell with generic shadow-heavy cards.
- **Don't** let chrome compete with the stage or soften pixel-art edges with filtering.
