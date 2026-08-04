from __future__ import annotations

import argparse
import platform
import shutil
import sys
from pathlib import Path

from lib.command import run
from lib.manifest import write_json_atomic
from lib.repo import build_path


def first_line(text: str) -> str:
    for line in text.splitlines():
        if line.strip():
            return line.strip()
    return ""


def windows_tool(name: str) -> dict[str, object]:
    path = shutil.which(name)
    return {"found": path is not None, "path": path}


def wsl_probe() -> dict[str, object]:
    wsl = shutil.which("wsl")
    if not wsl:
        return {"found": False, "error": "wsl executable not found"}
    distro_result = run(
        [wsl, "bash", "-lc", "cat /etc/os-release"],
        timeout=10,
    )
    distro = "unknown"
    if distro_result.ok:
        for line in distro_result.stdout.splitlines():
            if line.startswith("PRETTY_NAME="):
                distro = line.partition("=")[2].strip().strip('"')
                break
    version_commands = {
        "verilator": "verilator --version",
        "make": "make --version",
        "g++": "g++ --version",
        "python3": "python3 --version",
        "git": "git --version",
        "riscv64-unknown-elf-gcc": "riscv64-unknown-elf-gcc --version",
    }
    tools: dict[str, dict[str, object]] = {}
    for name, version_command in version_commands.items():
        path_result = run([wsl, "bash", "-lc", f"command -v {name}"], timeout=10)
        version_result = run([wsl, "bash", "-lc", version_command], timeout=10)
        path = first_line(path_result.stdout)
        tools[name] = {
            "found": path_result.ok and bool(path),
            "path": path or None,
            "version": first_line(version_result.stdout or version_result.stderr),
        }
    required = tuple(version_commands)
    return {
        "found": True,
        "ok": all(bool(tools.get(name, {}).get("found")) for name in required),
        "distro": distro,
        "tools": tools,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Detect SocRV build tools.")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    report = {
        "schema_version": 1,
        "host": {
            "platform": platform.platform(),
            "python": sys.version.split()[0],
            "python_executable": str(Path(sys.executable).resolve()),
        },
        "windows": {
            "git": windows_tool("git"),
            "make": windows_tool("make"),
            "vivado": windows_tool("vivado"),
            "riscv64-unknown-elf-gcc": windows_tool("riscv64-unknown-elf-gcc"),
        },
        "wsl": wsl_probe(),
    }
    report["ok_base"] = bool(report["wsl"].get("ok"))
    report["ok_fpga"] = bool(report["windows"]["vivado"]["found"])

    output = build_path("manifest", "eda_env.json")
    write_json_atomic(output, report)

    print(f"WSL toolchain: {'PASS' if report['ok_base'] else 'FAIL'}")
    print(f"Vivado:       {'PASS' if report['ok_fpga'] else 'MISSING'}")
    print(f"Report:       {output}")
    if args.verbose:
        import json

        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if report["ok_base"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
