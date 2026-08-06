from __future__ import annotations

import argparse
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from lib.manifest import read_json, write_json_atomic
from lib.repo import build_path, repo_path


@dataclass(frozen=True)
class Dependency:
    name: str
    lock_path: Path
    destination: Path


DEPENDENCIES = {
    dependency.name: dependency
    for dependency in (
        Dependency(
            "rt-thread",
            repo_path("software", "rt-thread", "dependency.lock.json"),
            repo_path("software", "rt-thread", "upstream"),
        ),
        Dependency(
            "riscv-tests",
            repo_path("software", "riscv-tests", "dependency.lock.json"),
            repo_path("software", "riscv-tests", "upstream"),
        ),
        Dependency(
            "coremark",
            repo_path("software", "coremark", "dependency.lock.json"),
            repo_path("software", "coremark", "upstream"),
        ),
        Dependency(
            "spike",
            repo_path("sim", "reference", "spike", "dependency.lock.json"),
            repo_path("sim", "reference", "spike", "upstream"),
        ),
        Dependency(
            "ibex-cosim",
            repo_path(
                "sim",
                "reference",
                "ibex-cosim",
                "dependency.lock.json",
            ),
            repo_path("sim", "reference", "ibex-cosim", "upstream"),
        ),
    )
}


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


def load_lock(dependency: Dependency) -> dict[str, object]:
    lock = read_json(dependency.lock_path)
    if lock.get("schema_version") != 1:
        raise SystemExit(
            f"{dependency.name}: unsupported lock version {lock.get('schema_version')!r}"
        )
    for field in ("name", "url", "commit", "required_paths"):
        if field not in lock:
            raise SystemExit(f"{dependency.name}: missing lock field {field}")
    if lock["name"] != dependency.name:
        raise SystemExit(
            f"{dependency.name}: lock name is {lock['name']!r}"
        )
    if not isinstance(lock["required_paths"], list):
        raise SystemExit(f"{dependency.name}: required_paths must be an array")
    sparse_paths = lock.get("sparse_paths")
    if sparse_paths is not None and not isinstance(sparse_paths, list):
        raise SystemExit(f"{dependency.name}: sparse_paths must be an array")
    submodules = lock.get("submodules")
    if submodules is not None and not isinstance(submodules, list):
        raise SystemExit(f"{dependency.name}: submodules must be an array")
    return lock


def current_commit(dependency: Dependency) -> str | None:
    if not (dependency.destination / ".git").exists():
        return None
    result = git("rev-parse", "HEAD", cwd=dependency.destination)
    return result.stdout.strip() if result.returncode == 0 else None


def current_remote(dependency: Dependency) -> str | None:
    if not (dependency.destination / ".git").exists():
        return None
    result = git("remote", "get-url", "origin", cwd=dependency.destination)
    return result.stdout.strip() if result.returncode == 0 else None


def configure_sparse(
    dependency: Dependency,
    lock: dict[str, object],
) -> list[str]:
    sparse_paths = [str(path) for path in lock.get("sparse_paths", [])]
    if not sparse_paths:
        disable = git("sparse-checkout", "disable", cwd=dependency.destination)
        if disable.returncode not in (0, 128):
            raise SystemExit(
                f"{dependency.name}: cannot disable sparse checkout:\n"
                f"{disable.stdout}{disable.stderr}"
            )
        return []
    sparse = git(
        "sparse-checkout",
        "set",
        "--no-cone",
        *sparse_paths,
        cwd=dependency.destination,
    )
    if sparse.returncode != 0:
        raise SystemExit(
            f"{dependency.name}: sparse checkout failed:\n"
            f"{sparse.stdout}{sparse.stderr}"
        )
    return sparse_paths


def verify_submodules(
    dependency: Dependency,
    lock: dict[str, object],
) -> None:
    for submodule in lock.get("submodules", []):
        path = dependency.destination / str(submodule["path"])
        result = git("rev-parse", "HEAD", cwd=path)
        actual = result.stdout.strip() if result.returncode == 0 else None
        expected = str(submodule["commit"])
        if actual != expected:
            raise SystemExit(
                f"{dependency.name}/{submodule['path']}: expected commit "
                f"{expected}, got {actual or 'missing'}"
            )
        remote = git("remote", "get-url", "origin", cwd=path)
        actual_url = (
            remote.stdout.strip().rstrip("/")
            if remote.returncode == 0
            else ""
        )
        expected_url = str(submodule["url"]).rstrip("/")
        if actual_url != expected_url:
            raise SystemExit(
                f"{dependency.name}/{submodule['path']}: expected origin "
                f"{expected_url}, got {actual_url or 'missing'}"
            )
        missing = [
            str(required)
            for required in submodule.get("required_paths", [])
            if not (path / str(required)).exists()
        ]
        if missing:
            raise SystemExit(
                f"{dependency.name}/{submodule['path']}: checkout is "
                "incomplete; missing:\n"
                + "\n".join(f"  {required}" for required in missing)
            )


def initialize_submodules(
    dependency: Dependency,
    lock: dict[str, object],
) -> None:
    for submodule in lock.get("submodules", []):
        path = str(submodule["path"])
        result = git(
            "submodule",
            "update",
            "--init",
            "--depth",
            "1",
            "--",
            path,
            cwd=dependency.destination,
            timeout=600,
        )
        if result.returncode != 0:
            raise SystemExit(
                f"{dependency.name}/{path}: submodule checkout failed:\n"
                f"{result.stdout}{result.stderr}"
            )
    verify_submodules(dependency, lock)


def verify_one(dependency: Dependency) -> dict[str, object]:
    lock = load_lock(dependency)
    actual = current_commit(dependency)
    expected = str(lock["commit"])
    if actual != expected:
        raise SystemExit(
            f"{dependency.name}: expected commit {expected}, "
            f"got {actual or 'missing'}"
        )
    expected_url = str(lock["url"]).rstrip("/")
    actual_url = (current_remote(dependency) or "").rstrip("/")
    if actual_url != expected_url:
        raise SystemExit(
            f"{dependency.name}: expected origin {expected_url}, "
            f"got {actual_url or 'missing'}"
        )
    verify_submodules(dependency, lock)
    missing = [
        str(path)
        for path in lock["required_paths"]
        if not (dependency.destination / str(path)).exists()
    ]
    if missing:
        raise SystemExit(
            f"{dependency.name}: checkout is incomplete; missing:\n"
            + "\n".join(f"  {path}" for path in missing)
        )
    manifest = {
        "schema_version": 1,
        "kind": "external_dependency",
        "name": dependency.name,
        "url": lock["url"],
        "ref": lock.get("ref"),
        "commit": actual,
        "sparse_paths": [str(path) for path in lock.get("sparse_paths", [])],
    }
    write_json_atomic(build_path("manifest", f"{dependency.name}.json"), manifest)
    print(f"{dependency.name} dependency verified: {actual}")
    return lock


def initialize_checkout(
    dependency: Dependency,
    lock: dict[str, object],
) -> None:
    destination = dependency.destination
    if destination.exists():
        if any(destination.iterdir()):
            raise SystemExit(
                f"{dependency.name}: destination is non-empty and not the locked "
                f"checkout: {destination}"
            )
        destination.rmdir()
    destination.mkdir(parents=True)

    commands = (
        ("init",),
        ("config", "core.autocrlf", "false"),
        ("config", "core.symlinks", "false"),
        ("remote", "add", "origin", str(lock["url"])),
    )
    for command in commands:
        result = git(*command, cwd=destination)
        if result.returncode != 0:
            raise SystemExit(
                f"{dependency.name}: git {' '.join(command)} failed:\n"
                f"{result.stdout}{result.stderr}"
            )

    configure_sparse(dependency, lock)
    fetch = git(
        "fetch",
        "--filter=blob:none",
        "--depth",
        "1",
        "origin",
        str(lock["commit"]),
        cwd=destination,
        timeout=600,
    )
    if fetch.returncode != 0:
        raise SystemExit(
            f"{dependency.name}: fetch failed:\n{fetch.stdout}{fetch.stderr}"
        )
    checkout = git("checkout", "--detach", "FETCH_HEAD", cwd=destination)
    if checkout.returncode != 0:
        raise SystemExit(
            f"{dependency.name}: checkout failed:\n"
            f"{checkout.stdout}{checkout.stderr}"
        )
    initialize_submodules(dependency, lock)


def fetch_one(dependency: Dependency) -> None:
    lock = load_lock(dependency)
    actual = current_commit(dependency)
    if actual == lock["commit"]:
        configure_sparse(dependency, lock)
        initialize_submodules(dependency, lock)
        verify_one(dependency)
        print(f"{dependency.name} already present at the locked revision")
        return
    initialize_checkout(dependency, lock)
    verify_one(dependency)
    print(f"Fetched {dependency.name} into {dependency.destination}")


def selected_dependencies(name: str) -> list[Dependency]:
    if name == "all":
        return list(DEPENDENCIES.values())
    return [DEPENDENCIES[name]]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch and verify pinned SocRV external dependencies."
    )
    parser.add_argument(
        "--dependency",
        choices=["all", *sorted(DEPENDENCIES)],
        default="all",
    )
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if not shutil.which("git"):
        raise SystemExit("git executable not found")
    for dependency in selected_dependencies(args.dependency):
        if args.verify:
            verify_one(dependency)
        else:
            fetch_one(dependency)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
