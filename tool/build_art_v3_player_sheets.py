"""Normalize ImageGen Art v3 weapon-idle sources for Flame.

Pass 0 sources contain four equal horizontal cells on a removable chroma-key
background. The chroma-key helper runs first and writes the ``*-alpha.png``
files under ``tmp/imagegen``. This script keeps each source cell's fixed camera
and baseline, crops the centered square, and exports four 256x256 frames.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "imagegen"
OUTPUT_DIR = ROOT / "assets" / "images" / "sprites" / "art_v3" / "hero"
FRAME_COUNT = 4
FRAME_SIZE = 256
TARGET_VISIBLE_HEIGHT = 220
MAX_VISIBLE_WIDTH = 232
TARGET_BASELINE_Y = 240

SHEETS = {
    "sword": "art-v3-sword-idle-alpha.png",
    "gauntlet": "art-v3-gauntlet-idle-alpha.png",
    "gun": "art-v3-gun-idle-alpha.png",
}


def _alpha_coverage(frame: Image.Image) -> float:
    alpha = frame.getchannel("A")
    visible = sum(1 for value in alpha.tobytes() if value > 16)
    return round(visible / (FRAME_SIZE * FRAME_SIZE), 4)


def _visible_bounds(frame: Image.Image) -> tuple[int, int, int, int]:
    mask = frame.getchannel("A").point(lambda value: 255 if value > 16 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("Generated frame contains no visible pixels")
    return bounds


def _align_frames(frames: list[Image.Image]) -> list[Image.Image]:
    bounds = [_visible_bounds(frame) for frame in frames]
    max_height = max(bottom - top for _, top, _, bottom in bounds)
    max_width = max(right - left for left, _, right, _ in bounds)
    scale = min(
        TARGET_VISIBLE_HEIGHT / max_height,
        MAX_VISIBLE_WIDTH / max_width,
    )

    aligned: list[Image.Image] = []
    for frame, (left, top, right, bottom) in zip(frames, bounds, strict=True):
        subject = frame.crop((left, top, right, bottom))
        width = max(1, round(subject.width * scale))
        height = max(1, round(subject.height * scale))
        subject = subject.resize((width, height), Image.Resampling.NEAREST)
        output = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        output.alpha_composite(
            subject,
            ((FRAME_SIZE - width) // 2, TARGET_BASELINE_Y - height),
        )
        aligned.append(output)
    return aligned


def normalize(source: Path, output: Path) -> list[float]:
    image = Image.open(source).convert("RGBA")
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        left = round(index * image.width / FRAME_COUNT)
        right = round((index + 1) * image.width / FRAME_COUNT)
        cell_width = right - left
        crop_size = min(cell_width, image.height)
        crop_left = left + (cell_width - crop_size) // 2
        crop_top = (image.height - crop_size) // 2
        frame = image.crop(
            (
                crop_left,
                crop_top,
                crop_left + crop_size,
                crop_top + crop_size,
            )
        )
        frame = frame.resize(
            (FRAME_SIZE, FRAME_SIZE),
            Image.Resampling.NEAREST,
        )
        frames.append(frame)

    frames = _align_frames(frames)
    strip = Image.new(
        "RGBA",
        (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE),
        (0, 0, 0, 0),
    )
    coverage: list[float] = []
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
        coverage.append(_alpha_coverage(frame))

    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)
    return coverage


def main() -> None:
    sequences: dict[str, object] = {}
    for weapon, source_name in SHEETS.items():
        output_name = f"{weapon}-idle.png"
        coverage = normalize(SOURCE_DIR / source_name, OUTPUT_DIR / output_name)
        sequences[weapon] = {
            "asset": output_name,
            "state": "idle",
            "sourceFrameSize": [FRAME_SIZE, FRAME_SIZE],
            "displaySize": [54, 54],
            "frames": FRAME_COUNT,
            "fps": 6,
            "loop": True,
            "pivot": [0.5, 0.5],
            "baseline": 0.86,
            "standingFrame": 0,
            "eventFrame": None,
            "alphaCoverage": coverage,
            "promptVersion": "art-v3-pass0-2026-08-11",
            "source": "OpenAI built-in ImageGen with Combat Motion v2 reference",
            "license": "OpenAI generated project asset",
        }
        print(f"Wrote {OUTPUT_DIR / output_name}")

    manifest = {
        "version": 1,
        "frameWidth": FRAME_SIZE,
        "frameHeight": FRAME_SIZE,
        "sequences": sequences,
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {manifest_path}")


if __name__ == "__main__":
    main()
