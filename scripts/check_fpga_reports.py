from __future__ import annotations

import argparse
import re
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import write_json_atomic
from lib.repo import repo_path


def check(build_root: Path, *, target: str = "kintex7_competition") -> Path:
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
    # Vivado's Design Timing Summary table starts with WNS/TNS/WHS/THS.  Keep
    # the numeric result in the sign-off JSON so frequency bottlenecks can be
    # compared without treating a looser build as proof for a faster one.
    wns_match = re.search(
        r"WNS\(ns\).*?\n[-\s]+\n\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)",
        timing_text,
        re.DOTALL,
    )
    wns_ns = float(wns_match.group(1)) if wns_match else None
    tns_ns = float(wns_match.group(2)) if wns_match else None
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
            "target": target,
            "status": status,
            "timing_met": timing_met,
            "wns_ns": wns_ns,
            "tns_ns": tns_ns,
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
    if status != "PASS":
        raise ValueError(f"FPGA report gate failed: timing_met={timing_met}, drc_errors={drc_errors}")
    print(f"FPGA reports PASS: timing met, DRC errors 0, warnings {warnings}")
    print(f"Bitstream: {bitstream} ({bitstream.stat().st_size} bytes)")
    return result_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--board",
        default="kintex7_competition",
    )
    parser.add_argument(
        "--build-root",
        type=Path,
        default=repo_path("build", "vivado", "kintex7-smoke"),
    )
    args = parser.parse_args()
    try:
        result = check(args.build_root.resolve(), target=args.board)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Result: {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
