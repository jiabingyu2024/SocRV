from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

from build_software import PROFILES, build_profile
from lib.hashing import sha256_file, sha256_text
from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path
from lib.wsl import bash, in_repo


CPP_SOURCES = [
    "tb/cpp/common/sim_config.cpp",
    "tb/cpp/common/uart_decoder.cpp",
    "tb/cpp/common/uart_stimulus.cpp",
    "tb/cpp/common/perf_stats.cpp",
    "tb/cpp/common/sim_result.cpp",
    "tb/cpp/common/sim_control.cpp",
    "tb/cpp/adapter/soc_dut_adapter.cpp",
    "tb/cpp/soc_main.cpp",
]

DEFAULT_CYCLES = {
    "smoke": 200_000,
    "trap-timer": 500_000,
    "rtthread": 2_000_000,
    "coremark-smoke": 50_000_000,
    "rtthread-coremark": 30_000_000,
}

DEFAULT_TESTS = {
    "smoke": "baremetal-smoke",
    "trap-timer": "baremetal-trap-timer",
    "rtthread": "rtthread-smoke",
    "coremark-smoke": "coremark-baremetal-functional",
    "rtthread-coremark": "rtthread-coremark-command",
}

BENCHMARK_ITERATIONS = {
    "coremark-smoke": 1,
    "rtthread-coremark": 3,
}


def filelist_inputs(path: Path, seen: set[Path] | None = None) -> set[Path]:
    if seen is None:
        seen = set()
    path = path.resolve()
    if path in seen:
        return seen
    if not path.is_file():
        raise RuntimeError(f"filelist input is missing: {path}")
    seen.add(path)
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("-f "):
            include = repo_path(*Path(line[3:].strip()).parts)
            filelist_inputs(include, seen)
        elif not line.startswith("-") and not line.startswith("+"):
            source = repo_path(*Path(line).parts).resolve()
            if not source.is_file():
                raise RuntimeError(f"filelist source is missing: {source}")
            seen.add(source)
    return seen


def model_inputs() -> list[Path]:
    inputs = filelist_inputs(repo_path("sim", "filelists", "soc_verilator.f"))
    inputs.add(repo_path("sim", "verilator", "common_flags.f").resolve())
    for relative in CPP_SOURCES:
        inputs.add(repo_path(*Path(relative).parts).resolve())
    for header in sorted(repo_path("tb", "cpp").rglob("*.h")):
        inputs.add(header.resolve())
    return sorted(inputs)


def verilator_version() -> str:
    result = bash(
        in_repo(repo_path(), ["verilator", "--version"]),
        timeout=30,
        check=False,
    )
    if not result.ok:
        raise RuntimeError("cannot query Verilator version")
    return result.stdout.strip()


def desired_model_manifest() -> dict[str, object]:
    entries = [
        {
            "path": path.relative_to(repo_path()).as_posix(),
            "sha256": sha256_file(path),
        }
        for path in model_inputs()
    ]
    version = verilator_version()
    fingerprint = sha256_text(
        json.dumps(
            {
                "top": "soc_sim_top",
                "version": version,
                "inputs": entries,
            },
            sort_keys=True,
        )
    )
    return {
        "schema_version": 1,
        "kind": "verilator_model_build",
        "target": "soc",
        "top": "soc_sim_top",
        "verilator": version,
        "fingerprint": fingerprint,
        "inputs": entries,
        "cpp_sources": CPP_SOURCES,
    }


def model_paths() -> tuple[Path, Path]:
    build_root = repo_path("build", "verilator", "soc")
    return (
        build_root / "obj_dir" / "soc_sim",
        build_root / "build_manifest.json",
    )


def model_is_current(desired: dict[str, object]) -> bool:
    executable, manifest_path = model_paths()
    if not executable.is_file() or not manifest_path.is_file():
        return False
    try:
        actual = read_json(manifest_path)
    except (OSError, ValueError):
        return False
    return actual.get("fingerprint") == desired["fingerprint"]


def build_model(*, force: bool = False) -> None:
    desired = desired_model_manifest()
    if not force and model_is_current(desired):
        print("Verilator model is current")
        return
    object_dir = repo_path("build", "verilator", "soc", "obj_dir")
    if object_dir.exists():
        shutil.rmtree(object_dir)
    object_dir.mkdir(parents=True, exist_ok=True)
    argv = [
        "verilator",
        "-f",
        "sim/verilator/common_flags.f",
        "--top-module",
        "soc_sim_top",
        "-f",
        "sim/filelists/soc_verilator.f",
        *CPP_SOURCES,
        "--Mdir",
        "build/verilator/soc/obj_dir",
        "-o",
        "soc_sim",
        "-CFLAGS",
        (
            "-std=c++17 -O2 "
            "-I../../../../tb/cpp/common "
            "-I../../../../tb/cpp/adapter"
        ),
    ]
    result = bash(in_repo(repo_path(), argv), timeout=240, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result.ok:
        raise RuntimeError("Verilator model build failed")
    executable, manifest_path = model_paths()
    if not executable.is_file():
        raise RuntimeError("Verilator build produced no executable")
    write_json_atomic(manifest_path, desired)


def ensure_model_current() -> None:
    desired = desired_model_manifest()
    if not model_is_current(desired):
        raise RuntimeError(
            "Verilator model is missing or stale; rerun without --no-rtl-build"
        )


def relative_to_repo(path: Path) -> str:
    return path.resolve().relative_to(repo_path().resolve()).as_posix()


def safe_test_name(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.-]+", "_", name)


def performance_arguments(
    enabled: bool,
    iterations: int,
) -> list[str]:
    if not enabled:
        return []
    contract = read_json(repo_path("data", "soc", "software_contract.json"))
    test_status = contract["test_status"]
    return [
        "--perf-start-code",
        test_status["perf_start_magic"],
        "--perf-stop-code",
        test_status["perf_stop_magic"],
        "--benchmark-iterations",
        str(iterations),
        "--soc-hz",
        str(contract["clocks"]["soc_hz"]),
    ]


def run_image(
    image_dir: Path,
    test_name: str,
    max_cycles: int,
    *,
    rebuild_model: bool,
    trace: bool,
    require_pass: bool = True,
    profile: str = "",
    seed: int = 1,
    performance: bool = False,
    benchmark_iterations: int = 0,
    reproduce: str = "",
    wall_timeout: int = 600,
    uart_command: str = "",
    uart_start_cycle: int = 900_000,
) -> Path:
    if rebuild_model:
        build_model()
    else:
        ensure_model_current()

    executable, _manifest = model_paths()
    for name in ("code.mem", "data.mem", "image.json"):
        if not (image_dir / name).exists():
            raise RuntimeError(f"image file is missing: {image_dir / name}")

    safe_name = safe_test_name(test_name)
    result_path = repo_path("build", "result", "soc", f"{safe_name}.json")
    log_path = repo_path("build", "log", "soc", f"{safe_name}.log")
    wave_path = (
        repo_path("build", "wave", "soc", f"{safe_name}.vcd")
        if trace
        else None
    )
    result_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if wave_path:
        wave_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.unlink(missing_ok=True)

    if not reproduce:
        reproduce = (
            f"python -B scripts/run_verilator.py --profile {profile} "
            f"--test {test_name} --max-cycles {max_cycles} "
            "--no-rtl-build --no-software-build"
        )
        if seed != 1:
            reproduce += f" --seed {seed}"
        if performance:
            reproduce += (
                f" --benchmark-iterations {benchmark_iterations}"
            )
        if uart_command:
            reproduce += (
                f" --uart-command {json.dumps(uart_command)}"
                f" --uart-start-cycle {uart_start_cycle}"
            )
        if wall_timeout != 600:
            reproduce += f" --wall-timeout {wall_timeout}"
        if trace:
            reproduce += " --trace"

    argv = [
        relative_to_repo(executable),
        f"+code_mem={relative_to_repo(image_dir / 'code.mem')}",
        f"+data_mem={relative_to_repo(image_dir / 'data.mem')}",
        "--test",
        test_name,
        "--profile",
        profile,
        "--seed",
        str(seed),
        "--max-cycles",
        str(max_cycles),
        "--result",
        relative_to_repo(result_path),
        "--log",
        relative_to_repo(log_path),
        "--image-manifest",
        relative_to_repo(image_dir / "image.json"),
        "--reproduce",
        reproduce,
        *performance_arguments(performance, benchmark_iterations),
    ]
    if uart_command:
        contract = read_json(
            repo_path("data", "soc", "software_contract.json")
        )
        cycles_per_bit = (
            int(contract["clocks"]["soc_hz"])
            // int(contract["clocks"]["uart_baud"])
        )
        argv.extend(
            [
                "--uart-command",
                uart_command + "\r",
                "--uart-start-cycle",
                str(uart_start_cycle),
                "--uart-cycles-per-bit",
                str(cycles_per_bit),
            ]
        )
    if wave_path:
        argv.extend(["--trace", relative_to_repo(wave_path)])
    command = in_repo(repo_path(), argv)
    result = bash(command, timeout=wall_timeout, check=False)
    combined_log = (
        f"COMMAND: {reproduce}\n"
        f"IMAGE: {relative_to_repo(image_dir / 'image.json')}\n"
        f"SEED: {seed}\n\n"
        f"{result.stdout}"
        f"{result.stderr}"
    )
    log_path.write_text(combined_log, encoding="utf-8", newline="\n")
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result_path.is_file():
        raise RuntimeError(
            f"simulation produced no result (exit {result.returncode}); "
            f"see {log_path}"
        )

    document = read_json(result_path)
    schema = read_json(repo_path("data", "schemas", "result.schema.json"))
    Draft202012Validator(schema).validate(document)
    exit_consistent = (
        (document["status"] == "PASS" and result.returncode == 0)
        or (document["status"] != "PASS" and result.returncode != 0)
    )
    if not exit_consistent:
        raise RuntimeError(
            "simulation JSON status and process exit code disagree"
        )
    if require_pass and document["status"] != "PASS":
        raise RuntimeError(
            f"simulation {document['status']}: {document['exit_reason']}; "
            f"see {log_path}"
        )
    return result_path


def run_profile(
    profile: str,
    test_name: str,
    max_cycles: int,
    *,
    rebuild_model: bool,
    build_sw: bool,
    trace: bool,
    seed: int = 1,
    performance: bool | None = None,
    benchmark_iterations: int | None = None,
    wall_timeout: int = 600,
    require_pass: bool = True,
    uart_command: str = "",
    uart_start_cycle: int = 900_000,
) -> Path:
    if build_sw:
        _, image_dir = build_profile(profile)
    else:
        image_dir = repo_path("build", "images", profile)
    if performance is None:
        performance = profile in BENCHMARK_ITERATIONS
    if benchmark_iterations is None:
        benchmark_iterations = BENCHMARK_ITERATIONS.get(profile, 0)
    return run_image(
        image_dir,
        test_name,
        max_cycles,
        rebuild_model=rebuild_model,
        trace=trace,
        profile=profile,
        seed=seed,
        performance=performance,
        benchmark_iterations=benchmark_iterations,
        wall_timeout=wall_timeout,
        require_pass=require_pass,
        uart_command=uart_command,
        uart_start_cycle=uart_start_cycle,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build and run the SocRV Verilator model through WSL."
    )
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--test")
    parser.add_argument("--max-cycles", type=int)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--benchmark-iterations", type=int)
    parser.add_argument("--uart-command")
    parser.add_argument("--uart-start-cycle", type=int, default=900_000)
    parser.add_argument("--wall-timeout", type=int, default=600)
    parser.add_argument("--no-rtl-build", action="store_true")
    parser.add_argument("--no-software-build", action="store_true")
    parser.add_argument("--trace", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--force-rtl-build", action="store_true")
    args = parser.parse_args()
    try:
        if args.build_only:
            build_model(force=args.force_rtl_build)
            return 0
        if args.profile not in DEFAULT_CYCLES and args.max_cycles is None:
            parser.error(
                f"profile {args.profile} is build-only unless "
                "--max-cycles is supplied"
            )
        test_name = args.test or DEFAULT_TESTS.get(
            args.profile,
            f"{args.profile}-run",
        )
        benchmark_iterations = args.benchmark_iterations
        if benchmark_iterations is None:
            benchmark_iterations = BENCHMARK_ITERATIONS.get(args.profile, 0)
        max_cycles = args.max_cycles
        if max_cycles is None and args.profile == "rtthread-coremark":
            max_cycles = 3_000_000 + 3_000_000 * benchmark_iterations
        uart_command = args.uart_command or (
            f"coremark {benchmark_iterations}"
            if args.profile == "rtthread-coremark"
            else ""
        )
        result_path = run_profile(
            args.profile,
            test_name,
            max_cycles or DEFAULT_CYCLES[args.profile],
            rebuild_model=not args.no_rtl_build,
            build_sw=not args.no_software_build,
            trace=args.trace,
            seed=args.seed,
            benchmark_iterations=benchmark_iterations,
            wall_timeout=args.wall_timeout,
            uart_command=uart_command,
            uart_start_cycle=args.uart_start_cycle,
        )
    except (OSError, RuntimeError, ValueError) as error:
        parser.error(str(error))
    print(f"Result: {result_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
