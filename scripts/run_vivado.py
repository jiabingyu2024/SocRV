from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

from build_software import PROFILES, build_profile
from check_fpga_reports import check
from lib.fpga import BOARDS, fpga_build_root, resolve_core_mhz
from lib.repo import repo_path


def find_vivado() -> Path:
    override = os.environ.get("VIVADO")
    candidates = [
        Path(override) if override else None,
        Path(r"D:\Xilinx\Vivado\2023.2\bin\vivado.bat"),
        Path(r"D:\AppMajor\xilinx\Vivado\2023.2\bin\vivado.bat"),
    ]
    for candidate in candidates:
        if candidate and candidate.exists():
            return candidate
    raise ValueError("Vivado batch launcher was not found; set VIVADO")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a SocRV FPGA bitstream with Vivado.")
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
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument(
        "--core-mhz",
        type=int,
        default=None,
        help="SoC core clock; defaults to 100 for Kintex-7 and 50 for PYNQ-Z2",
    )
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    board = BOARDS[args.board]
    profile = args.profile or board.default_profile
    try:
        core_mhz = resolve_core_mhz(board, args.core_mhz)
    except ValueError as error:
        parser.error(str(error))
    build_root = fpga_build_root(board, profile, core_mhz)
    if args.check_only:
        check(build_root, target=board.name)
        return 0

    _, image_dir = build_profile(profile)
    build_root.mkdir(parents=True, exist_ok=True)
    project_dir = build_root / "project"
    # A failed or interrupted rebuild must not leave a previous PASS result or
    # bitstream looking current. Vivado recreates each of these sign-off files.
    stale_artifacts = [
        build_root / "result.json",
        project_dir / "socrv.runs" / "impl_1" / "fpga_top.bit",
        project_dir / "reports" / "post_impl_timing_summary.rpt",
        project_dir / "reports" / "post_impl_drc.rpt",
    ]
    for artifact in stale_artifacts:
        artifact.unlink(missing_ok=True)
    command = [
        str(find_vivado()),
        "-mode",
        "batch",
        "-source",
        str(board.tcl_dir / "build_bitstream.tcl"),
        "-tclargs",
        str(project_dir),
        str(image_dir),
        str(args.jobs),
    ]
    env = dict(os.environ)
    if board.mmcm:
        # Keep the MMCM VCO legal and the independent peripheral clock at
        # 50 MHz for every supported Kintex-7 sweep point.
        clock_mult, divide, peripheral_divide = board.mmcm[core_mhz]
        env["SOCRV_CLOCK_MULT"] = clock_mult
        env["SOCRV_CORE_DIVIDE"] = divide
        env["SOCRV_PERIPHERAL_DIVIDE"] = peripheral_divide
        env["SOCRV_CORE_HZ"] = str(core_mhz * 1_000_000)
    completed = subprocess.run(command, cwd=build_root, check=False, env=env)
    if completed.returncode != 0:
        parser.error(f"Vivado failed with exit code {completed.returncode}")
    check(build_root, target=board.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
