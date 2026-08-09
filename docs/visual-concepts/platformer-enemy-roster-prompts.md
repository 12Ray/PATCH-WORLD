# Platformer enemy roster ImageGen prompt record

Generation mode: built-in OpenAI ImageGen. The existing
`assets/images/ui/patch_world_key_art.png` was supplied as a palette, lighting,
and universe reference only.

## Shared prompt

- Use case: stylized-concept.
- Asset: production concept sheet for a side-scrolling pixel-art roguelike.
- Strict side profile facing right, authored hard pixel edges, no anti-aliasing
  or 3D rendering.
- Wide dark-navy sheet with exactly five large silhouettes in one row and three
  smaller animation-pose thumbnails beneath each.
- Normal enemy designs must remain readable in 64x64 frames; mid-boss designs
  must remain readable in 96x96 frames.
- Preserve the PATCH//WORLD graphite, cyan, magenta, white, red, and limited
  amber palette while giving each room a distinct material language.
- No text, labels, logos, watermark, UI, player, top-down or isometric view,
  extra creatures, duplicate designs, or cropped bodies.

## Room prompts

### Damage Lab

Exactly five subjects, left to right: low six-legged Patch Mite with square
mouth; spring-loaded Checksum Hopper with amber coil; wall-mounted Pulse Turret
with cyan iris; cable-bodied Repair Leech with clamp jaws and repair hose;
Overflow Warden with transparent magenta tank, piston fist, and square shield.
Use an industrial corrupted-laboratory material language.

### Temporal Hall

Exactly five subjects, left to right: pendulum-legged Tick Runner; crescent
Echo Bat with cyan wings and magenta memory crystal; hourglass-barrel Delay
Sniper tripod; one-wheel Rewind Skater with trail spool; floating Chrono Jailer
clock cage with four clock-hand limbs and captive cyan core. Every subject must
have a readable frozen pose or motion-trail silhouette.

### Collision Archive

Exactly five subjects, left to right: arrow-bodied Vector Ram; split cyan and
magenta Polarity Drone; false-platform Phase Mimic; triangular-ammunition Shard
Lobber; twin-body Kernel Chimera around a white collision kernel. Encode force,
polarity, false collision, ricochet, and fusion directly in the silhouettes.
