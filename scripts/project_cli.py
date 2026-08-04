from __future__ import annotations

import argparse


HELP = """SocRV project entry points

Foundation:
  make env-check          detect WSL, Verilator, RISC-V GCC and Vivado
  make doctor             verbose environment report
  make deps               fetch pinned external source dependencies
  make deps-check         verify fetched dependency commits
  make soc-contract       regenerate BSP headers/linker constants
  make isa-data           build data/isa from pinned official riscv-tests
  make isa-data-check     validate ISA data hashes and current Memory Map
  make isa-regression     run all selected RV32UI tests on Verilator
  make validate-schemas   validate all JSON schemas
  make test-scripts       run project-script unit tests
  make check              schemas, contracts, filelists and WSL RTL lint

Software and simulation:
  make software-smoke     build bare-metal ELF and CODE/DATA images
  make software-trap-timer build the trap/timer BSP acceptance image
  make software-rtthread  build pinned RT-Thread ELF and images
  make software-coremark  build the formal bare-metal CoreMark FPGA image
  make coremark-smoke     build the short CoreMark functional image
  make coremark-rtthread  build the RT-Thread CoreMark image
  make sim-smoke          run the complete bare-metal SoC simulation
  make sim-trap-timer     verify ecall return and machine timer interrupt
  make sim-rtthread       run RT-Thread on the demo core
  make sim-coremark-smoke run short CoreMark and verify its reference CRC
  make sim-coremark-rtthread run CoreMark through RT-Thread
  make regression         run the controlled smoke testlist

FPGA:
  make fpga-bitstream PROFILE=smoke  synthesize, implement and write .bit
  make fpga-bitstream PROFILE=coremark-baremetal  build formal CoreMark image
  make fpga-check PROFILE=smoke      gate existing timing/DRC/bitstream
  make fpga-program PROFILE=smoke    program a connected Kintex-7 board
  make release PROFILE=smoke         package ELF, images, bitstream and reports
  make release-check PROFILE=smoke   verify release hashes

Scoped cleanup:
  make clean-software | clean-images | clean-sim | clean-regression | clean-fpga
  make clean              remove only build/ generated artifacts

Common variables:
  PYTHON=<path>            Python used by project scripts
  JOBS=<n>                 parallel build jobs (used by later stages)
  PROFILE=<software-profile> software/simulation profile
  SUITE=smoke|coremark      controlled regression suite
  TRACE=0|1                enable VCD for simulation targets
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
