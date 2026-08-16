from __future__ import annotations

import argparse
import ctypes
import os
import re
import subprocess
import sys
from pathlib import Path

from lib.repo import ensure_directory_accessible, ensure_within, repo_path


FAILED_PROCESSING_PATTERN = re.compile(r"Failed processing\s+([1-9][0-9]*)\s+files?", re.I)


def resolve_run_dir(path: Path) -> Path:
    candidate = path if path.is_absolute() else repo_path(*path.parts)
    candidate = ensure_within(candidate, repo_path("competition_runs"))
    if not candidate.exists():
        raise ValueError(f"competition run does not exist: {candidate}")
    return candidate


def is_elevated() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except (AttributeError, OSError):
        return False


def run_permission_command(command: list[str], *, action: str) -> None:
    completed = subprocess.run(
        command,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    if completed.stdout:
        print(completed.stdout, end="")
    combined_output = "\n".join((completed.stdout, completed.stderr))
    if completed.returncode != 0 or FAILED_PROCESSING_PATTERN.search(combined_output):
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f"{action} failed: {detail or 'command returned an error'}")


def repair(run_dir: Path) -> None:
    if sys.platform != "win32":
        raise ValueError("this repair command is only required on Windows")
    identity = os.environ.get("USERDOMAIN", "") + "\\" + os.environ.get(
        "USERNAME",
        "",
    )
    identity = identity.strip("\\")
    if not identity:
        raise ValueError("cannot determine the current Windows user")

    try:
        ensure_directory_accessible(run_dir, label="competition run")
    except ValueError:
        if not is_elevated():
            raise RuntimeError(
                f"Windows has protected {run_dir} with an owner-only ACL. "
                "Open PowerShell as Administrator and rerun this same command; "
                "administrator elevation is required once to take ownership."
            ) from None
        run_permission_command(
            ["takeown", "/F", str(run_dir), "/A", "/R", "/D", "Y"],
            action=f"taking ownership of {run_dir}",
        )

    run_permission_command(
        [
            "icacls",
            str(run_dir),
            "/inheritance:e",
            "/grant:r",
            f"{identity}:(OI)(CI)M",
            "/T",
        ],
        action=f"restoring inherited permissions on {run_dir}",
    )
    ensure_directory_accessible(run_dir, label="repaired competition run")
    vivado_dir = run_dir / "vivado"
    ensure_directory_accessible(vivado_dir, label="repaired Vivado directory")
    launchers = sorted(vivado_dir.glob("create_*_project.tcl"))
    if not launchers:
        raise RuntimeError(f"no Vivado launchers found after repair: {vivado_dir}")
    for launcher in launchers:
        with launcher.open("rb") as stream:
            stream.read(1)
        print(f"Readable: {launcher}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Repair inherited Windows ACLs for one competition run."
    )
    parser.add_argument("--run-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        run_dir = resolve_run_dir(args.run_dir)
        repair(run_dir)
    except (OSError, RuntimeError, ValueError) as error:
        parser.error(str(error))
    print(f"Permissions repaired: {run_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
