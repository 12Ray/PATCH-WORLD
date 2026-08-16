"""Pack a 4x2 transparent concept grid into Flame's 8x1 sprite strip."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


FRAME_SIZE = 256
FRAME_COUNT = 8
CONTENT_LIMIT = 224


def _content_box(frame: Image.Image) -> tuple[int, int, int, int]:
    alpha = frame.getchannel("A")
    meaningful_alpha = alpha.point(lambda value: 255 if value >= 8 else 0)
    box = meaningful_alpha.getbbox()
    if box is None:
        raise ValueError("Sprite grid contains an empty frame")
    return box


def pack_grid(source: Path, destination: Path, anchor: str) -> None:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    if image.width % 4 or image.height % 2:
        raise ValueError("Source dimensions must divide evenly into a 4x2 grid")

    cell_width = image.width // 4
    cell_height = image.height // 2
    cropped_frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        column = index % 4
        row = index // 4
        cell = image.crop(
            (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
        )
        cropped_frames.append(cell.crop(_content_box(cell)))

    maximum_width = max(frame.width for frame in cropped_frames)
    maximum_height = max(frame.height for frame in cropped_frames)
    scale = min(CONTENT_LIMIT / maximum_width, CONTENT_LIMIT / maximum_height)
    strip = Image.new("RGBA", (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE))

    for index, frame in enumerate(cropped_frames):
        width = max(1, round(frame.width * scale))
        height = max(1, round(frame.height * scale))
        resized = frame.resize((width, height), Image.Resampling.LANCZOS)
        x = index * FRAME_SIZE + (FRAME_SIZE - width) // 2
        y = (
            (FRAME_SIZE - height) // 2
            if anchor == "center"
            else FRAME_SIZE - 8 - height
        )
        strip.alpha_composite(resized, (x, y))

    destination.parent.mkdir(parents=True, exist_ok=True)
    strip.save(destination, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--anchor", choices=("bottom", "center"), default="bottom")
    arguments = parser.parse_args()
    pack_grid(arguments.input, arguments.output, arguments.anchor)


if __name__ == "__main__":
    main()
