from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from build_software import PROFILES, resolve_run_dir
from lib.fpga import BOARDS, resolve_core_mhz
from lib.hashing import sha256_file
from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path


def legacy_inputs(profile: str) -> dict[str, Path]:
    return {
        "software/firmware.elf": repo_path(
            "build", "software", profile, "firmware.elf"
        ),
        "software/firmware.map": repo_path(
            "build", "software", profile, "firmware.map"
        ),
        "software/firmware.dis": repo_path(
            "build", "software", profile, "firmware.dis"
        ),
        "software/size.json": repo_path(
            "build", "software", profile, "size.json"
        ),
        "software/build_manifest.json": repo_path(
            "build", "software", profile, "build_manifest.json"
        ),
        "image/code.mem": repo_path("build", "images", profile, "code.mem"),
        "image/data.mem": repo_path("build", "images", profile, "data.mem"),
        "image/image.json": repo_path(
            "build", "images", profile, "image.json"
        ),
        "fpga/fpga_top.bit": repo_path(
            "build", "vivado", f"kintex7-{profile}", "project",
            "socrv.runs", "impl_1", "fpga_top.bit",
        ),
        "fpga/post_impl_timing_summary.rpt": repo_path(
            "build", "vivado", f"kintex7-{profile}", "project",
            "reports", "post_impl_timing_summary.rpt",
        ),
        "fpga/post_impl_drc.rpt": repo_path(
            "build", "vivado", f"kintex7-{profile}", "project",
            "reports", "post_impl_drc.rpt",
        ),
    }


def competition_inputs(
    run_dir: Path,
    board_name: str,
    core_mhz: int,
) -> dict[str, Path]:
    board = BOARDS[board_name]
    fpga_root = run_dir / "vivado" / f"{board.build_prefix}-{core_mhz}mhz"
    project = fpga_root / "project"
    inputs: dict[str, Path] = {
        "source/source_manifest.json": run_dir / "source" / "source_manifest.json",
        "source/competition.json": run_dir / "source" / "competition.json",
        "software/firmware.elf": run_dir / "software" / "firmware.elf",
        "software/firmware.bin": run_dir / "software" / "firmware.bin",
        "software/firmware.map": run_dir / "software" / "firmware.map",
        "software/firmware.dis": run_dir / "software" / "firmware.dis",
        "software/size.json": run_dir / "software" / "size.json",
        "software/build_manifest.json": (
            run_dir / "software" / "build_manifest.json"
        ),
        "images/image.json": run_dir / "images" / "image.json",
        "images/code.mem": run_dir / "images" / "code.mem",
        "images/data.mem": run_dir / "images" / "data.mem",
        "fpga/fpga_top.bit": (
            project / "socrv.runs" / "impl_1" / "fpga_top.bit"
        ),
        "fpga/post_impl_timing_summary.rpt": (
            project / "reports" / "post_impl_timing_summary.rpt"
        ),
        "fpga/post_impl_drc.rpt": (
            project / "reports" / "post_impl_drc.rpt"
        ),
        "fpga/result.json": fpga_root / "result.json",
    }
    for lane in range(4):
        name = f"iccm_lane{lane}.mem"
        inputs[f"images/{name}"] = run_dir / "images" / name
    for bank in range(8):
        name = f"dccm_bank{bank}.mem"
        inputs[f"images/{name}"] = run_dir / "images" / name
    for source in sorted((run_dir / "source" / "original").rglob("*")):
        if source.is_file():
            relative = source.relative_to(run_dir / "source" / "original")
            inputs[f"source/original/{relative.as_posix()}"] = source
    inputs["simulation/result.json"] = run_dir / "simulation" / "result.json"
    inputs["simulation/uart.log"] = run_dir / "simulation" / "uart.log"
    return inputs


def verify_competition_results(
    run_dir: Path,
    board_name: str,
    core_mhz: int,
) -> None:
    simulation_path = run_dir / "simulation" / "result.json"
    if not simulation_path.is_file():
        raise ValueError(f"competition simulation result is missing: {simulation_path}")
    simulation = read_json(simulation_path)
    image_manifest = run_dir / "images" / "image.json"
    image_hash = sha256_file(image_manifest)
    if (
        simulation.get("status") != "PASS"
        or simulation.get("profile") != "contest-rtthread-coremark"
        or simulation.get("image_manifest_sha256") != image_hash
    ):
        raise ValueError(
            "competition simulation has not passed with the current images"
        )

    board = BOARDS[board_name]
    fpga_result_path = (
        run_dir
        / "vivado"
        / f"{board.build_prefix}-{core_mhz}mhz"
        / "result.json"
    )
    if not fpga_result_path.is_file():
        raise ValueError(f"FPGA sign-off result is missing: {fpga_result_path}")
    fpga_result = read_json(fpga_result_path)
    if (
        fpga_result.get("status") != "PASS"
        or fpga_result.get("target") != board.name
        or fpga_result.get("timing_met") is not True
        or fpga_result.get("drc_error_count") != 0
        or fpga_result.get("image_manifest_sha256") != image_hash
    ):
        raise ValueError(
            f"FPGA sign-off has not passed with the current images for "
            f"{board.name} at {core_mhz} MHz"
        )


def package(
    inputs: dict[str, Path],
    release_dir: Path,
    *,
    manifest_fields: dict[str, object],
) -> Path:
    missing = [path for path in inputs.values() if not path.is_file()]
    if missing:
        raise ValueError(f"release inputs are missing: {missing}")
    release_dir.mkdir(parents=True, exist_ok=True)
    entries = []
    for relative, source in sorted(inputs.items()):
        destination = release_dir.joinpath(*Path(relative).parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        entries.append(
            {
                "path": relative,
                "size": destination.stat().st_size,
                "sha256": sha256_file(destination),
            }
        )
    write_json_atomic(
        release_dir / "manifest.json",
        {
            "schema_version": 1,
            **manifest_fields,
            "files": entries,
        },
    )
    return Path(
        shutil.make_archive(
            str(release_dir),
            "zip",
            release_dir.parent,
            release_dir.name,
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Package verified SocRV artifacts and their SHA-256 manifest."
    )
    parser.add_argument("--profile", choices=sorted(PROFILES))
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument(
        "--board",
        choices=sorted(BOARDS),
        default="kintex7_competition",
    )
    parser.add_argument("--core-mhz", type=int)
    args = parser.parse_args()
    try:
        if args.run_dir is not None:
            if args.profile not in (None, "contest-rtthread-coremark"):
                raise ValueError(
                    "competition --run-dir requires profile "
                    "contest-rtthread-coremark"
                )
            run_dir = resolve_run_dir(args.run_dir)
            board = BOARDS[args.board]
            core_mhz = resolve_core_mhz(board, args.core_mhz)
            verify_competition_results(run_dir, board.name, core_mhz)
            inputs = competition_inputs(run_dir, board.name, core_mhz)
            release_dir = (
                run_dir
                / "release"
                / f"socrv-contest-{board.build_prefix}-{core_mhz}mhz"
            )
            archive = package(
                inputs,
                release_dir,
                manifest_fields={
                    "profile": "contest-rtthread-coremark",
                    "run_id": run_dir.name,
                    "board": board.name,
                    "core_mhz": core_mhz,
                },
            )
        else:
            profile = args.profile or "smoke"
            release_dir = repo_path("build", "release", f"socrv-{profile}")
            archive = package(
                legacy_inputs(profile),
                release_dir,
                manifest_fields={"profile": profile},
            )
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Release: {release_dir}")
    print(f"Archive: {archive}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
