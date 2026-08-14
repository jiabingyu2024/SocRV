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
        self.assertEqual(resolve_core_mhz(BOARDS["axku062"], None), 100)
        self.assertEqual(resolve_core_mhz(BOARDS["kintex7_competition"], None), 100)
        self.assertEqual(resolve_core_mhz(BOARDS["pynq_z2"], None), 50)
        self.assertEqual(BOARDS["axku062"].default_profile, "rtthread-coremark")
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

    def test_axku062_clock_contract(self) -> None:
        board = BOARDS["axku062"]
        self.assertEqual(board.supported_core_mhz, (50, 100, 125, 150, 200, 250))
        self.assertEqual(
            board.mmcm,
            {
                50: ("5.0", "20.0", "20"),
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
        axku = fpga_build_root(BOARDS["axku062"], "rtthread-coremark", 100)
        self.assertEqual(kintex.name, "kintex7-smoke-100mhz")
        self.assertEqual(pynq.name, "pynq_z2-rtthread-50mhz")
        self.assertEqual(axku.name, "axku062-rtthread-coremark-100mhz")

    def test_sensor_i2c_is_wired_on_all_boards(self) -> None:
        pin_contracts = {
            "axku062": ("L13", "K13"),
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

    def test_axku062_uses_ultrascale_part_and_mixed_voltage_leds(self) -> None:
        board_dir = REPO_DIR / "fpga" / "boards" / "axku062"
        create_project = (board_dir / "tcl" / "create_project.tcl").read_text(
            encoding="utf-8"
        )
        clock_rtl = (board_dir / "rtl" / "axku062_clock_wrapper.sv").read_text(
            encoding="utf-8"
        )
        pins = (board_dir / "constraints" / "pins.xdc").read_text(
            encoding="utf-8"
        )
        self.assertIn("xcku060-ffva1156-2-i", create_project)
        self.assertIn("MMCME3_BASE", clock_rtl)
        self.assertIn(
            "IOSTANDARD LVCMOS18 [get_ports {o_led[0] o_led[1] o_led[2]}]",
            pins,
        )
        self.assertIn("IOSTANDARD LVCMOS33 [get_ports {o_led[3]}]", pins)

    def test_pynq_clock_loss_pauses_without_reasserting_reset(self) -> None:
        board_dir = REPO_DIR / "fpga" / "boards" / "pynq_z2"
        reset_rtl = (board_dir / "rtl" / "board_clock_reset.sv").read_text(
            encoding="utf-8"
        )
        clock_rtl = (board_dir / "rtl" / "pynq_z2_clock_wrapper.sv").read_text(
            encoding="utf-8"
        )
        self.assertIn("startup_release_q = 3'b000", reset_rtl)
        self.assertIn("assign core_rst_no = startup_release_q[2]", reset_rtl)
        self.assertNotIn("pynq_z2_reset_sequencer", reset_rtl)
        self.assertEqual(clock_rtl.count("BUFGCE #("), 2)
        self.assertEqual(clock_rtl.count(".CE(locked_o)"), 2)


if __name__ == "__main__":
    unittest.main()
