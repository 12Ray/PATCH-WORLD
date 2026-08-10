"""Generate compact original arcade SFX used by PATCHWORLD.

The sounds are synthesized from simple oscillators and deterministic noise so
the project can rebuild them without third-party samples or licensing issues.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio" / "sfx"
RATE = 22_050


def envelope(t: float, duration: float, attack: float = 0.01) -> float:
    fade_in = min(1.0, t / max(attack, 0.001))
    fade_out = max(0.0, 1.0 - t / duration)
    return fade_in * fade_out * fade_out


def write_sound(
    name: str,
    duration: float,
    sample: Callable[[float, random.Random], float],
    *,
    seed: int,
) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    frames: list[bytes] = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        value = max(-1.0, min(1.0, sample(t, rng)))
        frames.append(struct.pack("<h", int(value * 30_000)))
    with wave.open(str(OUTPUT / name), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(b"".join(frames))


def chirp(start: float, end: float, t: float, duration: float) -> float:
    frequency = start + (end - start) * (t / duration)
    return math.sin(math.tau * frequency * t)


def main() -> None:
    specs = {
        "jump.wav": (0.16, lambda t, r: chirp(210, 620, t, 0.16) * envelope(t, 0.16), 1),
        "double_jump.wav": (
            0.30,
            lambda t, r: (chirp(280, 980, t, 0.30) * 0.7 + math.sin(math.tau * 95 * t) * 0.2)
            * envelope(t, 0.30),
            2,
        ),
        "land.wav": (
            0.13,
            lambda t, r: (r.uniform(-1, 1) * 0.55 + math.sin(math.tau * 72 * t) * 0.65)
            * envelope(t, 0.13, 0.002),
            3,
        ),
        "sword_slash.wav": (
            0.22,
            lambda t, r: (chirp(1050, 180, t, 0.22) * 0.62 + r.uniform(-1, 1) * 0.18)
            * envelope(t, 0.22, 0.004),
            4,
        ),
        "sword_dash.wav": (
            0.32,
            lambda t, r: (chirp(780, 120, t, 0.32) * 0.5 + r.uniform(-1, 1) * 0.28)
            * envelope(t, 0.32, 0.005),
            5,
        ),
        "gauntlet_hit.wav": (
            0.18,
            lambda t, r: (math.sin(math.tau * 82 * t) * 0.75 + r.uniform(-1, 1) * 0.3)
            * envelope(t, 0.18, 0.002),
            6,
        ),
        "gun_shot.wav": (
            0.14,
            lambda t, r: (chirp(920, 250, t, 0.14) * 0.55 + r.uniform(-1, 1) * 0.5)
            * envelope(t, 0.14, 0.001),
            7,
        ),
        "gun_rail.wav": (
            0.42,
            lambda t, r: (chirp(1400, 180, t, 0.42) * 0.65 + math.sin(math.tau * 63 * t) * 0.3)
            * envelope(t, 0.42, 0.015),
            8,
        ),
        "platform_break.wav": (
            0.34,
            lambda t, r: (r.uniform(-1, 1) * 0.6 + math.sin(math.tau * (120 - t * 180) * t) * 0.4)
            * envelope(t, 0.34, 0.002),
            9,
        ),
        "jump_pad.wav": (
            0.24,
            lambda t, r: chirp(150, 1100, t, 0.24) * envelope(t, 0.24),
            10,
        ),
        "laser_fire.wav": (
            0.28,
            lambda t, r: (chirp(1150, 520, t, 0.28) * 0.75 + math.sin(math.tau * 92 * t) * 0.2)
            * envelope(t, 0.28, 0.006),
            11,
        ),
        "crusher_impact.wav": (
            0.30,
            lambda t, r: (math.sin(math.tau * 48 * t) * 0.85 + r.uniform(-1, 1) * 0.34)
            * envelope(t, 0.30, 0.001),
            12,
        ),
        "checkpoint.wav": (
            0.48,
            lambda t, r: (math.sin(math.tau * (440 if t < 0.16 else 660 if t < 0.32 else 880) * t) * 0.7)
            * envelope(t, 0.48, 0.008),
            13,
        ),
        "enemy_melee.wav": (
            0.20,
            lambda t, r: (chirp(460, 95, t, 0.20) * 0.55 + r.uniform(-1, 1) * 0.32)
            * envelope(t, 0.20, 0.002),
            14,
        ),
        "enemy_projectile.wav": (
            0.24,
            lambda t, r: chirp(330, 760, t, 0.24) * envelope(t, 0.24),
            15,
        ),
        "enemy_field.wav": (
            0.38,
            lambda t, r: (math.sin(math.tau * 145 * t) * 0.5 + math.sin(math.tau * 233 * t) * 0.35)
            * envelope(t, 0.38, 0.02),
            16,
        ),
        "enemy_boss.wav": (
            0.52,
            lambda t, r: (chirp(95, 42, t, 0.52) * 0.72 + r.uniform(-1, 1) * 0.18)
            * envelope(t, 0.52, 0.01),
            17,
        ),
    }
    for name, (duration, sample, seed) in specs.items():
        write_sound(name, duration, sample, seed=seed)
        print(f"Wrote {OUTPUT / name}")


if __name__ == "__main__":
    main()
