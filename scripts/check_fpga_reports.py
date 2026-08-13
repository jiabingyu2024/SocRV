from __future__ import annotations

import argparse
import re
from pathlib import Path

from build_software import resolve_run_dir
from lib.fpga import BOARDS, resolve_core_mhz
from lib.hashing import sha256_file
from lib.manifest import write_json_atomic
from lib.repo import repo_path


def check(
    build_root: Path,
    *,
    target: str = "kintex7_competition",
    image_manifest: Path | None = None,
) -> Path:
    project = build_root / "project"
    bitstream = project / "socrv.runs" / "impl_1" / "fpga_top.bit"
    report_dir = project / "reports"
    timing = report_dir / "post_impl_timing_summary.rpt"
    drc = report_dir / "post_impl_drc.rpt"
    required = [bitstream, timing, drc]
    missing = [path for path in required if not path.exists()]
    if missing:
        raise ValueError(f"missing FPGA artifacts: {missing}")
    if image_manifest is not None:
        if not image_manifest.is_file():
            raise ValueError(f"image manifest is missing: {image_manifest}")
        image_dir = image_manifest.parent
        memory_images = [
            *(image_dir / f"iccm_lane{lane}.mem" for lane in range(4)),
            *(image_dir / f"dccm_bank{bank}.mem" for bank in range(8)),
        ]
        missing_images = [path for path in memory_images if not path.is_file()]
        if missing_images:
            raise ValueError(f"memory images are missing: {missing_images}")
        newest_image_time = max(
            path.stat().st_mtime for path in [image_manifest, *memory_images]
        )
        if bitstream.stat().st_mtime < newest_image_time:
            raise ValueError(
                "bitstream is older than the current software images; "
                "reset synthesis and regenerate it"
            )

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
    result: dict[str, object] = {
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
    }
    if image_manifest is not None:
        result["image_manifest"] = image_manifest.as_posix()
        result["image_manifest_sha256"] = sha256_file(image_manifest)
    write_json_atomic(result_path, result)
    if status != "PASS":
        raise ValueError(f"FPGA report gate failed: timing_met={timing_met}, drc_errors={drc_errors}")
    print(f"FPGA reports PASS: timing met, DRC errors 0, warnings {warnings}")
    print(f"Bitstream: {bitstream} ({bitstream.stat().st_size} bytes)")
    return result_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--board",
        choices=sorted(BOARDS),
        default="kintex7_competition",
    )
    location = parser.add_mutually_exclusive_group()
    location.add_argument(
        "--build-root",
        type=Path,
    )
    location.add_argument("--run-dir", type=Path)
    parser.add_argument("--core-mhz", type=int)
    args = parser.parse_args()
    try:
        if args.run_dir is not None:
            board = BOARDS[args.board]
            core_mhz = resolve_core_mhz(board, args.core_mhz)
            run_dir = resolve_run_dir(args.run_dir)
            build_root = (
                run_dir
                / "vivado"
                / f"{board.build_prefix}-{core_mhz}mhz"
            )
            image_manifest = run_dir / "images" / "image.json"
        else:
            build_root = (
                args.build_root.resolve()
                if args.build_root is not None
                else repo_path("build", "vivado", "kintex7-smoke")
            )
            image_manifest = None
        result = check(
            build_root,
            target=args.board,
            image_manifest=image_manifest,
        )
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Result: {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
