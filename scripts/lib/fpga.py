from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from lib.repo import repo_path


@dataclass(frozen=True)
class FpgaBoard:
    name: str
    build_prefix: str
    default_profile: str
    default_core_mhz: int
    supported_core_mhz: tuple[int, ...]
    mmcm: dict[int, tuple[str, str, str]]

    @property
    def tcl_dir(self) -> Path:
        return repo_path("fpga", "boards", self.name, "tcl")


BOARDS = {
    "axku062": FpgaBoard(
        name="axku062",
        build_prefix="axku062",
        default_profile="rtthread-coremark",
        default_core_mhz=100,
        supported_core_mhz=(
            50,
            100, 110, 120, 125, 130, 140, 150, 160, 170,
            180, 190, 200, 210, 220, 230, 240, 250,
        ),
        mmcm={
            50: ("5.0", "20.0", "20"),
            100: ("5.0", "10.0", "20"),
            110: ("5.5", "10.0", "22"),
            120: ("6.0", "10.0", "24"),
            125: ("5.0", "8.0", "20"),
            130: ("6.5", "10.0", "26"),
            140: ("7.0", "10.0", "28"),
            150: ("6.0", "8.0", "24"),
            160: ("4.0", "5.0", "16"),
            170: ("4.25", "5.0", "17"),
            180: ("4.5", "5.0", "18"),
            190: ("4.75", "5.0", "19"),
            200: ("5.0", "5.0", "20"),
            210: ("5.25", "5.0", "21"),
            220: ("5.5", "5.0", "22"),
            230: ("5.75", "5.0", "23"),
            240: ("6.0", "5.0", "24"),
            250: ("5.0", "4.0", "20"),
        },
    ),
    "kintex7_competition": FpgaBoard(
        name="kintex7_competition",
        build_prefix="kintex7",
        default_profile="rtthread-coremark",
        # Preserve the release branch's existing Kintex-7 CLI contract.
        default_core_mhz=100,
        supported_core_mhz=(
            100, 110, 120, 125, 130, 140, 150, 160, 170,
            180, 190, 200, 210, 220, 230, 240, 250,
        ),
        mmcm={
            100: ("5.0", "10.0", "20"),
            110: ("5.5", "10.0", "22"),
            120: ("6.0", "10.0", "24"),
            125: ("5.0", "8.0", "20"),
            130: ("3.25", "5.0", "13"),
            140: ("3.5", "5.0", "14"),
            150: ("6.0", "8.0", "24"),
            160: ("4.0", "5.0", "16"),
            170: ("4.25", "5.0", "17"),
            180: ("4.5", "5.0", "18"),
            190: ("4.75", "5.0", "19"),
            200: ("5.0", "5.0", "20"),
            210: ("5.25", "5.0", "21"),
            220: ("5.5", "5.0", "22"),
            230: ("5.75", "5.0", "23"),
            240: ("6.0", "5.0", "24"),
            250: ("5.0", "4.0", "20"),
        },
    ),
    "pynq_z2": FpgaBoard(
        name="pynq_z2",
        build_prefix="pynq_z2",
        default_profile="rtthread",
        default_core_mhz=50,
        supported_core_mhz=(50,),
        mmcm={},
    ),
}


def resolve_core_mhz(board: FpgaBoard, requested: int | None) -> int:
    core_mhz = board.default_core_mhz if requested is None else requested
    if core_mhz not in board.supported_core_mhz:
        supported = ", ".join(str(value) for value in board.supported_core_mhz)
        raise ValueError(
            f"{board.name} does not support --core-mhz {core_mhz}; "
            f"choose one of: {supported}"
        )
    return core_mhz


def fpga_build_root(board: FpgaBoard, profile: str, core_mhz: int) -> Path:
    return repo_path(
        "build", "vivado", f"{board.build_prefix}-{profile}-{core_mhz}mhz"
    )
