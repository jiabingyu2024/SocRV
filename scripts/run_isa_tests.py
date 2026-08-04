from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path
from run_verilator import run_image


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run generated official riscv-tests images on the SocRV model."
    )
    parser.add_argument(
        "--tests",
        help="comma-separated test names; defaults to the complete dataset",
    )
    parser.add_argument("--max-cycles", type=int, default=300_000)
    parser.add_argument("--no-rtl-build", action="store_true")
    args = parser.parse_args()

    manifest = read_json(repo_path("data", "isa", "manifest.json"))
    selected = (
        {name for name in args.tests.split(",") if name}
        if args.tests
        else None
    )
    tests = [
        entry
        for entry in manifest["tests"]
        if selected is None or entry["name"] in selected
    ]
    if not tests:
        parser.error("no ISA tests selected")
    if selected is not None:
        unknown = selected - {entry["name"] for entry in tests}
        if unknown:
            parser.error(f"unknown ISA tests: {sorted(unknown)}")

    results = []
    for index, test in enumerate(tests):
        name = test["name"]
        image_dir = repo_path(
            "data",
            "isa",
            manifest["suite"],
            name,
        )
        result_path = run_image(
            image_dir,
            f"{manifest['suite']}-{name}",
            args.max_cycles,
            rebuild_model=(index == 0 and not args.no_rtl_build),
            trace=False,
            run_dir=repo_path(
                "build",
                "verilator",
                "isa",
                manifest["suite"],
                name,
            ),
            require_pass=False,
        )
        result = json.loads(result_path.read_text(encoding="utf-8"))
        result["isa_test"] = name
        results.append(result)
        print(f"ISA {name}: {result['status']} ({result['cycles']} cycles)")

    passed = all(result["status"] == "PASS" for result in results)
    summary_path = repo_path(
        "build",
        "regression",
        "isa",
        manifest["suite"],
        "summary.json",
    )
    write_json_atomic(
        summary_path,
        {
            "schema_version": 1,
            "kind": "regression",
            "target": "soc-verilator",
            "status": "PASS" if passed else "FAIL",
            "suite": manifest["suite"],
            "upstream_commit": manifest["upstream"]["commit"],
            "memory_map_sha256": manifest["memory_map_sha256"],
            "tests": results,
        },
    )
    print(f"ISA regression summary: {summary_path}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
