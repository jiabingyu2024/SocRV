from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

from elf2mem import Region, convert
from lib.hashing import sha256_file
from lib.manifest import read_json, write_json_atomic
from lib.repo import build_path, ensure_within, repo_path
from lib.wsl import bash, in_repo


LOCK_PATH = repo_path("software", "riscv-tests", "dependency.lock.json")
TESTLIST_PATH = repo_path("software", "riscv-tests", "tests.json")
UPSTREAM = repo_path("software", "riscv-tests", "upstream")
ENVIRONMENT = repo_path("software", "riscv-tests", "env", "socrv")
DESTINATION = repo_path("data", "isa")


def run_wsl(argv: list[str], *, timeout: int = 180) -> None:
    result = bash(in_repo(repo_path(), argv), timeout=timeout, check=False)
    if result.returncode != 0:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(argv)}\n"
            f"{result.stdout}{result.stderr}"
        )


def upstream_commit() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=UPSTREAM,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError("riscv-tests upstream checkout is missing")
    return result.stdout.strip()


def build_test(
    suite: str,
    name: str,
    output: Path,
    march: str,
    mabi: str,
    memory_map: dict[str, object],
    contract: dict[str, object],
    memory_map_hash: str,
) -> dict[str, object]:
    source = UPSTREAM / "isa" / suite / f"{name}.S"
    if not source.is_file():
        raise RuntimeError(f"riscv-tests source is missing: {source}")
    output.mkdir(parents=True, exist_ok=True)
    elf = output / "firmware.elf"
    relative_elf = elf.relative_to(repo_path()).as_posix()
    run_wsl(
        [
            "riscv64-unknown-elf-gcc",
            f"-march={march}",
            f"-mabi={mabi}",
            "-nostdlib",
            "-nostartfiles",
            "-static",
            "-Wl,--gc-sections",
            "-Isoftware/riscv-tests/env/socrv",
            "-Isoftware/riscv-tests/upstream/isa/macros/scalar",
            source.relative_to(repo_path()).as_posix(),
            "-Tsoftware/riscv-tests/env/socrv/link.ld",
            f"-Wl,-Map,{(output / 'firmware.map').relative_to(repo_path()).as_posix()}",
            "-o",
            relative_elf,
        ]
    )
    disassembly = bash(
        in_repo(
            repo_path(),
            ["riscv64-unknown-elf-objdump", "-d", "-S", relative_elf],
        ),
        timeout=60,
        check=False,
    )
    if disassembly.returncode != 0:
        raise RuntimeError(f"objdump failed for {name}")
    (output / "firmware.dis").write_text(
        disassembly.stdout,
        encoding="utf-8",
        newline="\n",
    )

    regions = [
        Region.parse(
            "CODE:"
            f"{memory_map['regions']['CODE']['base']}:"
            f"{memory_map['regions']['CODE']['size']}:"
            f"{output / 'code.mem'}"
        ),
        Region.parse(
            "DATA:"
            f"{memory_map['regions']['DATA']['base']}:"
            f"{memory_map['regions']['DATA']['size']}:"
            f"{output / 'data.mem'}"
        ),
    ]
    image_manifest = output / "image.json"
    convert(
        elf,
        regions,
        image_manifest,
        profile=f"riscv-tests/{suite}/{name}",
        contract=contract,
        memory_map_hash=memory_map_hash,
        test_status_base=int(
            memory_map["regions"]["TEST_STATUS"]["base"],
            0,
        ),
        trim=True,
    )
    image_document = read_json(image_manifest)
    image_document["elf"]["path"] = (
        f"data/isa/{suite}/{name}/firmware.elf"
    )
    for region in image_document["regions"]:
        region["file"] = (
            f"data/isa/{suite}/{name}/"
            f"{Path(region['file']).name}"
        )
    write_json_atomic(image_manifest, image_document)
    return {
        "name": name,
        "source": source.relative_to(repo_path()).as_posix(),
        "source_sha256": sha256_file(source),
        "elf": elf.relative_to(output.parents[1]).as_posix(),
        "elf_sha256": sha256_file(elf),
        "image_manifest": image_manifest.relative_to(output.parents[1]).as_posix(),
    }


def replace_dataset(staging: Path) -> None:
    destination = ensure_within(DESTINATION, repo_path("data"))
    if destination != repo_path("data", "isa").resolve():
        raise RuntimeError(f"refusing unexpected ISA destination: {destination}")
    if destination.exists():
        old_manifest = destination / "manifest.json"
        if old_manifest.is_file():
            digest = sha256_file(old_manifest)[:12]
        else:
            digest = "unmanifested"
        backup = build_path("quarantine", f"data-isa-{digest}")
        if not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            destination.replace(backup)
            print(f"Previous ISA dataset preserved at {backup}")
        else:
            shutil.rmtree(destination)
    shutil.copytree(staging, destination)


def verify_dataset(destination: Path = DESTINATION) -> None:
    manifest_path = destination / "manifest.json"
    manifest = read_json(manifest_path)
    schema = read_json(
        repo_path("data", "schemas", "isa_dataset.schema.json")
    )
    Draft202012Validator(schema).validate(manifest)
    memory_map_hash = sha256_file(
        repo_path("data", "soc", "memory_map.json")
    )
    if manifest["memory_map_sha256"] != memory_map_hash:
        raise RuntimeError("ISA dataset was built for a different Memory Map")
    failures: list[str] = []
    image_schema = read_json(
        repo_path("data", "schemas", "image.schema.json")
    )
    for test in manifest["tests"]:
        test_root = destination / manifest["suite"] / test["name"]
        elf = test_root / "firmware.elf"
        image = test_root / "image.json"
        if not elf.is_file() or sha256_file(elf) != test["elf_sha256"]:
            failures.append(f"{test['name']}: ELF hash mismatch")
        if not image.is_file():
            failures.append(f"{test['name']}: image manifest missing")
            continue
        image_document = read_json(image)
        Draft202012Validator(image_schema).validate(image_document)
        image_elf = repo_path(*Path(image_document["elf"]["path"]).parts)
        if (
            not image_elf.is_file()
            or sha256_file(image_elf) != image_document["elf"]["sha256"]
        ):
            failures.append(f"{test['name']}: image ELF hash mismatch")
        for region in image_document["regions"]:
            region_path = repo_path(*Path(region["file"]).parts)
            if (
                not region_path.is_file()
                or sha256_file(region_path) != region["sha256"]
            ):
                failures.append(
                    f"{test['name']}: {region['name']} image hash mismatch"
                )
    if failures:
        raise RuntimeError("\n".join(failures))
    print(
        f"ISA dataset verified: {len(manifest['tests'])} "
        f"{manifest['suite']} tests"
    )


def generate() -> None:
    lock = read_json(LOCK_PATH)
    testlist = read_json(TESTLIST_PATH)
    actual_commit = upstream_commit()
    if actual_commit != lock["commit"]:
        raise RuntimeError(
            f"riscv-tests commit mismatch: {actual_commit} != {lock['commit']}"
        )
    memory_map_path = repo_path("data", "soc", "memory_map.json")
    memory_map = read_json(memory_map_path)
    contract = read_json(repo_path("data", "soc", "software_contract.json"))
    if testlist["march"] != contract["cpu"]["march"]:
        raise RuntimeError("riscv-tests march differs from software contract")
    memory_map_hash = sha256_file(memory_map_path)
    staging = build_path("isa-data", "generated")
    if staging.exists():
        shutil.rmtree(staging)
    suite = testlist["suite"]
    test_entries = []
    for name in testlist["tests"]:
        output = staging / suite / name
        test_entries.append(
            build_test(
                suite,
                name,
                output,
                testlist["march"],
                contract["cpu"]["mabi"],
                memory_map,
                contract,
                memory_map_hash,
            )
        )
        print(f"Built {suite}/{name}")
    write_json_atomic(
        staging / "manifest.json",
        {
            "schema_version": 1,
            "kind": "generated_isa_dataset",
            "suite": suite,
            "march": testlist["march"],
            "mabi": contract["cpu"]["mabi"],
            "upstream": {
                "url": lock["url"],
                "commit": lock["commit"],
            },
            "memory_map_sha256": memory_map_hash,
            "tests": test_entries,
            "excluded": testlist["excluded"],
        },
    )
    replace_dataset(staging)
    verify_dataset()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate SocRV ISA data from locked official riscv-tests sources."
    )
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    try:
        if args.verify:
            verify_dataset()
        else:
            generate()
    except (
        OSError,
        RuntimeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
