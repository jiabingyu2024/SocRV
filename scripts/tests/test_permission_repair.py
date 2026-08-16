from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from repair_competition_run_permissions import run_permission_command


class PermissionRepairTest(unittest.TestCase):
    @patch("repair_competition_run_permissions.subprocess.run")
    def test_icacls_failed_processing_is_an_error(self, run) -> None:
        run.return_value = subprocess.CompletedProcess(
            ["icacls"],
            0,
            stdout="Successfully processed 0 files; Failed processing 2 files\n",
            stderr="",
        )

        with self.assertRaisesRegex(RuntimeError, "Failed processing 2 files"):
            run_permission_command(["icacls"], action="repair")

    @patch("repair_competition_run_permissions.subprocess.run")
    def test_successful_permission_command_is_accepted(self, run) -> None:
        run.return_value = subprocess.CompletedProcess(
            ["icacls"],
            0,
            stdout="Successfully processed 4 files; Failed processing 0 files\n",
            stderr="",
        )

        run_permission_command(["icacls"], action="repair")


if __name__ == "__main__":
    unittest.main()
