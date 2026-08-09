from __future__ import annotations

import argparse
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
    parser.add_argument(
        "--core-mhz", type=int, choices=(100, 150, 200), default=100,
        help="core clock target; periph_clk remains 50 MHz",
    )
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    build_root = repo_path(
        "build", "vivado", f"kintex7-{args.profile}-{args.core_mhz}mhz"
    )
    if args.check_only:
        check(build_root)
        return 0

    _, image_dir = build_profile(args.profile)
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
        str(repo_path("fpga", "boards", "kintex7_competition", "tcl", "build_bitstream.tcl")),
        "-tclargs",
        str(project_dir),
        str(image_dir / "code_lo.mem"),
        str(image_dir / "code_hi.mem"),
        str(image_dir / "data.mem"),
        str(args.jobs),
    ]
    divide = {100: "10.0", 150: "6.6666666667", 200: "5.0"}[args.core_mhz]
    env = dict(os.environ)
    env["SOCRV_CORE_DIVIDE"] = divide
    completed = subprocess.run(command, cwd=build_root, check=False, env=env)
    if completed.returncode != 0:
        parser.error(f"Vivado failed with exit code {completed.returncode}")
    check(build_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
