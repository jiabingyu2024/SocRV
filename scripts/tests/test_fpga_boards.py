from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_DIR = SCRIPTS_DIR.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from lib.fpga import BOARDS, fpga_build_root, resolve_core_mhz


class FpgaBoardTest(unittest.TestCase):
    def test_board_defaults(self) -> None:
        self.assertEqual(resolve_core_mhz(BOARDS["kintex7_competition"], None), 100)
        self.assertEqual(resolve_core_mhz(BOARDS["pynq_z2"], None), 50)
        self.assertEqual(BOARDS["kintex7_competition"].default_profile, "rtthread-coremark")
        self.assertEqual(BOARDS["pynq_z2"].default_profile, "rtthread")

    def test_pynq_rejects_frequency_sweep(self) -> None:
        with self.assertRaisesRegex(ValueError, "choose one of: 50"):
            resolve_core_mhz(BOARDS["pynq_z2"], 100)

    def test_kintex_release_clock_contract_is_unchanged(self) -> None:
        board = BOARDS["kintex7_competition"]
        self.assertEqual(board.supported_core_mhz, (100, 125, 150, 200, 250))
        self.assertEqual(
            board.mmcm,
            {
                100: ("5.0", "10.0", "20"),
                125: ("5.0", "8.0", "20"),
                150: ("6.0", "8.0", "24"),
                200: ("5.0", "5.0", "20"),
                250: ("5.0", "4.0", "20"),
            },
        )

    def test_build_directories_are_board_scoped(self) -> None:
        kintex = fpga_build_root(BOARDS["kintex7_competition"], "smoke", 100)
        pynq = fpga_build_root(BOARDS["pynq_z2"], "rtthread", 50)
        self.assertEqual(kintex.name, "kintex7-smoke-100mhz")
        self.assertEqual(pynq.name, "pynq_z2-rtthread-50mhz")

    def test_sensor_i2c_is_wired_on_both_boards(self) -> None:
        pin_contracts = {
            "pynq_z2": ("W14", "Y14"),
            "kintex7_competition": ("F22", "G22"),
        }
        for board, (scl_pin, sda_pin) in pin_contracts.items():
            with self.subTest(board=board):
                board_dir = REPO_DIR / "fpga" / "boards" / board
                top = (board_dir / "rtl" / "fpga_top.sv").read_text(encoding="utf-8")
                pins = (board_dir / "constraints" / "pins.xdc").read_text(
                    encoding="utf-8"
                )
                self.assertIn("inout  wire", top)
                self.assertIn("sensor_i2c_scl_io", top)
                self.assertIn("sensor_i2c_sda_io", top)
                self.assertIn("i2c_scl_drive_low ? 1'b0 : 1'bz", top)
                self.assertIn("i2c_sda_drive_low ? 1'b0 : 1'bz", top)
                self.assertIn(f"PACKAGE_PIN {scl_pin}", pins)
                self.assertIn(f"PACKAGE_PIN {sda_pin}", pins)


if __name__ == "__main__":
    unittest.main()
