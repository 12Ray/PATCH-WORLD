# PATCH//WORLD Art v3 implementation record

Status: Pass 0–6 runtime complete and verified  
Updated: 2026-08-11

## Authority and scope

This implementation follows the current side-view action-platformer product
baseline in Notion documents 29–31. Archived top-down guides remain historical
references. Gameplay hitboxes, room geometry, movement, attack windows,
damage, and progression stay authoritative; Art v3 is presentation-only.

## Delivered passes

### Pass 0–1 — weapon identity and locomotion

- Sword, Gauntlet, and Gun have weapon-specific idle, run, jump-rise, apex,
  fall, and land strips.
- The 42 locomotion frames share the approved pivot and baseline.
- Landing is a low-priority one-shot and cannot interrupt attacks, abilities,
  parry, or hurt reactions.
- A missing individual Art v3 strip falls back independently to QA Hero.

### Pass 2 — combat continuity

- Every weapon has six four-frame attacks, parry, perfect parry, counter, and
  ability connector: 30 strips and 120 authored frames.
- The first frame is the existing gameplay event frame. No damage, projectile,
  parry, counter, cooldown, or movement timing was delayed.
- Sword dash, Gauntlet double jump, and Gun charged rail preserve their existing
  six-frame ability strips and add authored launch/recovery connectors.

### Pass 3–5 — rooms and 15 enemies

- Damage Lab, Temporal Hall, and Collision Archive each retain four normal
  enemies and one mid-boss.
- All 15 enemies add four locomotion frames plus a four-frame signature action:
  telegraph frame 4, active frame 5, recovery frames 6–7.
- `EnemyActionTimeline` remains the only gameplay clock. Hurt, stagger,
  overflow, and defeat keep the existing Combat Motion v2 fallback poses.
- Four foreground skins provide surface, corner/wall, state-platform, and
  interactive modules for Damage Lab, Temporal Hall, Collision Archive, and
  Optimizer Core. They repeat over existing code-owned geometry.

### Pass 6 — Optimizer Core and final integration

- The Optimizer now has four-frame Analyze, Predict, Perfect, and Overflow
  phase strips while retaining the existing boss rules and stability flow.
- Optimizer Core uses its own white/cyan/magenta foreground material skin.
- Existing VFX and deterministic local SFX remain connected; the visual pass
  does not replace or retime gameplay feedback.

## Runtime architecture

- Player paths and timing live in `PlayerCombatAnimation` and
  `PlayerAnimationState` metadata.
- Enemy phase-to-frame mapping is isolated in
  `resolveArtV3EnemyFrame`, mapping telegraph/active/recovery directly to
  authored frames.
- `PlatformSurfaceComponent` loads a room-specific foreground strip and renders
  it above procedural fallback material. `solidBounds` remains authoritative.
- All new bitmap packages have manifests containing dimensions, frames, FPS,
  event/active frames, pivot, display size, alpha coverage, prompt version,
  source, license, and gameplay contract.

## Verification

- `flutter analyze`: 0 issues.
- `flutter test`: 197 tests passed.
- Windows Release: `build/windows/x64/runner/Release/patch_world.exe`.
- Web Release: `build/web`, rebuilt with the production default start room.
- Browser QA: Damage Lab, Temporal Hall, Collision Archive, and Optimizer Core
  rendered without console warnings/errors; only the normal Flutter bootstrap
  debug message was present.
- Exact 960×540 evidence is stored in
  `docs/visual-concepts/art-v3/runtime/pass3-6/`.
- Automated gates validate 30 player combat strips, 15 enemy strips, four
  foreground strips, four boss strips, alpha coverage, dimensions, frame
  uniqueness, and timing/frame mappings.

## Completion boundary

Generated: complete. Runtime-applied: complete. Automated verification:
complete. Local browser verification: complete. Commit, push, merge, public
deployment, and final public URL verification are recorded separately so local
completion is never overstated.
