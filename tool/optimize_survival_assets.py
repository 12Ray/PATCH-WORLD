"""Create size-efficient WebP runtime copies of PATCH//SURVIVE production art."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPRITE_ROOT = ROOT / "assets/images/sprites/survival_v1"

SPRITES = (
    SPRITE_ROOT / "enemies/rift-stalker.png",
    SPRITE_ROOT / "enemies/arc-warden.png",
    SPRITE_ROOT / "enemies/mine-layer.png",
    SPRITE_ROOT / "bosses/foundry-overseer.png",
    SPRITE_ROOT / "bosses/temporal-regent.png",
    SPRITE_ROOT / "bosses/collision-behemoth.png",
    SPRITE_ROOT / "bosses/nexus-core.png",
)


def convert(source: Path, *, quality: int) -> None:
    destination = source.with_suffix(".webp")
    with Image.open(source) as image:
        image.convert("RGBA").save(
            destination,
            "WEBP",
            quality=quality,
            method=6,
            exact=True,
        )
    print(
        f"{source.relative_to(ROOT)} -> {destination.relative_to(ROOT)} "
        f"{source.stat().st_size / 1024:.1f} KiB -> "
        f"{destination.stat().st_size / 1024:.1f} KiB"
    )


def main() -> None:
    for sprite in SPRITES:
        convert(sprite, quality=92)


if __name__ == "__main__":
    main()
