"""Regression tests for the compact-report tooling.

Both cases below encode bugs that actually shipped:

* the utilization header guard used to require exactly one space after the
  pipe, but Vivado pads the Instance column with ~50 spaces, so the whole
  table silently parsed as zero rows;
* the CoreMark performance window is legitimately absent from the per-test
  result JSON files, so the window finder must return None instead of
  raising or inventing numbers.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import iteration_status
from summarize_utilization import _apply_filters, _mc, _parse_report

# Real Vivado shape: the Instance column is padded far past the pipe, and the
# hierarchy depth is carried by leading spaces inside the cell (2 per level).
UTILIZATION = """\
Copyright 1986-2023 Xilinx, Inc. All Rights Reserved.
1. Utilization by Hierarchy
---------------------------

+--------------------------------------------------+--------------------+------------+------------+--------+-------+--------+--------+-----------+
|                     Instance                     |       Module       | Total LUTs | Logic LUTs | LUTRAMs| SRLs  |   FFs  | RAMB36 | RAMB18 | DSP Blocks |
+--------------------------------------------------+--------------------+------------+------------+--------+-------+--------+--------+-----------+
| fpga_top                                         |              (top) |      37425 |      37425 |      0 |     0 |  27898 |     48 |      0 |          6 |
|   u_soc                                          |            soc_top |      37395 |      37395 |      0 |     0 |  27895 |     48 |      0 |          6 |
|     core                                         |       veer_wrapper |      36745 |      36745 |      0 |     0 |  27016 |     48 |      0 |          6 |
|       dec                                        |                dec |      22522 |      22522 |      0 |     0 |   6442 |      0 |      0 |          2 |
|         decode                                   |     dec_decode_ctl |       7998 |       7998 |      0 |     0 |   3423 |      0 |      0 |          2 |
+--------------------------------------------------+--------------------+------------+------------+--------+-------+--------+--------+-----------+
"""


class UtilizationParserTests(unittest.TestCase):
    def _rows(self) -> list[dict]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "post_synth_utilization.rpt"
            path.write_text(UTILIZATION, encoding="utf-8")
            return _parse_report(path)

    def test_padded_header_is_still_detected(self) -> None:
        # The guard must not depend on the pipe-to-Instance spacing.
        self.assertEqual(len(self._rows()), 5)

    def test_columns_map_to_the_right_metrics(self) -> None:
        top = self._rows()[0]
        self.assertEqual(top["instance"], "fpga_top")
        self.assertEqual(top["total_luts"], 37425)
        self.assertEqual(top["ffs"], 27898)
        self.assertEqual(top["ramb36"], 48)
        self.assertEqual(top["dsp"], 6)

    def test_depth_comes_from_leading_spaces(self) -> None:
        depths = {r["instance"]: r["depth"] for r in self._rows()}
        self.assertEqual(depths["fpga_top"], 0)
        self.assertEqual(depths["u_soc"], 1)
        self.assertEqual(depths["core"], 2)
        self.assertEqual(depths["dec"], 3)
        self.assertEqual(depths["decode"], 4)

    def test_depth_and_substring_filters(self) -> None:
        rows = self._rows()
        self.assertEqual(len(_apply_filters(rows, 2, None)), 3)
        self.assertEqual([r["instance"] for r in _apply_filters(rows, 9, "decode")], ["decode"])

    def test_pipes_are_escaped_for_markdown_cells(self) -> None:
        # Cluster and instance names contain '|', which would break columns.
        self.assertEqual(_mc("FPU_FMA | dec/decode/fpu"), "FPU_FMA \\| dec/decode/fpu")


class PerformanceWindowTests(unittest.TestCase):
    def _run_with(self, tree: dict[str, dict]) -> tuple[dict | None, Path | None]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, payload in tree.items():
                target = root / name / "summary.json"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps(payload), encoding="utf-8")
            original = iteration_status.REGRESSION_ROOT
            iteration_status.REGRESSION_ROOT = root
            try:
                return iteration_status.find_performance_window()
            finally:
                iteration_status.REGRESSION_ROOT = original

    def test_missing_performance_object_is_tolerated(self) -> None:
        # Mirrors build/verilator/.../result.json, which carries no window.
        perf, source = self._run_with(
            {"coremark": {"status": "PASS", "tests": [{"test": "coremark-rtthread", "cycles": 5156562}]}}
        )
        self.assertIsNone(perf)
        self.assertIsNone(source)

    def test_incomplete_window_is_rejected(self) -> None:
        perf, _ = self._run_with(
            {
                "correctness": {
                    "tests": [{"test": "smoke", "performance": {"complete": False, "cycles": 10, "iterations": 1}}]
                }
            }
        )
        self.assertIsNone(perf)

    def test_complete_window_is_found_in_nested_test_entry(self) -> None:
        perf, source = self._run_with(
            {
                "correctness": {
                    "tests": [
                        {"test": "smoke", "cycles": 74511},
                        {
                            "test": "rtthread-coremark-command-3",
                            "cycles": 11508527,
                            "performance": {
                                "complete": True,
                                "cycles": 7136021,
                                "iterations": 3,
                                "cycles_per_iteration": 2378673.666,
                                "ipc": 0.313871134,
                            },
                        },
                    ]
                }
            }
        )
        self.assertIsNotNone(perf)
        self.assertEqual(perf["iterations"], 3)
        # Must be the measured window, not the whole-simulation cycle count.
        self.assertEqual(perf["cycles"], 7136021)
        self.assertEqual(perf["test"], "rtthread-coremark-command-3")
        self.assertEqual(Path(source).name, "summary.json")

    def test_top_level_performance_list_is_accepted(self) -> None:
        perf, _ = self._run_with(
            {
                "performance": {
                    "performance": [
                        {
                            "test": "rtthread-coremark-command-10",
                            "complete": True,
                            "cycles": 23786691,
                            "iterations": 10,
                        }
                    ]
                }
            }
        )
        self.assertIsNotNone(perf)
        self.assertEqual(perf["iterations"], 10)


class MarkdownColumnTests(unittest.TestCase):
    """Cluster labels contain literal pipes; unescaped they add table columns."""

    CLUSTER = "FPU_FMA | dec/decode/fpu -> dec/decode/fpu | clk_core->clk_core"

    def _rows(self) -> list[dict[str, str]]:
        return [
            {
                "cluster": self.CLUSTER,
                "category": "FPU_FMA",
                "slack_ns": "-3.509",
                "status": "VIOLATED",
                "logic_levels": "41",
                "logic_percent": "29.0",
                "route_percent": "71.0",
                "max_fanout": "141",
                "max_fanout_net": "dec/decode/fpu/net|weird",
                "source_scope": "dec/decode/fpu",
                "destination_scope": "dec/decode/fpu",
            }
        ]

    def _column_counts(self, text: str) -> set[int]:
        return {
            line.count("|") - line.count("\\|")
            for line in text.splitlines()
            if line.startswith("|")
        }

    def test_group_table_keeps_a_single_column_count(self) -> None:
        import io
        from contextlib import redirect_stdout

        import query_timing_paths

        buffer = io.StringIO()
        with redirect_stdout(buffer):
            query_timing_paths.print_groups(self._rows(), "cluster", 10)
        counts = self._column_counts(buffer.getvalue())
        self.assertEqual(len(counts), 1, f"ragged markdown table: {counts}")

    def test_path_and_fanout_tables_keep_a_single_column_count(self) -> None:
        import io
        from contextlib import redirect_stdout

        import query_timing_paths

        for fn, args in (
            (query_timing_paths.print_paths, (self._rows(), 10)),
            (query_timing_paths.print_fanout, (self._rows(), 100, 10)),
        ):
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                fn(*args)
            counts = self._column_counts(buffer.getvalue())
            self.assertEqual(len(counts), 1, f"{fn.__name__} ragged: {counts}")


class AchievedFrequencyTests(unittest.TestCase):
    def test_negative_slack_lowers_achieved_frequency(self) -> None:
        # 8 ns period with -3.509 ns slack really closes at 1000/11.509 MHz.
        self.assertAlmostEqual(iteration_status.achieved_mhz(8.0, -3.509), 86.888, places=2)

    def test_positive_slack_raises_achieved_frequency(self) -> None:
        self.assertAlmostEqual(iteration_status.achieved_mhz(20.0, 16.43), 280.11, places=1)

    def test_degenerate_inputs_return_none(self) -> None:
        self.assertIsNone(iteration_status.achieved_mhz(None, -1.0))
        self.assertIsNone(iteration_status.achieved_mhz(8.0, None))
        self.assertIsNone(iteration_status.achieved_mhz(8.0, 8.0))


if __name__ == "__main__":
    unittest.main()
