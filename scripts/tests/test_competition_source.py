from __future__ import annotations

import json
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

from jsonschema import Draft202012Validator

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from lib.hashing import sha256_file
from lib.repo import repo_path
from build_software import verify_competition_sources
from prepare_competition_run import default_run_id, prepare_run


class CompetitionSourceTest(unittest.TestCase):
    def test_prepare_core_main_run(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "input"
            source.mkdir()
            core_main = source / "core_main.c"
            core_main.write_text("int main(void) { return 0; }\n", encoding="utf-8")
            (source / "rules.txt").write_text("contest\n", encoding="utf-8")

            run = prepare_run(source, run_id="round1", runs_root=root / "runs")

            config = json.loads(
                (run / "source" / "competition.json").read_text(encoding="utf-8")
            )
            schema = json.loads(
                repo_path("data", "schemas", "competition_source.schema.json").read_text(
                    encoding="utf-8"
                )
            )
            Draft202012Validator(schema).validate(config)
            self.assertEqual(config["mode"], "core_main_replacement")
            self.assertEqual(
                config["entry_source"], "source/original/core_main.c"
            )
            manifest = json.loads(
                (run / "source" / "source_manifest.json").read_text(encoding="utf-8")
            )
            entries = {item["path"]: item for item in manifest["files"]}
            copied = run / "source" / "original" / "core_main.c"
            self.assertEqual(
                entries["source/original/core_main.c"]["sha256"],
                sha256_file(copied),
            )
            self.assertIn(
                "set ::env(SOCRV_CORE_HZ) [expr {$CORE_MHZ * 1000000}]",
                (run / "vivado" / "create_kintex7_project.tcl").read_text(
                    encoding="utf-8"
                ),
            )
            self.assertIn(
                "pynq_z2-50mhz",
                (run / "vivado" / "create_pynq_z2_project.tcl").read_text(
                    encoding="utf-8"
                ),
            )

    def test_only_c_file_is_the_default_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "contest_driver.c"
            source.write_text("int main(void) { return 0; }\n", encoding="utf-8")
            run = prepare_run(source, run_id="single", runs_root=root / "runs")
            config = json.loads(
                (run / "source" / "competition.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                config["entry_source"], "source/original/contest_driver.c"
            )

    def test_ambiguous_c_sources_require_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "input"
            source.mkdir()
            (source / "one.c").write_text("\n", encoding="utf-8")
            (source / "two.c").write_text("\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "use --entry"):
                prepare_run(source, run_id="ambiguous", runs_root=root / "runs")

    def test_source_change_after_preparation_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "core_main.c"
            source.write_text("int main(void) { return 0; }\n", encoding="utf-8")
            run = prepare_run(source, run_id="changed", runs_root=root / "runs")
            copied = run / "source" / "original" / "core_main.c"
            copied.write_text("int main(void) { return 1; }\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "changed after preparation"):
                verify_competition_sources(run)

    def test_default_run_id_is_stable_for_supplied_time(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "CoreMark input"
            source.mkdir()
            self.assertEqual(
                default_run_id(source, now=datetime(2026, 8, 13, 14, 32, 5)),
                "20260813_143205_CoreMark_input",
            )


if __name__ == "__main__":
    unittest.main()
