"""Convert ImageGen 5x4 chroma-key atlases into normalized RGBA strips."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tmp" / "imagegen"
OUTPUT = ROOT / "assets" / "images" / "sprites" / "platformer"
FRAME = 256

ROOMS = {
    "room1-alpha.png": (["patch-mite", "checksum-hopper", "pulse-turret", "repair-leech", "overflow-warden"], [0, 340, 505, 685, 943]),
    "room2-alpha.png": (["tick-runner", "echo-bat", "delay-sniper", "rewind-skater", "chrono-jailer"], [0, 300, 535, 750, 1024]),
    "room3-alpha.png": (["vector-ram", "polarity-drone", "phase-mimic", "shard-lobber", "kernel-chimera"], [0, 300, 510, 720, 939]),
}


def normalize(cell: Image.Image, boss: bool) -> Image.Image:
    alpha = cell.getchannel("A")
    bbox = alpha.getbbox()
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    if bbox is None:
        return canvas
    subject = cell.crop(bbox)
    max_width = 232 if boss else 220
    max_height = 232 if boss else 210
    scale = min(max_width / subject.width, max_height / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.NEAREST)
    x = (FRAME - subject.width) // 2
    y = 240 - subject.height
    canvas.alpha_composite(subject, (x, max(4, y)))
    return canvas


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, (names, row_bounds) in ROOMS.items():
        atlas = Image.open(SOURCE / filename).convert("RGBA")
        cell_w = atlas.width / 5
        for column, name in enumerate(names):
            strip = Image.new("RGBA", (FRAME * 4, FRAME), (0, 0, 0, 0))
            for row in range(4):
                box = (
                    round(column * cell_w),
                    row_bounds[row],
                    round((column + 1) * cell_w),
                    row_bounds[row + 1],
                )
                frame = normalize(atlas.crop(box), boss=column == 4)
                strip.alpha_composite(frame, (row * FRAME, 0))
            strip.save(OUTPUT / f"{name}.png")


if __name__ == "__main__":
    main()
