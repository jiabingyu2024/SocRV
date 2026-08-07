from __future__ import annotations

from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def repo_path(*parts: str) -> Path:
    return repo_root().joinpath(*parts)


def ensure_within(path: Path, root: Path) -> Path:
    resolved_path = path.resolve()
    resolved_root = root.resolve()
    if resolved_path != resolved_root and resolved_root not in resolved_path.parents:
        raise ValueError(f"path escapes allowed root: {resolved_path} (root {resolved_root})")
    return resolved_path


def build_path(*parts: str) -> Path:
    path = repo_path("build", *parts)
    return ensure_within(path, repo_path("build"))
