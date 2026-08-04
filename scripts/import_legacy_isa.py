from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path


def default_source() -> Path:
    return repo_path().parent.parent / "2607round" / "superScalar" / "data"


def source_commit(source: Path) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(source.parent), "rev-parse", "HEAD"],
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def source_files(source: Path) -> list[Path]:
    roots = sorted(path for path in source.iterdir() if path.is_dir() and path.name.startswith("rv32"))
    return sorted(file for root in roots for file in root.rglob("*") if file.is_file())


def make_manifest(source: Path, destination: Path) -> dict[str, object]:
    files = []
    for input_path in source_files(source):
        relative = input_path.relative_to(source)
        output_path = destination / relative
        files.append(
            {
                "path": relative.as_posix(),
                "bytes": output_path.stat().st_size,
                "sha256": sha256_file(output_path),
            }
        )
    return {
        "schema_version": 1,
        "kind": "legacy_isa_import",
        "source": {
            "description": "2607round/superScalar ISA test data",
            "git_commit": source_commit(source),
        },
        "files": files,
    }


def import_data(source: Path, destination: Path) -> None:
    if not source.is_dir():
        raise SystemExit(f"legacy ISA source does not exist: {source}")
    destination.mkdir(parents=True, exist_ok=True)
    inputs = source_files(source)
    if not inputs:
        raise SystemExit(f"no rv32* data found under {source}")
    for input_path in inputs:
        relative = input_path.relative_to(source)
        output_path = destination / relative
        output_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(input_path, output_path)
    manifest = make_manifest(source, destination)
    write_json_atomic(destination / "manifest.json", manifest)
    print(f"Imported {len(inputs)} files into {destination}")


def verify(destination: Path) -> None:
    manifest_path = destination / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit(f"ISA manifest is missing: {manifest_path}")
    manifest = read_json(manifest_path)
    failures: list[str] = []
    entries = manifest.get("files")
    if not isinstance(entries, list):
        raise SystemExit("ISA manifest field 'files' must be an array")
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            failures.append(f"bad manifest entry: {entry!r}")
            continue
        path = destination / entry["path"]
        if not path.is_file():
            failures.append(f"missing: {entry['path']}")
            continue
        if path.stat().st_size != entry.get("bytes"):
            failures.append(f"size mismatch: {entry['path']}")
            continue
        if sha256_file(path) != entry.get("sha256"):
            failures.append(f"hash mismatch: {entry['path']}")
    if failures:
        raise SystemExit("ISA data verification failed:\n" + "\n".join(failures[:20]))
    print(f"Verified {len(entries)} ISA data files")


def main() -> int:
    parser = argparse.ArgumentParser(description="Import approved ISA data from the previous round.")
    parser.add_argument("--source", type=Path, default=default_source())
    parser.add_argument("--destination", type=Path, default=repo_path("data", "isa"))
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify(args.destination.resolve())
    else:
        import_data(args.source.resolve(), args.destination.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
