#!/usr/bin/env python3
"""Build the engine-ready Phase Hound strip from a matted AI filmstrip."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


FRAME_COUNT = 6
FRAME_SIZE = 256
BASELINE = 246
MAX_CONTENT_WIDTH = 216
MAX_CONTENT_HEIGHT = 220
ALPHA_THRESHOLD = 8


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("frame has no visible pixels")
    return bbox


def alpha_centroid_x(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    weighted_x = 0
    total_alpha = 0
    for y in range(image.height):
        for x in range(image.width):
            value = alpha.getpixel((x, y))
            if value <= ALPHA_THRESHOLD:
                continue
            weighted_x += x * value
            total_alpha += value
    if total_alpha == 0:
        raise ValueError("frame has no visible pixels")
    return weighted_x / total_alpha


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    if source.width % FRAME_COUNT != 0:
        raise ValueError(f"source width {source.width} is not divisible by {FRAME_COUNT}")

    cell_width = source.width // FRAME_COUNT
    poses: list[Image.Image] = []
    bounds: list[tuple[int, int, int, int]] = []
    for index in range(FRAME_COUNT):
        cell = source.crop((index * cell_width, 0, (index + 1) * cell_width, source.height))
        bbox = alpha_bbox(cell)
        poses.append(cell.crop(bbox))
        bounds.append(bbox)

    max_width = max(pose.width for pose in poses)
    max_height = max(pose.height for pose in poses)
    shared_scale = min(MAX_CONTENT_WIDTH / max_width, MAX_CONTENT_HEIGHT / max_height)

    sheet = Image.new("RGBA", (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE), (0, 0, 0, 0))
    centroids: list[float] = []
    baselines: list[int] = []
    coverage: list[float] = []

    for index, pose in enumerate(poses):
        target_size = (
            max(1, round(pose.width * shared_scale)),
            max(1, round(pose.height * shared_scale)),
        )
        resized = pose.resize(target_size, Image.Resampling.NEAREST)
        local_centroid = alpha_centroid_x(resized)
        x = round(FRAME_SIZE / 2 - local_centroid)
        y = BASELINE + 1 - resized.height
        frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        frame.alpha_composite(resized, (x, y))
        correction_x = round(FRAME_SIZE / 2 - alpha_centroid_x(frame))
        if correction_x:
            corrected = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
            corrected.alpha_composite(frame, (correction_x, 0))
            frame = corrected
        frame_bbox = alpha_bbox(frame)
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))

        centroids.append(round(alpha_centroid_x(frame), 2))
        baselines.append(frame_bbox[3] - 1)
        visible = sum(frame.getchannel("A").histogram()[ALPHA_THRESHOLD + 1 :])
        coverage.append(round(visible / (FRAME_SIZE * FRAME_SIZE), 4))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    report = {
        "sourceSize": [source.width, source.height],
        "sourceCellBounds": [list(bbox) for bbox in bounds],
        "sharedScale": round(shared_scale, 6),
        "centroidX": centroids,
        "baseline": baselines,
        "alphaCoverage": coverage,
        "transparentCorners": all(
            sheet.getpixel(point)[3] == 0
            for point in [(0, 0), (sheet.width - 1, 0), (0, sheet.height - 1), (sheet.width - 1, sheet.height - 1)]
        ),
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
