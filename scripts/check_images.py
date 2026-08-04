from __future__ import annotations

import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator

from lib.hashing import sha256_file
from lib.repo import repo_path


def check_manifest(path: Path) -> None:
    document = json.loads(path.read_text(encoding="utf-8"))
    schema = json.loads(repo_path("data", "schemas", "image.schema.json").read_text(encoding="utf-8"))
    Draft202012Validator(schema).validate(document)
    elf = Path(document["elf"]["path"])
    if not elf.is_absolute():
        elf = repo_path(elf.as_posix())
    if not elf.exists() or sha256_file(elf) != document["elf"]["sha256"]:
        raise ValueError(f"ELF hash mismatch: {elf}")
    for region in document["regions"]:
        image = Path(region["file"])
        if not image.is_absolute():
            image = repo_path(image.as_posix())
        if not image.exists() or sha256_file(image) != region["sha256"]:
            raise ValueError(f"region hash mismatch: {image}")
    print(f"Image OK: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifests", nargs="*", type=Path)
    args = parser.parse_args()
    manifests = args.manifests or sorted(repo_path("build", "images").glob("*/image.json"))
    if not manifests:
        parser.error("no generated image manifests found")
    try:
        for path in manifests:
            check_manifest(path.resolve())
    except (OSError, ValueError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
