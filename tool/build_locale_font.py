"""Build the minimal CJK font shipped with PATCH//WORLD.

Requires the development-only ``fonttools`` package and a local copy of the
SIL-OFL Noto Sans CJK KR Regular source font. The source font itself is not
committed; only the glyph subset used by the game is shipped.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont


def _collect_text(project_root: Path) -> str:
    characters = set(chr(codepoint) for codepoint in range(0x20, 0x7F))
    for locale_path in sorted(
        (project_root / "assets" / "localization").glob("*.json")
    ):
        payload = json.loads(locale_path.read_text(encoding="utf-8"))
        for value in payload.values():
            characters.update(value)

    for dart_path in sorted((project_root / "lib").rglob("*.dart")):
        characters.update(dart_path.read_text(encoding="utf-8"))

    # Common punctuation and input glyphs used in generated/debug labels.
    characters.update("→←↑↓×∞•·—–…//PATCHWORLD0123456789")
    return "".join(sorted(characters))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_font", type=Path)
    parser.add_argument("output_font", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.name_legacy = True
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.glyph_names = True

    font = TTFont(args.source_font, recalcBBoxes=False, recalcTimestamp=False)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=_collect_text(args.project_root.resolve()))
    subsetter.subset(font)

    args.output_font.parent.mkdir(parents=True, exist_ok=True)
    font.save(args.output_font, reorderTables=False)
    print(f"Wrote {args.output_font} ({args.output_font.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
