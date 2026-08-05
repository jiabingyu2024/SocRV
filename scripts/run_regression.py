from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path
from run_verilator import model_paths, run_profile


def display_testlist_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(repo_path()).as_posix()
    except ValueError:
        return resolved.as_posix()


def performance_line(result: dict[str, object]) -> str | None:
    performance = result.get("performance")
    if not isinstance(performance, dict) or not performance.get("complete"):
        return None
    return (
        f"window={performance['cycles']} cycles, "
        f"commits={performance['commits']}, "
        f"IPC={performance['ipc']:.6f}, "
        f"cycles/iteration={performance['cycles_per_iteration']:.2f}, "
        f"iterations/sim-second={performance['iterations_per_second']:.3f}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run SocRV tests from a controlled testlist."
    )
    parser.add_argument(
        "--testlist",
        type=Path,
        default=repo_path("data", "tests", "soc.json"),
    )
    parser.add_argument("--suite", default="smoke")
    parser.add_argument("--no-rtl-build", action="store_true")
    difftest_group = parser.add_mutually_exclusive_group()
    difftest_group.add_argument("--difftest", action="store_true")
    difftest_group.add_argument("--no-difftest", action="store_true")
    args = parser.parse_args()
    document = read_json(args.testlist)
    tests = [test for test in document["tests"] if args.suite in test["suite"]]
    if not tests:
        parser.error(f"no tests selected for suite {args.suite}")

    results = []
    performance_results = []
    for index, test in enumerate(tests):
        performance = test.get("performance", {})
        difftest_config = test.get("difftest", {})
        difftest_enabled = difftest_config.get("enabled", False)
        if args.difftest:
            difftest_enabled = True
        elif args.no_difftest:
            difftest_enabled = False
        result_path = run_profile(
            test["image"],
            test["name"],
            test["max_cycles"],
            rebuild_model=not args.no_rtl_build,
            build_sw=True,
            trace=False,
            seed=test.get("seed", 1),
            performance=performance.get("enabled", False),
            benchmark_iterations=performance.get("iterations", 0),
            wall_timeout=test.get("max_wall_seconds", 600),
            require_pass=False,
            uart_command=test.get("uart_command", ""),
            uart_prompt=test.get("uart_prompt", "msh >"),
            uart_prompt_timeout=test.get(
                "uart_prompt_timeout",
                5_000_000,
            ),
            checker=test["checker"],
            uart_expect=tuple(test.get("uart_expect", [])),
            uart_reject=tuple(test.get("uart_reject", [])),
            difftest=difftest_enabled,
            difftest_mode=difftest_config.get(
                "mode",
                "soc-mmio" if test["image"].startswith("rtthread")
                else "ram-strict",
            ),
            difftest_isa=difftest_config.get("isa", ""),
        )
        result = json.loads(result_path.read_text(encoding="utf-8"))
        results.append(result)
        line = performance_line(result)
        if line:
            performance_results.append(
                {
                    "test": result["test"],
                    **result["performance"],
                }
            )
            print(f"Performance {result['test']}: {line}")

    passed = all(result["status"] == "PASS" for result in results)
    summary_path = repo_path("build", "regression", args.suite, "summary.json")
    any_difftest = any(
        result.get("difftest", {}).get("enabled", False)
        for result in results
    )
    model_manifest = read_json(model_paths(any_difftest)[1])
    write_json_atomic(
        summary_path,
        {
            "schema_version": 1,
            "kind": "regression",
            "target": "soc-verilator",
            "status": "PASS" if passed else "FAIL",
            "suite": args.suite,
            "testlist": {
                "path": display_testlist_path(args.testlist),
                "sha256": sha256_file(args.testlist),
            },
            "model_fingerprint": model_manifest["fingerprint"],
            "tests": results,
            "performance": performance_results,
        },
    )
    print(f"Regression summary: {summary_path}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
