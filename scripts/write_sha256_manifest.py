from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Write a deterministic SHA-256 manifest for a directory.")
    parser.add_argument("root", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    output = (args.output or (root / "sha256.txt")).resolve()
    files = sorted(path for path in root.rglob("*") if path.is_file() and path != output)
    lines = [f"{sha256(path)}  {path.relative_to(root).as_posix()}" for path in files]
    output.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"SHA256_MANIFEST={output}")
    print(f"FILE_COUNT={len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
