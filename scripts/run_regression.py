from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.manifest import write_json_atomic
from lib.repo import repo_path
from run_verilator import run_profile


def main() -> int:
    parser = argparse.ArgumentParser(description="Run SocRV tests from a controlled testlist.")
    parser.add_argument("--testlist", type=Path, default=repo_path("data", "tests", "soc.json"))
    parser.add_argument("--suite", default="smoke")
    args = parser.parse_args()
    document = json.loads(args.testlist.read_text(encoding="utf-8"))
    tests = [test for test in document["tests"] if args.suite in test["suite"]]
    if not tests:
        parser.error(f"no tests selected for suite {args.suite}")

    results = []
    for index, test in enumerate(tests):
        result_path = run_profile(
            test["image"],
            test["name"],
            test["max_cycles"],
            rebuild_model=(index == 0),
            build_sw=True,
            trace=False,
        )
        results.append(json.loads(result_path.read_text(encoding="utf-8")))

    passed = all(result["status"] == "PASS" for result in results)
    summary_path = repo_path("build", "regression", args.suite, "summary.json")
    write_json_atomic(
        summary_path,
        {
            "schema_version": 1,
            "kind": "regression",
            "target": "soc-verilator",
            "status": "PASS" if passed else "FAIL",
            "suite": args.suite,
            "tests": results,
        },
    )
    print(f"Regression summary: {summary_path}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
