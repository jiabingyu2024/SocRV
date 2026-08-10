#!/usr/bin/env python3
"""summarize_utilization.py - compact hierarchy table from a Vivado utilization report.

Avoids loading the 2+ MB .rpt file into model context.  Outputs a markdown table
capped at --depth levels, optionally diff'd against a second build root.

Usage
-----
  python scripts/summarize_utilization.py --build-root <dir> [options]

  --stage {auto,synth,impl}    default auto  (impl takes priority over synth)
  --depth N                    max hierarchy depth to show  (default 4)
  --filter SUBSTR              keep rows whose instance or module contain SUBSTR
  --metric {luts,ffs,ramb,dsp} column to sort by  (default luts)
  --limit N                    max rows in output  (default 30)
  --diff OTHER_BUILD_ROOT      show delta vs another run, sorted by |dluts|

Output columns: Instance | Module | Total LUTs | FFs | RAMB36 | DSP
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Column order as they appear in the report after the Module column
COLS: list[tuple[str, str]] = [
    ("total_luts", "Total LUTs"),
    ("logic_luts", "Logic LUTs"),
    ("lutrams",    "LUTRAMs"),
    ("srls",       "SRLs"),
    ("ffs",        "FFs"),
    ("ramb36",     "RAMB36"),
    ("ramb18",     "RAMB18"),
    ("dsp",        "DSP Blocks"),
]

METRIC_KEYS: dict[str, str] = {
    "luts": "total_luts",
    "ffs":  "ffs",
    "ramb": "ramb36",
    "dsp":  "dsp",
}

# Match a hierarchy table row: | <instance> | <module> | <numbers...> |
# The instance cell must be captured WITHOUT stripping: its leading spaces are
# the only encoding of hierarchy depth (2 spaces per level). An `\s*` here
# silently flattens the whole tree to depth 0.
_ROW_RE  = re.compile(r"^\|([^|]*)\|([^|]*)\|(.+)$")
_NUMS_RE = re.compile(r"\b(\d+)\b")


# ---------------------------------------------------------------------------
# Report resolution
# ---------------------------------------------------------------------------

def _find_report(build_root: Path, stage: str) -> Path:
    base = build_root / "project" / "reports"
    candidates = {
        "impl":  base / "post_impl_utilization.rpt",
        "synth": base / "post_synth_utilization.rpt",
    }
    if stage == "auto":
        for key in ("impl", "synth"):
            p = candidates[key]
            if p.exists():
                return p
        raise FileNotFoundError(f"No utilization report found under {base}")
    p = candidates[stage]
    if not p.exists():
        raise FileNotFoundError(f"Report not found: {p}")
    return p


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def _parse_report(path: Path) -> list[dict]:
    """Stream-parse the hierarchy table; return one dict per row."""
    rows: list[dict] = []
    in_table = False
    for raw in path.open(encoding="utf-8", errors="replace"):
        line = raw.rstrip("\n")
        if "Instance" in line and "Total LUTs" in line:
            in_table = True
            continue
        if not in_table:
            continue
        if line.startswith("+--"):
            continue  # separator line
        m = _ROW_RE.match(line)
        if not m:
            break  # end of table
        inst_raw, mod_raw, nums_raw = m.group(1), m.group(2), m.group(3)
        nums = _NUMS_RE.findall(nums_raw)
        if len(nums) < len(COLS):
            continue
        leading = len(inst_raw) - len(inst_raw.lstrip())
        depth   = leading // 2
        rows.append({
            "instance": inst_raw.strip(),
            "module":   mod_raw.strip(),
            "depth":    depth,
            **{key: int(nums[i]) for i, (key, _) in enumerate(COLS)},
        })
    return rows


# ---------------------------------------------------------------------------
# Filtering
# ---------------------------------------------------------------------------

def _apply_filters(rows: list[dict], max_depth: int, substr: str | None) -> list[dict]:
    result = [r for r in rows if r["depth"] <= max_depth]
    if substr:
        low = substr.lower()
        result = [
            r for r in result
            if low in r["instance"].lower() or low in r["module"].lower()
        ]
    return result


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def _mc(s: str) -> str:
    """Escape pipe characters for a markdown table cell."""
    return s.replace("|", "\\|")


def _fmt_indent(row: dict) -> str:
    return "  " * row["depth"] + row["instance"]


def _print_table(rows: list[dict], metric_key: str, limit: int, label: str) -> None:
    sorted_rows = sorted(rows, key=lambda r: r.get(metric_key, 0), reverse=True)[:limit]
    print(f"\n**Utilization - {label}**\n")
    print("| Instance | Module | Total LUTs | FFs | RAMB36 | DSP |")
    print("|----------|--------|-----------|-----|--------|-----|")
    for r in sorted_rows:
        print(
            f"| {_mc(_fmt_indent(r))} | {_mc(r['module'])} |"
            f" {r['total_luts']:>10} | {r['ffs']:>5} | {r['ramb36']:>6} | {r['dsp']:>3} |"
        )


def _diff_tables(
    rows_a: list[dict],
    rows_b: list[dict],
    metric_key: str,
    limit: int,
) -> None:
    """Print delta table: rows_a = baseline, rows_b = new."""
    idx_a = {r["instance"]: r for r in rows_a}
    idx_b = {r["instance"]: r for r in rows_b}
    all_insts = sorted(set(idx_a) | set(idx_b))

    deltas: list[dict] = []
    for inst in all_insts:
        a = idx_a.get(inst, {})
        b = idx_b.get(inst, {})
        dl = b.get("total_luts", 0) - a.get("total_luts", 0)
        df = b.get("ffs",        0) - a.get("ffs",        0)
        dr = b.get("ramb36",     0) - a.get("ramb36",     0)
        dd = b.get("dsp",        0) - a.get("dsp",        0)
        if dl == 0 and df == 0 and dr == 0 and dd == 0:
            continue
        deltas.append({
            "instance":  inst,
            "module":    (b or a).get("module", ""),
            "luts_old":  a.get("total_luts", 0),
            "luts_new":  b.get("total_luts", 0),
            "ffs_old":   a.get("ffs", 0),
            "ffs_new":   b.get("ffs", 0),
            "dl": dl, "df": df, "dr": dr, "dd": dd,
        })

    deltas.sort(key=lambda d: abs(d["dl"]), reverse=True)
    deltas = deltas[:limit]

    print("\n**Utilization diff (baseline -> new)**\n")
    print("| Instance | Module | LUTs old->new | dLUT | FFs old->new | dFF |")
    print("|----------|--------|-------------|------|------------|-----|")
    for d in deltas:
        dl_s = (f"+{d['dl']}" if d["dl"] >= 0 else str(d["dl"]))
        df_s = (f"+{d['df']}" if d["df"] >= 0 else str(d["df"]))
        print(
            f"| {_mc(d['instance'])} | {_mc(d['module'])} |"
            f" {d['luts_old']}->{d['luts_new']} | {dl_s} |"
            f" {d['ffs_old']}->{d['ffs_new']} | {df_s} |"
        )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--build-root", required=True, type=Path, metavar="DIR",
                    help="Vivado build root directory")
    ap.add_argument("--stage", choices=["auto", "synth", "impl"], default="auto",
                    help="Report stage (default: auto, prefers impl)")
    ap.add_argument("--depth", type=int, default=4, metavar="N",
                    help="Max hierarchy depth to show (default 4)")
    ap.add_argument("--filter", metavar="SUBSTR",
                    help="Keep rows whose instance or module contain SUBSTR")
    ap.add_argument("--metric", choices=list(METRIC_KEYS), default="luts",
                    help="Column to sort by (default luts)")
    ap.add_argument("--limit", type=int, default=30, metavar="N",
                    help="Max rows to display (default 30)")
    ap.add_argument("--diff", type=Path, metavar="OTHER_BUILD_ROOT",
                    help="Compare against another build root")
    args = ap.parse_args(argv)

    try:
        rpt = _find_report(args.build_root, args.stage)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    stage_label = "post_impl" if "impl" in rpt.name else "post_synth"
    rows = _parse_report(rpt)
    rows = _apply_filters(rows, args.depth, args.filter)

    if args.diff:
        # Pin the diff target to the stage the baseline actually resolved to,
        # otherwise `auto` can silently compare post_synth against post_impl.
        diff_stage = "impl" if stage_label == "post_impl" else "synth"
        try:
            rpt_b = _find_report(args.diff, diff_stage)
        except FileNotFoundError as exc:
            print(f"ERROR (diff): {exc}", file=sys.stderr)
            print(
                f"hint: baseline resolved to {stage_label}; the diff target has no "
                f"matching report. Pass --stage explicitly.",
                file=sys.stderr,
            )
            return 1
        rows_b_all = _parse_report(rpt_b)
        rows_b = _apply_filters(rows_b_all, args.depth, args.filter)
        stage_b = "post_impl" if "impl" in rpt_b.name else "post_synth"
        print(f"baseline: {args.build_root.name}  ({stage_label})")
        print(f"new:      {args.diff.name}  ({stage_b})")
        _diff_tables(rows, rows_b, METRIC_KEYS[args.metric], args.limit)
    else:
        _print_table(rows, METRIC_KEYS[args.metric], args.limit, stage_label)

    return 0


if __name__ == "__main__":
    sys.exit(main())
