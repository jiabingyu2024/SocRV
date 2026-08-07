from __future__ import annotations

import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ELF_HEADER = struct.Struct("<16sHHIIIIIHHHHHH")
PROGRAM_HEADER = struct.Struct("<IIIIIIII")


def synthetic_elf() -> bytes:
    ident = bytearray(16)
    ident[:4] = b"\x7fELF"
    ident[4] = 1
    ident[5] = 1
    ident[6] = 1
    header = ELF_HEADER.pack(
        bytes(ident),
        2,
        243,
        1,
        0,
        ELF_HEADER.size,
        0,
        0,
        ELF_HEADER.size,
        PROGRAM_HEADER.size,
        2,
        0,
        0,
        0,
    )
    code_offset = 0x100
    data_offset = 0x104
    code_header = PROGRAM_HEADER.pack(1, code_offset, 0, 0, 4, 4, 5, 4)
    data_header = PROGRAM_HEADER.pack(1, data_offset, 0x1000, 0x1000, 4, 8, 6, 4)
    blob = bytearray(data_offset + 4)
    blob[: len(header)] = header
    blob[ELF_HEADER.size : ELF_HEADER.size + PROGRAM_HEADER.size] = code_header
    second = ELF_HEADER.size + PROGRAM_HEADER.size
    blob[second : second + PROGRAM_HEADER.size] = data_header
    blob[code_offset : code_offset + 4] = b"\x01\x02\x03\x04"
    blob[data_offset : data_offset + 4] = b"\xaa\xbb\xcc\xdd"
    return bytes(blob)


class Elf2MemTest(unittest.TestCase):
    def test_split_regions_and_zero_fill(self) -> None:
        repo = Path(__file__).resolve().parents[2]
        script = repo / "scripts" / "elf2mem.py"
        schema_path = repo / "data" / "schemas" / "image.schema.json"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            elf = root / "test.elf"
            code = root / "code.mem"
            data = root / "data.mem"
            manifest = root / "image.json"
            elf.write_bytes(synthetic_elf())
            completed = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--elf",
                    str(elf),
                    "--region",
                    f"CODE:0x0:16:{code}",
                    "--region",
                    f"DATA:0x1000:16:{data}",
                    "--manifest",
                    str(manifest),
                ],
                cwd=repo,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertEqual(code.read_text(encoding="ascii").splitlines()[0], "04030201")
            data_lines = data.read_text(encoding="ascii").splitlines()
            self.assertEqual(data_lines[0], "ddccbbaa")
            self.assertEqual(data_lines[1], "00000000")
            image = json.loads(manifest.read_text(encoding="utf-8"))
            self.assertEqual(image["entry"], "0x00000000")
            self.assertEqual([region["used"] for region in image["regions"]], [4, 8])

            from jsonschema import Draft202012Validator

            schema = json.loads(schema_path.read_text(encoding="utf-8"))
            Draft202012Validator(schema).validate(image)


if __name__ == "__main__":
    unittest.main()
