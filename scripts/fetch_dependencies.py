from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

from lib.manifest import read_json, write_json_atomic
from lib.repo import build_path, repo_path


LOCK_PATH = repo_path("software", "rt-thread", "dependency.lock.json")
DESTINATION = repo_path("software", "rt-thread", "upstream")


def git(*args: str, cwd: Path | None = None, timeout: int = 300) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=str(cwd) if cwd else None,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def load_lock() -> dict[str, object]:
    lock = read_json(LOCK_PATH)
    if lock.get("schema_version") != 1:
        raise SystemExit(f"unsupported dependency lock version: {lock.get('schema_version')!r}")
    for field in ("url", "tag", "commit", "sparse_paths"):
        if field not in lock:
            raise SystemExit(f"missing dependency lock field: {field}")
    return lock


def current_commit() -> str | None:
    if not (DESTINATION / ".git").exists():
        return None
    result = git("rev-parse", "HEAD", cwd=DESTINATION)
    return result.stdout.strip() if result.returncode == 0 else None


def verify() -> None:
    lock = load_lock()
    actual = current_commit()
    expected = str(lock["commit"])
    if actual != expected:
        raise SystemExit(
            f"RT-Thread dependency mismatch: expected {expected}, got {actual or 'missing'}"
        )
    missing = [
        str(path)
        for path in lock["sparse_paths"]
        if not (DESTINATION / str(path)).exists()
    ]
    if missing:
        raise SystemExit(
            "RT-Thread sparse checkout is incomplete; missing:\n"
            + "\n".join(f"  {path}" for path in missing)
        )
    print(f"RT-Thread dependency verified: {actual}")


def configure_sparse(lock: dict[str, object]) -> list[str]:
    sparse_paths = [str(path) for path in lock["sparse_paths"]]
    sparse = git(
        "sparse-checkout",
        "set",
        "--no-cone",
        *sparse_paths,
        cwd=DESTINATION,
    )
    if sparse.returncode != 0:
        raise SystemExit(f"RT-Thread sparse checkout failed:\n{sparse.stdout}{sparse.stderr}")
    return sparse_paths


def write_dependency_manifest(lock: dict[str, object], sparse_paths: list[str]) -> None:
    manifest = {
        "schema_version": 1,
        "kind": "external_dependency",
        "name": "rt-thread",
        "url": lock["url"],
        "tag": lock["tag"],
        "commit": current_commit(),
        "sparse_paths": sparse_paths,
    }
    write_json_atomic(build_path("manifest", "rt-thread.json"), manifest)


def fetch() -> None:
    lock = load_lock()
    actual = current_commit()
    if actual == lock["commit"]:
        sparse_paths = configure_sparse(lock)
        verify()
        write_dependency_manifest(lock, sparse_paths)
        print(f"RT-Thread dependency already present and configured: {actual}")
        return
    if DESTINATION.exists():
        if any(DESTINATION.iterdir()):
            raise SystemExit(
                f"dependency destination is non-empty but not the locked revision: {DESTINATION}"
            )
        DESTINATION.rmdir()
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)

    clone = git(
        "clone",
        "--depth",
        "1",
        "--filter=blob:none",
        "--sparse",
        "--branch",
        str(lock["tag"]),
        "--single-branch",
        str(lock["url"]),
        str(DESTINATION),
        timeout=600,
    )
    if clone.returncode != 0:
        raise SystemExit(f"RT-Thread clone failed:\n{clone.stdout}{clone.stderr}")

    sparse_paths = configure_sparse(lock)
    verify()
    write_dependency_manifest(lock, sparse_paths)
    print(f"Fetched RT-Thread {lock['tag']} into {DESTINATION}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch pinned SocRV external dependencies.")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if not shutil.which("git"):
        raise SystemExit("git executable not found")
    if args.verify:
        verify()
    else:
        fetch()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
