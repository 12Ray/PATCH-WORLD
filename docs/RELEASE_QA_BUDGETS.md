# PATCH//WORLD release QA budgets

These gates keep the connected campaign playable on Windows and on the web as
new rooms, animation frames, and localized text are added. They are acceptance
budgets, not targets to consume.

## Automated web build budgets

Run `flutter build web --release`, then:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\qa_budget.ps1
```

| Metric | Limit | Phase 5 baseline | Why it is gated |
| --- | ---: | ---: | --- |
| Complete `build/web` output | 90 MiB | 79.30 MiB | Includes Flutter's renderer variants and all deployable files. |
| Flutter asset payload | 45 MiB | 37.59 MiB | Detects accidental font, image, or localization growth. |
| PATCH//WORLD-owned game assets | 42 MiB | 36.24 MiB | Bounds the content downloaded for rooms, sprites, and audio. |
| `main.dart.js` | 4 MiB | 2.97 MiB | Detects code-size regressions in the compiled application. |
| Largest owned game asset | 3 MiB | 2.29 MiB | Prevents a single unoptimized bitmap or audio file from dominating startup. |

`tool/check.ps1` and the GitHub Pages workflow run the budget gate after the
release web build. A limit change requires a measured reason in this document;
do not raise a limit only to make CI green.

## Frame-pacing acceptance

The gameplay target is 60 FPS on a 60 Hz display. Test a release or profile
build at 1920×1080 with browser zoom at 100%, after one warm-up traversal.

- Sample at least 30 seconds in a combat room and 30 seconds in each boss room.
- The requestAnimationFrame median must be at most 17.5 ms.
- The 95th percentile must be at most 20 ms.
- Frames over 33.4 ms must remain below 1% of samples.
- Weapon attack animation must keep the same collision box and displayed size
  across idle, anticipation, active, recovery, and locomotion transitions.
- A run fails if the browser console reports an uncaught exception, an asset
  request returns 404, or room transition remains active after the next scene
  is ready.

Record the browser, OS, display refresh rate, build SHA, sample counts, median,
p95, and severe-frame percentage with the release evidence. Automated widget
tests verify deterministic gameplay transitions; this runtime measurement
captures renderer, GPU, and browser behavior that widget tests cannot model.

For a local instrumented release build, run:

```powershell
flutter build web --release --dart-define=FRAME_PACING_QA=true
```

The top-right `FRAME_QA` panel ignores its first two seconds, then reports the
30-second sample. `PASS` uses the acceptance thresholds above. Rebuild without
the define before deployment; the probe is disabled by default.

## Campaign regression matrix

Before deployment, all rows must pass on the exact release build:

| Flow | Sword | Gauntlet | Gun |
| --- | --- | --- | --- |
| New game → Damage Lab core | Required | Required | Required |
| Temporal Hall core → hub lift | Required | Required | Required |
| Collision Archive core → hub lift | Required | Required | Required |
| Optimizer terminal → overflow → ending | Required | Required | Required |
| Fall recovery and west/east entry spawn | Required | Required | Required |
| Korean, English, and Japanese critical UI | Required | Required | Required |

`connected_campaign_three_weapon_full_run_test.dart` executes the complete
three-weapon matrix and asserts that all 15 enemy archetypes are encountered.
`campaign_transition_stress_test.dart` covers illegal travel, duplicate door
activation, repeated backtracking, spawn direction, and fall recovery.
