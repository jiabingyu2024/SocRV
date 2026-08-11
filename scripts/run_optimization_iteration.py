from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path


STAGES = ("synth", "impl", "bitstream")


def run_step(name: str, command: list[str], log_dir: Path, *, dry_run: bool) -> dict[str, Any]:
    log_path = log_dir / f"{name}.log"
    print(f"[{name}] {' '.join(_quote(part) for part in command)}")
    if dry_run:
        return {"name": name, "command": command, "status": "DRY-RUN", "log": log_path.as_posix()}
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("$ " + " ".join(_quote(part) for part in command) + "\n\n")
        completed = subprocess.run(
            command,
            cwd=repo_path(),
            stdout=stream,
            stderr=subprocess.STDOUT,
            check=False,
        )
    result = {
        "name": name,
        "command": command,
        "status": "PASS" if completed.returncode == 0 else "FAIL",
        "returncode": completed.returncode,
        "log": log_path.as_posix(),
    }
    return result


def _quote(value: str) -> str:
    return json.dumps(value) if any(char.isspace() for char in value) else value


def python_script(name: str, *args: str) -> list[str]:
    return [sys.executable, "-B", str(repo_path("scripts", name)), *args]


def load_if_exists(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        return read_json(path)
    except (OSError, ValueError, json.JSONDecodeError):
        return None


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-") or "iteration"


def git_revision() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=repo_path(), capture_output=True, text=True, check=False
    )
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def render_iteration(document: dict[str, Any]) -> str:
    lines = [
        f"# RTL optimization iteration: {document['tag']}",
        "",
        f"- Started: `{document['started_at']}`",
        f"- Git revision: `{document['git_revision']}`",
        f"- Target core frequency: **{document['core_mhz']} MHz**",
        f"- Vivado stage: `{document['vivado_stage']}`",
        f"- Overall status: **{document['status']}**",
        "",
        "## Commands and logs",
        "",
        "| Step | Status | Log |",
        "|---|---|---|",
    ]
    for step in document.get("steps", []):
        lines.append(f"| `{step['name']}` | **{step['status']}** | `{step.get('log', '-')}` |")
    lines.extend(["", "## Compact results", ""])
    simulation = document.get("simulation") or {}
    if simulation:
        lines.extend(
            [
                "### Simulation",
                "",
                f"- Result: `{simulation.get('result_path', '-')}`",
                f"- Status: **{simulation.get('status', '-')}**",
                f"- Full run cycles / commits / IPC: `{simulation.get('cycles', '-')}` / `{simulation.get('commits', '-')}` / `{simulation.get('ipc', '-')}`",
                f"- CoreMark cycles / retired / IPC: `{simulation.get('perf_cycles', '-')}` / `{simulation.get('perf_commits', '-')}` / `{simulation.get('perf_ipc', '-')}`",
                f"- CoreMark CRC/checker: **{simulation.get('checker_passed', '-')}**",
                "",
            ]
        )
    vivado = document.get("vivado") or {}
    if vivado:
        lines.extend(
            [
                "### Vivado",
                "",
                f"- AI summary JSON: `{vivado.get('summary_json', '-')}`",
                f"- AI summary Markdown: `{vivado.get('summary_markdown', '-')}`",
                f"- WNS / TNS / WHS / THS: `{vivado.get('wns_ns', '-')}` / `{vivado.get('tns_ns', '-')}` / `{vivado.get('whs_ns', '-')}` / `{vivado.get('ths_ns', '-')}`",
                f"- Top setup cluster: `{vivado.get('top_setup_cluster', '-')}`",
                "",
            ]
        )
    lines.extend(
        [
            "## Next action",
            "",
            "Read the compact Vivado summary and simulation JSON first. Open raw `.rpt`/`.log` only for the selected representative path or a failure reproduction.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the fail-fast RTL -> simulation -> Vivado -> compact-report iteration loop."
    )
    parser.add_argument("--tag", required=True, help="filesystem-safe iteration label, e.g. fma-decode-r2")
    parser.add_argument("--core-mhz", type=int, choices=(100, 125, 150, 175, 200, 250), default=125)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--isa-gate", default="current")
    parser.add_argument("--coremark-iterations", type=int, default=1)
    parser.add_argument("--vivado-stage", choices=STAGES, default="synth")
    parser.add_argument("--vivado-all-violations", action="store_true")
    parser.add_argument("--build-software", action="store_true", help="rebuild the fixed software image before simulation/Vivado")
    parser.add_argument("--skip-static", action="store_true")
    parser.add_argument("--skip-smoke", action="store_true")
    parser.add_argument("--skip-isa", action="store_true")
    parser.add_argument("--skip-coremark", action="store_true")
    parser.add_argument("--skip-vivado", action="store_true")
    parser.add_argument("--compare-vivado", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.tag):
        parser.error("--tag may contain only letters, digits, '.', '_' and '-'")
    if args.jobs < 1 or args.coremark_iterations < 1:
        parser.error("--jobs and --coremark-iterations must be positive")

    tag = safe_name(args.tag)
    iteration_root = repo_path("build", "iterations", tag)
    log_dir = iteration_root / "logs"
    docs_root = repo_path("docs", "iterations")
    manifest_path = docs_root / f"{tag}.json"
    markdown_path = docs_root / f"{tag}.md"
    started_at = datetime.now(timezone.utc).isoformat()
    document: dict[str, Any] = {
        "schema_version": 1,
        "kind": "rtl-optimization-iteration",
        "tag": tag,
        "started_at": started_at,
        "git_revision": git_revision(),
        "core_mhz": args.core_mhz,
        "vivado_stage": args.vivado_stage,
        "status": "RUNNING",
        "steps": [],
        "artifacts": {
            "manifest": manifest_path.as_posix(),
            "markdown": markdown_path.as_posix(),
            "scratch_root": iteration_root.as_posix(),
        },
    }
    docs_root.mkdir(parents=True, exist_ok=True)
    write_json_atomic(manifest_path, document)

    def step(name: str, command: list[str]) -> None:
        result = run_step(name, command, log_dir, dry_run=args.dry_run)
        document["steps"].append(result)
        write_json_atomic(manifest_path, document)
        if result.get("status") == "FAIL":
            raise RuntimeError(
                f"{name} failed with exit code {result.get('returncode')}; see {result.get('log')}"
            )

    try:
        coremark_image_dir = repo_path("build", "images", "rtthread-coremark")
        coremark_image_ready = (coremark_image_dir / "image.json").is_file()
        if args.build_software or not coremark_image_ready:
            step("software", python_script("build_software.py", "--profile", "rtthread-coremark"))
            coremark_image_ready = True
        smoke_image_ready = (repo_path("build", "images", "smoke") / "image.json").is_file()
        if not args.skip_static:
            for name in ("check_filelists.py", "check_generated_tree.py", "check_memory_map.py", "validate_schemas.py", "lint_rtl.py"):
                step(name.removesuffix(".py"), python_script(name))
            step("verilator-build", python_script("run_verilator.py", "--profile", "smoke", "--build-only"))
        if not args.skip_smoke:
            smoke_args = ["--profile", "smoke", "--no-rtl-build"]
            if smoke_image_ready:
                smoke_args.append("--no-software-build")
            step("sim-smoke", python_script("run_verilator.py", *smoke_args))
        if not args.skip_isa:
            step(
                "sim-isa",
                python_script("run_isa_tests.py", "--gate", args.isa_gate, "--no-rtl-build"),
            )
        coremark_result = repo_path(
            "build", "result", "soc", f"opt-{tag}-coremark-{args.coremark_iterations}.json"
        )
        if not args.skip_coremark:
            coremark_args = [
                "--profile", "rtthread-coremark",
                "--test", f"opt-{tag}-coremark-{args.coremark_iterations}",
                "--benchmark-iterations", str(args.coremark_iterations),
                "--uart-command", f"coremark {args.coremark_iterations}",
                "--no-rtl-build",
            ]
            if coremark_image_ready:
                coremark_args.append("--no-software-build")
            step("sim-coremark", python_script("run_verilator.py", *coremark_args))
        vivado_root = repo_path(
            "build", "vivado", f"kintex7-rtthread-coremark-{args.core_mhz}mhz-{tag}"
        )
        if not args.skip_vivado:
            vivado_args = [
                "--profile", "rtthread-coremark",
                "--jobs", str(args.jobs),
                "--core-mhz", str(args.core_mhz),
                "--stage", args.vivado_stage,
                "--run-tag", tag,
                "--no-software-build",
                "--no-analyze",
            ]
            if args.vivado_all_violations:
                vivado_args.append("--all-violations")
            step("vivado", python_script("run_vivado.py", *vivado_args))
            compare_args = []
            if args.compare_vivado:
                compare_path = args.compare_vivado.resolve()
                if compare_path.is_dir():
                    compare_path = compare_path / "analysis" / "timing_summary.json"
                compare_args = ["--compare", str(compare_path)]
            step(
                "vivado-analysis",
                python_script(
                    "analyze_vivado_reports.py",
                    "--build-root", str(vivado_root),
                    "--stage", "impl" if args.vivado_stage != "synth" else "synth",
                    *compare_args,
                ),
            )

        sim = load_if_exists(coremark_result)
        if sim:
            performance = sim.get("performance") or {}
            checker = sim.get("checker") or {}
            document["simulation"] = {
                "result_path": coremark_result.as_posix(),
                "status": sim.get("status"),
                "cycles": sim.get("cycles"),
                "commits": sim.get("commits"),
                "ipc": sim.get("ipc"),
                "perf_cycles": performance.get("cycles"),
                "perf_commits": performance.get("commits"),
                "perf_ipc": performance.get("ipc"),
                "checker_passed": checker.get("passed"),
                "reproduce": sim.get("reproduce"),
            }
        timing_json = vivado_root / "analysis" / "timing_summary.json"
        timing = load_if_exists(timing_json)
        if timing:
            clusters = timing.get("setup_clusters") or []
            timing_metrics = timing.get("timing") or {}
            document["vivado"] = {
                "summary_json": timing_json.as_posix(),
                "summary_markdown": (vivado_root / "analysis" / "timing_summary.md").as_posix(),
                "wns_ns": timing_metrics.get("wns_ns"),
                "tns_ns": timing_metrics.get("tns_ns"),
                "whs_ns": timing_metrics.get("whs_ns"),
                "ths_ns": timing_metrics.get("ths_ns"),
                "top_setup_cluster": clusters[0].get("name") if clusters else None,
            }
        document["status"] = "DRY-RUN" if args.dry_run else "PASS"
    except (OSError, RuntimeError, ValueError) as error:
        document["status"] = "FAIL"
        document["error"] = str(error)
        write_json_atomic(manifest_path, document)
        markdown_path.write_text(render_iteration(document), encoding="utf-8", newline="\n")
        parser.error(str(error))
    write_json_atomic(manifest_path, document)
    markdown_path.write_text(render_iteration(document), encoding="utf-8", newline="\n")
    print(f"Iteration manifest: {manifest_path}")
    print(f"Iteration summary: {markdown_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
