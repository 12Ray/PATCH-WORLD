# PATCH//WORLD combat motion v2

Status: image-first concept set complete (2026-08-10)

This package is the visual source of truth for the next combat pass. It was
generated with the built-in ImageGen workflow using the current runtime sprites
and room sheets as identity references. Chroma-key sources were converted to
transparent RGBA with the installed ImageGen helper.

## Deliverables

- `enemies/`: fifteen enemy sheets, ten ordered combat poses each.
- `hero/`: sword, gauntlet, and gun sheets, ten combat poses each.
- `projectiles/`: one 3-column x 5-row attack-tier sheet per room.
- `rooms/`: three side-view room redesign concepts.
- `manifest.json`: exact cell order and gameplay meaning for every sheet.

These are approved concept/key-pose sheets, not runtime frame strips yet. The
next asset pass must crop each proportional grid cell, normalize pivots and
baselines, then create multi-frame in-between animation strips.

## Universal attack language

| Tier | Visual | Gameplay promise |
| --- | --- | --- |
| Normal | compact cyan shape, short clean trail | dodge, block, or outrange |
| Enhanced | larger layered magenta shape, jagged aura | cannot be parried; demands movement |
| Parryable | slow warm-white/gold core inside a double diamond | perfect parry reflects it and opens a counter window |

The gold double diamond is reserved for parryable attacks. It must never be
used as ordinary decoration. A successful parry should add a brief hit stop,
gold impact ring, pitch-rising sound, projectile ownership reversal, and a
weapon-specific counter opportunity.

## Hero parry chain

Each weapon sheet ends with the same three-step grammar:

1. cell 8: parry-ready guard;
2. cell 9: perfect-parry contact and gold hit-stop ring;
3. cell 10: weapon-specific counter finisher.

Sword rewards timing and reach, gauntlet rewards close-range stagger, and gun
rewards projectile reflection and ranged conversion.

## Room redesign intent

- ROOM 1 — Damage Lab: moving conveyors, upper reward shortcut, lower overflow
  hazard route, visible checkpoint, and a framed Warden boss gate.
- ROOM 2 — Temporal Hall: clock-platform climb, freeze/release chamber, rewind
  shortcut, timed reward cache, and a suspended Jailer boss stage.
- ROOM 3 — Collision Archive: polarity lifts, breakable shortcut, ricochet
  panels, magnetic crusher corridor, and a two-half Chimera boss arena.

Each room concept is side-view and keeps collision surfaces visually quieter
than the background. Cyan, magenta, and gold projectile paths are shown in the
same frame to validate peripheral readability.

## Generation prompt set

The final prompt set used the `stylized-concept` taxonomy and these shared
constraints: preserve the referenced character identity; crisp side-view pixel
art; fixed equal-cell grid; identical scale and baseline; flat `#00ff00`
background for removable chroma; no labels, text, grid lines, scenery, shadows,
or watermark. Enemy-specific action lists and exact cell order are recorded in
`manifest.json`.

