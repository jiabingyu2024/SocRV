from __future__ import annotations

import argparse
import json
import struct
from dataclasses import dataclass
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import write_json_atomic
from lib.repo import repo_path


ELF_HEADER = struct.Struct("<16sHHIIIIIHHHHHH")
PROGRAM_HEADER = struct.Struct("<IIIIIIII")
PT_LOAD = 1


@dataclass(frozen=True)
class Segment:
    address: int
    data: bytes
    memory_size: int
    flags: int


@dataclass
class Region:
    name: str
    base: int
    size: int
    output: Path
    image: bytearray
    used_end: int = 0
    stored_words: int = 0

    @classmethod
    def parse(cls, value: str) -> "Region":
        fields = value.split(":", 3)
        if len(fields) != 4:
            raise argparse.ArgumentTypeError(
                "region must be NAME:BASE:SIZE:OUTPUT"
            )
        name, base_text, size_text, output_text = fields
        base = int(base_text, 0)
        size = int(size_text, 0)
        if not name or size <= 0 or base < 0:
            raise argparse.ArgumentTypeError(f"invalid region: {value}")
        return cls(name=name, base=base, size=size, output=Path(output_text), image=bytearray(size))

    def contains(self, address: int, size: int) -> bool:
        return self.base <= address and address + size <= self.base + self.size

    def place(self, segment: Segment) -> None:
        offset = segment.address - self.base
        self.image[offset : offset + len(segment.data)] = segment.data
        memory_end = offset + segment.memory_size
        if memory_end > offset + len(segment.data):
            self.image[offset + len(segment.data) : memory_end] = bytes(
                memory_end - offset - len(segment.data)
            )
        self.used_end = max(self.used_end, memory_end)


def parse_elf32_little(path: Path) -> tuple[int, list[Segment]]:
    blob = path.read_bytes()
    if len(blob) < ELF_HEADER.size:
        raise ValueError("ELF file is too small")
    values = ELF_HEADER.unpack_from(blob)
    ident = values[0]
    if ident[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    if ident[4] != 1:
        raise ValueError("SocRV image conversion requires ELF32")
    if ident[5] != 1:
        raise ValueError("SocRV image conversion requires little-endian ELF")
    entry = values[4]
    program_offset = values[5]
    program_entry_size = values[9]
    program_count = values[10]
    if program_entry_size < PROGRAM_HEADER.size:
        raise ValueError(f"unsupported program-header size: {program_entry_size}")

    segments: list[Segment] = []
    for index in range(program_count):
        offset = program_offset + index * program_entry_size
        if offset + PROGRAM_HEADER.size > len(blob):
            raise ValueError("program-header table extends beyond ELF")
        (
            segment_type,
            file_offset,
            virtual_address,
            physical_address,
            file_size,
            memory_size,
            flags,
            _alignment,
        ) = PROGRAM_HEADER.unpack_from(blob, offset)
        if segment_type != PT_LOAD or memory_size == 0:
            continue
        if file_size > memory_size:
            raise ValueError(f"PT_LOAD {index} has file size larger than memory size")
        if file_offset + file_size > len(blob):
            raise ValueError(f"PT_LOAD {index} extends beyond ELF")
        address = physical_address if physical_address != 0 else virtual_address
        segments.append(
            Segment(
                address=address,
                data=blob[file_offset : file_offset + file_size],
                memory_size=memory_size,
                flags=flags,
            )
        )
    if not segments:
        raise ValueError("ELF contains no loadable segments")
    return entry, segments


def manifest_path(path: Path) -> str:
    resolved = path.resolve()
    root = repo_path().resolve()
    if resolved == root or root in resolved.parents:
        return resolved.relative_to(root).as_posix()
    return resolved.as_posix()


def write_word_mem(region: Region, *, trim: bool) -> None:
    region.output.parent.mkdir(parents=True, exist_ok=True)
    output_size = region.size
    if trim:
        output_size = max(4, (region.used_end + 3) & ~3)
    padded_size = (output_size + 3) & ~3
    if padded_size != len(region.image):
        if padded_size > len(region.image):
            region.image.extend(bytes(padded_size - len(region.image)))
    region.stored_words = padded_size // 4
    with region.output.open("w", encoding="ascii", newline="\n") as stream:
        for offset in range(0, padded_size, 4):
            word = int.from_bytes(region.image[offset : offset + 4], "little")
            stream.write(f"{word:08x}\n")


def write_instruction_banks(region: Region, low_output: Path, high_output: Path) -> list[dict[str, object]]:
    """Write the two physical 32-bit banks used by the 64-bit I-TCM port.

    The generic simulation backend continues to load the canonical code.mem
    image.  FPGA synthesis uses these fixed-size files directly, which avoids
    an elaboration-time array copy that would prevent clean BRAM inference.
    """
    if region.name != "CODE":
        raise ValueError("instruction bank files can only be generated for CODE")
    if region.size % 8:
        raise ValueError("CODE region must be a multiple of one 64-bit fetch word")
    low_output.parent.mkdir(parents=True, exist_ok=True)
    high_output.parent.mkdir(parents=True, exist_ok=True)
    with low_output.open("w", encoding="ascii", newline="\n") as low, high_output.open(
        "w", encoding="ascii", newline="\n"
    ) as high:
        for offset in range(0, region.size, 8):
            low_word = int.from_bytes(region.image[offset : offset + 4], "little")
            high_word = int.from_bytes(region.image[offset + 4 : offset + 8], "little")
            low.write(f"{low_word:08x}\n")
            high.write(f"{high_word:08x}\n")
    return [
        {
            "name": "CODE_LO",
            "file": manifest_path(low_output),
            "size": region.size // 2,
            "stored_words": region.size // 8,
            "sha256": sha256_file(low_output),
        },
        {
            "name": "CODE_HI",
            "file": manifest_path(high_output),
            "size": region.size // 2,
            "stored_words": region.size // 8,
            "sha256": sha256_file(high_output),
        },
    ]


def write_interleaved_banks(
    region: Region,
    outputs: list[Path],
    *,
    name_prefix: str,
) -> list[dict[str, object]]:
    """Split a flat little-endian word image across equal 32-bit TCM banks."""
    bank_count = len(outputs)
    if bank_count == 0 or region.size % (4 * bank_count):
        raise ValueError(
            f"{region.name} size must be a multiple of {bank_count} words"
        )
    depth = region.size // (4 * bank_count)
    entries: list[dict[str, object]] = []
    for bank, output in enumerate(outputs):
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("w", encoding="ascii", newline="\n") as stream:
            for row in range(depth):
                offset = (row * bank_count + bank) * 4
                word = int.from_bytes(region.image[offset : offset + 4], "little")
                stream.write(f"{word:08x}\n")
        entries.append(
            {
                "name": f"{name_prefix}{bank}",
                "file": manifest_path(output),
                "size": region.size // bank_count,
                "stored_words": depth,
                "sha256": sha256_file(output),
            }
        )
    return entries


def convert(
    elf: Path,
    regions: list[Region],
    output_manifest: Path,
    *,
    profile: str = "unspecified",
    contract: dict[str, object] | None = None,
    memory_map_hash: str | None = None,
    test_status_base: int | None = None,
    trim: bool = False,
    code_bank_low: Path | None = None,
    code_bank_high: Path | None = None,
    iccm_lanes: list[Path] | None = None,
    dccm_banks: list[Path] | None = None,
) -> None:
    entry, segments = parse_elf32_little(elf)
    placement: list[dict[str, object]] = []
    for segment in segments:
        matches = [region for region in regions if region.contains(segment.address, segment.memory_size)]
        if len(matches) != 1:
            raise ValueError(
                f"segment 0x{segment.address:08x}+0x{segment.memory_size:x} "
                f"matches {len(matches)} regions"
            )
        region = matches[0]
        region.place(segment)
        placement.append(
            {
                "region": region.name,
                "address": f"0x{segment.address:08x}",
                "file_size": len(segment.data),
                "memory_size": segment.memory_size,
                "flags": segment.flags,
            }
        )

    region_entries = []
    for region in regions:
        write_word_mem(region, trim=trim)
        region_entries.append(
            {
                "name": region.name,
                "base": f"0x{region.base:08x}",
                "size": region.size,
                "used": region.used_end,
                "stored_words": region.stored_words,
                "file": manifest_path(region.output),
                "sha256": sha256_file(region.output),
                "fill": "0x00000000",
            }
        )
    banks: list[dict[str, object]] = []
    if (code_bank_low is None) != (code_bank_high is None):
        raise ValueError("both instruction bank output paths are required")
    if code_bank_low is not None and code_bank_high is not None:
        code_region = next((region for region in regions if region.name == "CODE"), None)
        if code_region is None:
            raise ValueError("CODE region is required for instruction bank generation")
        banks = write_instruction_banks(code_region, code_bank_low, code_bank_high)
    if iccm_lanes:
        if len(iccm_lanes) != 4:
            raise ValueError("exactly four --iccm-lane outputs are required")
        code_region = next((region for region in regions if region.name == "CODE"), None)
        if code_region is None:
            raise ValueError("CODE region is required for ICCM lane generation")
        banks.extend(
            write_interleaved_banks(
                code_region, iccm_lanes, name_prefix="ICCM_LANE"
            )
        )
    if dccm_banks:
        if len(dccm_banks) != 8:
            raise ValueError("exactly eight --dccm-bank outputs are required")
        data_region = next((region for region in regions if region.name == "DATA"), None)
        if data_region is None:
            raise ValueError("DATA region is required for DCCM bank generation")
        banks.extend(
            write_interleaved_banks(
                data_region, dccm_banks, name_prefix="DCCM_BANK"
            )
        )
    manifest = {
        "schema_version": 2,
        "kind": "software_image",
        "profile": profile,
        "elf": {
            "path": manifest_path(elf),
            "sha256": sha256_file(elf),
        },
        "entry": f"0x{entry:08x}",
        "endianness": "little",
        "word_format": {
            "bits": 32,
            "hex_digits": 8,
            "address_unit": "word",
        },
        "regions": region_entries,
        "segments": placement,
    }
    if banks:
        manifest["banks"] = banks
    if contract is not None:
        cpu = contract["cpu"]
        test_status = contract["test_status"]
        manifest["isa"] = {
            "xlen": cpu["xlen"],
            "march": cpu["march"],
            "mabi": cpu["mabi"],
        }
        manifest["test_status"] = {
            "base": f"0x{test_status_base:08x}",
            "pass_magic": test_status["pass_magic"],
            "fail_magic": test_status["fail_magic"],
        }
    if memory_map_hash is not None:
        manifest["memory_map_sha256"] = memory_map_hash
    write_json_atomic(output_manifest, manifest)


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert an ELF32 little-endian image to word-oriented MEM files.")
    parser.add_argument("--elf", type=Path, required=True)
    parser.add_argument(
        "--region",
        type=Region.parse,
        action="append",
        required=True,
        help="NAME:BASE:SIZE:OUTPUT; repeat for every allowed load region",
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--profile", default="unspecified")
    parser.add_argument(
        "--contract",
        type=Path,
        default=repo_path("data", "soc", "software_contract.json"),
    )
    parser.add_argument(
        "--memory-map",
        type=Path,
        default=repo_path("data", "soc", "memory_map.json"),
    )
    parser.add_argument("--trim", action="store_true")
    parser.add_argument("--code-bank-low", type=Path)
    parser.add_argument("--code-bank-high", type=Path)
    parser.add_argument("--iccm-lane", type=Path, action="append")
    parser.add_argument("--dccm-bank", type=Path, action="append")
    args = parser.parse_args()
    try:
        contract = json.loads(args.contract.read_text(encoding="utf-8"))
        memory_map = json.loads(args.memory_map.read_text(encoding="utf-8"))
        convert(
            args.elf.resolve(),
            args.region,
            args.manifest.resolve(),
            profile=args.profile,
            contract=contract,
            memory_map_hash=sha256_file(args.memory_map),
            test_status_base=(
                int(memory_map["regions"]["SYSCTRL"]["base"], 0)
                + int(
                    contract["peripherals"]["SYSCTRL"]["registers"]
                    ["STATUS"]["offset"],
                    0,
                )
            ),
            trim=args.trim,
            code_bank_low=args.code_bank_low.resolve() if args.code_bank_low else None,
            code_bank_high=args.code_bank_high.resolve() if args.code_bank_high else None,
            iccm_lanes=[path.resolve() for path in args.iccm_lane]
            if args.iccm_lane
            else None,
            dccm_banks=[path.resolve() for path in args.dccm_bank]
            if args.dccm_bank
            else None,
        )
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Image manifest: {args.manifest.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
