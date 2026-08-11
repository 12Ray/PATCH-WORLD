"""Export Art v3 Pass 3-6 enemies, foreground modules, and final boss."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from build_art_v3_player_sheets import FRAME_SIZE, ROOT, SOURCE_DIR, _alpha_coverage


ENEMY_OUTPUT = ROOT / "assets" / "images" / "sprites" / "art_v3" / "enemies"
ENVIRONMENT_OUTPUT = ROOT / "assets" / "images" / "sprites" / "art_v3" / "environment"
BOSS_OUTPUT = ROOT / "assets" / "images" / "sprites" / "art_v3" / "boss"

ROOM_SOURCES = (
    (
        "damageLab",
        "art-v3-damage-lab-enemies-alpha.png",
        ("patch-mite", "checksum-hopper", "pulse-turret", "repair-leech", "overflow-warden"),
        3,
    ),
    (
        "temporalHall",
        "art-v3-temporal-hall-enemies-alpha.png",
        ("tick-runner", "echo-bat", "delay-sniper", "rewind-skater", "chrono-jailer"),
        4,
    ),
    (
        "collisionArchive",
        "art-v3-collision-archive-enemies-alpha.png",
        ("vector-ram", "polarity-drone", "phase-mimic", "shard-lobber", "kernel-chimera"),
        5,
    ),
)

ENVIRONMENT_STYLES = ("damage", "temporal", "collision", "optimizer")
BOSS_STATES = ("analyze", "predict", "perfect", "overflow")


def _extract_grid(
    source: Path,
    columns: int,
    rows: int,
    *,
    square: bool,
    output_size: tuple[int, int],
) -> list[list[Image.Image]]:
    image = Image.open(source).convert("RGBA")
    result: list[list[Image.Image]] = []
    for row in range(rows):
        top = round(row * image.height / rows)
        bottom = round((row + 1) * image.height / rows)
        row_frames: list[Image.Image] = []
        for column in range(columns):
            left = round(column * image.width / columns)
            right = round((column + 1) * image.width / columns)
            if square:
                width = right - left
                height = bottom - top
                crop_size = min(width, height)
                left += (width - crop_size) // 2
                top_offset = top + (height - crop_size) // 2
                right = left + crop_size
                cell_bottom = top_offset + crop_size
                cell = image.crop((left, top_offset, right, cell_bottom))
            else:
                cell = image.crop((left, top, right, bottom))
            cell = cell.resize(output_size, Image.Resampling.NEAREST)
            if cell.getchannel("A").getbbox() is None:
                raise ValueError(f"Empty cell row={row}, column={column}: {source}")
            row_frames.append(cell)
        result.append(row_frames)
    return result


def _write_strip(frames: list[Image.Image], output: Path) -> list[float]:
    frame_width, frame_height = frames[0].size
    strip = Image.new(
        "RGBA",
        (frame_width * len(frames), frame_height),
        (0, 0, 0, 0),
    )
    coverage: list[float] = []
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * frame_width, 0))
        if frame_width == FRAME_SIZE and frame_height == FRAME_SIZE:
            coverage.append(_alpha_coverage(frame))
        else:
            alpha = frame.getchannel("A")
            visible = sum(1 for value in alpha.tobytes() if value > 16)
            coverage.append(round(visible / (frame_width * frame_height), 4))
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)
    return coverage


def _export_enemies() -> None:
    manifest: dict[str, object] = {
        "version": 1,
        "frameWidth": FRAME_SIZE,
        "frameHeight": FRAME_SIZE,
        "framesPerEnemy": 8,
        "locomotionFrames": [0, 3],
        "signatureFrames": [4, 7],
        "signaturePhaseFrames": {
            "telegraph": 4,
            "active": 5,
            "recovering": [6, 7],
        },
        "enemies": {},
    }
    enemies = manifest["enemies"]
    assert isinstance(enemies, dict)
    for room, source_name, slugs, pass_number in ROOM_SOURCES:
        rows = _extract_grid(
            SOURCE_DIR / source_name,
            8,
            5,
            square=True,
            output_size=(FRAME_SIZE, FRAME_SIZE),
        )
        for row, slug in enumerate(slugs):
            asset = f"{slug}.png"
            coverage = _write_strip(rows[row], ENEMY_OUTPUT / asset)
            enemies[slug] = {
                "asset": asset,
                "room": room,
                "frames": 8,
                "fps": 10 if row == 4 else 12,
                "locomotion": {"frames": [0, 3], "fps": 8, "loop": True},
                "signature": {
                    "frames": [4, 7],
                    "fps": 10,
                    "loop": False,
                    "telegraphFrame": 4,
                    "activeFrame": 5,
                    "recoveryFrames": [6, 7],
                },
                "pivot": [0.5, 0.5],
                "displaySize": [104, 104] if row == 4 else [70, 70],
                "alphaCoverage": coverage,
                "sourceGrid": [8, 5],
                "sourceIndices": list(range(row * 8, row * 8 + 8)),
                "promptVersion": f"art-v3-pass{pass_number}-2026-08-11",
                "source": "OpenAI built-in ImageGen with the enemy's Combat Motion v2 strip as fixed identity reference",
                "license": "OpenAI generated project asset",
                "gameplayContract": "presentation only; existing hitbox and EnemyActionTimeline retained",
            }
            print(f"Wrote {ENEMY_OUTPUT / asset}")
    path = ENEMY_OUTPUT / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {path}")


def _export_environment() -> None:
    frame_size = (384, 256)
    rows = _extract_grid(
        SOURCE_DIR / "art-v3-room-foreground-alpha.png",
        4,
        4,
        square=False,
        output_size=frame_size,
    )
    manifest: dict[str, object] = {
        "version": 1,
        "frameWidth": frame_size[0],
        "frameHeight": frame_size[1],
        "roles": ["surface", "cornerWall", "statePlatform", "interactive"],
        "rooms": {},
    }
    rooms = manifest["rooms"]
    assert isinstance(rooms, dict)
    for row, style in enumerate(ENVIRONMENT_STYLES):
        asset = f"{style}-foreground.png"
        coverage = _write_strip(rows[row], ENVIRONMENT_OUTPUT / asset)
        rooms[style] = {
            "asset": asset,
            "frames": 4,
            "roles": ["surface", "cornerWall", "statePlatform", "interactive"],
            "alphaCoverage": coverage,
            "sourceGrid": [4, 4],
            "sourceIndices": list(range(row * 4, row * 4 + 4)),
            "promptVersion": "art-v3-pass3-6-2026-08-11",
            "source": "OpenAI built-in ImageGen with approved environment v2 and Damage Lab kit references",
            "license": "OpenAI generated project asset",
            "gameplayContract": "visual skin only; code geometry remains authoritative",
        }
        print(f"Wrote {ENVIRONMENT_OUTPUT / asset}")
    path = ENVIRONMENT_OUTPUT / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {path}")


def _export_boss() -> None:
    rows = _extract_grid(
        SOURCE_DIR / "art-v3-optimizer-phase-alpha.png",
        4,
        4,
        square=True,
        output_size=(FRAME_SIZE, FRAME_SIZE),
    )
    states: dict[str, object] = {}
    for row, state in enumerate(BOSS_STATES):
        asset = f"optimizer-{state}.png"
        coverage = _write_strip(rows[row], BOSS_OUTPUT / asset)
        states[state] = {
            "asset": asset,
            "state": state,
            "frames": 4,
            "fps": 6 if state in {"analyze", "perfect"} else 8,
            "loop": state in {"analyze", "perfect"},
            "eventFrame": 1 if state == "predict" else 0,
            "pivot": [0.5, 0.5],
            "displaySize": [132, 132],
            "alphaCoverage": coverage,
            "sourceGrid": [4, 4],
            "sourceIndices": list(range(row * 4, row * 4 + 4)),
            "promptVersion": "art-v3-pass6-2026-08-11",
            "source": "OpenAI built-in ImageGen with existing optimizer phase animations as identity references",
            "license": "OpenAI generated project asset",
        }
        print(f"Wrote {BOSS_OUTPUT / asset}")
    manifest = {
        "version": 1,
        "frameWidth": FRAME_SIZE,
        "frameHeight": FRAME_SIZE,
        "states": states,
    }
    path = BOSS_OUTPUT / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {path}")


def main() -> None:
    _export_enemies()
    _export_environment()
    _export_boss()


if __name__ == "__main__":
    main()
