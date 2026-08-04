from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path
from run_verilator import run_image


def test_id(test: dict[str, object]) -> str:
    return f"{test['suite']}/{test['name']}"


def parse_names(raw: str | None) -> set[str] | None:
    if raw is None:
        return None
    return {name.strip() for name in raw.split(",") if name.strip()}


def select_tests(
    manifest: dict[str, object],
    gate_name: str,
    suites: set[str] | None,
    names: set[str] | None,
) -> list[dict[str, object]]:
    gate = manifest["gates"].get(gate_name)
    if gate is None:
        raise ValueError(f"unknown ISA gate: {gate_name}")
    if not gate["ready"]:
        raise ValueError(
            f"ISA gate {gate_name} is not ready: {gate['blocked_reason']}"
        )
    selected_suites = suites or set(gate["suites"])
    excluded = set(gate["excluded_tests"])
    candidates = [
        test
        for test in manifest["tests"]
        if test["suite"] in selected_suites and test_id(test) not in excluded
    ]
    if names is None:
        return candidates

    qualified = {name for name in names if "/" in name}
    unqualified = names - qualified
    matches = [test for test in candidates if test_id(test) in qualified]
    for name in sorted(unqualified):
        named = [test for test in candidates if test["name"] == name]
        if len(named) > 1:
            choices = ", ".join(test_id(test) for test in named)
            raise ValueError(
                f"ambiguous ISA test {name}; use one of: {choices}"
            )
        if named:
            matches.extend(named)
    found = {test_id(test) for test in matches}
    found.update(test["name"] for test in matches)
    unknown = {
        name
        for name in names
        if name not in found
    }
    if unknown:
        raise ValueError(f"unknown ISA tests for gate {gate_name}: {sorted(unknown)}")
    return matches


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run generated official riscv-tests images on the SocRV model."
    )
    parser.add_argument(
        "--gate",
        help="ISA acceptance gate; defaults to manifest default_gate",
    )
    parser.add_argument(
        "--suites",
        help="comma-separated suite override, for example rv32mi,rv32um",
    )
    parser.add_argument(
        "--tests",
        help="comma-separated test names; use suite/name when ambiguous",
    )
    parser.add_argument(
        "--list-gates",
        action="store_true",
        help="show ISA gates without building or running the RTL model",
    )
    parser.add_argument("--max-cycles", type=int, default=300_000)
    parser.add_argument("--no-rtl-build", action="store_true")
    args = parser.parse_args()

    manifest = read_json(repo_path("data", "isa", "manifest.json"))
    if args.list_gates:
        for name, gate in manifest["gates"].items():
            state = "ready" if gate["ready"] else "blocked"
            suites = ",".join(gate["suites"]) or "-"
            detail = (
                ""
                if gate["ready"]
                else f" ({gate['blocked_reason']})"
            )
            print(f"{name}: {state}; suites={suites}{detail}")
        return 0
    gate_name = args.gate or manifest["default_gate"]
    try:
        tests = select_tests(
            manifest,
            gate_name,
            parse_names(args.suites),
            parse_names(args.tests),
        )
    except ValueError as error:
        parser.error(str(error))
    if not tests:
        parser.error("no ISA tests selected")

    results = []
    for index, test in enumerate(tests):
        suite = test["suite"]
        name = test["name"]
        image_dir = repo_path("data", "isa", suite, name)
        reproduce = (
            "python -B scripts/run_isa_tests.py "
            f"--gate {gate_name} --tests {suite}/{name} "
            f"--max-cycles {args.max_cycles} --no-rtl-build"
        )
        result_path = run_image(
            image_dir,
            f"isa-{suite}-{name}",
            args.max_cycles,
            rebuild_model=(index == 0 and not args.no_rtl_build),
            trace=False,
            require_pass=False,
            profile=f"isa/{suite}",
            seed=1,
            reproduce=reproduce,
        )
        result = json.loads(result_path.read_text(encoding="utf-8"))
        result["isa_suite"] = suite
        result["isa_test"] = name
        results.append(result)
        print(
            f"ISA {suite}/{name}: {result['status']} "
            f"({result['cycles']} cycles)"
        )

    passed = all(result["status"] == "PASS" for result in results)
    summary_path = repo_path(
        "build",
        "regression",
        "isa",
        gate_name,
        "summary.json",
    )
    write_json_atomic(
        summary_path,
        {
            "schema_version": 1,
            "kind": "regression",
            "target": "soc-verilator",
            "status": "PASS" if passed else "FAIL",
            "gate": gate_name,
            "suites": sorted({result["isa_suite"] for result in results}),
            "upstream_commit": manifest["upstream"]["commit"],
            "memory_map_sha256": manifest["memory_map_sha256"],
            "software_contract_sha256": manifest[
                "software_contract_sha256"
            ],
            "tests": results,
        },
    )
    print(f"ISA regression summary: {summary_path}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
