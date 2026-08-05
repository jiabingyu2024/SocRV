from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from lib.hashing import sha256_file, sha256_text
from lib.manifest import read_json, write_json_atomic
from lib.repo import build_path, repo_path
from lib.wsl import bash, to_wsl_path


SPIKE_LOCK = repo_path(
    "sim", "reference", "spike", "dependency.lock.json"
)
IBEX_LOCK = repo_path(
    "sim", "reference", "ibex-cosim", "dependency.lock.json"
)
SPIKE_SOURCE = repo_path("sim", "reference", "spike", "upstream")
IBEX_SOURCE = repo_path("sim", "reference", "ibex-cosim", "upstream")
IBEX_PATCH = repo_path(
    "sim", "reference", "ibex-cosim", "socrv_getters.patch"
)
SPIKE_MEMORY_MAP_PATCH = repo_path(
    "sim", "reference", "spike", "socrv_debug_window.patch"
)
REFERENCE_ROOT = build_path("reference", "spike")
INSTALL_ROOT = REFERENCE_ROOT / "install"
COSIM_ROOT = REFERENCE_ROOT / "ibex_cosim"
MANIFEST_PATH = REFERENCE_ROOT / "build_manifest.json"


def desired_manifest() -> dict[str, object]:
    spike_lock = read_json(SPIKE_LOCK)
    ibex_lock = read_json(IBEX_LOCK)
    inputs = {
        "spike_lock": sha256_file(SPIKE_LOCK),
        "ibex_lock": sha256_file(IBEX_LOCK),
        "ibex_patch": sha256_file(IBEX_PATCH),
        "spike_memory_map_patch": sha256_file(SPIKE_MEMORY_MAP_PATCH),
        "builder": sha256_file(Path(__file__)),
    }
    fingerprint = sha256_text(json.dumps(inputs, sort_keys=True))
    return {
        "schema_version": 1,
        "kind": "spike_reference_build",
        "fingerprint": fingerprint,
        "spike": {
            "url": spike_lock["url"],
            "ref": spike_lock.get("ref"),
            "commit": spike_lock["commit"],
        },
        "ibex_cosim": {
            "url": ibex_lock["url"],
            "commit": ibex_lock["commit"],
        },
        "configure": [
            "--enable-commitlog",
            "--enable-misaligned",
        ],
        "inputs": inputs,
    }


def is_current(desired: dict[str, object]) -> bool:
    required = [
        INSTALL_ROOT / "lib" / "libriscv.a",
        INSTALL_ROOT / "lib" / "pkgconfig" / "riscv-riscv.pc",
        COSIM_ROOT / "cosim.h",
        COSIM_ROOT / "spike_cosim.h",
        COSIM_ROOT / "spike_cosim.cc",
    ]
    if not MANIFEST_PATH.is_file() or not all(path.is_file() for path in required):
        return False
    try:
        actual = read_json(MANIFEST_PATH)
    except (OSError, ValueError):
        return False
    return actual.get("fingerprint") == desired["fingerprint"]


def spike_install_is_reusable(desired: dict[str, object]) -> bool:
    required = [
        INSTALL_ROOT / "lib" / "libriscv.a",
        INSTALL_ROOT / "lib" / "pkgconfig" / "riscv-riscv.pc",
    ]
    if not MANIFEST_PATH.is_file() or not all(path.is_file() for path in required):
        return False
    try:
        actual = read_json(MANIFEST_PATH)
    except (OSError, ValueError):
        return False
    return (
        actual.get("spike") == desired["spike"]
        and actual.get("configure") == desired["configure"]
        and actual.get("inputs", {}).get("spike_memory_map_patch")
        == desired["inputs"]["spike_memory_map_patch"]
    )


def require_checkout(path: Path, name: str) -> None:
    if not (path / ".git").exists():
        raise RuntimeError(
            f"{name} checkout is missing; run `make deps` first"
        )


def prepare_ibex_cosim() -> None:
    if COSIM_ROOT.exists():
        shutil.rmtree(COSIM_ROOT)
    COSIM_ROOT.mkdir(parents=True)
    source_dir = IBEX_SOURCE / "dv" / "cosim"
    for name in ("cosim.h", "spike_cosim.h", "spike_cosim.cc"):
        shutil.copy2(source_dir / name, COSIM_ROOT / name)
    result = subprocess.run(
        [
            "git",
            "apply",
            "--unsafe-paths",
            "--directory",
            str(COSIM_ROOT),
            str(IBEX_PATCH),
        ],
        cwd=repo_path(),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "cannot apply SocRV Ibex co-sim adapter patch:\n"
            f"{result.stdout}{result.stderr}"
        )


def build_spike(jobs: int) -> None:
    source = to_wsl_path(SPIKE_SOURCE)
    install = to_wsl_path(INSTALL_ROOT)
    memory_map_patch = to_wsl_path(SPIKE_MEMORY_MAP_PATCH)
    command = f"""
set -euo pipefail
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/src" "$tmp/build"
cp -a {source}/. "$tmp/src/"
git -C "$tmp/src" apply {memory_map_patch}
while IFS=$'\\t' read -r path target; do
  rm -f "$tmp/src/$path"
  ln -s "$target" "$tmp/src/$path"
done < <(
  cd {source}
  git ls-files -s |
    awk '$1 == "120000" {{print $4}}' |
    while read -r path; do
      printf '%s\\t%s\\n' "$path" "$(cat "$path")"
    done
)
cd "$tmp/build"
CXXFLAGS="-O2 -include cstdint" "$tmp/src/configure" \
  --enable-commitlog \
  --enable-misaligned \
  --prefix={install}
make -s -j{jobs}
make -s install
"""
    result = bash(command, timeout=900, check=False)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if not result.ok:
        raise RuntimeError("Spike build failed")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the pinned Spike/Ibex retirement reference model."
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=max(1, min(8, os.cpu_count() or 1)),
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    desired = desired_manifest()
    if not args.force and is_current(desired):
        print("Spike reference model is current")
        return 0
    require_checkout(SPIKE_SOURCE, "Spike")
    require_checkout(IBEX_SOURCE, "Ibex co-sim")
    reuse_spike = not args.force and spike_install_is_reusable(desired)
    if REFERENCE_ROOT.exists() and not reuse_spike:
        shutil.rmtree(REFERENCE_ROOT)
    REFERENCE_ROOT.mkdir(parents=True, exist_ok=True)
    INSTALL_ROOT.mkdir(parents=True, exist_ok=True)
    prepare_ibex_cosim()
    if reuse_spike:
        print("Reusing pinned Spike installation; refreshing co-sim adapter")
    else:
        build_spike(args.jobs)
    write_json_atomic(MANIFEST_PATH, desired)
    print(f"Spike reference model built: {MANIFEST_PATH}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError) as error:
        raise SystemExit(str(error)) from error
