"""Convert ImageGen chroma filmstrips into aligned runtime sprite sheets."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "imagegen-animation"
OUTPUT_DIR = ROOT / "assets" / "images" / "sprites" / "animations"
FRAME_SIZE = 256
BOTTOM = 246


@dataclass(frozen=True)
class AnimationSpec:
    name: str
    source: str
    frames: int
    fps: int
    loop: bool


SPECS = (
    AnimationSpec("qa-hero-idle", "qa-hero-idle-source.png", 4, 6, True),
    AnimationSpec("qa-hero-pulse", "qa-hero-pulse-source.png", 4, 10, False),
    AnimationSpec("crawler-chase", "crawler-chase-source.png", 6, 9, True),
    AnimationSpec("crawler-overflow", "crawler-overflow-source.png", 5, 12, False),
)


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for r, g, b, _ in rgba.get_flattened_data():
        dominance = g - max(r, b)
        if g > 105 and dominance > 34:
            alpha = max(0, min(255, int((82 - dominance) * 5.3)))
            # Despill edge pixels so the chroma color cannot halo in-game.
            g = min(g, max(r, b) + 16)
        else:
            alpha = 255
        pixels.append((r, g, b, alpha))
    rgba.putdata(pixels)
    return rgba


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 20 else 0).getbbox()
    if bbox is None:
        raise ValueError("Frame contains no opaque pixels")
    return bbox


def weighted_center_x(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    total = 0
    weighted = 0
    for y in range(alpha.height):
        for x in range(alpha.width):
            value = alpha.getpixel((x, y))
            total += value
            weighted += x * value
    return weighted / total if total else image.width / 2


def split_frames(source: Image.Image, count: int) -> list[Image.Image]:
    frames = []
    for index in range(count):
        left = round(index * source.width / count)
        right = round((index + 1) * source.width / count)
        frames.append(source.crop((left, 0, right, source.height)))
    return frames


def process(spec: AnimationSpec) -> dict[str, object]:
    source = remove_green(Image.open(SOURCE_DIR / spec.source))
    raw_frames = split_frames(source, spec.frames)
    crops = [frame.crop(alpha_bbox(frame)) for frame in raw_frames]
    max_width = max(frame.width for frame in crops)
    max_height = max(frame.height for frame in crops)
    scale = min(228 / max_width, 228 / max_height)

    normalized = []
    centers = []
    baselines = []
    coverages = []
    for crop in crops:
        resized = crop.resize(
            (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
            Image.Resampling.NEAREST,
        )
        center_x = weighted_center_x(resized)
        x = round(FRAME_SIZE / 2 - center_x)
        y = BOTTOM - resized.height
        frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        frame.alpha_composite(resized, (x, y))
        normalized.append(frame)
        bbox = alpha_bbox(frame)
        centers.append(round(weighted_center_x(frame), 2))
        baselines.append(bbox[3])
        alpha_values = frame.getchannel("A").get_flattened_data()
        coverages.append(round(sum(alpha_values) / 255 / (FRAME_SIZE**2), 4))

    sheet = Image.new("RGBA", (FRAME_SIZE * spec.frames, FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT_DIR / f"{spec.name}.png", optimize=True)

    return {
        "asset": f"images/sprites/animations/{spec.name}.png",
        "frames": spec.frames,
        "fps": spec.fps,
        "loop": spec.loop,
        "frameSize": [FRAME_SIZE, FRAME_SIZE],
        "pivot": [0.5, round(BOTTOM / FRAME_SIZE, 4)],
        "validation": {
            "centroidX": centers,
            "baseline": baselines,
            "alphaCoverage": coverages,
            "transparentCorners": all(frame.getpixel((0, 0))[3] == 0 for frame in normalized),
        },
    }


def main() -> None:
    manifest = {spec.name: process(spec) for spec in SPECS}
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
