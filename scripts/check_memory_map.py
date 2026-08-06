from __future__ import annotations

import json
import re

from generate_soc_contract import OUTPUTS, rendered_outputs
from lib.repo import repo_path


SV_PATTERN = re.compile(
    r"localparam\s+logic\s+\[31:0\]\s+([A-Z0-9_]+)_(BASE|SIZE)\s*=\s*32'h([0-9a-fA-F_]+)"
)
C_PATTERN = re.compile(r"#define\s+SOCRV_([A-Z0-9_]+)_(BASE|SIZE)\s+0x([0-9a-fA-F]+)u")


def parse_constants(text: str, pattern: re.Pattern[str]) -> dict[str, int]:
    values: dict[str, int] = {}
    for name, kind, digits in pattern.findall(text):
        values[f"{name}_{kind}"] = int(digits.replace("_", ""), 16)
    return values


def main() -> int:
    document = json.loads(repo_path("data", "soc", "memory_map.json").read_text(encoding="utf-8"))
    contract = json.loads(
        repo_path("data", "soc", "software_contract.json").read_text(
            encoding="utf-8"
        )
    )
    expected: dict[str, int] = {}
    for name, region in document["regions"].items():
        expected[f"{name}_BASE"] = int(region["base"], 0)
        expected[f"{name}_SIZE"] = int(region["size"], 0)

    sv_values = parse_constants(
        repo_path("rtl", "common", "pkg", "memory_map_pkg.sv").read_text(encoding="utf-8"),
        SV_PATTERN,
    )
    c_values = parse_constants(
        repo_path("software", "bsp", "include", "soc_memory_map.h").read_text(encoding="utf-8"),
        C_PATTERN,
    )
    failures = []
    for name, content in rendered_outputs().items():
        output = OUTPUTS[name]
        if not output.is_file() or output.read_text(encoding="utf-8") != content:
            failures.append(
                f"generated software contract is stale: "
                f"{output.relative_to(repo_path())}"
            )
    for peripheral_name, peripheral in contract["peripherals"].items():
        if peripheral["region"] not in document["regions"]:
            failures.append(
                f"software peripheral {peripheral_name} references unknown "
                f"region {peripheral['region']}"
            )
    for key, value in expected.items():
        if sv_values.get(key) != value:
            failures.append(f"RTL {key}: expected 0x{value:08x}, got {sv_values.get(key)!r}")
        if key in c_values and c_values[key] != value:
            failures.append(f"C {key}: expected 0x{value:08x}, got 0x{c_values[key]:08x}")
        if key.endswith("_BASE") and key not in c_values:
            failures.append(f"C header is missing {key}")
    if failures:
        print("\n".join(failures))
        return 1
    print(
        f"Memory map/software contract OK: {len(expected) // 2} regions, "
        f"{len(contract['peripherals'])} peripherals"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
