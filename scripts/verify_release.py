from __future__ import annotations

import argparse
import json
from pathlib import Path

from build_software import PROFILES
from lib.hashing import sha256_file
from lib.repo import repo_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    args = parser.parse_args()
    release_dir = repo_path("build", "release", f"socrv-{args.profile}")
    manifest_path = release_dir / "manifest.json"
    if not manifest_path.exists():
        parser.error(f"release manifest is missing: {manifest_path}")
    document = json.loads(manifest_path.read_text(encoding="utf-8"))
    failures = []
    for entry in document["files"]:
        path = release_dir / entry["path"]
        if not path.exists():
            failures.append(f"missing {entry['path']}")
        elif path.stat().st_size != entry["size"]:
            failures.append(f"size mismatch {entry['path']}")
        elif sha256_file(path) != entry["sha256"]:
            failures.append(f"hash mismatch {entry['path']}")
    if failures:
        parser.error("; ".join(failures))
    print(f"Release verified: {release_dir} ({len(document['files'])} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
