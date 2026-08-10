from __future__ import annotations

import sys

from lib.repo import repo_path
from lib.wsl import bash, in_repo


def main() -> int:
    argv = [
        "verilator",
        "--lint-only",
        "--timing",
        "-Wall",
        "-Wno-fatal",
        "-Wno-DECLFILENAME",
        "-Wno-UNUSEDPARAM",
        "-Wno-UNUSEDSIGNAL",
        "-Wno-SYNCASYNCNET",
        "--top-module",
        "soc_top",
        "-f",
        "rtl/filelist.f",
    ]
    result = bash(in_repo(repo_path(), argv), timeout=120, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
