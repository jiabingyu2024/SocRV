from __future__ import annotations

import argparse


HELP = """SocRV project entry points

Daily CPU iteration:
  make sim-smoke
      Fast bare-metal SoC sanity test.
  make sim-isa ISA_GATE=current
      Fast ISA gate for the instructions implemented by the current core.
  make sim-rtthread
      Boot RT-Thread and verify scheduler/timer/basic BSP behavior.
  make sim-msh
      Verify help, ps and uptime on the exact FPGA RT-Thread/CoreMark image.
  make sim-coremark COREMARK_ITERATIONS=3
      Inject `coremark 3` through the real UART RX and collect CRC/timing data.
  make sim-quick
      Run the four checks above in sequence.
  make sim-full
      Run RV32UI/RV32MI/RV32UM, RT-Thread and CoreMark 10 milestone checks.
  make diff-smoke
      Lockstep the bare-metal smoke image against pinned Spike.
  make diff-isa ISA_GATE=current
      Run the selected riscv-tests gate with retirement-level Spike DiffTest.
  make diff-rtthread
      Boot RT-Thread with explicit MMIO/interrupt synchronization to Spike.
  make diff-replay RESULT=<result.json> TRACE=1
      Reproduce the first architectural mismatch with trace artifacts.

Software:
  make deps
      Clone or update pinned RT-Thread, CoreMark, riscv-tests, Spike and
      the minimal Ibex co-simulation adapter.
  make difftest-build
      Build pinned Spike locally and the separate Verilator DiffTest model.
  make difftest-selftest
      Inject known commit faults and verify ORDER/PC/GPR/MEM diagnosis.
  make software-fpga
      Build the unified RT-Thread + FinSH + CoreMark board image.
  make software PROFILE=<name>
      Build one explicit software profile.

FPGA (these commands invoke Vivado):
  make fpga-build BOARD=kintex7_competition|pynq_z2
      Build the selected board's bitstream and checked reports.
  make fpga-check BOARD=<board>
      Check an existing implementation result without rebuilding.
  make fpga-program BOARD=<board>
      Program the existing default bitstream.

Project checks:
  make doctor
      Print detailed tool/dependency diagnostics.
  make check
      Validate contracts, generated ISA data, schemas, scripts, filelists,
      Memory Map and RTL lint.
  make isa-gates
      List current/final-base/fp-single/fp-double/final ISA gates.
  make regression SUITE=smoke|msh|correctness|coremark|performance
      Run the controlled JSON testlist.

Useful variables:
  BOARD=kintex7_competition|pynq_z2
  CORE_MHZ=100 (Kintex-7 default; PYNQ-Z2 is fixed at 50 MHz)
  PROFILE=rtthread-coremark (Kintex-7 default; PYNQ-Z2 defaults to rtthread)
  ISA_GATE=current|final-base|fp-single|fp-double|final
  COREMARK_ITERATIONS=3
  TRACE=0|1
  DIFFTEST=0|1
  DIFFTEST_MODE=ram-strict|soc-mmio
  JOBS=4

Generated files are under build/. Use scoped clean targets where possible:
  make clean-software | clean-images | clean-sim | clean-regression | clean-fpga
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("help")
    message_parser = subparsers.add_parser("message")
    message_parser.add_argument("text")
    args = parser.parse_args()

    if args.command == "help":
        print(HELP.rstrip())
    else:
        print(args.text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
