from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from analyze_vivado_reports import (
    _datapath_region,
    parse_timing_paths,
    parse_timing_summary,
    parse_utilization,
)


TIMING = """\
Timing Report
Slack (VIOLATED) :        -1.250ns  (required time - arrival time)
  Source:                 u_soc/core/veer/lsu/dccm/read_q_reg[0]/C
                             (rising edge-triggered cell FDCE clocked by clk_core_unbuffered  {rise@0.000ns fall@4.000ns period=8.000ns})
  Destination:            u_soc/core/veer/lsu/dccm/data_q_reg[0]/D
                             (rising edge-triggered cell FDCE clocked by clk_core_unbuffered  {rise@0.000ns fall@4.000ns period=8.000ns})
  Path Group:             clk_core_unbuffered
  Path Type:              Setup (Max at Slow Process Corner)
  Requirement:            8.000ns  (clk_core_unbuffered rise@8.000ns - clk_core_unbuffered rise@0.000ns)
  Data Path Delay:        9.250ns  (logic 3.000ns (32.432%) route 6.250ns (67.568%))
  Logic Levels:           12  (LUT6=4 CARRY4=2)
  Clock Path Skew:        -0.100ns (DCD - SCD + CPR)
  Clock Uncertainty:      0.064ns

Slack (MET) :        0.250ns  (required time - arrival time)
  Source:                 u_soc/core/veer/ifu/iccm/a_reg[0]/C
                             (rising edge-triggered cell FDCE clocked by clk_core_unbuffered)
  Destination:            u_soc/core/veer/dec/decode/b_reg[0]/D
                             (rising edge-triggered cell FDCE clocked by clk_core_unbuffered)
  Path Group:             clk_core_unbuffered
  Path Type:              Setup (Max at Slow Process Corner)
  Requirement:            8.000ns
  Data Path Delay:        7.500ns  (logic 4.000ns (53.333%) route 3.500ns (46.667%))
  Logic Levels:           8  (LUT6=8)
"""


TIMING_WITH_CLOCK_PATH = """\
Slack (VIOLATED) :        -2.100ns  (required time - arrival time)
  Source:                 fpga_top/u_core/dec/instbuff/ibvalff/dout_reg[3]/C
  Destination:            fpga_top/u_core/exu/i_alu/result_reg[7]/D
  Path Group:             core_clk
  Path Type:              Setup (Max at Slow Process Corner)
  Requirement:            8.000ns
  Data Path Delay:        9.500ns  (logic 3.000ns (31.579%) route 6.500ns (68.421%))
  Logic Levels:           9  (LUT6=9)

    Location             Delay type                Incr(ns)  Path(ns)    Netlist Resource(s)
  -------------------------------------------------------------------    -------------------
                         (clock core_clk rise edge)  0.000     0.000 r
    AD12                                             0.000     0.000 r    sys_clk_p
                         net (fo=27332, routed)      1.500     1.500      u_clock/core_clk
    BUFGCTRL_X0Y0        BUFG (Prop_bufg_I_O)        0.096     1.596 r    u_clock/core_clk_buf/O
  -------------------------------------------------------------------    -------------------
    SLICE_X10Y20         FDRE                        0.000     1.596 r    dec/instbuff/ibvalff/dout_reg[3]
                         net (fo=141, routed)        2.400     3.996      dec/instbuff/ibvalff/dout[36]_i_4__1_n_0
    SLICE_X11Y21         LUT6 (Prop_lut6_I0_O)       0.124     4.120 r    exu/i_alu/result[7]_i_2/O
                         net (fo=12, routed)         0.900     5.020      exu/i_alu/result[7]_i_2_n_0
    SLICE_X12Y22         FDRE                        0.000     5.020 r    exu/i_alu/result_reg[7]/D
  -------------------------------------------------------------------    -------------------
                         (clock core_clk rise edge)  8.000     8.000 r
                         net (fo=27332, routed)      1.500     9.500      u_clock/core_clk
    BUFGCTRL_X0Y0        BUFG (Prop_bufg_I_O)        0.096     9.596 r    u_clock/core_clk_buf/O
  -------------------------------------------------------------------    -------------------
"""


class VivadoReportTests(unittest.TestCase):
    def test_datapath_region_excludes_clock_paths(self) -> None:
        region = _datapath_region(TIMING_WITH_CLOCK_PATH)
        self.assertIn("fo=141", region)
        self.assertNotIn("fo=27332", region)
        self.assertNotIn("BUFG", region)

    def test_max_fanout_ignores_clock_tree_nets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "paths.rpt"
            path.write_text(TIMING_WITH_CLOCK_PATH, encoding="utf-8")
            records = parse_timing_paths(path, "setup")
        self.assertEqual(len(records), 1)
        record = records[0]
        # The BUFG-driven core_clk net has fanout 27332 and would win any
        # whole-block scan; the reported fanout must come from the data path.
        self.assertEqual(record.max_fanout, 141)
        self.assertEqual(record.max_fanout_net, "dec/instbuff/ibvalff/dout[36]_i_4__1_n_0")

    def test_timing_path_parser_extracts_fields_and_category(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "paths.rpt"
            path.write_text(TIMING, encoding="utf-8")
            records = parse_timing_paths(path, "setup")
        self.assertEqual(len(records), 2)
        self.assertEqual(records[0].slack_ns, -1.25)
        self.assertEqual(records[0].category, "LSU_DCCM")
        self.assertEqual(records[0].logic_levels, 12)
        self.assertEqual(records[0].cell_counts["LUT6"], 4)
        self.assertEqual(records[0].launch_clock, "clk_core_unbuffered")
        self.assertEqual(records[1].category, "IFU_ICCM")

    def test_summary_and_utilization_parser(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            summary = Path(directory) / "summary.rpt"
            summary.write_text(
                """Design Timing Summary
    WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)      THS(ns)  THS Failing Endpoints  THS Total Endpoints
    -------      -------  ---------------------  -------------------      -------      -------  ---------------------  -------------------
     -1.250      -10.500                     4                 100       -0.100       -1.000                      2                 100
""",
                encoding="utf-8",
            )
            utilization = Path(directory) / "util.rpt"
            utilization.write_text(
                "| fpga_top | (top) | 100 | 90 | 0 | 0 | 200 | 4 | 0 | 2 |\n",
                encoding="utf-8",
            )
            timing = parse_timing_summary(summary)
            resources = parse_utilization(utilization)
        self.assertEqual(timing["wns_ns"], -1.25)
        self.assertEqual(timing["hold_failing_endpoints"], 2)
        self.assertEqual(resources["total_luts"], 100)
        self.assertEqual(resources["dsp"], 2)


if __name__ == "__main__":
    unittest.main()
