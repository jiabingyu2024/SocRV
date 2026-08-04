from __future__ import annotations

import argparse
import struct
from dataclasses import dataclass
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import write_json_atomic


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


def write_word_mem(region: Region) -> None:
    region.output.parent.mkdir(parents=True, exist_ok=True)
    padded_size = (region.size + 3) & ~3
    if padded_size != len(region.image):
        region.image.extend(bytes(padded_size - len(region.image)))
    with region.output.open("w", encoding="ascii", newline="\n") as stream:
        for offset in range(0, padded_size, 4):
            word = int.from_bytes(region.image[offset : offset + 4], "little")
            stream.write(f"{word:08x}\n")


def convert(elf: Path, regions: list[Region], manifest_path: Path) -> None:
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
        write_word_mem(region)
        region_entries.append(
            {
                "name": region.name,
                "base": f"0x{region.base:08x}",
                "size": region.size,
                "used": region.used_end,
                "file": region.output.as_posix(),
                "sha256": sha256_file(region.output),
            }
        )
    manifest = {
        "schema_version": 1,
        "elf": {
            "path": elf.as_posix(),
            "sha256": sha256_file(elf),
        },
        "entry": f"0x{entry:08x}",
        "endianness": "little",
        "regions": region_entries,
        "segments": placement,
    }
    write_json_atomic(manifest_path, manifest)


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
    args = parser.parse_args()
    try:
        convert(args.elf.resolve(), args.region, args.manifest.resolve())
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Image manifest: {args.manifest.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
