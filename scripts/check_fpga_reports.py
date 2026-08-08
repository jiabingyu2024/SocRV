from __future__ import annotations

import argparse
import re
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import write_json_atomic
from lib.repo import repo_path


def check(build_root: Path, *, require_timing: bool = True) -> Path:
    project = build_root / "project"
    bitstream = project / "socrv.runs" / "impl_1" / "fpga_top.bit"
    report_dir = project / "reports"
    timing = report_dir / "post_impl_timing_summary.rpt"
    drc = report_dir / "post_impl_drc.rpt"
    required = [bitstream, timing, drc]
    missing = [path for path in required if not path.exists()]
    if missing:
        raise ValueError(f"missing FPGA artifacts: {missing}")

    timing_text = timing.read_text(encoding="utf-8", errors="replace")
    drc_text = drc.read_text(encoding="utf-8", errors="replace")
    timing_met = "All user specified timing constraints are met." in timing_text
    drc_errors = len(re.findall(r"\|\s*(?:Error|Critical Warning)\s*\|", drc_text))
    warning_match = re.search(r"Violations found:\s*(\d+)", drc_text)
    warnings = int(warning_match.group(1)) if warning_match else 0
    status = "PASS" if timing_met and drc_errors == 0 else "FAIL"
    result_path = build_root / "result.json"
    write_json_atomic(
        result_path,
        {
            "schema_version": 1,
            "kind": "fpga",
            "target": "kintex7_competition",
            "status": status,
            "timing_met": timing_met,
            "drc_error_count": drc_errors,
            "drc_warning_count": warnings,
            "artifacts": {
                "bitstream": bitstream.as_posix(),
                "bitstream_sha256": sha256_file(bitstream),
                "timing": timing.as_posix(),
                "drc": drc.as_posix(),
            },
        },
    )
    if drc_errors != 0 or (require_timing and not timing_met):
        raise ValueError(f"FPGA report gate failed: timing_met={timing_met}, drc_errors={drc_errors}")
    print(
        f"FPGA reports recorded: timing_met={timing_met}, "
        f"DRC errors 0, warnings {warnings}"
    )
    print(f"Bitstream: {bitstream} ({bitstream.stat().st_size} bytes)")
    return result_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--build-root",
        type=Path,
        default=repo_path("build", "vivado", "kintex7-smoke"),
    )
    args = parser.parse_args()
    try:
        result = check(args.build_root.resolve())
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Result: {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
