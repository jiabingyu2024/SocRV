from __future__ import annotations

import argparse
import subprocess

from build_software import PROFILES
from lib.fpga import BOARDS, fpga_build_root, resolve_core_mhz
from lib.repo import repo_path
from run_vivado import find_vivado


def main() -> int:
    parser = argparse.ArgumentParser(description="Program an FPGA board with an existing SocRV bitstream.")
    parser.add_argument(
        "--board",
        choices=sorted(BOARDS),
        default="kintex7_competition",
    )
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILES),
        default=None,
        help="software profile; defaults to rtthread-coremark for Kintex-7 and rtthread for PYNQ-Z2",
    )
    parser.add_argument("--core-mhz", type=int, default=None)
    parser.add_argument("--server", default="localhost:3121")
    args = parser.parse_args()
    board = BOARDS[args.board]
    profile = args.profile or board.default_profile
    try:
        core_mhz = resolve_core_mhz(board, args.core_mhz)
    except ValueError as error:
        parser.error(str(error))
    bitstream = (
        fpga_build_root(board, profile, core_mhz)
        / "project"
        / "socrv.runs"
        / "impl_1"
        / "fpga_top.bit"
    )
    if args.board == "kintex7_competition" and args.core_mhz is None:
        # Older release builds used a frequency-less programming path. Prefer
        # it when present so the original command remains backward compatible,
        # then fall back to the path produced by the current build command.
        legacy_bitstream = repo_path(
            "build", "vivado", f"kintex7-{profile}", "project",
            "socrv.runs", "impl_1", "fpga_top.bit",
        )
        if legacy_bitstream.exists():
            bitstream = legacy_bitstream
    if not bitstream.exists():
        parser.error(f"bitstream is missing: {bitstream}")
    command = [
        str(find_vivado()),
        "-mode",
        "batch",
        "-source",
        str(board.tcl_dir / "program.tcl"),
        "-tclargs",
        str(bitstream),
        args.server,
    ]
    return subprocess.run(command, cwd=repo_path("build"), check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
