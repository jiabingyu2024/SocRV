from __future__ import annotations

from pathlib import Path

from lib.repo import repo_path


FORBIDDEN_NAMES = {
    "vivado.log",
    "vivado.jou",
    "xsim.log",
    "xsim.jou",
    "xvlog.log",
    "xelab.log",
}
FORBIDDEN_PARTS = {
    "obj_dir",
    ".Xil",
}


def main() -> int:
    root = repo_path()
    build = repo_path("build").resolve()
    violations: list[Path] = []
    for path in root.rglob("*"):
        resolved = path.resolve()
        if resolved == build or build in resolved.parents:
            continue
        if path.name in FORBIDDEN_NAMES or any(part in FORBIDDEN_PARTS for part in path.parts):
            violations.append(path)
    if violations:
        print("Generated artifacts found outside build/:")
        for path in violations:
            print(f"  {path.relative_to(root)}")
        return 1
    print("Generated-tree check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
