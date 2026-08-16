import json
import tempfile
import unittest
from pathlib import Path

import survival_playtest_report as report


def record(weapon: str, *, completed: bool, death: str, timestamp: int) -> dict:
    return {
        "version": 1,
        "recordedAtEpochMs": timestamp,
        "weapon": weapon,
        "elapsedSeconds": 1210 if completed else 610,
        "finalBossDefeated": completed,
        "deathCauseId": death,
        "damageByCause": {death: 2},
        "patchIds": ["power"],
        "itemIds": [f"{weapon}_item"],
        "weaponBuildTiers": {f"{weapon}_build": 3},
        "completedWeaponBuilds": 1,
        "visitedRegionCount": 3,
        "regionEventsCompleted": 2,
        "survivalBossesDefeated": 4 if completed else 2,
    }


class SurvivalPlaytestReportTest(unittest.TestCase):
    def test_loads_flutter_string_list_and_passes_balanced_sample(self) -> None:
        encoded = []
        causes = ["arc", "mine", "rift", "contact", "boss"]
        timestamp = 1_800_000_000_000
        for weapon in report.WEAPONS:
            for index in range(5):
                encoded.append(
                    json.dumps(
                        record(
                            weapon,
                            completed=index < 3,
                            death=causes[(index + report.WEAPONS.index(weapon)) % len(causes)],
                            timestamp=timestamp,
                        )
                    )
                )
                timestamp += 1

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "shared_preferences.json"
            path.write_text(json.dumps({"survivalPlaytestRecords": encoded}), encoding="utf-8")
            records, warnings = report.load_records(path)

        self.assertEqual(len(records), 15)
        self.assertEqual(warnings, [])
        payload = report.build_payload(records, tells_approved=True)
        self.assertTrue(payload["allGatesPassed"])
        self.assertEqual(payload["weapons"]["sword"]["runs"], 5)
        self.assertEqual(payload["weapons"]["gun"]["twentyMinuteSurvivals"], 3)

    def test_incomplete_samples_and_manual_tell_audit_do_not_pass(self) -> None:
        records = [
            report.parse_record(record("sword", completed=False, death="mine", timestamp=1))
        ]
        payload = report.build_payload(records, tells_approved=False)
        gates = {gate["name"]: gate["passed"] for gate in payload["gates"]}
        self.assertFalse(payload["allGatesPassed"])
        self.assertFalse(gates["weapon_samples"])
        self.assertFalse(gates["attack_tell_audit"])

    def test_corrupt_record_is_skipped_without_discarding_valid_records(self) -> None:
        valid = json.dumps(record("gun", completed=True, death="none", timestamp=3))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "shared_preferences.json"
            path.write_text(
                json.dumps({"flutter.survivalPlaytestRecords": ["bad json", valid]}),
                encoding="utf-8",
            )
            records, warnings = report.load_records(path)
        self.assertEqual(len(records), 1)
        self.assertEqual(len(warnings), 1)


if __name__ == "__main__":
    unittest.main()
