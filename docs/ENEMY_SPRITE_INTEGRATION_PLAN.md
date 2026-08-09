# Enemy sprite integration plan

Status: planned, runtime sprite work not started  
Date: 2026-08-09

The detailed behavior, state-machine, attack, and test architecture is defined
in `ENEMY_COMBAT_ANIMATION_IMPLEMENTATION_PLAN.md`. This document remains the
asset-production and visual-integration checklist.

## Diagnosis

The fifteen platformer archetypes are present in the campaign runtime. Each
room spawns four normal enemies and one mid-boss through
`PlatformerEnemyComponent`, and the current tests confirm the roster and room
geometry boot correctly.

The generated enemy images are not runtime assets. The three files under
`docs/visual-concepts/` are concept sheets used to approve silhouette, palette,
and animation poses. They are not transparent, frame-aligned sprite strips and
are not referenced by `pubspec.yaml`, the animation manifest, or enemy code.
`PlatformerEnemyComponent.render()` therefore draws temporary rectangles,
lines, and circles for all fifteen archetypes.

This is an asset-integration gap, not a room-spawn failure.

## Target state

- Every archetype keeps its existing stable enum ID, combat callback, and room
  placement.
- Normal enemies render from 64x64 transparent RGBA animation strips;
  mid-bosses render from 96x96 strips.
- Movement, anticipation, action, hurt, and defeat states are visibly distinct.
- Missing or invalid assets fall back to the current procedural proxy so a bad
  export cannot block the game from loading.
- ROOM 1 is the visual quality gate. ROOM 2 and ROOM 3 start only after ROOM 1
  is approved in motion.

## Implementation sequence

### Phase 0 — freeze the runtime contract

1. Extract each archetype's size, health, mobility, palette, animation keys,
   and state timings into `PlatformerEnemyDefinition`.
2. Add an explicit enemy state model: `idle`, `move`, `anticipation`, `action`,
   `hurt`, `defeat`, plus boss-only states.
3. Keep damage, overflow, projectile, support, and completion callbacks
   independent from rendering.
4. Add tests proving that changing the visual implementation cannot change the
   five-enemy room completion count.

Acceptance: all current tests pass with proxy rendering still enabled.

### Phase 1 — build the sprite pipeline

1. Produce one transparent, right-facing source character per enemy from the
   approved concept sheet instead of cropping the sheet directly.
2. Export one horizontal strip per state using the frame counts in
   `PLATFORMER_ENEMY_ROSTER.md`.
3. Store assets under
   `assets/images/sprites/platformer/<room>/<enemy>/<state>.png`.
4. Extend `assets/images/sprites/animations/manifest.json` with frame size,
   frame count, FPS, loop, pivot, baseline, and validation data.
5. Add an asset validator for exact dimensions, transparent corners, stable
   baseline, centered pivot, and alpha coverage.
6. Record every final strip in `assets/licenses/ASSET_LEDGER.md`.

Acceptance: every manifest entry resolves to a file and every strip passes the
pixel validation script before it can be selected at runtime.

### Phase 2 — add the reusable runtime visual

1. Add `PlatformerEnemySpriteVisual`, following the proven
   `EntitySpriteVisual` loading pattern used by the player and legacy enemies.
2. Map enemy state changes to animation keys and mirror the visual when facing
   left without flipping the hitbox.
3. Align the sprite pivot to the collision body and ground baseline; keep boss
   telegraphs outside the sprite component when gameplay readability requires
   it.
4. Retain the procedural renderer behind a development fallback and emit a
   clear debug warning for missing states.

Acceptance: a test enemy can switch through every state without changing its
world position, collision bounds, or combat result.

### Phase 3 — ROOM 1 vertical slice

Implement and review in this order:

1. Patch Mite — idle, scuttle, bite wind-up, bite, hurt, overflow.
2. Checksum Hopper — compress, rise, fall, land, hurt, overflow.
3. Pulse Turret — scan, charge, fire, vent, hurt, overflow.
4. Repair Leech — crawl, seek, latch, channel, detach, hurt, overflow.
5. Overflow Warden — intro, walk, guard, slam, summon, stagger, collapse.

ROOM 1 is approved only when silhouettes are readable at gameplay scale,
anticipation appears before damage, facing changes do not jitter, and all five
enemies complete the existing patch-selection transition.

### Phase 4 — ROOM 2 and ROOM 3 rollout

1. Apply the verified pipeline to the five Temporal Hall enemies.
2. Add frozen-pose and rewind/replay animation handling without advancing
   frames while the room clock is stopped.
3. Apply the pipeline to the five Collision Archive enemies.
4. Add polarity, disguise, ricochet, split, and recombination visual states as
   explicit state-machine events rather than render-time guesses.

Acceptance: each room displays exactly five visually distinct enemies and each
enemy's core mechanic can be identified before contact.

### Phase 5 — regression and release gate

- Static analysis and full Flutter test suite pass.
- Manifest and sprite validation pass with no missing state or dimension.
- Web build completes and all three rooms are played from title to ending.
- Verify 60 FPS target, no first-use texture hitch, no sprite baseline jitter,
  and no visual/hitbox mismatch at both fixed and resized browser windows.
- Capture one short review clip per room and compare it against the approved
  concept sheet before removing the proxy-render fallback from release builds.

## Planned code and asset changes

| Area | Planned change |
| --- | --- |
| `lib/game/components/enemies/platformer_enemy_component.dart` | Separate behavior/state from procedural rendering and attach the sprite visual |
| `lib/game/components/enemies/platformer_enemy_definition.dart` | Add data-driven archetype and animation-key definitions |
| `lib/game/components/visuals/platformer_enemy_sprite_visual.dart` | Load, switch, mirror, and fall back between animations |
| `assets/images/sprites/platformer/` | Add final per-room, per-enemy RGBA strips |
| `assets/images/sprites/animations/manifest.json` | Register all platformer enemy states and validation metadata |
| `tool/validate_sprite_manifest.dart` | Validate files, dimensions, alpha, pivot, and baseline |
| `test/components/platformer_enemy_visual_test.dart` | Verify state mapping, mirroring, fallback, and hitbox stability |
| `test/game/*_platformer_test.dart` | Verify five-enemy roster and room completion after visual replacement |

## Scope guardrails

- Do not crop and ship the concept sheets as sprites; their composition,
  background, and thumbnail spacing are unsuitable for animation playback.
- Do not create fifteen unrelated enemy classes solely for visuals. Reuse the
  common state and sprite system, then add bespoke behavior only where the room
  mechanic requires it.
- Do not produce all fifteen final sheets before validating ROOM 1 in motion.
  Fixing pivot, scale, or outline rules after bulk generation would multiply
  rework.
- Do not remove the current procedural proxy until final assets have passed
  automated validation and browser playtesting.

## Definition of done

The task is complete when the game no longer shows geometric proxy enemies in
campaign rooms, all fifteen approved concepts appear as animated sprites, their
telegraphs match the damaging frames, and the existing ROOM 1 to ROOM 3
progression reaches the ending without regression.
