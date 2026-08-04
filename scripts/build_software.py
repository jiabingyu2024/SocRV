from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from lib.repo import repo_path
from lib.wsl import bash, in_repo


@dataclass(frozen=True)
class SoftwareProfile:
    app: str
    output_name: str


PROFILES = {
    "smoke": SoftwareProfile(app="smoke", output_name="baremetal-smoke"),
    "rtthread": SoftwareProfile(app="rtthread", output_name="rtthread"),
}


def build_profile(profile_name: str, *, force: bool = False) -> tuple[Path, Path]:
    profile = PROFILES[profile_name]
    root = repo_path()
    output = repo_path("build", "software", profile.output_name)
    make_argv = ["make"]
    if force:
        make_argv.append("-B")
    make_argv.extend(
        [
            "-C",
            "software",
            f"APP={profile.app}",
            f"OUT=../build/software/{profile.output_name}",
        ]
    )
    result = bash(in_repo(root, make_argv), timeout=180, check=False)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result.ok:
        raise RuntimeError(f"software build failed for profile {profile_name}")

    elf = output / f"socrv-{profile.app}.elf"
    image_dir = repo_path("build", "images", profile_name)
    image_dir.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        str(repo_path("scripts", "elf2mem.py")),
        "--elf",
        str(elf),
        "--region",
        f"CODE:0x00000000:0x10000:{image_dir / 'code.mem'}",
        "--region",
        f"DATA:0x10000000:0x10000:{image_dir / 'data.mem'}",
        "--manifest",
        str(image_dir / "image.json"),
    ]
    subprocess.run(command, cwd=root, check=True)
    return elf, image_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a SocRV software profile in WSL and generate memory images.")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="smoke")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    try:
        elf, image_dir = build_profile(args.profile, force=args.force)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.error(str(error))
    print(f"ELF:   {elf}")
    print(f"Image: {image_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
