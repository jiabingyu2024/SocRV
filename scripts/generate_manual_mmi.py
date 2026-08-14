from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


ICCM_RE = re.compile(r"/iccm/lane([0-3])_reg_([0-7])$")
DCCM_RE = re.compile(r"/dccm_bank_gen\[([0-7])\]\.bank_mem_reg_([01])$")


@dataclass(frozen=True)
class Bram:
    cell: str
    loc: str
    ref_name: str
    primitive_type: str
    read_width_a: int
    read_width_b: int
    write_width_a: int
    write_width_b: int
    ram_mode: str
    porta_layout: str
    portb_layout: str


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_bram_map(path: Path) -> tuple[dict[str, str], list[Bram]]:
    metadata: dict[str, str] = {}
    data_lines: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("# ") and "=" in raw:
            key, value = raw[2:].split("=", 1)
            metadata[key] = value
        elif raw.strip():
            data_lines.append(raw)

    if not data_lines:
        raise ValueError(f"empty BRAM map: {path}")
    rows = csv.DictReader(data_lines, delimiter="\t")
    required = {
        "cell",
        "loc",
        "ref_name",
        "primitive_type",
        "read_width_a",
        "read_width_b",
        "write_width_a",
        "write_width_b",
        "ram_mode",
        "porta_layout",
        "portb_layout",
    }
    if rows.fieldnames is None or not required.issubset(rows.fieldnames):
        missing = sorted(required.difference(rows.fieldnames or ()))
        raise ValueError(f"BRAM map is missing columns: {', '.join(missing)}")

    brams = [
        Bram(
            cell=row["cell"],
            loc=row["loc"],
            ref_name=row["ref_name"],
            primitive_type=row["primitive_type"],
            read_width_a=int(row["read_width_a"]),
            read_width_b=int(row["read_width_b"]),
            write_width_a=int(row["write_width_a"]),
            write_width_b=int(row["write_width_b"]),
            ram_mode=row["ram_mode"],
            porta_layout=row["porta_layout"],
            portb_layout=row["portb_layout"],
        )
        for row in rows
    ]
    return metadata, brams


def classify(brams: list[Bram]) -> tuple[dict[int, dict[int, Bram]], dict[int, dict[int, Bram]]]:
    iccm = {lane: {} for lane in range(4)}
    dccm = {bank: {} for bank in range(8)}
    seen_cells: set[str] = set()
    seen_locs: set[str] = set()

    for bram in brams:
        if bram.cell in seen_cells:
            raise ValueError(f"duplicate BRAM cell: {bram.cell}")
        if bram.loc in seen_locs:
            raise ValueError(f"duplicate BRAM LOC: {bram.loc}")
        seen_cells.add(bram.cell)
        seen_locs.add(bram.loc)

        match = ICCM_RE.search(bram.cell)
        if match:
            lane, slice_index = map(int, match.groups())
            iccm[lane][slice_index] = bram
            continue
        match = DCCM_RE.search(bram.cell)
        if match:
            bank, slice_index = map(int, match.groups())
            dccm[bank][slice_index] = bram
            continue
        raise ValueError(f"unrecognized ICCM/DCCM BRAM cell: {bram.cell}")

    if len(brams) != 48:
        raise ValueError(f"expected 48 BRAMs, got {len(brams)}")
    for lane, slices in iccm.items():
        if set(slices) != set(range(8)):
            raise ValueError(f"ICCM lane {lane} does not contain slices 0..7")
        for bram in slices.values():
            expected = (4, 4, 4, 4, "p0_d4", "p0_d4")
            actual = (
                bram.read_width_a,
                bram.read_width_b,
                bram.write_width_a,
                bram.write_width_b,
                bram.porta_layout,
                bram.portb_layout,
            )
            if actual != expected:
                raise ValueError(f"unexpected ICCM BRAM geometry at {bram.cell}: {actual}")
    for bank, slices in dccm.items():
        if set(slices) != {0, 1}:
            raise ValueError(f"DCCM bank {bank} does not contain slices 0 and 1")
        for index, layout in ((0, "p2_d16"), (1, "p0_d14")):
            bram = slices[index]
            expected = (18, 18, 18, 18, layout, layout)
            actual = (
                bram.read_width_a,
                bram.read_width_b,
                bram.write_width_a,
                bram.write_width_b,
                bram.porta_layout,
                bram.portb_layout,
            )
            if actual != expected:
                raise ValueError(f"unexpected DCCM BRAM geometry at {bram.cell}: {actual}")
    return iccm, dccm


def add_bram(
    layout: ET.Element,
    bram: Bram,
    lsb: int,
    msb: int,
    end_address: int,
) -> None:
    node = ET.SubElement(
        layout,
        "BRAM",
        {
            "MemType": "RAMB36",
            "Placement": bram.loc.removeprefix("RAMB36_"),
            "Read_Width_A": str(bram.read_width_a),
            "Read_Width_B": str(bram.read_width_b),
            "SLR_INDEX": "0",
        },
    )
    for port, bit_layout in (("A", bram.porta_layout), ("B", bram.portb_layout)):
        ET.SubElement(node, f"DataWidth_Port{port}", {"MSB": str(msb), "LSB": str(lsb)})
        ET.SubElement(
            node,
            f"AddressRange_Port{port}",
            {"Begin": "0", "End": str(end_address)},
        )
        ET.SubElement(node, f"BitLayout_Port{port}", {"pattern": bit_layout})
    ET.SubElement(node, "Parity", {"ON": "false", "NumBits": "0"})


def add_memory_array(root: ET.Element, name: str, end_address: int) -> ET.Element:
    array = ET.SubElement(
        root,
        "MemoryArray",
        {"InstPath": name, "MemoryPrimitive": "block", "MemoryConfiguration": "ram"},
    )
    return ET.SubElement(
        array,
        "MemoryLayout",
        {"Name": name, "CoreMemory_Width": "32", "MemoryType": "RAM_TDP"},
    )


def generate(bram_map: Path, output: Path, validation: Path) -> None:
    metadata, brams = read_bram_map(bram_map)
    part = metadata.get("part")
    if not part:
        raise ValueError("BRAM map does not declare '# part=...'")
    iccm, dccm = classify(brams)

    root = ET.Element("MemInfo", {"Version": "1", "Minor": "9"})
    for lane in range(4):
        layout = add_memory_array(root, f"ICCM_LANE{lane}", 8191)
        for index in range(8):
            add_bram(layout, iccm[lane][index], index * 4, index * 4 + 3, 8191)
    for bank in range(8):
        layout = add_memory_array(root, f"DCCM_BANK{bank}", 2047)
        add_bram(layout, dccm[bank][0], 0, 17, 2047)
        add_bram(layout, dccm[bank][1], 18, 31, 2047)

    config = ET.SubElement(root, "Config")
    ET.SubElement(config, "Option", {"Name": "Part", "Val": part})
    drc = ET.SubElement(root, "DRC")
    ET.SubElement(drc, "Rule", {"Name": "RDADDRCHANGE", "Val": "false"})
    ET.indent(root, space="  ")
    tree = ET.ElementTree(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="UTF-8", xml_declaration=True)

    payload = {
        "schema_version": 1,
        "status": "pass",
        "part": part,
        "source_dcp": metadata.get("source_dcp"),
        "bram_count": len(brams),
        "unique_loc_count": len({bram.loc for bram in brams}),
        "memory_arrays": [
            *[f"ICCM_LANE{lane}" for lane in range(4)],
            *[f"DCCM_BANK{bank}" for bank in range(8)],
        ],
        "bram_map_sha256": sha256(bram_map),
        "mmi_sha256": sha256(output),
    }
    validation.parent.mkdir(parents=True, exist_ok=True)
    validation.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate and validate a manual SocRV MMI file.")
    parser.add_argument("--bram-map", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validation", type=Path)
    args = parser.parse_args()
    validation = args.validation or args.output.with_name("mmi_validation.json")
    generate(args.bram_map.resolve(), args.output.resolve(), validation.resolve())
    print(f"MMI={args.output.resolve()}")
    print(f"VALIDATION={validation.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
