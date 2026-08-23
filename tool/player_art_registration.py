"""VFX-resistant body landmarks for generated player sprite sheets.

The Art v3 combat and ability sources contain detached cell fragments, attack
trails, muzzle flashes, and after-images.  Full alpha bounds therefore cannot
be used to register or size the character.  This module identifies the dense,
central dark-suit component and exposes landmarks that generators can compare
with the equipped idle strip.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from PIL import Image


ALPHA_THRESHOLD = 64
DARK_LUMA_THRESHOLD = 135
CYAN_GREEN_MARGIN = 18
DENSE_NEIGHBOR_COUNT = 6
MIN_COMPONENT_PIXELS = 64


@dataclass(frozen=True)
class BodyLandmark:
    """Robust source-pixel landmarks for one sprite frame.

    ``bounds`` follows the Pillow convention: left/top are inclusive and
    right/bottom are exclusive.  The bounds are 1st/99th-percentile bounds of
    the selected component, which avoids single-pixel outline noise.
    """

    center_x: int
    center_y: int
    root_x: int
    foot_y: int
    bounds: tuple[int, int, int, int]
    pixel_count: int


@dataclass(frozen=True)
class IdleBodyReference:
    """Median body landmarks across an equipped idle strip."""

    center_x: int
    center_y: int
    root_x: int
    foot_y: int
    pixel_count: int


def _quantile(values: list[int], fraction: float) -> int:
    if not values:
        raise ValueError("Cannot calculate a body landmark without pixels")
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * fraction)]


def _body_candidate_mask(frame: Image.Image) -> set[tuple[int, int]]:
    """Return dense dark-suit pixels while rejecting chromatic combat VFX.

    Cyan trails and after-images can be darker than a simple luma threshold.
    Their green channel is nevertheless dominant, unlike the neutral/purple
    suit.  A local-density pass then removes thin VFX outlines and sparks.
    """

    rgba = frame.convert("RGBA")
    pixels = rgba.load()
    raw: set[tuple[int, int]] = set()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha > ALPHA_THRESHOLD
                and (red + green + blue) / 3 < DARK_LUMA_THRESHOLD
                and green <= red + CYAN_GREEN_MARGIN
            ):
                raw.add((x, y))

    dense: set[tuple[int, int]] = set()
    for x, y in raw:
        neighbors = 0
        for neighbor_y in range(max(0, y - 1), min(rgba.height - 1, y + 1) + 1):
            for neighbor_x in range(
                max(0, x - 1),
                min(rgba.width - 1, x + 1) + 1,
            ):
                if (neighbor_x, neighbor_y) in raw:
                    neighbors += 1
        if neighbors >= DENSE_NEIGHBOR_COUNT:
            dense.add((x, y))
    return dense


def _connected_components(
    mask: set[tuple[int, int]],
    *,
    width: int,
    height: int,
) -> list[list[tuple[int, int]]]:
    remaining = set(mask)
    components: list[list[tuple[int, int]]] = []
    while remaining:
        start = remaining.pop()
        pending = [start]
        component = [start]
        for x, y in pending:
            for neighbor_y in range(max(0, y - 1), min(height - 1, y + 1) + 1):
                for neighbor_x in range(
                    max(0, x - 1),
                    min(width - 1, x + 1) + 1,
                ):
                    neighbor = (neighbor_x, neighbor_y)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        pending.append(neighbor)
                        component.append(neighbor)
        if len(component) >= MIN_COMPONENT_PIXELS:
            components.append(component)
    return components


def _central_component(
    components: list[list[tuple[int, int]]],
    *,
    width: int,
    height: int,
) -> list[tuple[int, int]]:
    if not components:
        raise ValueError("Sprite frame does not contain a detectable body component")

    center_x = width / 2
    center_y = height * 0.515

    def score(component: list[tuple[int, int]]) -> float:
        component_x = sum(x for x, _ in component) / len(component)
        component_y = sum(y for _, y in component) / len(component)
        distance = ((component_x - center_x) / width) ** 2 + (
            (component_y - center_y) / height
        ) ** 2
        return len(component) / (1 + 0.35 * distance)

    return max(components, key=score)


def detect_body_landmark(frame: Image.Image) -> BodyLandmark:
    """Detect the character component independently of detached/bright VFX."""

    rgba = frame.convert("RGBA")
    component = _central_component(
        _connected_components(
            _body_candidate_mask(rgba),
            width=rgba.width,
            height=rgba.height,
        ),
        width=rgba.width,
        height=rgba.height,
    )
    xs = [x for x, _ in component]
    ys = [y for _, y in component]
    lower_cut = _quantile(ys, 0.82)
    lower_xs = [x for x, y in component if y >= lower_cut]
    return BodyLandmark(
        center_x=_quantile(xs, 0.5),
        center_y=_quantile(ys, 0.5),
        root_x=_quantile(lower_xs, 0.5),
        foot_y=_quantile(ys, 0.99),
        bounds=(
            _quantile(xs, 0.01),
            _quantile(ys, 0.01),
            _quantile(xs, 0.99) + 1,
            _quantile(ys, 0.99) + 1,
        ),
        pixel_count=len(component),
    )


def idle_body_reference(
    strip: Image.Image,
    *,
    frame_size: int,
) -> IdleBodyReference:
    """Return median landmarks from every complete frame in an idle strip."""

    if strip.width % frame_size != 0 or strip.height != frame_size:
        raise ValueError(
            f"Idle strip must contain {frame_size}x{frame_size} frames: "
            f"{strip.size}"
        )
    landmarks = [
        detect_body_landmark(
            strip.crop(
                (
                    index * frame_size,
                    0,
                    (index + 1) * frame_size,
                    frame_size,
                )
            )
        )
        for index in range(strip.width // frame_size)
    ]
    return IdleBodyReference(
        center_x=_quantile([landmark.center_x for landmark in landmarks], 0.5),
        center_y=_quantile([landmark.center_y for landmark in landmarks], 0.5),
        root_x=_quantile([landmark.root_x for landmark in landmarks], 0.5),
        foot_y=_quantile([landmark.foot_y for landmark in landmarks], 0.5),
        pixel_count=_quantile(
            [landmark.pixel_count for landmark in landmarks],
            0.5,
        ),
    )


def normalized_body_scale(
    reference: IdleBodyReference,
    landmark: BodyLandmark,
) -> float:
    """Scale a frame so its detected body area matches the idle reference."""

    if reference.pixel_count <= 0 or landmark.pixel_count <= 0:
        raise ValueError("Body pixel counts must be positive")
    return math.sqrt(reference.pixel_count / landmark.pixel_count)
