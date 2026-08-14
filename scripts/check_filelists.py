from __future__ import annotations

import argparse
from pathlib import Path

from lib.repo import repo_path


def expand(path: Path, seen_lists: set[Path], sources: list[Path]) -> None:
    path = path.resolve()
    if path in seen_lists:
        raise ValueError(f"recursive filelist inclusion: {path}")
    seen_lists.add(path)
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("-f "):
            nested = repo_path(line[3:].strip())
            if not nested.exists():
                raise ValueError(f"{path}:{line_number}: missing nested filelist {nested}")
            expand(nested, seen_lists, sources)
        elif line.startswith("+incdir+"):
            include_dir = repo_path(line[len("+incdir+"):].strip())
            if not include_dir.is_dir():
                raise ValueError(
                    f"{path}:{line_number}: missing include directory "
                    f"{include_dir}"
                )
        elif line.startswith("-"):
            continue
        else:
            source = repo_path(line)
            if not source.exists():
                raise ValueError(f"{path}:{line_number}: missing source {source}")
            sources.append(source.resolve())
    seen_lists.remove(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "filelists",
        nargs="*",
        type=Path,
        default=[
            repo_path("rtl", "filelist.f"),
            repo_path("sim", "filelists", "soc_verilator.f"),
            repo_path("sim", "filelists", "fpga_axku062.f"),
            repo_path("sim", "filelists", "fpga_kintex7.f"),
            repo_path("sim", "filelists", "fpga_pynq_z2.f"),
        ],
    )
    args = parser.parse_args()
    failed = False
    for filelist in args.filelists:
        try:
            sources: list[Path] = []
            expand(filelist, set(), sources)
            duplicates = sorted({path for path in sources if sources.count(path) > 1})
            if duplicates:
                raise ValueError(f"duplicate sources: {duplicates}")
            print(f"Filelist OK: {filelist} ({len(sources)} sources)")
        except (OSError, ValueError) as error:
            print(f"Filelist ERROR: {error}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
