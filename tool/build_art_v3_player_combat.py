"""Export Art v3 Pass 2 player combat sheets for Flame.

The approved ImageGen sources contain one four-frame action per row. Combo
sheets are 4x6 (attack 1..6) and defense sheets are 4x4 (parry, perfect
parry, counter, ability transition). Chroma removal runs before this script.

The source grids contain authored VFX, so their full alpha bounds are not a
safe character pivot. Runtime registration is derived from the dark suit/root
pixels instead: every grounded pose shares the equipped idle root and foot
baseline while the finisher's explicit airborne arc remains authored data.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from build_art_v3_player_sheets import (
    FRAME_SIZE,
    OUTPUT_DIR,
    SOURCE_DIR,
    _alpha_coverage,
)
from player_art_registration import (
    BodyLandmark,
    IdleBodyReference,
    detect_body_landmark,
    idle_body_reference,
    normalized_body_scale,
)


COMBO_COLUMNS = 4
COMBO_ROWS = 6
DEFENSE_COLUMNS = 4
DEFENSE_ROWS = 4

COMBO_SOURCES = {
    "sword": "art-v3-sword-combo-alpha.png",
    "gauntlet": "art-v3-gauntlet-combo-alpha.png",
    "gun": "art-v3-gun-combo-alpha.png",
}

DEFENSE_SOURCES = {
    "sword": "art-v3-sword-defense-alpha.png",
    "gauntlet": "art-v3-gauntlet-defense-alpha.png",
    "gun": "art-v3-gun-defense-alpha.png",
}

ATTACK_FPS = {
    "sword": 14.285714,
    "gauntlet": 11.111111,
    "gun": 12.5,
}

DISPLAY_SIZE = 46
SOURCE_BASELINE = 240 / FRAME_SIZE
MIN_BODY_SCALE = 1.15
MAX_BODY_SCALE = 2.4
REGISTRATION_VERSION = "art-v3-body-component-v2-2026-08-23"
SCALE_POLICY = "idle-body-area-v1"
AIRBORNE_MOTION_Y = {
    ("sword", "attack6"): (-6.0, -11.0, -6.0, 0.0),
}


@dataclass(frozen=True)
class ActionSpec:
    key: str
    source_row: int
    fps: float
    active_end: int
    source_kind: str


def _actions(weapon: str) -> tuple[ActionSpec, ...]:
    attack_fps = ATTACK_FPS[weapon]
    attacks = tuple(
        ActionSpec(
            key=f"attack{index + 1}",
            source_row=index,
            fps=attack_fps,
            active_end=(1 if weapon == "sword" or (weapon == "gauntlet" and index == 5) else 0),
            source_kind="combo",
        )
        for index in range(COMBO_ROWS)
    )
    return attacks + (
        ActionSpec("parry", 0, 12, 1, "defense"),
        ActionSpec("perfectParry", 1, 18, 0, "defense"),
        ActionSpec("counter", 2, 16, 0 if weapon == "gun" else 2, "defense"),
        ActionSpec(
            "abilityTransition",
            3,
            {"sword": 20, "gauntlet": 16.5, "gun": 14}[weapon],
            0,
            "defense",
        ),
    )


def _extract_grid(source: Path, columns: int, rows: int) -> list[list[Image.Image]]:
    image = Image.open(source).convert("RGBA")
    result: list[list[Image.Image]] = []
    for row in range(rows):
        top = round(row * image.height / rows)
        bottom = round((row + 1) * image.height / rows)
        row_frames: list[Image.Image] = []
        for column in range(columns):
            left = round(column * image.width / columns)
            right = round((column + 1) * image.width / columns)
            width = right - left
            height = bottom - top
            crop_size = min(width, height)
            crop_left = left + (width - crop_size) // 2
            crop_top = top + (height - crop_size) // 2
            frame = image.crop(
                (
                    crop_left,
                    crop_top,
                    crop_left + crop_size,
                    crop_top + crop_size,
                )
            ).resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)
            if frame.getchannel("A").getbbox() is None:
                raise ValueError(f"Empty source cell at row={row}, column={column}: {source}")
            row_frames.append(frame)
        result.append(row_frames)
    return result


def _write_strip(frames: list[Image.Image], output: Path) -> list[float]:
    strip = Image.new(
        "RGBA",
        (FRAME_SIZE * len(frames), FRAME_SIZE),
        (0, 0, 0, 0),
    )
    coverage: list[float] = []
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
        coverage.append(_alpha_coverage(frame))
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output, optimize=True)
    return coverage


def _idle_reference(weapon: str) -> IdleBodyReference:
    strip = Image.open(OUTPUT_DIR / f"{weapon}-idle.png").convert("RGBA")
    return idle_body_reference(strip, frame_size=FRAME_SIZE)


def _frame_registration(
    *,
    weapon: str,
    action: ActionSpec,
    frames: list[Image.Image],
    idle_reference: IdleBodyReference,
) -> tuple[
    list[dict[str, float]],
    list[dict[str, int]],
    list[list[int]],
    list[int],
]:
    source_to_world = DISPLAY_SIZE / FRAME_SIZE
    target_x = (idle_reference.root_x - FRAME_SIZE / 2) * source_to_world
    target_y = (idle_reference.foot_y - FRAME_SIZE / 2) * source_to_world
    authored_y = AIRBORNE_MOTION_Y.get(
        (weapon, action.key),
        (0.0,) * len(frames),
    )
    transforms: list[dict[str, float]] = []
    roots: list[dict[str, int]] = []
    bounds: list[list[int]] = []
    pixel_counts: list[int] = []
    for frame, motion_y in zip(frames, authored_y, strict=True):
        landmark: BodyLandmark = detect_body_landmark(frame)
        scale = normalized_body_scale(idle_reference, landmark)
        if not MIN_BODY_SCALE <= scale <= MAX_BODY_SCALE:
            raise ValueError(
                f"{weapon}.{action.key} body scale {scale:.3f} is outside "
                f"the supported range {MIN_BODY_SCALE}..{MAX_BODY_SCALE}"
            )
        transforms.append(
            {
                "dx": round(
                    target_x
                    - (landmark.root_x - FRAME_SIZE / 2)
                    * source_to_world
                    * scale,
                    3,
                ),
                "dy": round(
                    target_y
                    - (landmark.foot_y - FRAME_SIZE / 2)
                    * source_to_world
                    * scale
                    + motion_y,
                    3,
                ),
                "scale": round(scale, 4),
            }
        )
        roots.append({"x": landmark.root_x, "y": landmark.foot_y})
        bounds.append(list(landmark.bounds))
        pixel_counts.append(landmark.pixel_count)
    return transforms, roots, bounds, pixel_counts


def _asset_suffix(key: str) -> str:
    return {
        "perfectParry": "perfect-parry",
        "abilityTransition": "ability-transition",
    }.get(key, key.replace("attack", "attack-"))


def _manifest_entry(
    *,
    weapon: str,
    action: ActionSpec,
    asset: str,
    coverage: list[float],
    frame_transforms: list[dict[str, float]],
    body_roots: list[dict[str, int]],
    body_bounds: list[list[int]],
    body_pixel_counts: list[int],
    reference_body_pixels: int,
) -> dict[str, object]:
    grid = (
        [COMBO_COLUMNS, COMBO_ROWS]
        if action.source_kind == "combo"
        else [DEFENSE_COLUMNS, DEFENSE_ROWS]
    )
    event_frame = (
        1 if action.key.startswith("attack") or action.key == "counter" else 0
    )
    return {
        "asset": asset,
        "state": action.key,
        "sourceFrameSize": [FRAME_SIZE, FRAME_SIZE],
        "displaySize": [DISPLAY_SIZE, DISPLAY_SIZE],
        "frames": 4,
        "fps": action.fps,
        "loop": False,
        "pivot": [0.5, 0.5],
        "baseline": SOURCE_BASELINE,
        "eventFrame": event_frame,
        "activeFrame": [0, max(action.active_end, event_frame)],
        "presentationScale": round(
            sum(transform["scale"] for transform in frame_transforms)
            / len(frame_transforms),
            4,
        ),
        "frameTransforms": frame_transforms,
        "bodyRoots": body_roots,
        "bodyBounds": body_bounds,
        "bodyPixelCounts": body_pixel_counts,
        "referenceBodyPixels": reference_body_pixels,
        "scalePolicy": SCALE_POLICY,
        "registrationVersion": REGISTRATION_VERSION,
        "alphaCoverage": coverage,
        "sourceGrid": grid,
        "sourceIndices": list(
            range(action.source_row * 4, action.source_row * 4 + 4)
        ),
        "promptVersion": "art-v3-pass2-2026-08-11",
        "source": "OpenAI built-in ImageGen with approved Pass 1 identity, Combat Motion v2, and ability references",
        "license": "OpenAI generated project asset",
        "timingContract": "visual contact and gameplay event share eventFrame; playback duration is derived from the effective attack interval",
    }


def main() -> None:
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    combat: dict[str, object] = {}

    for weapon in COMBO_SOURCES:
        idle_reference = _idle_reference(weapon)
        combo_rows = _extract_grid(
            SOURCE_DIR / COMBO_SOURCES[weapon],
            COMBO_COLUMNS,
            COMBO_ROWS,
        )
        defense_rows = _extract_grid(
            SOURCE_DIR / DEFENSE_SOURCES[weapon],
            DEFENSE_COLUMNS,
            DEFENSE_ROWS,
        )
        weapon_actions: dict[str, object] = {}
        for action in _actions(weapon):
            frames = (
                combo_rows[action.source_row]
                if action.source_kind == "combo"
                else defense_rows[action.source_row]
            )
            asset = f"{weapon}-{_asset_suffix(action.key)}.png"
            coverage = _write_strip(frames, OUTPUT_DIR / asset)
            (
                frame_transforms,
                body_roots,
                body_bounds,
                body_pixel_counts,
            ) = _frame_registration(
                weapon=weapon,
                action=action,
                frames=frames,
                idle_reference=idle_reference,
            )
            weapon_actions[action.key] = _manifest_entry(
                weapon=weapon,
                action=action,
                asset=asset,
                coverage=coverage,
                frame_transforms=frame_transforms,
                body_roots=body_roots,
                body_bounds=body_bounds,
                body_pixel_counts=body_pixel_counts,
                reference_body_pixels=idle_reference.pixel_count,
            )
            print(f"Wrote {OUTPUT_DIR / asset}")
        combat[weapon] = weapon_actions

    manifest["version"] = 3
    manifest["combat"] = combat
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {manifest_path}")


if __name__ == "__main__":
    main()
