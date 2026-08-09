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
from lib.wsl import bash, in_repo, to_wsl_path


CPP_SOURCES = [
    "tb/cpp/common/sim_config.cpp",
    "tb/cpp/common/uart_decoder.cpp",
    "tb/cpp/common/uart_checker.cpp",
    "tb/cpp/common/uart_stimulus.cpp",
    "tb/cpp/common/perf_stats.cpp",
    "tb/cpp/common/sim_result.cpp",
    "tb/cpp/common/sim_control.cpp",
    "tb/cpp/difftest/difftest_checker.cpp",
    "tb/cpp/difftest/spike_ref_model.cpp",
    "tb/cpp/adapter/soc_dut_adapter.cpp",
    "tb/cpp/soc_main.cpp",
]
SPIKE_COSIM_SOURCE = "build/reference/spike/ibex_cosim/spike_cosim.cc"
SPIKE_BUILD_MANIFEST = repo_path(
    "build", "reference", "spike", "build_manifest.json"
)

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

DEFAULT_CHECKERS = {
    "smoke": "test-status-and-uart",
    "trap-timer": "test-status",
    "rtthread": "test-status-and-uart",
    "coremark-smoke": "coremark-crc-and-test-status",
    "rtthread-coremark":
        "uart-command-coremark-crc-test-status-and-perf-window",
}

DEFAULT_UART_EXPECT = {
    "smoke": ("SocRV smoke PASS",),
    "coremark-smoke": ("Correct operation validated",),
    "rtthread": (
        "Thread Nano Operating System",
        "SocRV RT-Thread boot",
        "msh >",
    ),
    "rtthread-coremark": (
        "SocRV RT-Thread ready",
        "msh >",
    ),
}

DEFAULT_UART_REJECT = {
    "coremark-smoke": (
        "ERROR! list crc",
        "ERROR! matrix crc",
        "ERROR! state crc",
        "Errors detected",
        "Cannot validate operation",
    ),
    "rtthread-coremark": (
        "ERROR! list crc",
        "ERROR! matrix crc",
        "ERROR! state crc",
        "Cannot validate operation",
        "SocRV CoreMark CRC check FAIL",
    ),
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


def model_inputs(difftest: bool = False) -> list[Path]:
    inputs = filelist_inputs(repo_path("sim", "filelists", "soc_verilator.f"))
    inputs.add(repo_path("sim", "verilator", "common_flags.f").resolve())
    for relative in CPP_SOURCES:
        inputs.add(repo_path(*Path(relative).parts).resolve())
    for header in sorted(repo_path("tb", "cpp").rglob("*.h")):
        inputs.add(header.resolve())
    if difftest:
        for path in (
            SPIKE_BUILD_MANIFEST,
            repo_path(*Path(SPIKE_COSIM_SOURCE).parts),
            repo_path(
                "build", "reference", "spike", "ibex_cosim", "spike_cosim.h"
            ),
            repo_path(
                "build", "reference", "spike", "ibex_cosim", "cosim.h"
            ),
            repo_path(
                "sim", "reference", "spike", "dependency.lock.json"
            ),
            repo_path(
                "sim", "reference", "ibex-cosim", "dependency.lock.json"
            ),
            repo_path(
                "sim",
                "reference",
                "ibex-cosim",
                "socrv_getters.patch",
            ),
        ):
            if not path.is_file():
                raise RuntimeError(
                    "Spike reference model is missing or stale; "
                    "run `make difftest-build`"
                )
            inputs.add(path.resolve())
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


def desired_model_manifest(difftest: bool = False) -> dict[str, object]:
    entries = [
        {
            "path": path.relative_to(repo_path()).as_posix(),
            "sha256": sha256_file(path),
        }
        for path in model_inputs(difftest)
    ]
    version = verilator_version()
    fingerprint = sha256_text(
        json.dumps(
            {
                "top": "soc_sim_top",
                "difftest": difftest,
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
        "difftest": difftest,
        "top": "soc_sim_top",
        "verilator": version,
        "fingerprint": fingerprint,
        "inputs": entries,
        "cpp_sources": CPP_SOURCES,
    }


def model_paths(difftest: bool = False) -> tuple[Path, Path]:
    target = "soc-diff" if difftest else "soc"
    build_root = repo_path("build", "verilator", target)
    return (
        build_root / "obj_dir" / "soc_sim",
        build_root / "build_manifest.json",
    )


def model_is_current(
    desired: dict[str, object],
    difftest: bool = False,
) -> bool:
    executable, manifest_path = model_paths(difftest)
    if not executable.is_file() or not manifest_path.is_file():
        return False
    try:
        actual = read_json(manifest_path)
    except (OSError, ValueError):
        return False
    return actual.get("fingerprint") == desired["fingerprint"]


def build_model(*, force: bool = False, difftest: bool = False) -> None:
    if difftest:
        raise RuntimeError(
            "DiffTest is unavailable for the EH1F integration until a precise "
            "retirement/CSR/memory trace is implemented"
        )
    desired = desired_model_manifest(difftest)
    if not force and model_is_current(desired, difftest):
        print(
            "Verilator DiffTest model is current"
            if difftest
            else "Verilator model is current"
        )
        return
    target = "soc-diff" if difftest else "soc"
    object_dir = repo_path("build", "verilator", target, "obj_dir")
    if object_dir.exists():
        shutil.rmtree(object_dir)
    object_dir.mkdir(parents=True, exist_ok=True)
    cpp_sources = list(CPP_SOURCES)
    cflags = (
        "-std=c++17 -O2 "
        "-I../../../../tb/cpp/common "
        "-I../../../../tb/cpp/adapter "
        "-I../../../../tb/cpp/difftest"
    )
    argv = [
        "verilator",
        "-f",
        "sim/verilator/common_flags.f",
        "--top-module",
        "soc_sim_top",
        "-f",
        "sim/filelists/soc_verilator.f",
        *cpp_sources,
        "--Mdir",
        f"build/verilator/{target}/obj_dir",
        "-o",
        "soc_sim",
        "-CFLAGS",
        cflags,
    ]
    if difftest:
        cpp_sources.append(SPIKE_COSIM_SOURCE)
        argv[argv.index("--Mdir") - 1:argv.index("--Mdir") - 1] = [
            SPIKE_COSIM_SOURCE
        ]
        spike_install = repo_path(
            "build", "reference", "spike", "install"
        )
        spike_cosim = repo_path(
            "build", "reference", "spike", "ibex_cosim"
        )
        install_wsl = to_wsl_path(spike_install)
        cosim_wsl = to_wsl_path(spike_cosim)
        cflags = (
            f"{cflags} -DSOCRV_ENABLE_SPIKE "
            f"-I{install_wsl}/include "
            f"-I{install_wsl}/include/fesvr "
            f"-I{install_wsl}/include/riscv "
            f"-I{install_wsl}/include/softfloat "
            f"-I{cosim_wsl}"
        )
        argv[argv.index("-CFLAGS") + 1] = cflags
        ldflags = (
            f"-Wl,-rpath,{install_wsl}/lib -L{install_wsl}/lib "
            "-Wl,--start-group -lriscv -lsoftfloat -ldisasm "
            "-lfesvr -lfdt -Wl,--end-group "
            "-lboost_regex -lboost_system -pthread -ldl"
        )
        argv.extend(["-LDFLAGS", ldflags])
    result = bash(in_repo(repo_path(), argv), timeout=240, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result.ok:
        raise RuntimeError("Verilator model build failed")
    executable, manifest_path = model_paths(difftest)
    if not executable.is_file():
        raise RuntimeError("Verilator build produced no executable")
    write_json_atomic(manifest_path, desired)


def ensure_model_current(difftest: bool = False) -> None:
    desired = desired_model_manifest(difftest)
    if not model_is_current(desired, difftest):
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
    uart_followup_commands: tuple[str, ...] = (),
    uart_prompt: str = "msh >",
    uart_prompt_timeout: int = 5_000_000,
    checker: str = "test-status",
    uart_expect: tuple[str, ...] = (),
    uart_reject: tuple[str, ...] = (),
    difftest: bool = False,
    difftest_mode: str = "ram-strict",
    difftest_isa: str = "",
    difftest_fault: str = "",
) -> Path:
    if difftest:
        raise RuntimeError(
            "DiffTest is unavailable for the EH1F integration until a precise "
            "retirement/CSR/memory trace is implemented"
        )
    if rebuild_model:
        build_model(difftest=difftest)
    else:
        ensure_model_current(difftest)

    executable, _manifest = model_paths(difftest)
    memory_files = [
        *(f"iccm_lane{lane}.mem" for lane in range(4)),
        *(f"dccm_bank{bank}.mem" for bank in range(8)),
    ]
    for name in (*memory_files, "image.json"):
        if not (image_dir / name).exists():
            raise RuntimeError(f"image file is missing: {image_dir / name}")

    safe_name = safe_test_name(test_name) + ("-diff" if difftest else "")
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
    difftest_log_path = repo_path(
        "build", "log", "difftest", f"{safe_name}.log"
    )
    difftest_trace_path = repo_path(
        "build", "trace", "difftest", f"{safe_name}.jsonl"
    )
    spike_trace_path = repo_path(
        "build", "trace", "difftest", f"{safe_name}.spike.log"
    )
    if difftest:
        difftest_log_path.parent.mkdir(parents=True, exist_ok=True)
        difftest_trace_path.parent.mkdir(parents=True, exist_ok=True)
        difftest_log_path.unlink(missing_ok=True)
        difftest_trace_path.unlink(missing_ok=True)
        spike_trace_path.unlink(missing_ok=True)

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
        if difftest_fault:
            reproduce += f" --difftest-fault {difftest_fault}"
        if uart_command:
            reproduce += (
                f" --uart-command {json.dumps(uart_command)}"
                f" --uart-prompt {json.dumps(uart_prompt)}"
                f" --uart-prompt-timeout {uart_prompt_timeout}"
            )
            for followup in uart_followup_commands:
                reproduce += (
                    " --uart-followup-command " + json.dumps(followup)
                )
        reproduce += f" --checker {checker}"
        for expected in uart_expect:
            reproduce += f" --uart-expect {json.dumps(expected)}"
        for forbidden in uart_reject:
            reproduce += f" --uart-reject {json.dumps(forbidden)}"
        if wall_timeout != 600:
            reproduce += f" --wall-timeout {wall_timeout}"
        if trace:
            reproduce += " --trace"
        if difftest:
            reproduce += (
                f" --difftest --difftest-mode {difftest_mode}"
            )
            if difftest_isa:
                reproduce += f" --difftest-isa {difftest_isa}"

    argv = [
        relative_to_repo(executable),
        *(
            f"+{Path(name).stem}={relative_to_repo(image_dir / name)}"
            for name in memory_files
        ),
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
        "--checker",
        checker,
        *performance_arguments(performance, benchmark_iterations),
    ]
    if difftest:
        image = read_json(image_dir / "image.json")
        memory_map = read_json(
            repo_path("data", "soc", "memory_map.json")
        )
        spike_manifest = read_json(SPIKE_BUILD_MANIFEST)
        selected_isa = difftest_isa or image["isa"]["march"]
        argv.extend(
            [
                "--difftest",
                "--difftest-backend",
                "spike",
                "--difftest-backend-version",
                spike_manifest["spike"]["commit"],
                "--difftest-mode",
                difftest_mode,
                "--difftest-isa",
                selected_isa,
                "--difftest-log",
                relative_to_repo(difftest_log_path),
                "--difftest-trace",
                relative_to_repo(difftest_trace_path),
                "--difftest-reset-pc",
                memory_map["reset_vector"],
                "--difftest-reset-mtvec",
                memory_map["reset_vector"],
            ]
        )
        if trace:
            argv.extend(
                [
                    "--difftest-reference-trace",
                    relative_to_repo(spike_trace_path),
                ]
            )
        image_regions = {
            region["name"]: region for region in image["regions"]
        }
        for name in ("CODE", "DATA"):
            region = memory_map["regions"][name]
            image_region = image_regions[name]
            argv.extend(
                [
                    "--difftest-region",
                    ",".join(
                        [
                            name,
                            region["base"],
                            region["size"],
                            "ram",
                            image_region["file"],
                        ]
                    ),
                ]
            )
        mmio_regions = ["SYSCTRL"]
        if difftest_mode == "soc-mmio":
            mmio_regions.extend(
                (
                    "TIMER",
                    "UART",
                    "GPIO",
                )
            )
        for name in mmio_regions:
            region = memory_map["regions"][name]
            argv.extend(
                [
                    "--difftest-region",
                    ",".join(
                        [
                            name,
                            region["base"],
                            region["size"],
                            "mmio",
                            "-",
                        ]
                    ),
                ]
            )
        if difftest_fault:
            argv.extend(["--difftest-fault", difftest_fault])
    for expected in uart_expect:
        argv.extend(["--uart-expect", expected])
    for forbidden in uart_reject:
        argv.extend(["--uart-reject", forbidden])
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
                uart_command + "\n",
                "--uart-prompt",
                uart_prompt,
                "--uart-prompt-timeout",
                str(uart_prompt_timeout),
                "--uart-cycles-per-bit",
                str(cycles_per_bit),
            ]
        )
        for followup in uart_followup_commands:
            argv.extend(["--uart-followup-command", followup + "\n"])
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
    uart_followup_commands: tuple[str, ...] = (),
    uart_prompt: str = "msh >",
    uart_prompt_timeout: int = 5_000_000,
    checker: str = "",
    uart_expect: tuple[str, ...] | None = None,
    uart_reject: tuple[str, ...] | None = None,
    difftest: bool = False,
    difftest_mode: str = "ram-strict",
    difftest_isa: str = "",
    difftest_fault: str = "",
) -> Path:
    if build_sw:
        _, image_dir = build_profile(profile)
    else:
        image_dir = repo_path("build", "images", profile)
    if performance is None:
        performance = profile in BENCHMARK_ITERATIONS
    if benchmark_iterations is None:
        benchmark_iterations = BENCHMARK_ITERATIONS.get(profile, 0)
    if not checker:
        checker = DEFAULT_CHECKERS.get(profile, "test-status")
    if uart_expect is None:
        uart_expect = DEFAULT_UART_EXPECT.get(profile, ())
    if uart_reject is None:
        uart_reject = DEFAULT_UART_REJECT.get(profile, ())
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
        uart_followup_commands=uart_followup_commands,
        uart_prompt=uart_prompt,
        uart_prompt_timeout=uart_prompt_timeout,
        checker=checker,
        uart_expect=uart_expect,
        uart_reject=uart_reject,
        difftest=difftest,
        difftest_mode=difftest_mode,
        difftest_isa=difftest_isa,
        difftest_fault=difftest_fault,
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
    parser.add_argument("--uart-followup-command", action="append")
    parser.add_argument("--uart-prompt", default="msh >")
    parser.add_argument("--uart-prompt-timeout", type=int, default=5_000_000)
    parser.add_argument("--checker")
    parser.add_argument("--uart-expect", action="append")
    parser.add_argument("--uart-reject", action="append")
    parser.add_argument("--wall-timeout", type=int, default=600)
    parser.add_argument("--no-rtl-build", action="store_true")
    parser.add_argument("--no-software-build", action="store_true")
    parser.add_argument("--trace", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--force-rtl-build", action="store_true")
    parser.add_argument("--difftest", action="store_true")
    parser.add_argument(
        "--difftest-mode",
        choices=("ram-strict", "soc-mmio"),
        default="ram-strict",
    )
    parser.add_argument("--difftest-isa")
    parser.add_argument(
        "--difftest-fault",
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args()
    try:
        if args.build_only:
            build_model(
                force=args.force_rtl_build,
                difftest=args.difftest,
            )
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
            uart_followup_commands=tuple(
                args.uart_followup_command or ()
            ),
            uart_prompt=args.uart_prompt,
            uart_prompt_timeout=args.uart_prompt_timeout,
            checker=args.checker or "",
            uart_expect=(
                tuple(args.uart_expect)
                if args.uart_expect is not None
                else None
            ),
            uart_reject=(
                tuple(args.uart_reject)
                if args.uart_reject is not None
                else None
            ),
            difftest=args.difftest,
            difftest_mode=args.difftest_mode,
            difftest_isa=args.difftest_isa or "",
            difftest_fault=args.difftest_fault or "",
        )
    except (OSError, RuntimeError, ValueError) as error:
        parser.error(str(error))
    print(f"Result: {result_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
