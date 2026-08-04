"""Convert ImageGen chroma filmstrips into aligned runtime sprite sheets."""

from __future__ import annotations

import json
from collections import deque
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
    AnimationSpec("qa-hero-move", "qa-hero-move-source.png", 6, 10, True),
    AnimationSpec("qa-hero-pulse", "qa-hero-pulse-source.png", 4, 10, False),
    AnimationSpec("qa-hero-hurt", "qa-hero-hurt-source.png", 3, 10, False),
    AnimationSpec("crawler-chase", "crawler-chase-source.png", 6, 9, True),
    AnimationSpec("crawler-heal", "crawler-heal-source.png", 3, 8, False),
    AnimationSpec("crawler-overflow", "crawler-overflow-source.png", 5, 12, False),
    AnimationSpec("sentinel-scan", "sentinel-scan-source.png", 4, 6, True),
    AnimationSpec("sentinel-fire", "sentinel-fire-source.png", 4, 10, False),
    AnimationSpec("sentinel-cooldown", "sentinel-cooldown-source.png", 3, 8, False),
    AnimationSpec("composite-stalk", "composite-stalk-source.png", 6, 8, True),
    AnimationSpec("composite-shockwave", "composite-shockwave-source.png", 5, 10, False),
    AnimationSpec("optimizer-analyze", "optimizer-analyze-source.png", 6, 6, True),
    AnimationSpec("optimizer-predict", "optimizer-predict-source.png", 5, 10, False),
    AnimationSpec("optimizer-perfect", "optimizer-perfect-source.png", 4, 6, True),
    AnimationSpec("optimizer-overflow", "optimizer-overflow-source.png", 6, 9, False),
)


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    source = rgba.load()
    background = set()
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        r, g, b, _ = source[x, y]
        return (
            (g > 55 and g - max(r, b) > 25)
            or (r > 242 and g > 242 and b > 242)
            or (r < 10 and g < 10 and b < 10)
        )

    for x in range(rgba.width):
        queue.append((x, 0))
        queue.append((x, rgba.height - 1))
    for y in range(rgba.height):
        queue.append((0, y))
        queue.append((rgba.width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in background or not is_background(x, y):
            continue
        background.add((x, y))
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < rgba.width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < rgba.height:
            queue.append((x, y + 1))

    pixels = []
    for index, (r, g, b, _) in enumerate(rgba.get_flattened_data()):
        x = index % rgba.width
        y = index // rgba.width
        if (x, y) in background:
            pixels.append((r, g, b, 0))
            continue
        dominance = g - max(r, b)
        if g > 55 and dominance > 25:
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


def clear_panel_seams(frame: Image.Image, width: int = 16) -> Image.Image:
    """Remove generator-owned divider pixels at the edge of each panel."""
    cleaned = frame.copy()
    transparent = Image.new("RGBA", cleaned.size, (0, 0, 0, 0))
    if cleaned.width > width * 2 and cleaned.height > width * 2:
        interior = cleaned.crop(
            (width, width, cleaned.width - width, cleaned.height - width)
        )
        transparent.alpha_composite(interior, (width, width))
    return transparent


def remove_tall_dividers(frame: Image.Image) -> Image.Image:
    """Erase narrow, nearly full-height divider remnants inside a panel."""
    cleaned = frame.copy()
    suspicious = []
    for x in range(cleaned.width):
        occupied = sum(cleaned.getpixel((x, y))[3] > 20 for y in range(cleaned.height))
        if occupied > cleaned.height * 0.75:
            suspicious.append(x)
    if not suspicious:
        return cleaned
    pixels = cleaned.load()
    for divider_x in suspicious:
        for x in range(max(0, divider_x - 3), min(cleaned.width, divider_x + 4)):
            for y in range(cleaned.height):
                pixels[x, y] = (0, 0, 0, 0)
    return cleaned


def remove_long_horizontal_dividers(frame: Image.Image) -> Image.Image:
    """Erase nearly full-width panel borders left by generated filmstrips."""
    cleaned = frame.copy()
    suspicious = []
    for y in range(cleaned.height):
        seam_pixels = 0
        for x in range(cleaned.width):
            r, g, b, alpha = cleaned.getpixel((x, y))
            if alpha > 20 and g - max(r, b) > 5:
                seam_pixels += 1
        if seam_pixels > cleaned.width * 0.75:
            suspicious.append(y)
    if not suspicious:
        return cleaned
    pixels = cleaned.load()
    for divider_y in suspicious:
        for y in range(max(0, divider_y - 3), min(cleaned.height, divider_y + 4)):
            for x in range(cleaned.width):
                pixels[x, y] = (0, 0, 0, 0)
    return cleaned


def process(spec: AnimationSpec) -> dict[str, object]:
    source = Image.open(SOURCE_DIR / spec.source).convert("RGBA")
    # ImageGen sometimes draws pale dividers between filmstrip panels. Removing
    # border-connected backgrounds per panel makes those dividers reachable
    # without erasing white highlights enclosed inside the character artwork.
    raw_frames = [
        remove_long_horizontal_dividers(
            remove_tall_dividers(clear_panel_seams(remove_green(frame)))
        )
        for frame in split_frames(source, spec.frames)
    ]
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
        final_bbox = alpha_bbox(frame)
        baseline_delta = BOTTOM - final_bbox[3]
        if baseline_delta:
            aligned = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
            aligned.alpha_composite(frame, (0, baseline_delta))
            frame = aligned
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
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest = (
        json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest_path.exists()
        else {}
    )
    for spec in SPECS:
        if (SOURCE_DIR / spec.source).exists():
            manifest[spec.name] = process(spec)
        elif spec.name not in manifest:
            raise FileNotFoundError(SOURCE_DIR / spec.source)
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
