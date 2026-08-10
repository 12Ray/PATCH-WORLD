"""Normalize generated six-frame hero ability strips for Flame.

Generated source sheets are 2172x724 (six 362x724 cells). The useful animation
area is the centered 362x362 square in every cell. This script crops that area,
keeps nearest-neighbour pixel edges, and writes six 256x256 frames in one row.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tmp" / "imagegen"
OUTPUT_DIR = ROOT / "assets" / "images" / "sprites" / "abilities"

SHEETS = {
    "gauntlet-spin-alpha.png": "gauntlet-double-jump-spin.png",
    "sword-dash-alpha.png": "sword-dash.png",
    "gun-rail-alpha.png": "gun-charged-rail.png",
}


def normalize(source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGBA")
    frame_width = image.width // 6
    if image.width % 6 or image.height < frame_width:
        raise ValueError(f"Unexpected six-frame sheet dimensions: {image.size}")

    crop_top = (image.height - frame_width) // 2
    strip = Image.new("RGBA", (256 * 6, 256), (0, 0, 0, 0))
    for index in range(6):
        left = index * frame_width
        frame = image.crop(
            (left, crop_top, left + frame_width, crop_top + frame_width)
        )
        frame = frame.resize((256, 256), Image.Resampling.NEAREST)
        strip.alpha_composite(frame, (index * 256, 0))

    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)


def main() -> None:
    for source_name, output_name in SHEETS.items():
        normalize(SOURCE_DIR / source_name, OUTPUT_DIR / output_name)
        print(f"Wrote {OUTPUT_DIR / output_name}")


if __name__ == "__main__":
    main()
