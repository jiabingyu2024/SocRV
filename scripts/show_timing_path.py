#!/usr/bin/env python3
"""Extract one or a few timing paths from a large Vivado report.

Purpose: never put a multi-MB `.rpt` into a review/LLM context. Select paths by
index, slack, endpoint substring or category, and print either a condensed
cell-by-cell chain (default), delay hotspots, or the raw block.

Examples
--------
  python -B scripts/show_timing_path.py --build-root build/vivado/<run> --index 1
  python -B scripts/show_timing_path.py --build-root build/vivado/<run> \
      --dest flush_lower_ff --mode chain
  python -B scripts/show_timing_path.py --build-root build/vivado/<run> \
      --kind setup-violations --category LSU_DCCM --count 2 --mode hotspots
  python -B scripts/show_timing_path.py --report <file>.rpt --index 3 --mode full
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

SLACK_RE = re.compile(r"^Slack\s+\((MET|VIOLATED)\)\s*:\s*(-?\d+\.?\d*)ns")
ROW_RE = re.compile(r"^(?P<head>.*?)(?P<incr>-?\d+\.\d+)\s+(?P<total>-?\d+\.\d+)\s+(?P<edge>[rf])?\s{2,}(?P<res>\S.*)$")
NET_RE = re.compile(r"^net\s*\(fo=(\d+)")
CELL_RE = re.compile(r"^([A-Z][A-Z0-9_]*)\s*\(")
ARRAY_RE = re.compile(r"\[\d+\]")
GENERATED_RE = re.compile(r"gen_\w+?\[\d+\]\.|active_\w+\.|\w+_instance\.|genblock\.")

REPORTS = {
    "setup": "{stage}_setup_paths.rpt",
    "hold": "{stage}_hold_paths.rpt",
    "setup-violations": "{stage}_setup_violations.rpt",
    "hold-violations": "{stage}_hold_violations.rpt",
}
ALL_VIOLATIONS = {
    "setup-violations": "all_setup_violations.rpt",
    "hold-violations": "all_hold_violations.rpt",
}


def field(block: list[str], name: str) -> str:
    prefix = f"{name}:"
    for line in block:
        stripped = line.strip()
        if stripped.startswith(prefix):
            return stripped[len(prefix):].strip()
    return ""


def short_scope(instance: str) -> str:
    value = ARRAY_RE.sub("[*]", instance)
    value = GENERATED_RE.sub("", value)
    parts = [p for p in value.split("/") if p]
    for marker in ("veer", "u_soc"):
        if marker in parts:
            parts = parts[parts.index(marker) + 1:]
            break
    return "/".join(parts[-3:]) if parts else instance


def resolve_report(args: argparse.Namespace) -> Path:
    if args.report:
        return Path(args.report)
    root = Path(args.build_root)
    stage = args.stage
    if stage == "auto":
        stage = "post_impl" if (root / "project/reports/post_impl_timing_summary.rpt").exists() else "post_synth"
    elif not stage.startswith("post_"):
        stage = f"post_{stage}"
    reports = root / "project" / "reports"
    candidates = [reports / REPORTS[args.kind].format(stage=stage)]
    if args.kind in ALL_VIOLATIONS:
        candidates.append(reports / "all_violations" / ALL_VIOLATIONS[args.kind])
        candidates.append(root / "analysis" / "raw" / ALL_VIOLATIONS[args.kind])
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise SystemExit(
        f"no report found for kind={args.kind} stage={stage}; looked for:\n  "
        + "\n  ".join(str(c) for c in candidates)
    )


def category_of(text: str) -> str:
    lowered = text.lower()
    rules = (
        ("FPU_FMA", ("i_fma", "fpnew_fma", "/fma", "fma_")),
        ("FPU_CAST", ("i_cast", "fpnew_cast", "/cast", "cast_")),
        ("FPU_DIVSQRT", ("divsqrt", "fp_div", "sqrt")),
        ("FPU_OTHER", ("/fpu/", "fpnew", "fpu_")),
        ("EXU_DIV", ("/div_e", "/div/", "exu_div", "divider")),
        ("EXU_MUL", ("/mul", "multiplier", "exu_mul")),
        ("LSU_DCCM", ("dccm", "lsu_dccm", "dmem")),
        ("LSU", ("/lsu/", "lsu_", "/stbuf", "store_buffer")),
        ("IFU_ICCM", ("iccm", "ifu_iccm", "imem")),
        ("IFU_BHT_BP", ("/bp/", "bht", "btb", "ghr", "predict")),
        ("IFU", ("/ifu/", "ifu_", "fetch")),
        ("TLU_CSR_TRAP", ("/tlu/", "tlu_", "csr", "trap", "mcause", "mepc")),
        ("DECODE_IBUF", ("/dec/", "decode", "dec_", "ibuf", "instruction_buffer")),
        ("CLOCK_RESET_CDC", ("clock", "reset", "sync", "cdc", "peripheral")),
    )
    for name, needles in rules:
        if any(needle in lowered for needle in needles):
            return name
    return "OTHER"


def selected(block: list[str], index: int, args: argparse.Namespace) -> bool:
    if args.index and index != args.index:
        return False
    header = "\n".join(block[:8])
    if args.source and args.source not in header:
        return False
    if args.dest and args.dest not in field(block, "Destination"):
        return False
    if args.contains and args.contains not in "\n".join(block):
        return False
    if args.category:
        source = field(block, "Source")
        destination = field(block, "Destination")
        if category_of(f"{source} {destination}") != args.category.upper():
            return False
    if args.max_slack is not None:
        match = SLACK_RE.match(block[0])
        if not match or float(match.group(2)) > args.max_slack:
            return False
    return True


def parse_rows(block: list[str]) -> list[dict[str, object]]:
    """Return the datapath rows after the second separator line."""
    separators = [i for i, line in enumerate(block) if set(line.strip()) <= {"-", " "} and "---" in line]
    if len(separators) >= 3:
        start, stop = separators[1] + 1, separators[2]
    elif len(separators) >= 2:
        start, stop = separators[1] + 1, len(block)
    else:
        start, stop = 0, len(block)
    rows: list[dict[str, object]] = []
    pending = ""
    for line in block[start:stop]:
        if not line.strip():
            continue
        match = ROW_RE.match(line.strip())
        if not match:
            stripped = line.strip()
            if stripped and not stripped[0].isdigit() and "(" in stripped:
                pending = stripped
            continue
        head = (pending + " " + match.group("head")).strip() if pending else match.group("head").strip()
        pending = ""
        resource = match.group("res").strip()
        net = NET_RE.match(head)
        cell = CELL_RE.match(head)
        rows.append(
            {
                "kind": "net" if net else ("cell" if cell else "other"),
                "type": cell.group(1) if cell else (f"net(fo={net.group(1)})" if net else head[:26]),
                "fanout": int(net.group(1)) if net else None,
                "incr": float(match.group("incr")),
                "total": float(match.group("total")),
                "resource": resource,
            }
        )
    return rows


def print_header(block: list[str], index: int, report: Path) -> None:
    match = SLACK_RE.match(block[0])
    slack = f"{match.group(2)} ns ({match.group(1)})" if match else "?"
    source = field(block, "Source")
    destination = field(block, "Destination")
    print(f"# path #{index}  slack {slack}")
    print(f"- report: {report.as_posix()}")
    print(f"- category: {category_of(f'{source} {destination}')}")
    print(f"- requirement: {field(block, 'Requirement')}")
    print(f"- data path delay: {field(block, 'Data Path Delay')}")
    print(f"- logic levels: {field(block, 'Logic Levels')}")
    print(f"- source: {source}")
    print(f"- destination: {destination}")


def render_chain(rows: list[dict[str, object]], min_incr: float) -> None:
    print(f"\n| # | incr | total | type | fanout | instance |")
    print("|---:|---:|---:|---|---:|---|")
    shown = 0
    hidden_incr = 0.0
    for row in rows:
        if row["incr"] < min_incr:
            hidden_incr += row["incr"]
            continue
        shown += 1
        fanout = row["fanout"] if row["fanout"] is not None else ""
        print(
            f"| {shown} | {row['incr']:.3f} | {row['total']:.3f} | {row['type']} "
            f"| {fanout} | {short_scope(str(row['resource']))} |"
        )
    if hidden_incr:
        print(f"\n({len(rows) - shown} rows below {min_incr} ns hidden, {hidden_incr:.3f} ns total)")


def render_hotspots(rows: list[dict[str, object]], top: int) -> None:
    by_type: dict[str, list[float]] = defaultdict(list)
    by_scope: dict[str, list[float]] = defaultdict(list)
    logic = route = 0.0
    for row in rows:
        by_type[str(row["type"]).split("(")[0]].append(float(row["incr"]))
        by_scope[short_scope(str(row["resource"]))].append(float(row["incr"]))
        if row["kind"] == "net":
            route += float(row["incr"])
        else:
            logic += float(row["incr"])
    print(f"\n- logic {logic:.3f} ns / route {route:.3f} ns  (route {route / (logic + route) * 100:.1f}%)")
    print("\n| delay type | count | sum ns | mean ns |")
    print("|---|---:|---:|---:|")
    for name, values in sorted(by_type.items(), key=lambda kv: -sum(kv[1]))[:top]:
        print(f"| {name} | {len(values)} | {sum(values):.3f} | {sum(values) / len(values):.3f} |")
    print("\n| hierarchy scope | cells/nets | sum ns |")
    print("|---|---:|---:|")
    for name, values in sorted(by_scope.items(), key=lambda kv: -sum(kv[1]))[:top]:
        print(f"| {name} | {len(values)} | {sum(values):.3f} |")


def render_fanout(rows: list[dict[str, object]], threshold: int) -> None:
    high = [r for r in rows if (r["fanout"] or 0) >= threshold]
    if not high:
        print(f"\nno nets with fanout >= {threshold}")
        return
    print(f"\n| fanout | incr ns | net |")
    print("|---:|---:|---|")
    for row in sorted(high, key=lambda r: -(r["fanout"] or 0)):
        print(f"| {row['fanout']} | {row['incr']:.3f} | {short_scope(str(row['resource']))} |")


def emit(block: list[str], index: int, report: Path, args: argparse.Namespace) -> None:
    if args.mode == "full":
        print(f"# path #{index} (raw block)\n")
        print("\n".join(block).rstrip())
        return
    print_header(block, index, report)
    rows = parse_rows(block)
    if not rows:
        print("\n(no datapath table in this report; rerun report_timing without -no_detailed_paths)")
        return
    if args.mode == "chain":
        render_chain(rows, args.min_incr)
    elif args.mode == "hotspots":
        render_hotspots(rows, args.top)
    elif args.mode == "fanout":
        render_fanout(rows, args.fanout_threshold)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument("--build-root", help="build/vivado/<run>")
    source_group.add_argument("--report", help="explicit .rpt path")
    parser.add_argument("--stage", default="auto", choices=("auto", "synth", "impl"))
    parser.add_argument("--kind", default="setup", choices=tuple(REPORTS))
    parser.add_argument(
        "--mode",
        default="chain",
        choices=("chain", "hotspots", "fanout", "full"),
        help="chain: condensed cell list; hotspots: delay by type/scope; fanout: high-fanout nets; full: raw block",
    )
    parser.add_argument("--index", type=int, help="1-based path index inside the report")
    parser.add_argument("--count", type=int, default=1, help="max paths to print")
    parser.add_argument("--source", help="substring filter on the source pin")
    parser.add_argument("--dest", help="substring filter on the destination pin")
    parser.add_argument("--contains", help="substring filter anywhere in the path block")
    parser.add_argument("--category", help="cluster category, e.g. LSU_DCCM, FPU_FMA, DECODE_IBUF")
    parser.add_argument("--max-slack", type=float, help="only paths with slack <= this value")
    parser.add_argument("--min-incr", type=float, default=0.05, help="chain mode: hide rows below this delay")
    parser.add_argument("--top", type=int, default=8, help="hotspots mode: rows per table")
    parser.add_argument("--fanout-threshold", type=int, default=100, help="fanout mode: minimum fanout")
    parser.add_argument("--list", action="store_true", help="only list matching path indexes and slacks")
    args = parser.parse_args()

    report = resolve_report(args)
    printed = 0
    index = 0
    block: list[str] = []
    with report.open("r", encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if SLACK_RE.match(line):
                if block:
                    index += 1
                    if selected(block, index, args):
                        if args.list:
                            match = SLACK_RE.match(block[0])
                            print(f"#{index}\t{match.group(2)}\t{short_scope(field(block, 'Destination'))}")
                        else:
                            if printed:
                                print()
                            emit(block, index, report, args)
                        printed += 1
                        if printed >= args.count and not args.list:
                            return 0
                block = [line.rstrip("\n")]
            elif block:
                block.append(line.rstrip("\n"))
    if block:
        index += 1
        if selected(block, index, args) and (args.list or printed < args.count):
            if args.list:
                match = SLACK_RE.match(block[0])
                print(f"#{index}\t{match.group(2)}\t{short_scope(field(block, 'Destination'))}")
            else:
                emit(block, index, report, args)
            printed += 1
    if not printed:
        print("no path matched the given filters", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
