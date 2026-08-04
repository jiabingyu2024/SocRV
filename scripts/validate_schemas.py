from __future__ import annotations

import json
from pathlib import Path

from jsonschema import Draft202012Validator

from lib.repo import repo_path


def main() -> int:
    schema_dir = repo_path("data", "schemas")
    schemas = sorted(schema_dir.glob("*.schema.json"))
    if not schemas:
        print(f"No schemas found under {schema_dir}")
        return 1
    for path in schemas:
        schema = json.loads(path.read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
        print(f"Schema OK: {path.relative_to(repo_path())}")
    instances = [
        ("board.schema.json", repo_path("fpga", "boards", "kintex7_competition", "board.json")),
        ("memory_map.schema.json", repo_path("data", "soc", "memory_map.json")),
        *[
            ("profile.schema.json", path)
            for path in sorted(repo_path("data", "profiles").glob("*.json"))
        ],
        *[
            ("testlist.schema.json", path)
            for path in sorted(repo_path("data", "tests").glob("*.json"))
        ],
    ]
    loaded = {
        path.name: json.loads(path.read_text(encoding="utf-8"))
        for path in schemas
    }
    for schema_name, path in instances:
        instance = json.loads(path.read_text(encoding="utf-8"))
        Draft202012Validator(loaded[schema_name]).validate(instance)
        print(f"Data OK:   {path.relative_to(repo_path())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
