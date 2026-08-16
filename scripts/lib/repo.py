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


def ensure_directory_accessible(path: Path, *, label: str = "directory") -> Path:
    """Fail with an actionable error when Windows denies directory traversal."""
    try:
        if not path.is_dir():
            raise ValueError(f"{label} does not exist or is not a directory: {path}")
        next(path.iterdir(), None)
    except PermissionError as error:
        raise ValueError(
            f"{label} is not accessible: {path}; fix its Windows ACL "
            "or use a new run-id"
        ) from error
    return path


def build_path(*parts: str) -> Path:
    path = repo_path("build", *parts)
    return ensure_within(path, repo_path("build"))
