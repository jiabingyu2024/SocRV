from __future__ import annotations

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

from lib.repo import repo_path


def read_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except PermissionError as error:
        raise RuntimeError(
            f"permission denied while reading {path}; fix the Windows ACL "
            "or exclude the inaccessible run from this validation"
        ) from error


def main() -> int:
    schema_dir = repo_path("data", "schemas")
    schemas = sorted(schema_dir.glob("*.schema.json"))
    if not schemas:
        print(f"No schemas found under {schema_dir}")
        return 1
    for path in schemas:
        schema = read_json(path)
        Draft202012Validator.check_schema(schema)
        print(f"Schema OK: {path.relative_to(repo_path())}")
    instances = [
        *[
            ("board.schema.json", path)
            for path in sorted(repo_path("fpga", "boards").glob("*/board.json"))
        ],
        ("memory_map.schema.json", repo_path("data", "soc", "memory_map.json")),
        (
            "software_contract.schema.json",
            repo_path("data", "soc", "software_contract.json"),
        ),
        (
            "isa_dataset.schema.json",
            repo_path("data", "isa", "manifest.json"),
        ),
        (
            "riscv_tests_selection.schema.json",
            repo_path("software", "riscv-tests", "tests.json"),
        ),
        *[
            ("profile.schema.json", path)
            for path in sorted(repo_path("data", "profiles").glob("*.json"))
        ],
        *[
            ("testlist.schema.json", path)
            for path in sorted(repo_path("data", "tests").glob("*.json"))
        ],
        *[
            ("software_build.schema.json", path)
            for path in sorted(
                repo_path("build", "software").glob("*/build_manifest.json")
            )
        ],
        *[
            ("competition_source.schema.json", path)
            for path in sorted(
                repo_path("competition_runs").glob(
                    "*/source/competition.json"
                )
            )
        ],
        *[
            ("software_build.schema.json", path)
            for path in sorted(
                repo_path("competition_runs").glob(
                    "*/software/build_manifest.json"
                )
            )
        ],
    ]
    loaded = {
        path.name: json.loads(path.read_text(encoding="utf-8"))
        for path in schemas
    }
    for schema_name, path in instances:
        instance = read_json(path)
        Draft202012Validator(loaded[schema_name]).validate(instance)
        print(f"Data OK:   {path.relative_to(repo_path())}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"Schema validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
