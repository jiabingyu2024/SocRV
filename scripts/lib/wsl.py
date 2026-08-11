from __future__ import annotations

import os
import shlex
from pathlib import Path

from .command import CommandResult, run


def to_wsl_path(path: Path) -> str:
    if os.name != "nt":
        return path.resolve().as_posix()
    result = run(["wsl.exe", "-e", "wslpath", "-a", str(path.resolve())], check=True)
    return result.stdout.strip()


def bash(command: str, *, timeout: float | None = None, check: bool = False) -> CommandResult:
    if os.name != "nt":
        return run(
            ["bash", "-lc", command],
            timeout=timeout,
            check=check,
        )
    return run(
        ["wsl.exe", "-e", "bash", "-lc", command],
        timeout=timeout,
        check=check,
    )


def in_repo(repo: Path, argv: list[str]) -> str:
    repo_wsl = to_wsl_path(repo)
    rendered = " ".join(shlex.quote(item) for item in argv)
    return f"cd {shlex.quote(repo_wsl)} && {rendered}"
