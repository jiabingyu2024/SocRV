from __future__ import annotations

import argparse
import shlex
import subprocess
from pathlib import Path

from lib.manifest import read_json
from lib.repo import repo_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Replay a DiffTest result using its recorded command."
    )
    parser.add_argument("--result", type=Path, required=True)
    parser.add_argument("--trace", action="store_true")
    args = parser.parse_args()
    result_path = args.result
    if not result_path.is_absolute():
        result_path = repo_path(*result_path.parts)
    document = read_json(result_path)
    difftest = document.get("difftest", {})
    if not difftest.get("enabled", False):
        parser.error("the selected result was not produced with DiffTest")
    command = document.get("reproduce")
    if not isinstance(command, str) or not command.strip():
        parser.error("the selected result has no reproduce command")
    argv = shlex.split(command, posix=True)
    if "--difftest" not in argv:
        argv.append("--difftest")
    if args.trace and "--trace" not in argv:
        argv.append("--trace")
    print("Replay:", subprocess.list2cmdline(argv))
    completed = subprocess.run(argv, cwd=repo_path(), check=False)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
