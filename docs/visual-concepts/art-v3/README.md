# PATCH//WORLD Art v3 package

Generated with OpenAI built-in ImageGen and integrated on 2026-08-11.

## Runtime packages

- `assets/images/sprites/art_v3/hero/`: three weapon identities, locomotion,
  six attacks, parry, perfect parry, counter, and ability connectors.
- `assets/images/sprites/art_v3/enemies/`: 15 eight-frame enemy strips.
- `assets/images/sprites/art_v3/environment/`: four room foreground strips.
- `assets/images/sprites/art_v3/boss/`: four Optimizer phase strips.

Each runtime directory contains a manifest. Conversion is reproducible with:

- `tool/build_art_v3_player_sheets.py`
- `tool/build_art_v3_player_locomotion.py`
- `tool/build_art_v3_player_combat.py`
- `tool/build_art_v3_world.py`

ImageGen source masters are retained under `player/pass2`, `enemies/pass3–5`,
`environment/pass3-6`, and `boss/pass6`. Chroma-removed intermediates stay in
the ignored `tmp/imagegen` directory.

## Runtime evidence

`runtime/pass3-6/` contains exact 960×540 captures for weapon selection,
Damage Lab idle/attack/dash/parry, Temporal Hall, Collision Archive, and
Optimizer Core. Browser consoles reported zero warning/error entries.

## Contract

Art v3 never infers collision or independently triggers damage. Player actions
begin at the current gameplay event frame, enemy active frame 5 is selected by
`EnemyActionTimeline`, and foreground pixels are skins over code geometry.

The complete generation prompt set is in `PROMPTS.md`.
