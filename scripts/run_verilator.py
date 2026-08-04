from __future__ import annotations

import argparse
import sys
from pathlib import Path

from build_software import build_profile
from build_software import PROFILES
from lib.repo import repo_path
from lib.wsl import bash, in_repo


DEFAULT_CYCLES = {
    "smoke": 200_000,
    "trap-timer": 500_000,
    "rtthread": 2_000_000,
    "coremark-smoke": 50_000_000,
    "coremark-rtthread": 60_000_000,
}

DEFAULT_TESTS = {
    "smoke": "baremetal-smoke",
    "trap-timer": "baremetal-trap-timer",
    "rtthread": "rtthread-smoke",
    "coremark-smoke": "coremark-baremetal-functional",
    "coremark-rtthread": "coremark-rtthread-functional",
}


def build_model() -> None:
    object_dir = repo_path("build", "verilator", "soc", "obj_dir")
    object_dir.mkdir(parents=True, exist_ok=True)
    argv = [
        "verilator",
        "-f",
        "sim/verilator/common_flags.f",
        "--top-module",
        "soc_sim_top",
        "-f",
        "sim/filelists/soc_verilator.f",
        "tb/harness/verilator/soc_main.cpp",
        "--Mdir",
        "build/verilator/soc/obj_dir",
        "-o",
        "soc_sim",
        "-CFLAGS",
        "-std=c++17 -O2",
    ]
    result = bash(in_repo(repo_path(), argv), timeout=180, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result.ok:
        raise RuntimeError("Verilator model build failed")


def relative_to_repo(path: Path) -> str:
    return path.resolve().relative_to(repo_path().resolve()).as_posix()


def run_image(
    image_dir: Path,
    test_name: str,
    max_cycles: int,
    *,
    rebuild_model: bool,
    trace: bool,
    run_dir: Path | None = None,
    require_pass: bool = True,
) -> Path:
    if rebuild_model:
        build_model()

    executable = repo_path("build", "verilator", "soc", "obj_dir", "soc_sim")
    if not executable.exists():
        raise RuntimeError(f"Verilator executable is missing: {executable}")
    for name in ("code.mem", "data.mem"):
        if not (image_dir / name).exists():
            raise RuntimeError(f"image file is missing: {image_dir / name}")

    if run_dir is None:
        run_dir = repo_path("build", "verilator", "soc", "run", test_name)
    run_dir.mkdir(parents=True, exist_ok=True)
    result_path = run_dir / "result.json"
    argv = [
        "build/verilator/soc/obj_dir/soc_sim",
        f"+code_mem={relative_to_repo(image_dir / 'code.mem')}",
        f"+data_mem={relative_to_repo(image_dir / 'data.mem')}",
        "--test",
        test_name,
        "--max-cycles",
        str(max_cycles),
        "--result",
        relative_to_repo(result_path),
    ]
    if trace:
        argv.extend(["--trace", relative_to_repo(run_dir / "wave.vcd")])
    result = bash(in_repo(repo_path(), argv), timeout=600, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result_path.is_file():
        raise RuntimeError(
            f"simulation produced no result (exit {result.returncode})"
        )
    if require_pass and not result.ok:
        raise RuntimeError(f"simulation failed with exit code {result.returncode}")
    return result_path


def run_profile(
    profile: str,
    test_name: str,
    max_cycles: int,
    *,
    rebuild_model: bool,
    build_sw: bool,
    trace: bool,
) -> Path:
    if build_sw:
        _, image_dir = build_profile(profile)
    else:
        image_dir = repo_path("build", "images", profile)
    return run_image(
        image_dir,
        test_name,
        max_cycles,
        rebuild_model=rebuild_model,
        trace=trace,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build and run the SocRV Verilator model through WSL.")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--test")
    parser.add_argument("--max-cycles", type=int)
    parser.add_argument("--no-rtl-build", action="store_true")
    parser.add_argument("--no-software-build", action="store_true")
    parser.add_argument("--trace", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    args = parser.parse_args()
    try:
        if args.build_only:
            build_model()
            return 0
        if args.profile not in DEFAULT_CYCLES and args.max_cycles is None:
            parser.error(
                f"profile {args.profile} is build-only unless --max-cycles is supplied"
            )
        test_name = args.test or DEFAULT_TESTS.get(
            args.profile,
            f"{args.profile}-run",
        )
        result_path = run_profile(
            args.profile,
            test_name,
            args.max_cycles or DEFAULT_CYCLES[args.profile],
            rebuild_model=not args.no_rtl_build,
            build_sw=not args.no_software_build,
            trace=args.trace,
        )
    except (OSError, RuntimeError) as error:
        parser.error(str(error))
    print(f"Result: {result_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
