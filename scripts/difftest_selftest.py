from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from lib.repo import repo_path


EXPECTED = {
    "order": "ORDER",
    "pc": "NEXT_PC",
    "rd": "GPR",
    "mem": "MEM",
}


def main() -> int:
    failures: list[str] = []
    for fault, expected_kind in EXPECTED.items():
        test_name = f"difftest-selftest-{fault}"
        command = [
            sys.executable,
            "-B",
            str(repo_path("scripts", "run_verilator.py")),
            "--profile",
            "smoke",
            "--test",
            test_name,
            "--max-cycles",
            "100000",
            "--no-rtl-build",
            "--no-software-build",
            "--difftest",
            "--difftest-mode",
            "soc-mmio",
            "--difftest-isa",
            "rv32im_zicsr_zicntr_zifencei",
            "--difftest-fault",
            f"{fault}@8",
        ]
        completed = subprocess.run(
            command,
            cwd=repo_path(),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        result_path = repo_path(
            "build",
            "result",
            "soc",
            f"{test_name}-diff.json",
        )
        if not result_path.is_file():
            failures.append(f"{fault}: result file was not produced")
            continue
        result = json.loads(result_path.read_text(encoding="utf-8"))
        actual_kind = (result.get("failure") or {}).get("kind")
        if completed.returncode == 0:
            failures.append(f"{fault}: injected run unexpectedly passed")
        elif result.get("status") != "DIFF_MISMATCH":
            failures.append(
                f"{fault}: status={result.get('status')}, expected DIFF_MISMATCH"
            )
        elif actual_kind != expected_kind:
            failures.append(
                f"{fault}: kind={actual_kind}, expected {expected_kind}"
            )
        else:
            print(f"DiffTest fault self-test {fault}: {actual_kind} PASS")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
