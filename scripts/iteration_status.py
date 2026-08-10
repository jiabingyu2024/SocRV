#!/usr/bin/env python3
"""One-command iteration digest for the 100 MHz -> 10 s optimization loop.

Collapses everything one RTL iteration produces -- simulation gates, ISA gates,
the CoreMark performance window and the Vivado timing/utilization digest -- into
a single compact report, so the reader never has to open a raw .rpt, .log or
per-test result JSON.

Examples
--------
  python scripts/iteration_status.py
  python scripts/iteration_status.py --build-root build/vivado/kintex7-smoke
  python scripts/iteration_status.py --core-mhz 150 175 200 --iterations 2000
  python scripts/iteration_status.py --trend
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REGRESSION_ROOT = REPO_ROOT / "build" / "regression"
VIVADO_ROOT = REPO_ROOT / "build" / "vivado"
ITERATION_ROOT = REPO_ROOT / "docs" / "iterations"

COREMARK_GATE_SECONDS = 10.0
DEFAULT_ITERATIONS = 2000
DEFAULT_FREQS = (100.0, 125.0, 150.0, 175.0, 200.0)
SIM_SUITES = ("correctness", "coremark")


def load_json(path: Path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def rel(path) -> str:
    if path is None:
        return "-"
    try:
        return str(Path(path).resolve().relative_to(REPO_ROOT)).replace("\\", "/")
    except (ValueError, OSError):
        return str(path).replace("\\", "/")


def num(value, digits: int = 3) -> str:
    if value is None:
        return "-"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    if isinstance(value, int):
        return f"{value:,}"
    return str(value)


def table(headers: list[str], rows: list[list[str]]) -> str:
    if not rows:
        return "  (no data)"
    cells = [[str(c) for c in row] for row in rows]
    widths = [len(h) for h in headers]
    for row in cells:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))
    out = ["  " + "  ".join(h.ljust(widths[i]) for i, h in enumerate(headers)).rstrip()]
    out.append("  " + "  ".join("-" * widths[i] for i in range(len(headers))))
    for row in cells:
        out.append("  " + "  ".join(row[i].ljust(widths[i]) for i in range(len(headers))).rstrip())
    return "\n".join(out)


def newest_build_root() -> Path | None:
    if not VIVADO_ROOT.is_dir():
        return None
    candidates = [d for d in VIVADO_ROOT.iterdir() if (d / "analysis" / "timing_summary.json").is_file()]
    if not candidates:
        return None
    return max(candidates, key=lambda d: (d / "analysis" / "timing_summary.json").stat().st_mtime)


def achieved_mhz(requirement_ns, wns_ns) -> float | None:
    """Frequency the design would close at, given the period and worst slack."""
    if requirement_ns in (None, 0) or wns_ns is None:
        return None
    period = float(requirement_ns) - float(wns_ns)
    if period <= 0:
        return None
    return 1000.0 / period


def sim_section() -> tuple[str, list[str]]:
    """Simulation gates from build/regression/<suite>/summary.json."""
    rows: list[list[str]] = []
    blockers: list[str] = []
    for suite in SIM_SUITES:
        summary_path = REGRESSION_ROOT / suite / "summary.json"
        data = load_json(summary_path)
        if data is None:
            rows.append([suite, "MISSING", "-", "-", f"no {rel(summary_path)}"])
            blockers.append(f"{suite}: summary missing")
            continue
        tests = data.get("tests") or []
        failed = [t for t in tests if str(t.get("status")) != "PASS"]
        status = str(data.get("status", "?"))
        note = ", ".join(str(t.get("test")) for t in failed[:3]) if failed else "-"
        rows.append([suite, status, str(len(tests)), str(len(failed)), note])
        if status != "PASS":
            blockers.append(f"{suite}: {status}")
    return table(["suite", "status", "tests", "failed", "first failures"], rows), blockers


def isa_section() -> tuple[str, list[str]]:
    """ISA gates from build/regression/isa/<gate>/summary.json."""
    isa_root = REGRESSION_ROOT / "isa"
    if not isa_root.is_dir():
        return "  (no build/regression/isa)", ["isa: not run"]
    rows: list[list[str]] = []
    blockers: list[str] = []
    for gate_dir in sorted(isa_root.iterdir()):
        data = load_json(gate_dir / "summary.json")
        if data is None:
            continue
        tests = data.get("tests") or []
        failed = [t for t in tests if str(t.get("status")) != "PASS"]
        status = str(data.get("status", "?"))
        suites = data.get("suites") or []
        note = ", ".join(str(t.get("test")) for t in failed[:3]) if failed else ",".join(suites)
        rows.append([gate_dir.name, status, str(len(tests)), str(len(failed)), note or "-"])
        if status != "PASS":
            blockers.append(f"isa/{gate_dir.name}: {status}")
    return table(["gate", "status", "tests", "failed", "suites / failures"], rows), blockers


def find_performance_window() -> tuple[dict | None, Path | None]:
    """Newest complete CoreMark performance window across regression summaries.

    The window lives in the `performance` sub-object, NOT in the top-level
    cycles/commits/ipc of a test entry. It is legitimately absent from the
    per-test result.json files under build/verilator, so callers must cope
    with None.
    """
    best: tuple[float, dict, Path] | None = None
    if not REGRESSION_ROOT.is_dir():
        return None, None
    for summary_path in sorted(REGRESSION_ROOT.rglob("summary.json")):
        data = load_json(summary_path)
        if not isinstance(data, dict):
            continue
        candidates: list[dict] = []
        top = data.get("performance")
        if isinstance(top, list):
            candidates.extend(e for e in top if isinstance(e, dict))
        elif isinstance(top, dict):
            candidates.append(top)
        for test in data.get("tests") or []:
            perf = test.get("performance") if isinstance(test, dict) else None
            if isinstance(perf, dict):
                perf = dict(perf)
                perf.setdefault("test", test.get("test"))
                candidates.append(perf)
        mtime = summary_path.stat().st_mtime
        for perf in candidates:
            if not perf.get("complete"):
                continue
            if not perf.get("iterations") or not perf.get("cycles"):
                continue
            if best is None or mtime > best[0]:
                best = (mtime, perf, summary_path)
    if best is None:
        return None, None
    return best[1], best[2]


def coremark_section(iterations: int, freqs: list[float]) -> tuple[str, list[str]]:
    perf, source = find_performance_window()
    if perf is None:
        msg = (
            "  (no complete CoreMark performance window found)\n"
            "  run: make sim-coremark   (or scripts/run_regression.py --suite correctness)"
        )
        return msg, ["coremark: no performance window"]

    cpi_iter = perf.get("cycles_per_iteration")
    if not cpi_iter:
        cpi_iter = float(perf["cycles"]) / float(perf["iterations"])
    lines = [
        table(
            ["metric", "value"],
            [
                ["test", str(perf.get("test", "-"))],
                ["measured iterations", num(perf.get("iterations"))],
                ["window cycles", num(perf.get("cycles"))],
                ["cycles / iteration", num(cpi_iter, 1)],
                ["commits / iteration", num(perf.get("commits_per_iteration"), 1)],
                ["IPC", num(perf.get("ipc"), 4)],
                ["sim seconds", num(perf.get("seconds"), 4)],
                ["iterations / second (sim)", num(perf.get("iterations_per_second"), 2)],
                ["source", rel(source)],
            ],
        )
    ]

    proj_rows = []
    for mhz in freqs:
        per_iter = cpi_iter / (mhz * 1e6)
        seconds = per_iter * iterations
        budget_iters = int(COREMARK_GATE_SECONDS / per_iter)
        verdict = "PASS" if seconds <= COREMARK_GATE_SECONDS else "FAIL"
        proj_rows.append(
            [f"{mhz:g}", f"{per_iter * 1000:.3f}", num(seconds, 3), f"{COREMARK_GATE_SECONDS - seconds:+.3f}",
             f"{budget_iters:,}", verdict]
        )
    lines.append("")
    lines.append(
        f"  wall time = CoreMark window cycles / core frequency; gate <= {COREMARK_GATE_SECONDS:g} s."
    )
    lines.append(f"  'iters in 10 s' is workload-agnostic; 'seconds' assumes --iterations {iterations}.")
    lines.append(
        table(["core MHz", "ms / iter", "seconds", "margin s", "iters in 10 s", "verdict"], proj_rows)
    )

    blockers: list[str] = []
    if not perf.get("complete"):
        blockers.append("coremark: window incomplete")
    return "\n".join(lines), blockers


def timing_section(build_root: Path | None, cluster_limit: int) -> tuple[str, list[str]]:
    if build_root is None:
        return (
            "  (no Vivado run with analysis/timing_summary.json)\n"
            "  run: make fpga-synth RUN_TAG=<tag>   then   make fpga-analyze RUN_TAG=<tag>"
        ), ["vivado: no analysis"]
    data = load_json(build_root / "analysis" / "timing_summary.json")
    if data is None:
        return f"  (unreadable {rel(build_root / 'analysis' / 'timing_summary.json')})", ["vivado: unreadable"]

    timing = data.get("timing") or {}
    util = data.get("utilization") or {}
    blockers: list[str] = []
    met = timing.get("constraints_met")
    if met is False:
        blockers.append("vivado: timing not met")

    lines = [
        table(
            ["metric", "value"],
            [
                ["run tag", build_root.name],
                ["stage", str(data.get("stage", "-"))],
                ["constraints met", num(met)],
                ["WNS ns (setup)", num(timing.get("wns_ns"))],
                ["TNS ns (setup)", num(timing.get("tns_ns"))],
                ["setup failing endpoints", f"{num(timing.get('setup_failing_endpoints'))} / {num(timing.get('setup_total_endpoints'))}"],
                ["WHS ns (hold)", num(timing.get("whs_ns"))],
                ["THS ns (hold)", num(timing.get("ths_ns"))],
                ["hold failing endpoints", f"{num(timing.get('hold_failing_endpoints'))} / {num(timing.get('hold_total_endpoints'))}"],
                ["unconstrained reg pins", num(timing.get("unconstrained_register_pins"))],
                ["setup paths exported", num(data.get("setup_path_count"))],
                ["hold paths exported", num(data.get("hold_path_count"))],
            ],
        ),
        "",
        "  utilization: "
        + " | ".join(
            f"{k}={num(util.get(v))}"
            for k, v in (
                ("LUT", "total_luts"),
                ("FF", "ff"),
                ("RAMB36", "ramb36"),
                ("RAMB18", "ramb18"),
                ("DSP", "dsp"),
                ("SRL", "srl"),
            )
        ),
    ]

    clock_rows = []
    for edge in data.get("clock_interaction") or []:
        mhz = achieved_mhz(edge.get("requirement_ns"), edge.get("wns_ns"))
        clock_rows.append(
            [
                f"{edge.get('from_clock')}->{edge.get('to_clock')}",
                num(edge.get("requirement_ns")),
                num(edge.get("wns_ns")),
                f"{mhz:.1f}" if mhz else "-",
                num(edge.get("failing_endpoints")),
                str(edge.get("classification", "-")),
            ]
        )
    if clock_rows:
        lines.append("")
        lines.append("  clock pairs (achieved MHz = 1000 / (requirement - WNS)):")
        lines.append(table(["clock pair", "req ns", "WNS ns", "achieved MHz", "failing", "class"], clock_rows))

    clusters = data.get("setup_clusters") or []
    if clusters:
        rows = []
        for cluster in clusters[:cluster_limit]:
            rows.append(
                [
                    str(cluster.get("category", "-")),
                    num(cluster.get("worst_slack_ns")),
                    num(cluster.get("count")),
                    num(cluster.get("violating_count")),
                    num(cluster.get("max_logic_levels"), 0),
                    num(cluster.get("mean_route_percent"), 1),
                    ",".join(f"{c[0]}x{c[1]}" for c in (cluster.get("dominant_cells") or [])[:3]),
                ]
            )
        lines.append("")
        lines.append(f"  worst setup clusters (top {min(cluster_limit, len(clusters))} of {len(clusters)}):")
        lines.append(table(["category", "worst ns", "paths", "viol", "max lvl", "route %", "top cells"], rows))

    cdc = data.get("cdc") or {}
    if cdc:
        unsafe = cdc.get("unsafe") or 0
        unknown = cdc.get("unknown") or 0
        no_async = cdc.get("no_async_reg") or 0
        lines.append("")
        lines.append(f"  CDC: unsafe={unsafe} unknown={unknown} no_async_reg={no_async}")
        if unsafe or unknown:
            blockers.append(f"cdc: unsafe={unsafe} unknown={unknown}")

    stage = str(data.get("stage", "synth"))
    vb = rel(build_root)
    lines.append("")
    lines.append("  drill down without opening a .rpt:")
    lines.append(f"    make fpga-paths VIVADO_BUILD={vb} PATH_GROUP=category")
    lines.append(f"    make fpga-path  VIVADO_BUILD={vb} VIVADO_STAGE={stage} PATH_INDEX=1 PATH_MODE=hotspots")
    lines.append(f"    make fpga-util  VIVADO_BUILD={vb}")
    return "\n".join(lines), blockers


def trend_report() -> str:
    """Cross-run table for the iteration record section of the plan doc."""
    lines: list[str] = ["## Vivado runs (oldest -> newest by analysis mtime)", ""]
    entries = []
    if VIVADO_ROOT.is_dir():
        for run_dir in VIVADO_ROOT.iterdir():
            summary_path = run_dir / "analysis" / "timing_summary.json"
            if not summary_path.is_file():
                continue
            data = load_json(summary_path)
            if data is None:
                continue
            entries.append((summary_path.stat().st_mtime, run_dir.name, data))
    entries.sort()

    rows = []
    for _, tag, data in entries:
        timing = data.get("timing") or {}
        util = data.get("utilization") or {}
        edges = data.get("clock_interaction") or []
        req = next((e.get("requirement_ns") for e in edges if e.get("requirement_ns")), None)
        mhz = achieved_mhz(req, timing.get("wns_ns"))
        rows.append(
            [
                tag,
                str(data.get("stage", "-")),
                num(req),
                num(timing.get("wns_ns")),
                num(timing.get("tns_ns"), 1),
                f"{mhz:.1f}" if mhz else "-",
                num(timing.get("setup_failing_endpoints")),
                num(util.get("total_luts")),
                num(util.get("ff")),
            ]
        )
    lines.append(
        table(["run tag", "stage", "req ns", "WNS ns", "TNS ns", "achieved MHz", "failing", "LUT", "FF"], rows)
    )

    manifests = sorted(ITERATION_ROOT.glob("*.json")) if ITERATION_ROOT.is_dir() else []
    if manifests:
        lines.extend(["", "## Iteration manifests (docs/iterations/*.json)", ""])
        man_rows = []
        for path in manifests:
            data = load_json(path)
            if not isinstance(data, dict):
                continue
            steps = data.get("steps") or []
            bad = [s.get("name") for s in steps if str(s.get("status")) not in ("PASS", "OK", "DRY-RUN")]
            man_rows.append(
                [
                    str(data.get("tag", path.stem)),
                    str(data.get("status", "-")),
                    num(data.get("core_mhz")),
                    str(data.get("vivado_stage", "-")),
                    str(data.get("git_revision", "-"))[:12],
                    f"{len(steps) - len(bad)}/{len(steps)}",
                    ",".join(str(b) for b in bad[:3]) if bad else "-",
                ]
            )
        lines.append(table(["tag", "status", "MHz", "stage", "rev", "steps ok", "not ok"], man_rows))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build-root", type=Path, help="Vivado run directory (default: newest analysed run)")
    parser.add_argument("--iterations", type=int, default=DEFAULT_ITERATIONS,
                        help=f"CoreMark iterations to project onto (default {DEFAULT_ITERATIONS})")
    parser.add_argument("--core-mhz", type=float, nargs="+", default=list(DEFAULT_FREQS),
                        help="frequencies for the CoreMark projection table")
    parser.add_argument("--clusters", type=int, default=6, help="setup clusters to show (default 6)")
    parser.add_argument("--trend", action="store_true", help="cross-run trend tables instead of the digest")
    args = parser.parse_args()

    if args.trend:
        print(trend_report())
        return 0

    build_root = args.build_root.resolve() if args.build_root else newest_build_root()
    if args.build_root and not build_root.is_dir():
        parser.error(f"build root not found: {args.build_root}")

    sim_text, sim_blockers = sim_section()
    isa_text, isa_blockers = isa_section()
    perf_text, perf_blockers = coremark_section(args.iterations, args.core_mhz)
    timing_text, timing_blockers = timing_section(build_root, args.clusters)

    print("# Iteration status\n")
    print("## Simulation gates\n")
    print(sim_text + "\n")
    print("## ISA gates\n")
    print(isa_text + "\n")
    print("## CoreMark performance window\n")
    print(perf_text + "\n")
    print("## Vivado timing digest\n")
    print(timing_text + "\n")

    blockers = sim_blockers + isa_blockers + perf_blockers + timing_blockers
    print("## Verdict\n")
    if blockers:
        print("  BLOCKED")
        for item in blockers:
            print(f"    - {item}")
    else:
        print("  CLEAR: sim + ISA gates pass, timing met, CoreMark window valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
