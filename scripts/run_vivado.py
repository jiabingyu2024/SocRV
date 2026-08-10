from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from build_software import PROFILES, build_profile
from check_fpga_reports import check
from lib.repo import repo_path


STAGES = ("synth", "impl", "bitstream")


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
    parser = argparse.ArgumentParser(description="Build the Kintex-7 SocRV design with Vivado.")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="rtthread-coremark")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument(
        "--core-mhz",
        type=int,
        choices=(100, 125, 150, 175, 200, 250),
        default=100,
        help="EH1 TCM SoC target clock in MHz (MMCM VCO is fixed at 1 GHz)",
    )
    parser.add_argument("--stage", choices=STAGES, default="bitstream", help="stop after synthesis, implementation, or bitstream")
    parser.add_argument(
        "--synth-only",
        action="store_true",
        help="compatibility alias for --stage synth",
    )
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument(
        "--all-violations",
        action="store_true",
        help="export every violating setup/hold endpoint in addition to top paths",
    )
    parser.add_argument(
        "--no-software-build",
        action="store_true",
        help="reuse build/images/<profile> instead of rebuilding the fixed software image",
    )
    parser.add_argument(
        "--no-analyze",
        action="store_true",
        help="do not generate build-root/analysis/timing_summary.{json,md,csv}",
    )
    parser.add_argument(
        "--run-tag",
        help="optional filesystem-safe suffix used to preserve multiple runs at one frequency",
    )
    args = parser.parse_args()
    if args.synth_only:
        if args.stage != "bitstream":
            parser.error("--synth-only cannot be combined with --stage")
        args.stage = "synth"
    if args.run_tag and not all(char.isalnum() or char in "-_" for char in args.run_tag):
        parser.error("--run-tag may contain only letters, digits, '-' and '_'")
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    run_suffix = f"-{args.run_tag}" if args.run_tag else ""
    build_root = repo_path(
        "build", "vivado", f"kintex7-{args.profile}-{args.core_mhz}mhz{run_suffix}"
    )
    if args.check_only:
        check(build_root)
        return 0

    if args.no_software_build:
        image_dir = repo_path("build", "images", args.profile)
        if not (image_dir / "image.json").is_file():
            parser.error(f"software image is missing; omit --no-software-build: {image_dir / 'image.json'}")
    else:
        _, image_dir = build_profile(args.profile)
    build_root.mkdir(parents=True, exist_ok=True)
    project_dir = build_root / "project"
    stale_artifacts = [
        build_root / "result.json",
        project_dir / "socrv.runs" / "impl_1" / "fpga_top.bit",
        project_dir / "reports" / "post_impl_timing_summary.rpt",
        project_dir / "reports" / "post_impl_drc.rpt",
        build_root / "analysis" / "timing_summary.json",
        build_root / "analysis" / "timing_summary.md",
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
        str(image_dir),
        str(args.jobs),
        args.stage,
        "all" if args.all_violations else "top",
    ]
    divide = {
        100: "10.0",
        125: "8.0",
        150: "6.625",
        175: "5.75",
        200: "5.0",
        250: "4.0",
    }[args.core_mhz]
    env = dict(os.environ)
    env["SOCRV_CORE_DIVIDE"] = divide
    env["SOCRV_CORE_HZ"] = str(args.core_mhz * 1_000_000)
    completed = subprocess.run(command, cwd=build_root, check=False, env=env)
    if completed.returncode != 0:
        parser.error(f"Vivado failed with exit code {completed.returncode}")

    if not args.no_analyze:
        analyze_command = [
            sys.executable,
            "-B",
            str(repo_path("scripts", "analyze_vivado_reports.py")),
            "--build-root",
            str(build_root),
            "--stage",
            "impl" if args.stage != "synth" else "synth",
        ]
        analyzed = subprocess.run(analyze_command, cwd=repo_path(), check=False)
        if analyzed.returncode != 0:
            parser.error(f"Vivado report analysis failed with exit code {analyzed.returncode}")
    if args.stage == "bitstream":
        check(build_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
