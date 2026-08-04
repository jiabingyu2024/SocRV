from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from run_isa_tests import select_tests


class IsaSelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = {
            "gates": {
                "current": {
                    "ready": True,
                    "suites": ["rv32ui"],
                    "excluded_tests": ["rv32ui/fence_i"],
                    "blocked_reason": None,
                },
                "final-base": {
                    "ready": True,
                    "suites": ["rv32ui", "rv32mi", "rv32um"],
                    "excluded_tests": [],
                    "blocked_reason": None,
                },
                "final": {
                    "ready": False,
                    "suites": ["rv32ui", "rv32mi", "rv32um"],
                    "excluded_tests": [],
                    "blocked_reason": "select floating point",
                },
            },
            "tests": [
                {"suite": "rv32ui", "name": "add"},
                {"suite": "rv32ui", "name": "fence_i"},
                {"suite": "rv32mi", "name": "csr"},
                {"suite": "rv32um", "name": "mul"},
            ],
        }

    def test_current_gate_excludes_fence_i(self) -> None:
        selected = select_tests(self.manifest, "current", None, None)
        self.assertEqual(
            [(test["suite"], test["name"]) for test in selected],
            [("rv32ui", "add")],
        )

    def test_final_base_uses_all_mandatory_suites(self) -> None:
        selected = select_tests(self.manifest, "final-base", None, None)
        self.assertEqual(
            {test["suite"] for test in selected},
            {"rv32ui", "rv32mi", "rv32um"},
        )

    def test_qualified_name_selects_one_test(self) -> None:
        selected = select_tests(
            self.manifest,
            "final-base",
            None,
            {"rv32um/mul"},
        )
        self.assertEqual(selected, [{"suite": "rv32um", "name": "mul"}])

    def test_blocked_final_gate_fails_before_simulation(self) -> None:
        with self.assertRaisesRegex(ValueError, "not ready"):
            select_tests(self.manifest, "final", None, None)


if __name__ == "__main__":
    unittest.main()
