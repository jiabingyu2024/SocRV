from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path


EXPECTED_ARRAYS = (
    *(f"ICCM_LANE{index}" for index in range(4)),
    *(f"DCCM_BANK{index}" for index in range(8)),
)
FAILURE_MARKERS = ("ERROR:", "update_mem failed", "Abnormal program termination")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_flat_mem(path: Path, expected_words: int) -> list[str]:
    words: list[str] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        word = raw.strip()
        if not re.fullmatch(r"[0-9A-Fa-f]{8}", word):
            raise ValueError(f"{path}:{line_number}: expected exactly 8 hexadecimal digits")
        words.append(word.lower())
    if len(words) != expected_words:
        raise ValueError(f"{path}: expected {expected_words} words, got {len(words)}")
    return words


def split_words(words: list[str], ways: int) -> list[list[str]]:
    if len(words) % ways:
        raise ValueError(f"cannot split {len(words)} words into {ways} interleaved memories")
    return [words[index::ways] for index in range(ways)]


def write_updatemem_file(path: Path, words: list[str]) -> None:
    path.write_text("@00000000\n" + "\n".join(words) + "\n", encoding="ascii")


def validate_mmi(path: Path) -> tuple[str, tuple[str, ...]]:
    root = ET.parse(path).getroot()
    arrays = tuple(node.attrib.get("InstPath", "") for node in root.findall("MemoryArray"))
    if arrays != EXPECTED_ARRAYS:
        raise ValueError(f"MMI memory arrays must be exactly {EXPECTED_ARRAYS}, got {arrays}")
    option = root.find("./Config/Option[@Name='Part']")
    if option is None or not option.attrib.get("Val"):
        raise ValueError("MMI does not declare the FPGA Part")
    return option.attrib["Val"], arrays


def find_updatemem(explicit: Path | None) -> Path:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    xilinx_vivado = os.environ.get("XILINX_VIVADO")
    if xilinx_vivado:
        candidates.append(Path(xilinx_vivado) / "bin" / "updatemem.bat")
    candidates.extend(
        (
            Path(r"D:\Xilinx\Vivado\2023.2\bin\updatemem.bat"),
            Path(r"C:\Xilinx\Vivado\2023.2\bin\updatemem.bat"),
        )
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    resolved = shutil.which("updatemem") or shutil.which("updatemem.bat")
    if resolved:
        return Path(resolved).resolve()
    raise FileNotFoundError("updatemem was not found; pass --updatemem")


def run_update(
    executable: Path,
    mmi: Path,
    data: Path,
    source_bit: Path,
    proc: str,
    output_bit: Path,
    log: Path,
    expected_size: int,
) -> dict[str, object]:
    command = [
        str(executable),
        "--force",
        "--meminfo",
        str(mmi),
        "--data",
        str(data),
        "--bit",
        str(source_bit),
        "--proc",
        proc,
        "--out",
        str(output_bit),
    ]
    completed = subprocess.run(
        command,
        cwd=output_bit.parent,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=sys.platform == "win32",
        check=False,
    )
    text = completed.stdout or ""
    log.write_text(text, encoding="utf-8")
    errors = [marker for marker in FAILURE_MARKERS if marker in text]
    success_marker = "update_mem completed successfully" in text
    output_exists = output_bit.is_file()
    output_size = output_bit.stat().st_size if output_exists else None
    passed = (
        completed.returncode == 0
        and not errors
        and success_marker
        and output_exists
        and output_size == expected_size
    )
    result: dict[str, object] = {
        "proc": proc,
        "data": str(data),
        "input_bit": str(source_bit),
        "output_bit": str(output_bit),
        "log": str(log),
        "returncode": completed.returncode,
        "failure_markers": errors,
        "success_marker": success_marker,
        "output_exists": output_exists,
        "output_size": output_size,
        "status": "pass" if passed else "fail",
    }
    if output_exists:
        result["output_sha256"] = sha256(output_bit)
    if not passed:
        raise RuntimeError(f"updatemem validation failed for {proc}: {result}")
    return result


def patch(
    golden_dir: Path,
    code_mem: Path,
    data_mem: Path,
    output_dir: Path,
    updatemem: Path | None,
) -> Path:
    golden_bit = golden_dir / "golden.bit"
    mmi = golden_dir / "golden.mmi"
    for required in (golden_bit, mmi, code_mem, data_mem):
        if not required.is_file():
            raise FileNotFoundError(required)
    if output_dir.exists() and any(output_dir.iterdir()):
        raise FileExistsError(f"output directory is not empty: {output_dir}")
    work = output_dir / "work"
    work.mkdir(parents=True, exist_ok=True)

    part, arrays = validate_mmi(mmi)
    code_words = read_flat_mem(code_mem, 32768)
    data_words = read_flat_mem(data_mem, 16384)
    image_files: list[tuple[str, Path]] = []
    for index, words in enumerate(split_words(code_words, 4)):
        path = work / f"iccm_lane{index}.mem"
        write_updatemem_file(path, words)
        image_files.append((f"ICCM_LANE{index}", path))
    for index, words in enumerate(split_words(data_words, 8)):
        path = work / f"dccm_bank{index}.mem"
        write_updatemem_file(path, words)
        image_files.append((f"DCCM_BANK{index}", path))
    if tuple(proc for proc, _ in image_files) != arrays:
        raise AssertionError("internal update order does not match MMI")

    executable = find_updatemem(updatemem)
    expected_size = golden_bit.stat().st_size
    current_bit = golden_bit
    steps: list[dict[str, object]] = []
    for step_number, (proc, mem) in enumerate(image_files, 1):
        next_bit = work / f"stage-{step_number:02d}.bit"
        log = work / f"stage-{step_number:02d}.log"
        steps.append(
            run_update(
                executable,
                mmi,
                mem,
                current_bit,
                proc,
                next_bit,
                log,
                expected_size,
            )
        )
        current_bit = next_bit

    final_bit = output_dir / "competition.bit"
    shutil.copy2(current_bit, final_bit)
    result = {
        "schema_version": 1,
        "status": "pass",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "part": part,
        "updatemem": str(executable),
        "golden_dir": str(golden_dir),
        "golden_bit": {"path": str(golden_bit), "size": expected_size, "sha256": sha256(golden_bit)},
        "mmi": {"path": str(mmi), "sha256": sha256(mmi)},
        "code_mem": {"path": str(code_mem), "sha256": sha256(code_mem)},
        "data_mem": {"path": str(data_mem), "sha256": sha256(data_mem)},
        "steps": steps,
        "competition_bit": {"path": str(final_bit), "size": final_bit.stat().st_size, "sha256": sha256(final_bit)},
    }
    result_path = output_dir / "patch_result.json"
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Patch a SocRV golden bitstream from canonical code.mem and data.mem."
    )
    parser.add_argument("--golden-dir", type=Path, required=True)
    parser.add_argument("--code-mem", type=Path, required=True)
    parser.add_argument("--data-mem", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--updatemem", type=Path)
    args = parser.parse_args()
    result = patch(
        args.golden_dir.resolve(),
        args.code_mem.resolve(),
        args.data_mem.resolve(),
        args.output_dir.resolve(),
        args.updatemem.resolve() if args.updatemem else None,
    )
    print(f"PATCH_RESULT={result}")
    print(f"BITSTREAM={result.parent / 'competition.bit'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
