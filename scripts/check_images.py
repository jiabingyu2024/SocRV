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
    memory_map_path = repo_path("data", "soc", "memory_map.json")
    memory_map = json.loads(memory_map_path.read_text(encoding="utf-8"))
    contract = json.loads(
        repo_path("data", "soc", "software_contract.json").read_text(
            encoding="utf-8"
        )
    )
    expected_map_hash = sha256_file(memory_map_path)
    if document["memory_map_sha256"] != expected_map_hash:
        raise ValueError(
            f"image uses a stale memory map: {path}; rebuild the profile"
        )
    expected_regions = memory_map["regions"]
    for region in document["regions"]:
        expected = expected_regions.get(region["name"])
        if expected is None:
            raise ValueError(f"image contains unknown region: {region['name']}")
        if int(region["base"], 0) != int(expected["base"], 0) or (
            region["size"] != int(expected["size"], 0)
        ):
            raise ValueError(
                f"image region {region['name']} does not match the current map"
            )
    status_offset = contract["peripherals"]["SYSCTRL"]["registers"]
    status_offset = int(status_offset["STATUS"]["offset"], 0)
    expected_status = (
        int(expected_regions["SYSCTRL"]["base"], 0) + status_offset
    )
    if int(document["test_status"]["base"], 0) != expected_status:
        raise ValueError(
            f"image test-status address is stale: {path}; rebuild the profile"
        )
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
    for bank in document.get("banks", []):
        image = Path(bank["file"])
        if not image.is_absolute():
            image = repo_path(image.as_posix())
        if not image.exists() or sha256_file(image) != bank["sha256"]:
            raise ValueError(f"bank hash mismatch: {image}")
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
