"""Normalize and register generated six-frame hero ability strips for Flame.

Generated source sheets are 2172x724 (six 362x724 cells). The useful animation
area is the centered 362x362 square in every cell. This script crops that area,
keeps nearest-neighbour pixel edges, and writes six 256x256 frames in one row.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from build_art_v3_player_sheets import DISPLAY_SIZE, FRAME_SIZE, SOURCE_BASELINE
from player_art_registration import (
    BodyLandmark,
    IdleBodyReference,
    detect_body_landmark,
    idle_body_reference,
    normalized_body_scale,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "imagegen"
OUTPUT_DIR = ROOT / "assets" / "images" / "sprites" / "abilities"
HERO_DIR = ROOT / "assets" / "images" / "sprites" / "art_v3" / "hero"
FRAME_COUNT = 6
REGISTRATION_VERSION = "art-v3-ability-root-v1-2026-08-23"

SHEETS = {
    "sword": ("sword-dash-alpha.png", "sword-dash.png", "grounded-root"),
    "gauntlet": (
        "gauntlet-spin-alpha.png",
        "gauntlet-double-jump-spin.png",
        "airborne-center",
    ),
    "gun": ("gun-rail-alpha.png", "gun-charged-rail.png", "grounded-root"),
}


def normalize(source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGBA")
    frame_width = image.width // FRAME_COUNT
    if image.width % FRAME_COUNT or image.height < frame_width:
        raise ValueError(f"Unexpected six-frame sheet dimensions: {image.size}")

    crop_top = (image.height - frame_width) // 2
    strip = Image.new(
        "RGBA",
        (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE),
        (0, 0, 0, 0),
    )
    for index in range(FRAME_COUNT):
        left = index * frame_width
        frame = image.crop(
            (left, crop_top, left + frame_width, crop_top + frame_width)
        )
        frame = frame.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))

    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)


def _strip_frames(strip: Image.Image) -> list[Image.Image]:
    return [
        strip.crop(
            (
                index * FRAME_SIZE,
                0,
                (index + 1) * FRAME_SIZE,
                FRAME_SIZE,
            )
        )
        for index in range(FRAME_COUNT)
    ]


def _landmark_dict(landmark: BodyLandmark) -> dict[str, object]:
    return {
        "center": [landmark.center_x, landmark.center_y],
        "root": [landmark.root_x, landmark.foot_y],
        "bounds": list(landmark.bounds),
        "pixelCount": landmark.pixel_count,
    }


def _reference_dict(reference: IdleBodyReference) -> dict[str, object]:
    return {
        "center": [reference.center_x, reference.center_y],
        "root": [reference.root_x, reference.foot_y],
        "pixelCount": reference.pixel_count,
    }


def _registered_entry(
    *,
    weapon: str,
    asset: str,
    registration_mode: str,
) -> dict[str, object]:
    strip = Image.open(OUTPUT_DIR / asset).convert("RGBA")
    idle_strip = Image.open(HERO_DIR / f"{weapon}-idle.png").convert("RGBA")
    reference = idle_body_reference(idle_strip, frame_size=FRAME_SIZE)
    landmarks = [detect_body_landmark(frame) for frame in _strip_frames(strip)]
    source_to_world = DISPLAY_SIZE / FRAME_SIZE
    transforms: list[dict[str, float]] = []
    for landmark in landmarks:
        scale = normalized_body_scale(reference, landmark)
        if registration_mode == "airborne-center":
            source_x = landmark.center_x
            source_y = landmark.center_y
            target_x = reference.center_x
            target_y = reference.center_y
        else:
            source_x = landmark.root_x
            source_y = landmark.foot_y
            target_x = reference.root_x
            target_y = reference.foot_y
        transforms.append(
            {
                "dx": round(
                    (target_x - FRAME_SIZE / 2) * source_to_world
                    - (source_x - FRAME_SIZE / 2) * source_to_world * scale,
                    3,
                ),
                "dy": round(
                    (target_y - FRAME_SIZE / 2) * source_to_world
                    - (source_y - FRAME_SIZE / 2) * source_to_world * scale,
                    3,
                ),
                "scale": round(scale, 6),
            }
        )
    return {
        "asset": asset,
        "state": "ability",
        "sourceFrameSize": [FRAME_SIZE, FRAME_SIZE],
        "displaySize": [DISPLAY_SIZE, DISPLAY_SIZE],
        "frames": FRAME_COUNT,
        "pivot": [0.5, 0.5],
        "baseline": SOURCE_BASELINE,
        "registrationMode": registration_mode,
        "frameTransforms": transforms,
        "bodyLandmarks": [_landmark_dict(landmark) for landmark in landmarks],
        "idleBodyReference": _reference_dict(reference),
        "registrationVersion": REGISTRATION_VERSION,
        "source": "OpenAI built-in ImageGen approved ability reference",
        "license": "OpenAI generated project asset",
    }


def main() -> None:
    for source_name, output_name, _ in SHEETS.values():
        normalize(SOURCE_DIR / source_name, OUTPUT_DIR / output_name)
        print(f"Wrote {OUTPUT_DIR / output_name}")

    manifest_path = HERO_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["abilities"] = {
        weapon: _registered_entry(
            weapon=weapon,
            asset=asset,
            registration_mode=registration_mode,
        )
        for weapon, (_, asset, registration_mode) in SHEETS.items()
    }
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {manifest_path}")


if __name__ == "__main__":
    main()
