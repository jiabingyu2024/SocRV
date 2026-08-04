from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence


@dataclass(frozen=True)
class CommandResult:
    argv: tuple[str, ...]
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0


def run(
    argv: Sequence[str],
    *,
    cwd: Path | None = None,
    env: Mapping[str, str] | None = None,
    timeout: float | None = None,
    check: bool = False,
) -> CommandResult:
    completed = subprocess.run(
        [str(item) for item in argv],
        cwd=str(cwd) if cwd else None,
        env=dict(env) if env else None,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    result = CommandResult(
        argv=tuple(str(item) for item in argv),
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )
    if check and not result.ok:
        rendered = " ".join(result.argv)
        raise RuntimeError(
            f"command failed ({result.returncode}): {rendered}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result
