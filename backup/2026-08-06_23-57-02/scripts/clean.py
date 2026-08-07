from __future__ import annotations

import argparse
import shutil

from lib.repo import build_path, repo_path


TARGETS = {
    "software": (build_path("software"),),
    "images": (build_path("images"),),
    "sim": (
        build_path("verilator"),
        build_path("result"),
        build_path("log"),
        build_path("wave"),
    ),
    "regression": (build_path("regression"),),
    "fpga": (build_path("vivado"),),
    "all": (repo_path("build"),),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Remove a scoped SocRV generated-artifact directory.")
    parser.add_argument("scope", choices=sorted(TARGETS))
    args = parser.parse_args()
    build_root = repo_path("build").resolve()
    targets = tuple(target.resolve() for target in TARGETS[args.scope])
    for target in targets:
        if target != build_root and build_root not in target.parents:
            parser.error(f"refusing to clean outside build/: {target}")
    for target in targets:
        if target.exists():
            shutil.rmtree(target)
            print(f"Removed generated artifacts: {target}")
        else:
            print(f"Nothing to remove: {target}")
    if args.scope == "all":
        build_root.mkdir(parents=True, exist_ok=True)
        (build_root / ".gitkeep").touch()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
