from __future__ import annotations

import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from generate_manual_mmi import generate
from patch_bitstream import read_flat_mem, split_words, validate_mmi


class BitstreamPatchTest(unittest.TestCase):
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
            mmi = root / "golden.mmi"
            validation = root / "mmi_validation.json"
            generate(bram_map, mmi, validation)

            part, arrays = validate_mmi(mmi)
            self.assertEqual(part, "xc7z020clg400-1")
            self.assertEqual(len(arrays), 12)
            self.assertEqual(len(ET.parse(mmi).getroot().findall(".//BRAM")), 48)
            self.assertTrue(validation.is_file())


if __name__ == "__main__":
    unittest.main()
