#!/usr/bin/env python3
"""Read PATCH//SURVIVE Windows telemetry and print the Phase 10.5 report.

The game stores each completed or failed run as a JSON string inside Flutter's
Windows shared_preferences file. This tool is deliberately read-only: it never
creates, edits, clears, or migrates player data.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence


WEAPONS = ("sword", "gauntlet", "gun")
WEAPON_LABELS = {
    "sword": "Sword / 칼",
    "gauntlet": "Gauntlet / 주먹",
    "gun": "Gun / 총",
}
MINIMUM_RUNS_PER_WEAPON = 5
MINIMUM_DEATH_SAMPLES = 5
MAXIMUM_COMPLETION_RATE_SPREAD = 0.10
MAXIMUM_DEATH_CAUSE_SHARE = 0.35
TWENTY_MINUTES_SECONDS = 20 * 60
PREFERENCE_KEYS = (
    "survivalPlaytestRecords",
    "flutter.survivalPlaytestRecords",
)


@dataclass(frozen=True)
class RunRecord:
    recorded_at_epoch_ms: int
    weapon: str
    elapsed_seconds: float
    completed: bool
    death_cause_id: str
    damage_by_cause: dict[str, int]
    patch_ids: tuple[str, ...]
    item_ids: tuple[str, ...]
    weapon_build_tiers: dict[str, int]
    completed_weapon_builds: int
    visited_region_count: int
    region_events_completed: int
    survival_bosses_defeated: int

    @property
    def survived_twenty_minutes(self) -> bool:
        return self.completed or self.elapsed_seconds >= TWENTY_MINUTES_SECONDS

    @property
    def met_region_engagement(self) -> bool:
        return self.visited_region_count >= 3 and self.region_events_completed >= 2


@dataclass(frozen=True)
class GateResult:
    name: str
    passed: bool
    detail: str


def default_preferences_path() -> Path:
    roaming = os.environ.get("APPDATA")
    if roaming:
        return Path(roaming) / "com.example" / "patch_world" / "shared_preferences.json"
    return Path.home() / "AppData" / "Roaming" / "com.example" / "patch_world" / "shared_preferences.json"


def _int_map(raw: Any) -> dict[str, int]:
    if not isinstance(raw, dict):
        return {}
    values: dict[str, int] = {}
    for key, value in raw.items():
        if isinstance(key, str) and isinstance(value, (int, float)) and not isinstance(value, bool):
            values[key] = round(value)
    return values


def _string_tuple(raw: Any) -> tuple[str, ...]:
    if not isinstance(raw, list):
        return ()
    return tuple(sorted(value for value in raw if isinstance(value, str)))


def parse_record(raw: Any) -> RunRecord:
    if isinstance(raw, str):
        raw = json.loads(raw)
    if not isinstance(raw, dict):
        raise ValueError("record is not a JSON object")

    weapon = raw.get("weapon")
    if weapon not in WEAPONS:
        raise ValueError(f"unknown weapon: {weapon!r}")

    return RunRecord(
        recorded_at_epoch_ms=int(raw["recordedAtEpochMs"]),
        weapon=weapon,
        elapsed_seconds=float(raw["elapsedSeconds"]),
        completed=bool(raw["finalBossDefeated"]),
        death_cause_id=str(raw.get("deathCauseId", "unknown")),
        damage_by_cause=_int_map(raw.get("damageByCause")),
        patch_ids=_string_tuple(raw.get("patchIds")),
        item_ids=_string_tuple(raw.get("itemIds")),
        weapon_build_tiers=_int_map(raw.get("weaponBuildTiers")),
        completed_weapon_builds=int(raw.get("completedWeaponBuilds", 0)),
        visited_region_count=int(raw.get("visitedRegionCount", 0)),
        region_events_completed=int(raw.get("regionEventsCompleted", 0)),
        survival_bosses_defeated=int(raw.get("survivalBossesDefeated", 0)),
    )


def load_records(path: Path) -> tuple[list[RunRecord], list[str]]:
    outer = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(outer, dict):
        raise ValueError("shared_preferences root must be a JSON object")

    encoded: Any = None
    for key in PREFERENCE_KEYS:
        if key in outer:
            encoded = outer[key]
            break
    if encoded is None:
        return [], [f"preference key not found: {PREFERENCE_KEYS[0]}"]
    if not isinstance(encoded, list):
        raise ValueError("survivalPlaytestRecords must be a JSON list")

    records: list[RunRecord] = []
    warnings: list[str] = []
    for index, value in enumerate(encoded):
        try:
            records.append(parse_record(value))
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            warnings.append(f"record {index + 1} skipped: {error}")
    records.sort(key=lambda record: record.recorded_at_epoch_ms)
    return records[-90:], warnings


def parse_since(value: str | None) -> int | None:
    if not value:
        return None
    normalized = value.strip().replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return int(parsed.timestamp() * 1000)


def percent(value: float) -> str:
    return f"{value * 100:5.1f}%"


def duration(seconds: float) -> str:
    minutes = int(seconds // 60)
    remainder = int(round(seconds - minutes * 60))
    if remainder == 60:
        minutes += 1
        remainder = 0
    return f"{minutes:02d}:{remainder:02d}"


def _completion_rate(records: Sequence[RunRecord]) -> float:
    return sum(record.completed for record in records) / len(records) if records else 0.0


def build_gates(records: Sequence[RunRecord], tells_approved: bool) -> list[GateResult]:
    by_weapon = {weapon: [record for record in records if record.weapon == weapon] for weapon in WEAPONS}
    counts = {weapon: len(values) for weapon, values in by_weapon.items()}
    samples_passed = all(count >= MINIMUM_RUNS_PER_WEAPON for count in counts.values())

    rates = [_completion_rate(by_weapon[weapon]) for weapon in WEAPONS]
    spread = max(rates) - min(rates) if samples_passed else 1.0

    failed_runs = [record for record in records if not record.completed]
    deaths = Counter(record.death_cause_id for record in failed_runs)
    top_cause, top_count = deaths.most_common(1)[0] if deaths else ("none", 0)
    top_share = top_count / len(failed_runs) if failed_runs else 0.0
    death_samples_passed = len(failed_runs) >= MINIMUM_DEATH_SAMPLES

    engaged = sum(record.met_region_engagement for record in records)
    region_rate = engaged / len(records) if records else 0.0

    return [
        GateResult(
            "weapon_samples",
            samples_passed,
            ", ".join(f"{weapon} {counts[weapon]}/{MINIMUM_RUNS_PER_WEAPON}" for weapon in WEAPONS),
        ),
        GateResult(
            "completion_parity",
            samples_passed and spread <= MAXIMUM_COMPLETION_RATE_SPREAD,
            f"spread {percent(spread)} / limit {percent(MAXIMUM_COMPLETION_RATE_SPREAD)}",
        ),
        GateResult(
            "death_samples",
            death_samples_passed,
            f"{len(failed_runs)}/{MINIMUM_DEATH_SAMPLES}",
        ),
        GateResult(
            "death_cause_diversity",
            death_samples_passed and top_share <= MAXIMUM_DEATH_CAUSE_SHARE,
            f"{top_cause} {percent(top_share)} / limit {percent(MAXIMUM_DEATH_CAUSE_SHARE)}",
        ),
        GateResult(
            "region_engagement",
            bool(records) and engaged == len(records),
            f"{engaged}/{len(records)} runs visited 3+ regions and completed 2+ events",
        ),
        GateResult(
            "attack_tell_audit",
            tells_approved,
            "manual visual audit approved" if tells_approved else "manual visual audit still required",
        ),
    ]


def build_payload(records: Sequence[RunRecord], tells_approved: bool) -> dict[str, Any]:
    by_weapon = {weapon: [record for record in records if record.weapon == weapon] for weapon in WEAPONS}
    failed_runs = [record for record in records if not record.completed]
    deaths = Counter(record.death_cause_id for record in failed_runs)
    damages: Counter[str] = Counter()
    items: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    builds: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0, 0])

    for record in records:
        damages.update(record.damage_by_cause)
        for item_id in record.item_ids:
            items[item_id][0] += 1
            items[item_id][1] += int(record.completed)
        for build_id, tier in record.weapon_build_tiers.items():
            if tier <= 0:
                continue
            builds[build_id][0] += 1
            builds[build_id][1] += int(tier >= 3)
            builds[build_id][2] += int(record.completed)
            builds[build_id][3] += tier

    gates = build_gates(records, tells_approved)
    weapon_payload: dict[str, Any] = {}
    for weapon, values in by_weapon.items():
        weapon_payload[weapon] = {
            "runs": len(values),
            "completions": sum(record.completed for record in values),
            "completionRate": _completion_rate(values),
            "twentyMinuteSurvivals": sum(record.survived_twenty_minutes for record in values),
            "twentyMinuteSurvivalRate": (
                sum(record.survived_twenty_minutes for record in values) / len(values) if values else 0.0
            ),
            "averageSurvivalSeconds": (
                sum(record.elapsed_seconds for record in values) / len(values) if values else 0.0
            ),
        }

    return {
        "runCount": len(records),
        "firstRecordedAtEpochMs": records[0].recorded_at_epoch_ms if records else None,
        "lastRecordedAtEpochMs": records[-1].recorded_at_epoch_ms if records else None,
        "weapons": weapon_payload,
        "deathCauseCounts": dict(deaths.most_common()),
        "damageCauseTotals": dict(damages.most_common()),
        "items": {
            item_id: {
                "picks": stats[0],
                "completions": stats[1],
                "completionRate": stats[1] / stats[0],
            }
            for item_id, stats in sorted(items.items())
        },
        "builds": {
            build_id: {
                "picks": stats[0],
                "tierThreeRuns": stats[1],
                "completions": stats[2],
                "averageTier": stats[3] / stats[0],
                "completionRate": stats[2] / stats[0],
            }
            for build_id, stats in sorted(builds.items())
        },
        "regionEngagedRuns": sum(record.met_region_engagement for record in records),
        "averageBossesDefeated": (
            sum(record.survival_bosses_defeated for record in records) / len(records) if records else 0.0
        ),
        "gates": [
            {"name": gate.name, "passed": gate.passed, "detail": gate.detail}
            for gate in gates
        ],
        "allGatesPassed": all(gate.passed for gate in gates),
    }


def print_report(payload: dict[str, Any], source: Path, warnings: Iterable[str]) -> None:
    print("PATCH//SURVIVE — Phase 10.5 balance report")
    print(f"Source: {source}")
    print(f"Runs: {payload['runCount']}/15 minimum")
    print()
    print("Weapon                 Runs  Clear       20 min      Average")
    print("---------------------  ----  ----------  ----------  -------")
    for weapon in WEAPONS:
        stats = payload["weapons"][weapon]
        print(
            f"{WEAPON_LABELS[weapon]:21}  "
            f"{stats['runs']:>4}  "
            f"{stats['completions']:>2}/{stats['runs']:<2} {percent(stats['completionRate'])}  "
            f"{stats['twentyMinuteSurvivals']:>2}/{stats['runs']:<2} {percent(stats['twentyMinuteSurvivalRate'])}  "
            f"{duration(stats['averageSurvivalSeconds'])}"
        )

    print()
    print("Death causes:")
    death_counts = payload["deathCauseCounts"]
    death_total = sum(death_counts.values())
    if not death_counts:
        print("  (no failed-run samples)")
    for cause, count in death_counts.items():
        print(f"  {cause}: {count} ({percent(count / death_total)})")

    print("Damage sources:")
    damage_totals = payload["damageCauseTotals"]
    damage_total = sum(damage_totals.values())
    if not damage_totals:
        print("  (no damage samples)")
    for cause, amount in list(damage_totals.items())[:8]:
        share = amount / damage_total if damage_total else 0.0
        print(f"  {cause}: {amount} ({percent(share)})")

    print()
    print("Gates:")
    for gate in payload["gates"]:
        marker = "PASS" if gate["passed"] else "WAIT"
        print(f"  [{marker}] {gate['name']}: {gate['detail']}")
    print(f"Overall: {'PASS' if payload['allGatesPassed'] else 'NOT READY'}")

    warning_list = list(warnings)
    if warning_list:
        print()
        print("Warnings:")
        for warning in warning_list:
            print(f"  - {warning}")


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--file",
        type=Path,
        default=default_preferences_path(),
        help="shared_preferences.json path (defaults to the PATCHWORLD Windows app data path)",
    )
    parser.add_argument(
        "--since",
        help="include only records at or after this ISO-8601 timestamp, interpreted as UTC when no zone is supplied",
    )
    parser.add_argument("--json", action="store_true", help="write the report as JSON")
    parser.add_argument(
        "--tells-approved",
        action="store_true",
        help="confirm the separate manual audit found every damaging attack tell readable",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit with code 2 while any statistical or manual release gate is not passed",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = make_parser().parse_args(argv)
    source = args.file.expanduser().resolve()
    if not source.is_file():
        message = f"No playtest data yet: {source}"
        if args.json:
            print(json.dumps({"error": message, "runCount": 0, "allGatesPassed": False}, ensure_ascii=False, indent=2))
        else:
            print(message)
            print("Finish or fail an ordinary Windows PATCH//SURVIVE run, then run this report again.")
        return 2 if args.strict else 0

    try:
        records, warnings = load_records(source)
        since_epoch_ms = parse_since(args.since)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Unable to read playtest data: {error}", file=sys.stderr)
        return 2

    if since_epoch_ms is not None:
        records = [record for record in records if record.recorded_at_epoch_ms >= since_epoch_ms]
    payload = build_payload(records, args.tells_approved)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print_report(payload, source, warnings)
    return 2 if args.strict and not payload["allGatesPassed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
