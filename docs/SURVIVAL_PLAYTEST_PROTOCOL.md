# PATCH//SURVIVE Phase 10.5 playtest protocol

This protocol collects the human evidence that automated combat, performance,
and UI tests cannot replace. The game persists up to 90 completed or failed
runs. The report tools are read-only and never clear player data.

## Fixed test conditions

- Use the normal Windows Release build with no QA defines, invincibility, or
  automatic attacks.
- Turn Assist Mode off and keep the same display, input method, and text scale
  for the full cohort.
- A run counts only after the result screen appears. Closing or restarting an
  active run does not create a balance record.
- Do not delete `%APPDATA%\com.example\patch_world` during the cohort.
- Record a tell-audit note whenever damage occurs without a readable warning.
  Include the enemy or boss, attack, weapon, region, and what obscured it.
- The basic Crawler now stops and displays a gold/red contraction ring for
  0.46 seconds before its bite. Body overlap alone must never deal survival
  damage; report any `enemy.crawler.contact` result as a regression.

## Fifteen-run order

The order rotates weapons to reduce practice and fatigue bias. Each row is one
play session; exit the game after the row so persistence is checked and the
report is printed.

| Session | Run 1 | Run 2 | Run 3 |
| --- | --- | --- | --- |
| 1 | Sword | Gauntlet | Gun |
| 2 | Gauntlet | Gun | Sword |
| 3 | Gun | Sword | Gauntlet |
| 4 | Sword | Gun | Gauntlet |
| 5 | Gun | Gauntlet | Sword |

Start a session from PowerShell in the repository root:

```powershell
.\tool\run_survival_playtest.ps1
```

The existing Release executable opens visibly. Play the three listed runs,
close the game normally, and inspect the automatically printed report. To read
the report without starting the game:

```powershell
.\tool\run_survival_playtest.ps1 -ReportOnly
```

To isolate a new tuning cohort, pass its UTC or offset-aware start time:

```powershell
.\tool\run_survival_playtest.ps1 -ReportOnly -Since '2026-08-16T00:00:00+09:00'
```

## Release gates

- Sword, Gauntlet, and Gun each have at least five valid runs.
- Weapon completion-rate spread is at most 10 percentage points.
- At least five failed runs exist so death-cause diversity has a sample.
- The leading death cause is no more than 35% of failed runs.
- Every run visits at least three regions and completes at least two region
  events.
- A person verifies every observed damaging attack had a readable tell.

After reviewing the tell notes, run the strict final audit. `-TellsApproved`
is a human assertion and must never be supplied by automated QA:

```powershell
.\tool\run_survival_playtest.ps1 -ReportOnly -StrictReport -TellsApproved
```

Exit code `0` means all statistical gates plus the manual tell audit passed.
Exit code `2` means the release is not ready or the telemetry file is invalid.

## Interpreting the report

- Compare both final-boss completion and 20-minute survival rate. A run that
  reaches 20 minutes but fails the Nexus Core is a pacing or boss-balance
  signal, not an early-game survival failure.
- Use damage totals to find sustained pressure and death causes to find lethal
  spikes; they answer different questions.
- Item and build completion rates are correlations. Do not nerf an item from a
  single pick or without checking its weapon and player-skill context.
- After balance changes, start a new cohort with `-Since`; do not silently mix
  pre-change and post-change runs in the release decision.
