# PATCH//WORLD Platformer Enemy Roster v1

This document fixes the first production roster for the side-view roguelike
campaign before gameplay code or final sprite sheets are rebuilt.

## Shared production rules

- View: strict side profile, facing right; mirror in-engine for left-facing.
- Normal enemy frame: 64x64 pixels. Mid-boss frame: 96x96 pixels.
- Pixel language: hard 1-pixel edges, no sub-pixel blur, no painted shadows.
- Anchor: centered X pivot and a shared room-specific ground baseline.
- Readability: attack anticipation must alter the silhouette for at least 3
  frames before the damaging frame.
- Palette: deep navy and graphite base; stable code cyan; corruption magenta;
  physical danger red; reward and execution gold.
- Required export: one horizontal strip per state, transparent RGBA, exact frame
  count recorded in the animation manifest.
- Normal enemies need idle, locomotion, anticipation, action, hurt, and defeat.
  Mid-bosses additionally need intro, stagger, phase change, and collapse.

## Room 1 — DAMAGE LAB

Room fantasy: a leaking build laboratory where the player's pulse restores
hostile code until it overflows. The terrain uses glass tanks, broken conduits,
acid pits, pistons, and short industrial platforms. Enemies are grounded,
compact, red/graphite machines with magenta fluid cores.

### 1. Patch Mite — ground patrol

- Silhouette: low six-legged maintenance bug with a bright square mouth.
- Role: teaches ledges, jump-over attacks, and stomp spacing.
- Behavior: patrols a platform, turns at ledges, then performs a short bite dash.
- Counterplay: jump over the bite and pulse from behind; overflow launches data.
- Animation: idle 3f/6fps loop, scuttle 6f/10fps loop, bite-windup 3f/10fps,
  bite 4f/12fps, hurt 2f/12fps, overflow 6f/12fps.

### 2. Checksum Hopper — vertical space check

- Silhouette: spring-loaded quadruped with a compressed amber checksum coil.
- Role: forces the player to read arcs instead of staying on one platform.
- Behavior: crouches, locks an arc, leaps to the player's platform, and stalls
  briefly after landing.
- Counterplay: cross beneath the jump or use the landing stall to overflow it.
- Animation: idle 3f/6fps loop, compress 4f/10fps, rise 2f/10fps, fall 2f/10fps,
  land 4f/12fps, hurt 2f/12fps, overflow 6f/12fps.

### 3. Pulse Turret — lane controller

- Silhouette: wall-mounted rectangular cannon with a cyan targeting iris.
- Role: makes safe platforms temporary and creates jump timing windows.
- Behavior: scans horizontally, flashes a line, fires one slow magenta bolt,
  then vents its barrel.
- Counterplay: move during venting or redirect environmental damage into it.
- Animation: idle 3f/6fps loop, scan 4f/8fps loop, charge 4f/10fps, fire 4f/12fps,
  vent 3f/8fps, hurt 2f/12fps, overflow 6f/12fps.

### 4. Repair Leech — support threat

- Silhouette: long cable-bodied parasite with two clamp jaws and a cyan hose.
- Role: changes target priority and demonstrates Room 1's inverted healing rule.
- Behavior: crawls along floors and walls, latches onto the most damaged enemy,
  and pumps repair energy into it.
- Counterplay: allow it to overfill a nearly full target, causing a chain
  overflow, or interrupt the exposed hose.
- Animation: crawl 6f/9fps loop, seek 3f/8fps, latch 4f/10fps, channel 4f/8fps
  loop, detach 3f/10fps, hurt 2f/12fps, overflow 7f/12fps.

### 5. Overflow Warden — Room 1 mid-boss

- Silhouette: broad two-legged containment suit with a transparent magenta tank,
  one piston fist, and one square shield arm.
- Role: tests platform movement, overflow timing, and Repair Leech manipulation.
- Behavior: walks between two levels, shields frontal pulses, slams the floor to
  send a conduit wave, and summons one Repair Leech at health thresholds.
- Counterplay: bait a Leech behind the shield or attack during the tank-vent
  window; overfilling the tank triggers the stagger phase.
- Animation: intro 6f/8fps, idle 4f/6fps loop, walk 8f/10fps loop, guard 4f/8fps,
  slam-windup 5f/10fps, slam 6f/12fps, summon 6f/10fps, vent-stagger 6f/10fps,
  overflow-collapse 10f/12fps.

## Room 2 — TEMPORAL HALL

Room fantasy: a suspended clock corridor where time advances only when the
player expresses movement. Platforms, bolts, and enemies share the same
readable timeline. Enemies are lean or floating cyan/violet machines with
clock arcs, afterimages, and very clear frozen poses.

### 1. Tick Runner — synchronized patrol

- Silhouette: thin biped with a single pendulum leg and clock-hand nose.
- Role: teaches that enemy locomotion advances with player intent.
- Behavior: patrols while the player moves, freezes instantly when input stops,
  and performs a fast three-step lunge after three movement beats.
- Counterplay: stop to inspect the lane, then move in short deliberate bursts.
- Animation: frozen 1f hold, tick-walk 6f/10fps loop, beat-charge 3f/8fps,
  lunge 5f/12fps, hurt 2f/12fps, shatter 6f/12fps.

### 2. Echo Bat — jump recorder

- Silhouette: crescent drone with two cyan wings and a magenta memory crystal.
- Role: turns repeated jump habits into airborne pressure.
- Behavior: records the player's most recent jump arc, then replays that arc as
  a damaging magenta afterimage.
- Counterplay: deliberately feed it a harmless low jump before crossing.
- Animation: hover 6f/9fps loop, record 4f/8fps, fold 3f/10fps, replay-flight
  6f/12fps, hurt 2f/12fps, erase 6f/12fps.

### 3. Delay Sniper — long-range timer

- Silhouette: tall tripod with an hourglass barrel and a razor-thin aim beam.
- Role: creates visible deadlines across multiple platforms.
- Behavior: tracks the player, locks a line, and releases a bolt that remains
  suspended whenever the player stops.
- Counterplay: freeze the bolt in a safe position, reposition, then resume time.
- Animation: idle 4f/6fps loop, track 4f/8fps loop, lock 4f/8fps, fire 4f/12fps,
  cooldown 3f/8fps, hurt 2f/12fps, desync 7f/12fps.

### 4. Rewind Skater — reversible charger

- Silhouette: low one-wheel duelist with a long cyan trail spool.
- Role: punishes standing where an enemy has already travelled.
- Behavior: dashes across a platform, marks its route, then rewinds along the
  exact path after a short frozen tell.
- Counterplay: cross the route after the first dash and leave before rewind.
- Animation: idle 3f/6fps loop, skate 6f/12fps loop, dash-start 4f/12fps,
  dash 4f/14fps, rewind-tell 3f/8fps, rewind 4f/14fps, desync 7f/12fps.

### 5. Chrono Jailer — Room 2 mid-boss

- Silhouette: floating clock-cage torso with four long clock-hand limbs and a
  captive cyan core.
- Role: combines frozen projectiles, moving platforms, and recorded movement.
- Behavior: locks one platform in time, sweeps two clock hands, records one
  player jump, and replays it as a hostile echo during the next cycle.
- Counterplay: stop time to create safe gaps, deliberately record a simple
  motion, and strike the exposed core while all four hands rewind.
- Animation: intro 8f/8fps, hover 6f/8fps loop, platform-lock 6f/10fps,
  hand-sweep 8f/12fps, record 5f/8fps, rewind 8f/12fps, stagger 5f/10fps,
  clock-collapse 10f/12fps.

## Room 3 — COLLISION ARCHIVE

Room fantasy: a broken physics archive built from shifting blocks, magnetic
rails, false floors, and polarity gates. Enemies are angular cyan/magenta
constructs whose hitboxes and force direction are visibly encoded in shape.

### 1. Vector Ram — horizontal launcher

- Silhouette: wedge-headed quadruped with a large arrow engraved through its
  body and a red impact plate.
- Role: turns enemies into moving terrain hazards and launch tools.
- Behavior: locks a horizontal vector, charges, rebounds from solid blocks, and
  briefly exposes its rear core after impact.
- Counterplay: make it break cracked walls or launch another enemy into a gate.
- Animation: idle 3f/6fps loop, aim 4f/8fps, charge 5f/14fps, impact 4f/12fps,
  rebound 4f/10fps, hurt 2f/12fps, fragment 7f/12fps.

### 2. Polarity Drone — push/pull controller

- Silhouette: floating split orb, cyan positive half and magenta negative half.
- Role: changes jump arcs and platform approach angles.
- Behavior: alternates pull and push fields after a readable rotation, affecting
  the player, loose blocks, and other enemies.
- Counterplay: enter pull to extend a jump or use push to redirect a hazard.
- Animation: hover 6f/8fps loop, rotate 4f/8fps, pull 5f/10fps loop, push
  5f/10fps loop, overload 3f/12fps, split 7f/12fps.

### 3. Phase Mimic — false platform

- Silhouette: a square archive tile that unfolds into four articulated legs and
  a magenta mouth seam.
- Role: makes platform reading part of enemy recognition.
- Behavior: pretends to be a safe block, wakes under player weight, becomes
  intangible, then snaps shut from below.
- Counterplay: identify its pulsing seam or trigger it with a downward pulse.
- Animation: disguise 2f/4fps loop, wake 4f/10fps, unfold 5f/12fps, phase
  4f/10fps, snap 4f/12fps, fragment 7f/12fps.

### 4. Shard Lobber — ricochet artillery

- Silhouette: hunched block carrier with a visible triangular ammunition rack.
- Role: fills vertical spaces with predictable bouncing projectiles.
- Behavior: samples nearby surfaces, throws a shard along a two-bounce path,
  then reloads from the environment.
- Counterplay: read the projected bounce dots or redirect the shard into a lock.
- Animation: idle 4f/6fps loop, calculate 4f/8fps, lift 4f/10fps, throw 5f/12fps,
  reload 5f/9fps, hurt 2f/12fps, fragment 7f/12fps.

### 5. Kernel Chimera — Room 3 mid-boss

- Silhouette: two offset bodies sharing one collision cage; cyan core pulls and
  magenta core pushes while a central white kernel stays shielded.
- Role: tests collision routing, polarity, wall breaking, and vertical movement.
- Behavior: separates into two linked halves, charges from opposite platforms,
  creates polarity lanes, and recombines into a shockwave body.
- Counterplay: force the two halves to collide inside the containment target;
  the kernel opens only after a correct cyan/magenta collision.
- Animation: intro-fusion 10f/10fps, stalk 8f/10fps loop, split 6f/10fps,
  polarity-charge 6f/12fps, collision-stagger 6f/10fps, shockwave 7f/12fps,
  refuse 6f/10fps, kernel-collapse 12f/12fps.

## Concept-sheet mapping

Each generated room sheet presents the five enemies from left to right in the
same order as this document. The large row fixes silhouette, palette, scale,
and side profile. The small thumbnails beneath each enemy communicate the
largest anticipation and action poses; they are animation references, not
final runtime sprite strips.

## Implementation order after concept approval

1. Rebuild side-view player physics and one grey-box Damage Lab room.
2. Produce Room 1 final sprite strips and implement its four enemies.
3. Implement Overflow Warden and validate the complete five-enemy room loop.
4. Reuse the verified animation pipeline for Temporal Hall, then Collision
   Archive.
5. Only after the three campaign rooms work, adapt survival mode to the new
   side-view controller.
