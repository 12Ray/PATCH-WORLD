"""Build deterministic runtime strips from the combat-motion-v2 concept grids."""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "visual-concepts" / "combat-motion-v2"
OUTPUT = ROOT / "assets" / "images" / "sprites" / "combat_v2"
CHARACTER_FRAME = 256
PROJECTILE_FRAME = 128


def slug(value: str) -> str:
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", value).lower()


def crop_cell(image: Image.Image, column: int, row: int, columns: int, rows: int) -> Image.Image:
    left = round(image.width * column / columns)
    top = round(image.height * row / rows)
    right = round(image.width * (column + 1) / columns)
    bottom = round(image.height * (row + 1) / rows)
    return image.crop((left, top, right, bottom))


def normalize_character(cell: Image.Image) -> Image.Image:
    alpha = cell.getchannel("A")
    bbox = alpha.getbbox()
    canvas = Image.new("RGBA", (CHARACTER_FRAME, CHARACTER_FRAME), (0, 0, 0, 0))
    if bbox is None:
        return canvas
    subject = cell.crop(bbox)
    scale = min(236 / subject.width, 228 / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.NEAREST)
    x = (CHARACTER_FRAME - subject.width) // 2
    y = max(4, 240 - subject.height)
    canvas.alpha_composite(subject, (x, y))
    return canvas


def normalize_projectile(cell: Image.Image) -> Image.Image:
    alpha = cell.getchannel("A")
    bbox = alpha.getbbox()
    canvas = Image.new("RGBA", (PROJECTILE_FRAME, PROJECTILE_FRAME), (0, 0, 0, 0))
    if bbox is None:
        return canvas
    subject = cell.crop(bbox)
    scale = min(116 / subject.width, 104 / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.NEAREST)
    x = (PROJECTILE_FRAME - subject.width) // 2
    y = (PROJECTILE_FRAME - subject.height) // 2
    canvas.alpha_composite(subject, (x, y))
    return canvas


def build_character_strip(source: Path, columns: int, rows: int) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    frames = [
        normalize_character(crop_cell(image, index % columns, index // columns, columns, rows))
        for index in range(columns * rows)
    ]
    strip = Image.new(
        "RGBA",
        (CHARACTER_FRAME * len(frames), CHARACTER_FRAME),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CHARACTER_FRAME, 0))
    return strip


def build_projectile_strip(source: Path, row: int, columns: int, rows: int) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    strip = Image.new(
        "RGBA",
        (PROJECTILE_FRAME * columns, PROJECTILE_FRAME),
        (0, 0, 0, 0),
    )
    for column in range(columns):
        frame = normalize_projectile(crop_cell(image, column, row, columns, rows))
        strip.alpha_composite(frame, (column * PROJECTILE_FRAME, 0))
    return strip


def main() -> None:
    source_manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    runtime_manifest = {
        "characterFrameSize": [CHARACTER_FRAME, CHARACTER_FRAME],
        "projectileFrameSize": [PROJECTILE_FRAME, PROJECTILE_FRAME],
        "attackTiers": ["normal", "enhanced", "parryable"],
        "enemies": {},
        "hero": {},
        "projectiles": {},
    }

    for entry in source_manifest["enemySheets"]:
        output = OUTPUT / "enemies" / f"{slug(entry['id'])}.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        build_character_strip(SOURCE / entry["file"], *entry["grid"]).save(output)
        runtime_manifest["enemies"][entry["id"]] = {
            "asset": output.relative_to(OUTPUT).as_posix(),
            "motions": entry["motions"],
        }

    for entry in source_manifest["heroSheets"]:
        output = OUTPUT / "hero" / f"{entry['weapon']}.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        build_character_strip(SOURCE / entry["file"], *entry["grid"]).save(output)
        runtime_manifest["hero"][entry["weapon"]] = {
            "asset": output.relative_to(OUTPUT).as_posix(),
            "motions": entry["motions"],
        }

    for sheet in source_manifest["projectileSheets"]:
        columns, rows = sheet["grid"]
        for row, enemy_id in enumerate(sheet["rows"]):
            output = OUTPUT / "projectiles" / f"{slug(enemy_id)}.png"
            output.parent.mkdir(parents=True, exist_ok=True)
            build_projectile_strip(SOURCE / sheet["file"], row, columns, rows).save(output)
            runtime_manifest["projectiles"][enemy_id] = {
                "asset": output.relative_to(OUTPUT).as_posix(),
                "tiers": sheet["columns"],
            }

    (OUTPUT / "manifest.json").write_text(
        json.dumps(runtime_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
