from __future__ import annotations

import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch as mock_patch

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import patch_bitstream
from generate_manual_mmi import generate
from patch_bitstream import BASE_BIT_RELATIVE, read_flat_mem, split_words, validate_mmi


class BitstreamPatchTest(unittest.TestCase):
    @staticmethod
    def write_bram_map(path: Path, part: str = "xc7z020clg400-1") -> None:
        lines = [
            "# bram_map_version=1",
            f"# part={part}",
            "# source_bit=C:/base/project/socrv.runs/impl_1/fpga_top.bit",
            "cell\tloc\tref_name\tprimitive_type\tread_width_a\tread_width_b\twrite_width_a\twrite_width_b\tram_mode\tdoa_reg\tdob_reg\tporta_layout\tportb_layout",
        ]
        for lane in range(4):
            for index in range(8):
                lines.append(
                    f"u_soc/core/mem/iccm/lane{lane}_reg_{index}\tRAMB36_X0Y{lane * 8 + index}\tRAMB36E1\tBMEM.bram.RAMB36E1\t4\t4\t4\t4\tTDP\t0\t0\tp0_d4\tp0_d4"
                )
        for bank in range(8):
            for index, layout in ((0, "p2_d16"), (1, "p0_d14")):
                lines.append(
                    f"u_soc/core/mem/Gen_dccm_enable.dccm/dccm_bank_gen[{bank}].bank_mem_reg_{index}\tRAMB36_X1Y{bank * 2 + index}\tRAMB36E1\tBMEM.bram.RAMB36E1\t18\t18\t18\t18\tTDP\t0\t0\t{layout}\t{layout}"
                )
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    @classmethod
    def make_patch_tree(cls, root: Path) -> tuple[Path, Path, Path]:
        base_dir = root / "base" / "vivado" / "pynq_z2-50mhz"
        out_dir = root / "target"
        base_bit = base_dir / BASE_BIT_RELATIVE
        base_bit.parent.mkdir(parents=True)
        base_bit.write_bytes(b"test-bitstream")
        cls.write_bram_map(base_dir / "bram_map.tsv")
        images = out_dir / "images"
        images.mkdir(parents=True)
        (images / "code.mem").write_text("00000000\n" * 32768, encoding="ascii")
        (images / "data.mem").write_text("00000000\n" * 16384, encoding="ascii")
        executable = root / "updatemem.bat"
        executable.write_text("", encoding="ascii")
        return base_dir, out_dir, executable

    def test_flat_mem_validation_and_interleave(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "code.mem"
            path.write_text("00000000\n00000001\n00000002\n00000003\n", encoding="ascii")
            words = read_flat_mem(path, 4)
            self.assertEqual(split_words(words, 2), [["00000000", "00000002"], ["00000001", "00000003"]])

    def test_manual_mmi_covers_all_arrays_and_brams(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bram_map = root / "bram_map.tsv"
            lines = [
                "# bram_map_version=1",
                "# part=xc7z020clg400-1",
                "# source_dcp=C:/golden.dcp",
                "cell\tloc\tref_name\tprimitive_type\tread_width_a\tread_width_b\twrite_width_a\twrite_width_b\tram_mode\tdoa_reg\tdob_reg\tporta_layout\tportb_layout",
            ]
            for lane in range(4):
                for index in range(8):
                    lines.append(
                        f"u_soc/core/mem/iccm/lane{lane}_reg_{index}\tRAMB36_X0Y{lane * 8 + index}\tRAMB36E1\tBMEM.bram.RAMB36E1\t4\t4\t4\t4\tTDP\t0\t0\tp0_d4\tp0_d4"
                    )
            for bank in range(8):
                for index, layout in ((0, "p2_d16"), (1, "p0_d14")):
                    lines.append(
                        f"u_soc/core/mem/Gen_dccm_enable.dccm/dccm_bank_gen[{bank}].bank_mem_reg_{index}\tRAMB36_X1Y{bank * 2 + index}\tRAMB36E1\tBMEM.bram.RAMB36E1\t18\t18\t18\t18\tTDP\t0\t0\t{layout}\t{layout}"
                    )
            bram_map.write_text("\n".join(lines) + "\n", encoding="utf-8")
            mmi = root / "base.mmi"
            validation = root / "mmi_validation.json"
            generate(bram_map, mmi, validation)

            part, arrays = validate_mmi(mmi)
            self.assertEqual(part, "xc7z020clg400-1")
            self.assertEqual(len(arrays), 12)
            self.assertEqual(len(ET.parse(mmi).getroot().findall(".//BRAM")), 48)
            self.assertTrue(validation.is_file())

    def test_manual_mmi_accepts_inferred_kintex_iccm_names(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bram_map = root / "bram_map.tsv"
            self.write_bram_map(bram_map)
            text = bram_map.read_text(encoding="utf-8")
            for lane in range(4):
                for index in range(8):
                    text = text.replace(
                        f"u_soc/core/mem/iccm/lane{lane}_reg_{index}",
                        f"u_soc/core/u_memory/iccm/lane_q_reg[{lane}]_{index}",
                    )
            text = text.replace(
                "u_soc/core/mem/Gen_dccm_enable.dccm/",
                "u_soc/core/u_memory/Gen_dccm_enable.dccm/",
            )
            bram_map.write_text(text, encoding="utf-8")

            mmi = root / "base.mmi"
            validation = root / "mmi_validation.json"
            generate(bram_map, mmi, validation)

            part, arrays = validate_mmi(mmi)
            self.assertEqual(part, "xc7z020clg400-1")
            self.assertEqual(len(arrays), 12)
            self.assertEqual(len(ET.parse(mmi).getroot().findall(".//BRAM")), 48)

    def test_patch_uses_base_and_output_run_layout(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base_dir, out_dir, executable = self.make_patch_tree(Path(temporary))

            def fake_run_update(
                _executable: Path,
                _mmi: Path,
                data: Path,
                source_bit: Path,
                proc: str,
                output_bit: Path,
                _log: Path,
                expected_size: int,
            ) -> dict[str, object]:
                output_bit.write_bytes(source_bit.read_bytes())
                return {
                    "proc": proc,
                    "data_sha256": patch_bitstream.sha256(data),
                    "input_bit_sha256": patch_bitstream.sha256(source_bit),
                    "output_sha256": patch_bitstream.sha256(output_bit),
                    "output_size": expected_size,
                    "status": "pass",
                }

            with mock_patch.object(patch_bitstream, "run_update", side_effect=fake_run_update) as update:
                result_path = patch_bitstream.patch(base_dir, out_dir, executable)

            self.assertEqual(result_path, out_dir / "patch_result.json")
            self.assertEqual((out_dir / "competition.bit").read_bytes(), b"test-bitstream")
            result = json.loads(result_path.read_text(encoding="utf-8"))
            self.assertEqual(result["base_dir"], str(base_dir))
            self.assertEqual(result["base_bit"]["path"], str(base_dir / BASE_BIT_RELATIVE))
            self.assertEqual(result["bram_map"]["path"], str(base_dir / "bram_map.tsv"))
            self.assertEqual(result["code_mem"]["path"], str(out_dir / "images" / "code.mem"))
            self.assertEqual(result["data_mem"]["path"], str(out_dir / "images" / "data.mem"))
            self.assertEqual(result["competition_bit"]["path"], str(out_dir / "competition.bit"))
            self.assertEqual(update.call_count, 12)

    def test_patch_reports_each_missing_required_input(self) -> None:
        required = (
            BASE_BIT_RELATIVE,
            Path("bram_map.tsv"),
            Path("images/code.mem"),
            Path("images/data.mem"),
        )
        for missing in required:
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as temporary:
                base_dir, out_dir, executable = self.make_patch_tree(Path(temporary))
                target = base_dir / missing if missing in (BASE_BIT_RELATIVE, Path("bram_map.tsv")) else out_dir / missing
                target.unlink()
                with self.assertRaises(FileNotFoundError) as raised:
                    patch_bitstream.patch(base_dir, out_dir, executable)
                self.assertEqual(raised.exception.args[0], target)

    def test_patch_allows_built_output_run_but_refuses_existing_results(self) -> None:
        for result_name in ("competition.bit", "patch_result.json"):
            with self.subTest(result_name=result_name), tempfile.TemporaryDirectory() as temporary:
                base_dir, out_dir, executable = self.make_patch_tree(Path(temporary))
                (out_dir / "build_report.json").write_text("{}\n", encoding="utf-8")
                (out_dir / result_name).write_text("existing\n", encoding="utf-8")
                with self.assertRaisesRegex(FileExistsError, "refusing to overwrite"):
                    patch_bitstream.patch(base_dir, out_dir, executable)

    def test_manual_mmi_supports_ultrascale_mixed_iccm_geometry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bram_map = root / "bram_map.tsv"
            lines = [
                "# bram_map_version=1",
                "# part=xcku060-ffva1156-2-i",
                "# source_dcp=D:/golden.dcp",
                "cell\tloc\tref_name\tprimitive_type\tread_width_a\tread_width_b\twrite_width_a\twrite_width_b\tram_mode\tdoa_reg\tdob_reg\tporta_layout\tportb_layout",
            ]
            geometry = (
                *((18, "p2_d16", "RAMB36E2") for _ in range(4)),
                *((9, "p1_d8", "RAMB36E2") for _ in range(2)),
                (4, "p0_d4", "RAMB36E2"),
                (2, "p0_d1", "RAMB18E2"),
            )
            for lane in range(4):
                for index, (width, layout, primitive) in enumerate(geometry):
                    mem_type = primitive[:6]
                    lines.append(
                        f"u_soc/core/mem/iccm/lane{lane}_reg_bram_{index}\t{mem_type}_X0Y{lane * 8 + index}\t{primitive}\tBLOCKRAM.BRAM.{primitive}\t{width}\t{width}\t{width}\t{width}\t\t0\t0\t{layout}\t{layout}"
                    )
            for bank in range(8):
                for index, layout in ((0, "p2_d16"), (1, "p0_d14")):
                    lines.append(
                        f"u_soc/core/mem/Gen_dccm_enable.dccm/dccm_bank_gen[{bank}].bank_mem_reg_bram_{index}\tRAMB36_X1Y{bank * 2 + index}\tRAMB36E2\tBLOCKRAM.BRAM.RAMB36E2\t18\t18\t18\t18\t\t0\t0\t{layout}\t{layout}"
                    )
            bram_map.write_text("\n".join(lines) + "\n", encoding="utf-8")
            mmi = root / "base.mmi"
            validation = root / "mmi_validation.json"
            generate(bram_map, mmi, validation)

            part, arrays = validate_mmi(mmi)
            tree = ET.parse(mmi)
            brams = tree.getroot().findall(".//BRAM")
            self.assertEqual(part, "xcku060-ffva1156-2-i")
            self.assertEqual(len(arrays), 12)
            self.assertEqual(len(brams), 48)
            self.assertEqual(sum(bram.attrib["MemType"] == "RAMB18" for bram in brams), 4)

            lane0 = tree.getroot().find("./MemoryArray[@InstPath='ICCM_LANE0']/MemoryLayout")
            self.assertIsNotNone(lane0)
            lane0_brams = lane0.findall("BRAM")
            expected = (
                ("0", "17", "0", "2047"),
                ("0", "17", "2048", "4095"),
                ("0", "17", "4096", "6143"),
                ("0", "17", "6144", "8191"),
                ("18", "26", "0", "4095"),
                ("18", "26", "4096", "8191"),
                ("27", "30", "0", "8191"),
                ("31", "31", "0", "8191"),
            )
            actual = tuple(
                (
                    bram.find("DataWidth_PortA").attrib["LSB"],
                    bram.find("DataWidth_PortA").attrib["MSB"],
                    bram.find("AddressRange_PortA").attrib["Begin"],
                    bram.find("AddressRange_PortA").attrib["End"],
                )
                for bram in lane0_brams
            )
            self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
