from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

from build_software import PROFILES, build_profile
from check_fpga_reports import check
from lib.repo import repo_path


def find_vivado() -> Path:
    override = os.environ.get("VIVADO")
    candidates = [
        Path(override) if override else None,
        Path(r"D:\AppMajor\xilinx\Vivado\2023.2\bin\vivado.bat"),
        Path(r"D:\Xilinx\Vivado\2023.2\bin\vivado.bat"),
    ]
    for candidate in candidates:
        if candidate and candidate.exists():
            return candidate
    raise ValueError("Vivado batch launcher was not found; set VIVADO")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the Kintex-7 SocRV bitstream with Vivado.")
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILES),
        default="rtthread-coremark",
    )
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    board_path = repo_path(
        "fpga", "boards", "kintex7_competition", "board.json"
    )
    contract_path = repo_path("data", "soc", "software_contract.json")
    board = json.loads(board_path.read_text(encoding="utf-8"))
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    board_hz = int(board["clock"]["soc_frequency_hz"])
    contract_hz = int(contract["clocks"]["soc_hz"])
    if board_hz != contract_hz:
        parser.error(
            f"board clock {board_hz} Hz does not match software contract "
            f"{contract_hz} Hz"
        )
    frequency_tag = (
        f"{board_hz // 1_000_000}mhz"
        if board_hz % 1_000_000 == 0
        else f"{board_hz}hz"
    )
    build_root = repo_path(
        "build", "vivado", f"kintex7-{frequency_tag}-{args.profile}"
    )
    if args.check_only:
        check(build_root)
        return 0

    _, image_dir = build_profile(args.profile)
    build_root.mkdir(parents=True, exist_ok=True)
    project_dir = build_root / "project"
    command = [
        str(find_vivado()),
        "-mode",
        "batch",
        "-source",
        str(repo_path("fpga", "boards", "kintex7_competition", "tcl", "build_bitstream.tcl")),
        "-tclargs",
        str(project_dir),
        str(image_dir / "code.mem"),
        str(image_dir / "data.mem"),
        str(args.jobs),
    ]
    completed = subprocess.run(command, cwd=build_root, check=False)
    if completed.returncode != 0:
        parser.error(f"Vivado failed with exit code {completed.returncode}")
    check(build_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
