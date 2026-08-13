from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from jsonschema import Draft202012Validator

from elf2mem import parse_elf32_little
from lib.hashing import sha256_file
from lib.manifest import read_json, write_json_atomic
from lib.repo import ensure_within, repo_path
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
    "contest-rtthread-coremark": SoftwareProfile(
        "contest-rtthread-coremark-command",
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


def tool_output(
    profile: str,
    target: str,
    *,
    make_variables: tuple[str, ...] = (),
) -> str:
    return run_wsl(
        [
            "make",
            "-s",
            "-C",
            "software",
            f"PROFILE={profile}",
            *make_variables,
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
        path = ensure_within(
            repo_path("software", *Path(relative).parts),
            repo_path(),
        )
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


def relative_from_software(path: Path) -> str:
    return os.path.relpath(path, repo_path("software")).replace(os.sep, "/")


def resolve_run_dir(path: Path) -> Path:
    candidate = path if path.is_absolute() else repo_path(*path.parts)
    candidate = ensure_within(candidate, repo_path("competition_runs"))
    if not candidate.is_dir():
        raise ValueError(f"competition run directory does not exist: {candidate}")
    return candidate


@dataclass(frozen=True)
class CompetitionConfig:
    path: Path
    mode: str
    entry_source: Path
    source_root: Path


def verify_competition_sources(run_dir: Path) -> None:
    manifest_path = run_dir / "source" / "source_manifest.json"
    if not manifest_path.is_file():
        raise ValueError(f"competition source manifest does not exist: {manifest_path}")
    manifest = read_json(manifest_path)
    files = manifest.get("files")
    if (
        manifest.get("schema_version") != 1
        or manifest.get("kind") != "competition_source"
        or not isinstance(files, list)
    ):
        raise ValueError(f"invalid competition source manifest: {manifest_path}")
    expected: dict[str, str] = {}
    for item in files:
        if not isinstance(item, dict):
            raise ValueError(f"invalid source entry in {manifest_path}")
        relative = item.get("path")
        digest = item.get("sha256")
        if not isinstance(relative, str) or not isinstance(digest, str):
            raise ValueError(f"invalid source entry in {manifest_path}")
        path = ensure_within(
            run_dir.joinpath(*Path(relative).parts),
            run_dir / "source" / "original",
        )
        expected[path.relative_to(run_dir).as_posix()] = digest

    actual_paths = sorted(
        path
        for path in (run_dir / "source" / "original").rglob("*")
        if path.is_file()
    )
    actual_names = {path.relative_to(run_dir).as_posix() for path in actual_paths}
    if actual_names != set(expected):
        added = sorted(actual_names - set(expected))
        missing = sorted(set(expected) - actual_names)
        raise ValueError(
            "competition source set changed after preparation; "
            f"added={added}, missing={missing}"
        )
    for path in actual_paths:
        relative = path.relative_to(run_dir).as_posix()
        if sha256_file(path) != expected[relative]:
            raise ValueError(
                "competition source changed after preparation: "
                f"{relative}"
            )


def load_competition_config(
    run_dir: Path,
    requested: Path | None = None,
) -> CompetitionConfig:
    verify_competition_sources(run_dir)
    if requested is None:
        path = run_dir / "source" / "competition.json"
    else:
        path = requested if requested.is_absolute() else repo_path(*requested.parts)
    path = ensure_within(path, run_dir / "source")
    if not path.is_file():
        raise ValueError(f"competition configuration does not exist: {path}")
    document = read_json(path)
    schema = read_json(
        repo_path("data", "schemas", "competition_source.schema.json")
    )
    Draft202012Validator(schema).validate(document)
    if document["mode"] != "core_main_replacement":
        raise ValueError(
            "contest-rtthread-coremark currently supports only "
            "mode=core_main_replacement"
        )
    if document["entry_symbol"] != "main":
        raise ValueError(
            "core_main_replacement requires entry_symbol=main"
        )
    if document["extra_sources"]:
        raise ValueError(
            "core_main_replacement currently expects one driver C file; "
            "extra_sources must be empty"
        )
    entry_source = ensure_within(
        run_dir.joinpath(*Path(document["entry_source"]).parts),
        run_dir / "source" / "original",
    )
    if not entry_source.is_file():
        raise ValueError(f"competition entry source does not exist: {entry_source}")
    if entry_source.suffix.lower() != ".c":
        raise ValueError(f"competition entry source is not a C file: {entry_source}")
    return CompetitionConfig(
        path=path,
        mode=str(document["mode"]),
        entry_source=entry_source,
        source_root=(run_dir / "source" / "original").resolve(),
    )


def build_profile(
    profile_name: str,
    *,
    force: bool = False,
    run_dir: Path | None = None,
    competition_config: Path | None = None,
) -> tuple[Path, Path]:
    profile = PROFILES[profile_name]
    selected_run = resolve_run_dir(run_dir) if run_dir is not None else None
    if profile_name == "contest-rtthread-coremark" and selected_run is None:
        raise ValueError(
            "contest-rtthread-coremark requires --run-dir from "
            "scripts/prepare_competition_run.py"
        )
    if competition_config is not None and selected_run is None:
        raise ValueError("--competition-config requires --run-dir")
    contest = (
        load_competition_config(selected_run, competition_config)
        if profile_name == "contest-rtthread-coremark" and selected_run is not None
        else None
    )
    output = (
        selected_run / "software"
        if selected_run is not None
        else repo_path("build", "software", profile_name)
    )
    make_variables = [f"OUT={relative_from_software(output)}"]
    if contest is not None:
        make_variables.extend(
            [
                f"CONTEST_ENTRY_SOURCE={relative_from_software(contest.entry_source)}",
                f"CONTEST_SOURCE_ROOT={relative_from_software(contest.source_root)}",
            ]
        )
    make_argv = ["make"]
    if force:
        make_argv.append("-B")
    make_argv.extend(
        [
            "-C",
            "software",
            f"PROFILE={profile_name}",
            *make_variables,
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

    tool_variables = tuple(make_variables)
    sources = [
        line
        for line in tool_output(
            profile_name,
            "print-sources",
            make_variables=tool_variables,
        ).splitlines()
        if line
    ]
    flags = tool_output(
        profile_name,
        "print-flags",
        make_variables=tool_variables,
    )
    kind = tool_output(
        profile_name,
        "print-kind",
        make_variables=tool_variables,
    )
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
    build_manifest: dict[str, object] = {
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
    }
    if contest is not None:
        build_manifest["competition"] = {
            "mode": contest.mode,
            "config": {
                "path": contest.path.relative_to(repo_path()).as_posix(),
                "sha256": sha256_file(contest.path),
            },
            "entry_source": {
                "path": contest.entry_source.relative_to(repo_path()).as_posix(),
                "sha256": sha256_file(contest.entry_source),
            },
        }
    write_json_atomic(output / "build_manifest.json", build_manifest)

    image_dir = (
        selected_run / "images"
        if selected_run is not None
        else repo_path("build", "images", profile_name)
    )
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
    for lane in range(4):
        command.extend(
            ["--iccm-lane", str(image_dir / f"iccm_lane{lane}.mem")]
        )
    for bank in range(8):
        command.extend(
            ["--dccm-bank", str(image_dir / f"dccm_bank{bank}.mem")]
        )
    subprocess.run(command, cwd=repo_path(), check=True)
    return elf, image_dir


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a SocRV software profile in WSL and generate memory images."
    )
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--run-dir",
        type=Path,
        help="competition_runs/<run-id>; stores software/ and images/ together",
    )
    parser.add_argument(
        "--competition-config",
        type=Path,
        help="override <run-dir>/source/competition.json",
    )
    args = parser.parse_args()
    try:
        elf, image_dir = build_profile(
            args.profile,
            force=args.force,
            run_dir=args.run_dir,
            competition_config=args.competition_config,
        )
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
