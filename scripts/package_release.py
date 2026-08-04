from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from lib.hashing import sha256_file
from lib.manifest import write_json_atomic
from lib.repo import repo_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Package verified SocRV artifacts into build/release.")
    parser.add_argument("--profile", choices=["smoke", "rtthread"], default="smoke")
    args = parser.parse_args()
    software_name = "baremetal-smoke" if args.profile == "smoke" else "rtthread"
    app_name = "smoke" if args.profile == "smoke" else "rtthread"
    inputs = {
        f"software/socrv-{app_name}.elf": repo_path(
            "build", "software", software_name, f"socrv-{app_name}.elf"
        ),
        "image/code.mem": repo_path("build", "images", args.profile, "code.mem"),
        "image/data.mem": repo_path("build", "images", args.profile, "data.mem"),
        "image/image.json": repo_path("build", "images", args.profile, "image.json"),
        "fpga/fpga_top.bit": repo_path(
            "build", "vivado", f"kintex7-{args.profile}", "project",
            "socrv.runs", "impl_1", "fpga_top.bit",
        ),
        "fpga/post_impl_timing_summary.rpt": repo_path(
            "build", "vivado", f"kintex7-{args.profile}", "project",
            "reports", "post_impl_timing_summary.rpt",
        ),
        "fpga/post_impl_drc.rpt": repo_path(
            "build", "vivado", f"kintex7-{args.profile}", "project",
            "reports", "post_impl_drc.rpt",
        ),
    }
    missing = [path for path in inputs.values() if not path.exists()]
    if missing:
        parser.error(f"release inputs are missing: {missing}")

    release_dir = repo_path("build", "release", f"socrv-{args.profile}")
    release_dir.mkdir(parents=True, exist_ok=True)
    entries = []
    for relative, source in inputs.items():
        destination = release_dir / relative
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
            "profile": args.profile,
            "files": sorted(entries, key=lambda item: item["path"]),
        },
    )
    archive = shutil.make_archive(str(release_dir), "zip", release_dir.parent, release_dir.name)
    print(f"Release: {release_dir}")
    print(f"Archive: {archive}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
