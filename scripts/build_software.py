from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from elf2mem import parse_elf32_little
from lib.hashing import sha256_file
from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path
from lib.wsl import bash, in_repo


@dataclass(frozen=True)
class SoftwareProfile:
    kind: str
    dependencies: tuple[str, ...]
    default_max_cycles: int | None
    score_candidate: bool = False


PROFILES = {
    "smoke": SoftwareProfile("baremetal", (), 300_000),
    "trap-timer": SoftwareProfile("baremetal", (), 500_000),
    "rtthread": SoftwareProfile("rtthread", ("rt-thread",), 2_500_000),
    "coremark-smoke": SoftwareProfile(
        "coremark-baremetal-functional",
        ("coremark",),
        50_000_000,
    ),
    "coremark-baremetal": SoftwareProfile(
        "coremark-baremetal-score-candidate",
        ("coremark",),
        None,
        score_candidate=True,
    ),
    "rtthread-coremark": SoftwareProfile(
        "rtthread-coremark-command",
        ("rt-thread", "coremark"),
        30_000_000,
    ),
}


def run_wsl(argv: list[str], *, timeout: int = 180) -> str:
    result = bash(in_repo(repo_path(), argv), timeout=timeout, check=False)
    if result.returncode != 0:
        raise RuntimeError(
            f"WSL command failed ({result.returncode}): {' '.join(argv)}\n"
            f"{result.stdout}{result.stderr}"
        )
    return result.stdout


def tool_output(profile: str, target: str) -> str:
    return run_wsl(
        [
            "make",
            "-s",
            "-C",
            "software",
            f"PROFILE={profile}",
            target,
        ]
    ).strip()


def git_dirty() -> bool:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=normal"],
        cwd=repo_path(),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    return result.returncode != 0 or bool(result.stdout.strip())


def source_entries(paths: list[str]) -> list[dict[str, object]]:
    entries = []
    for relative in paths:
        path = repo_path("software", *Path(relative).parts)
        if not path.is_file():
            raise RuntimeError(f"profile source does not exist: {path}")
        entries.append(
            {
                "path": path.relative_to(repo_path()).as_posix(),
                "sha256": sha256_file(path),
            }
        )
    return entries


def dependency_entries(names: tuple[str, ...]) -> list[dict[str, str]]:
    entries = []
    for name in names:
        lock = read_json(
            repo_path("software", name, "dependency.lock.json")
        )
        entries.append(
            {
                "name": name,
                "url": str(lock["url"]),
                "commit": str(lock["commit"]),
            }
        )
    return entries


def parse_size(output: str) -> dict[str, int]:
    lines = [line.split() for line in output.splitlines() if line.strip()]
    if len(lines) < 2 or len(lines[-1]) < 4:
        raise RuntimeError(f"cannot parse size output:\n{output}")
    values = lines[-1]
    return {
        "text": int(values[0]),
        "data": int(values[1]),
        "bss": int(values[2]),
        "total": int(values[3]),
    }


def build_profile(
    profile_name: str,
    *,
    force: bool = False,
) -> tuple[Path, Path]:
    profile = PROFILES[profile_name]
    output = repo_path("build", "software", profile_name)
    make_argv = ["make"]
    if force:
        make_argv.append("-B")
    make_argv.extend(
        [
            "-C",
            "software",
            f"PROFILE={profile_name}",
            f"OUT=../build/software/{profile_name}",
        ]
    )
    result = bash(in_repo(repo_path(), make_argv), timeout=300, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result.ok:
        raise RuntimeError(f"software build failed for profile {profile_name}")

    elf = output / "firmware.elf"
    if not elf.is_file():
        raise RuntimeError(f"software build did not produce {elf}")
    entry, _segments = parse_elf32_little(elf)

    memory_map_path = repo_path("data", "soc", "memory_map.json")
    memory_map = json.loads(memory_map_path.read_text(encoding="utf-8"))
    reset_vector = int(memory_map["reset_vector"], 0)
    if entry != reset_vector:
        raise RuntimeError(
            f"{profile_name}: ELF entry 0x{entry:08x} does not match "
            f"reset vector 0x{reset_vector:08x}"
        )

    sources = [
        line
        for line in tool_output(profile_name, "print-sources").splitlines()
        if line
    ]
    flags = tool_output(profile_name, "print-flags")
    kind = tool_output(profile_name, "print-kind")
    compiler_version = run_wsl(
        ["riscv64-unknown-elf-gcc", "--version"]
    ).splitlines()[0]
    size_output = run_wsl(
        ["riscv64-unknown-elf-size", str(elf.relative_to(repo_path()).as_posix())]
    )
    size = parse_size(size_output)
    code_size = int(memory_map["regions"]["CODE"]["size"], 0)
    data_size = int(memory_map["regions"]["DATA"]["size"], 0)
    if size["text"] > code_size:
        raise RuntimeError(f"{profile_name}: text exceeds CODE capacity")
    if size["data"] + size["bss"] > data_size - 8192:
        raise RuntimeError(
            f"{profile_name}: initialized/uninitialized data reaches reserved stack"
        )

    write_json_atomic(
        output / "size.json",
        {
            "schema_version": 1,
            "profile": profile_name,
            "text": size["text"],
            "data": size["data"],
            "bss": size["bss"],
            "total": size["total"],
            "code_capacity": code_size,
            "data_capacity": data_size,
            "reserved_stack": 8192,
        },
    )
    contract = read_json(repo_path("data", "soc", "software_contract.json"))
    write_json_atomic(
        output / "build_manifest.json",
        {
            "schema_version": 1,
            "kind": "software_build",
            "profile": profile_name,
            "profile_kind": kind,
            "score_candidate": profile.score_candidate,
            "toolchain": {
                "compiler": compiler_version,
                "flags": flags,
                "march": contract["cpu"]["march"],
                "mabi": contract["cpu"]["mabi"],
            },
            "linker": "software/linker/socrv_code_data.ld",
            "elf": {
                "path": elf.relative_to(repo_path()).as_posix(),
                "sha256": sha256_file(elf),
                "entry": f"0x{entry:08x}",
            },
            "dependencies": dependency_entries(profile.dependencies),
            "sources": source_entries(sources),
            "repository_dirty": git_dirty(),
        },
    )

    image_dir = repo_path("build", "images", profile_name)
    image_dir.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        str(repo_path("scripts", "elf2mem.py")),
        "--elf",
        str(elf),
        "--profile",
        profile_name,
        "--region",
        "CODE:"
        f"{memory_map['regions']['CODE']['base']}:"
        f"{memory_map['regions']['CODE']['size']}:"
        f"{image_dir / 'code.mem'}",
        "--region",
        "DATA:"
        f"{memory_map['regions']['DATA']['base']}:"
        f"{memory_map['regions']['DATA']['size']}:"
        f"{image_dir / 'data.mem'}",
        "--manifest",
        str(image_dir / "image.json"),
    ]
    subprocess.run(command, cwd=repo_path(), check=True)
    return elf, image_dir


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a SocRV software profile in WSL and generate memory images."
    )
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    try:
        elf, image_dir = build_profile(args.profile, force=args.force)
    except (
        OSError,
        RuntimeError,
        subprocess.CalledProcessError,
        ValueError,
    ) as error:
        parser.error(str(error))
    print(f"ELF:   {elf}")
    print(f"Image: {image_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
