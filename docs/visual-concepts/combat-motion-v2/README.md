# PATCH//WORLD combat motion v2

Status: runtime key-pose integration and wide-room v3 pass complete (2026-08-10)

This package is the visual source of truth for the next combat pass. It was
generated with the built-in ImageGen workflow using the current runtime sprites
and room sheets as identity references. Chroma-key sources were converted to
transparent RGBA with the installed ImageGen helper.

## Deliverables

- `enemies/`: fifteen enemy sheets, ten ordered combat poses each.
- `hero/`: sword, gauntlet, and gun sheets, ten combat poses each.
- `projectiles/`: one 3-column x 5-row attack-tier sheet per room.
- `rooms/`: original v2 concepts and three extended v3 wide-room concepts.
- `manifest.json`: exact cell order and gameplay meaning for every sheet.

The character grids were cropped and normalized into 33 runtime strips under
`assets/images/sprites/combat_v2/`. Each character owns ten unique key poses.
Runtime code now adds anticipation, attack travel, squash, recoil, hurt hold,
defeat hold, and return-to-idle timing around those poses. Authored multi-frame
in-betweens remain a later animation-polish pass rather than being represented
as frames that do not exist.

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

## Wide-room v3 runtime contract

- Each campaign room is `2880 x 540`, three times the original horizontal size.
- The fixed-resolution camera follows the player and clamps to world edges.
- Each room contains at least twenty solid surfaces, four data pits, two
  checkpoints, two or more active hazards, and two or more jump pads.
- The four normal enemies are distributed across the traversal sections. The
  room boss remains sealed in the final arena until all four are defeated.
- Falling after a checkpoint returns the player to the latest section instead
  of the room entrance.

The v3 concepts are:

- `rooms/room-1-damage-lab-sideview-v3-wide.png`
- `rooms/room-2-temporal-hall-sideview-v3-wide.png`
- `rooms/room-3-collision-archive-sideview-v3-wide.png`

## Generation prompt set

The final prompt set used the `stylized-concept` taxonomy and these shared
constraints: preserve the referenced character identity; crisp side-view pixel
art; fixed equal-cell grid; identical scale and baseline; flat `#00ff00`
background for removable chroma; no labels, text, grid lines, scenery, shadows,
or watermark. Enemy-specific action lists and exact cell order are recorded in
`manifest.json`.

The wide-room v3 prompts used the existing v2 room images as visual references,
requested one continuous three-screen left-to-right route, and required
multi-level paths, safe checkpoint alcoves, pits, vertical machinery, readable
cyan walkable edges, magenta hazards, a gold boss seal, and no UI, labels, text,
watermark, perspective floor, or top-down view. Generation used the built-in
ImageGen mode; final project copies are the three `v3-wide.png` files above.
