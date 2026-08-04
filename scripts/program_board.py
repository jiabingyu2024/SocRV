from __future__ import annotations

import argparse
import subprocess

from build_software import PROFILES
from lib.repo import repo_path
from run_vivado import find_vivado


def main() -> int:
    parser = argparse.ArgumentParser(description="Program the Kintex-7 board with an existing SocRV bitstream.")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--server", default="localhost:3121")
    args = parser.parse_args()
    bitstream = repo_path(
        "build", "vivado", f"kintex7-{args.profile}", "project",
        "socrv.runs", "impl_1", "fpga_top.bit",
    )
    if not bitstream.exists():
        parser.error(f"bitstream is missing: {bitstream}")
    command = [
        str(find_vivado()),
        "-mode",
        "batch",
        "-source",
        str(repo_path("fpga", "boards", "kintex7_competition", "tcl", "program.tcl")),
        "-tclargs",
        str(bitstream),
        args.server,
    ]
    return subprocess.run(command, cwd=repo_path("build"), check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
