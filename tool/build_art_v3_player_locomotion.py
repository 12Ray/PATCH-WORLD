"""Normalize approved Art v3 player locomotion sheets for Flame.

Pass 1 ImageGen sources use a 4x4 chroma-key grid. The first fourteen cells
contain six run, two jump-rise, one apex, two fall, and three land poses; the
last two cells must be empty. ``remove_chroma_key.py`` runs before this script.

The exporter keeps one shared scale and foot baseline across every state for a
weapon, writes one horizontal 256x256-frame strip per state, and extends the
Pass 0 manifest without changing gameplay geometry or timing.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from build_art_v3_player_sheets import (
    FRAME_SIZE,
    OUTPUT_DIR,
    SOURCE_DIR,
    _align_frames,
    _alpha_coverage,
    DISPLAY_SIZE,
    SOURCE_BASELINE,
)


GRID_SIZE = 4
OCCUPIED_CELLS = 14
EMPTY_CELL_COVERAGE_LIMIT = 0.005

SOURCES = {
    "sword": "art-v3-sword-locomotion-alpha.png",
    "gauntlet": "art-v3-gauntlet-locomotion-alpha.png",
    "gun": "art-v3-gun-locomotion-alpha.png",
}


@dataclass(frozen=True)
class StateSpec:
    key: str
    asset_suffix: str
    start: int
    frames: int
    fps: int
    loop: bool


STATES = (
    StateSpec("run", "run", 0, 6, 10, True),
    StateSpec("jumpRise", "jump-rise", 6, 2, 10, True),
    StateSpec("apex", "apex", 8, 1, 1, True),
    StateSpec("fall", "fall", 9, 2, 10, True),
    StateSpec("land", "land", 11, 3, 12, False),
)


def _extract_cells(source: Path) -> list[Image.Image]:
    image = Image.open(source).convert("RGBA")
    cells: list[Image.Image] = []
    for row in range(GRID_SIZE):
        top = round(row * image.height / GRID_SIZE)
        bottom = round((row + 1) * image.height / GRID_SIZE)
        for column in range(GRID_SIZE):
            left = round(column * image.width / GRID_SIZE)
            right = round((column + 1) * image.width / GRID_SIZE)
            width = right - left
            height = bottom - top
            crop_size = min(width, height)
            crop_left = left + (width - crop_size) // 2
            crop_top = top + (height - crop_size) // 2
            cells.append(
                image.crop(
                    (
                        crop_left,
                        crop_top,
                        crop_left + crop_size,
                        crop_top + crop_size,
                    )
                ).resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)
            )
    return cells


def _validate_empty_cells(cells: list[Image.Image], weapon: str) -> None:
    for index, cell in enumerate(cells[OCCUPIED_CELLS:], OCCUPIED_CELLS):
        coverage = _alpha_coverage(cell)
        if coverage > EMPTY_CELL_COVERAGE_LIMIT:
            raise ValueError(
                f"{weapon} source cell {index} should be empty, coverage={coverage}"
            )


def _write_strip(frames: list[Image.Image], output: Path) -> list[float]:
    strip = Image.new(
        "RGBA",
        (FRAME_SIZE * len(frames), FRAME_SIZE),
        (0, 0, 0, 0),
    )
    coverage: list[float] = []
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
        coverage.append(_alpha_coverage(frame))
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)
    return coverage


def _sequence(
    *,
    weapon: str,
    state: StateSpec,
    coverage: list[float],
) -> dict[str, object]:
    return {
        "asset": f"{weapon}-{state.asset_suffix}.png",
        "state": state.key,
        "sourceFrameSize": [FRAME_SIZE, FRAME_SIZE],
        "displaySize": [DISPLAY_SIZE, DISPLAY_SIZE],
        "frames": state.frames,
        "fps": state.fps,
        "loop": state.loop,
        "pivot": [0.5, 0.5],
        "baseline": SOURCE_BASELINE,
        "eventFrame": None,
        "alphaCoverage": coverage,
        "sourceGrid": [GRID_SIZE, GRID_SIZE],
        "sourceIndices": list(range(state.start, state.start + state.frames)),
        "promptVersion": "art-v3-pass1-2026-08-11",
        "source": "OpenAI built-in ImageGen with approved Art v3 idle and Combat Motion v2 references",
        "license": "OpenAI generated project asset",
    }


def main() -> None:
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    locomotion: dict[str, object] = {}

    for weapon, source_name in SOURCES.items():
        cells = _extract_cells(SOURCE_DIR / source_name)
        _validate_empty_cells(cells, weapon)
        aligned = _align_frames(cells[:OCCUPIED_CELLS])
        weapon_states: dict[str, object] = {}
        for state in STATES:
            frames = aligned[state.start : state.start + state.frames]
            output = OUTPUT_DIR / f"{weapon}-{state.asset_suffix}.png"
            coverage = _write_strip(frames, output)
            weapon_states[state.key] = _sequence(
                weapon=weapon,
                state=state,
                coverage=coverage,
            )
            print(f"Wrote {output}")
        locomotion[weapon] = weapon_states

    manifest["version"] = 2
    manifest["locomotion"] = locomotion
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {manifest_path}")


if __name__ == "__main__":
    main()
