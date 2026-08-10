#!/usr/bin/env python3
"""Filter and aggregate analysis/setup_paths.csv without reading the whole file.

The clustering step already writes a compact `timing_summary.md`. This tool is
the drill-down layer: pick one cluster or category and get its member paths,
group delay by hierarchy scope, list high-fanout nets, or diff two runs.

Examples
--------
  python -B scripts/query_timing_paths.py --build-root build/vivado/<run> --group category
  python -B scripts/query_timing_paths.py --build-root build/vivado/<run> \
      --category LSU_DCCM --limit 10
  python -B scripts/query_timing_paths.py --build-root build/vivado/<run> --fanout 500
  python -B scripts/query_timing_paths.py --build-root build/vivado/<run> \
      --diff build/vivado/<previous-run>
"""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


def load(build_root: Path, kind: str) -> list[dict[str, str]]:
    path = build_root / "analysis" / f"{kind}_paths.csv"
    if not path.exists():
        raise SystemExit(f"missing {path}; run scripts/analyze_vivado_reports.py first")
    with path.open("r", encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def as_float(value: str | None) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def apply_filters(rows: list[dict[str, str]], args: argparse.Namespace) -> list[dict[str, str]]:
    out = rows
    if args.category:
        wanted = {c.strip().upper() for c in args.category.split(",")}
        out = [r for r in out if r.get("category", "").upper() in wanted]
    if args.cluster:
        out = [r for r in out if args.cluster.lower() in r.get("cluster", "").lower()]
    if args.scope:
        out = [
            r
            for r in out
            if args.scope.lower() in r.get("source_scope", "").lower()
            or args.scope.lower() in r.get("destination_scope", "").lower()
        ]
    if args.max_slack is not None:
        out = [r for r in out if as_float(r.get("slack_ns")) <= args.max_slack]
    if args.violated:
        out = [r for r in out if r.get("status", "").upper() == "VIOLATED"]
    return out


def mc(value) -> str:
    """Escape a free-text markdown cell.

    Cluster labels are built as "CATEGORY | src -> dst | launch->capture", so
    they carry literal pipes. Emitted raw, one row silently gains columns and
    the whole table stops parsing.
    """
    return str("" if value is None else value).replace("|", "\\|")


def print_paths(rows: list[dict[str, str]], limit: int) -> None:
    print(f"\n| slack | levels | logic% | route% | fanout | category | source_scope -> destination_scope |")
    print("|---:|---:|---:|---:|---:|---|---|")
    for row in sorted(rows, key=lambda r: as_float(r.get("slack_ns")))[:limit]:
        print(
            f"| {row.get('slack_ns')} | {row.get('logic_levels')} "
            f"| {as_float(row.get('logic_percent')):.0f} | {as_float(row.get('route_percent')):.0f} "
            f"| {row.get('max_fanout')} | {mc(row.get('category'))} "
            f"| {mc(row.get('source_scope'))} -> {mc(row.get('destination_scope'))} |"
        )
    if len(rows) > limit:
        print(f"\n({len(rows) - limit} more paths; raise --limit or narrow the filter)")


def print_groups(rows: list[dict[str, str]], key: str, limit: int) -> None:
    buckets: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        buckets[row.get(key, "") or "unknown"].append(row)
    print(f"\n| {key} | paths | violating | worst slack | mean slack | levels avg | route% avg |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    ordered = sorted(buckets.items(), key=lambda kv: min(as_float(r.get("slack_ns")) for r in kv[1]))
    for name, group in ordered[:limit]:
        slacks = [as_float(r.get("slack_ns")) for r in group]
        violating = sum(1 for r in group if r.get("status", "").upper() == "VIOLATED")
        levels = [as_float(r.get("logic_levels")) for r in group]
        routes = [as_float(r.get("route_percent")) for r in group]
        print(
            f"| {mc(name)} | {len(group)} | {violating} | {min(slacks):.3f} "
            f"| {sum(slacks) / len(slacks):.3f} | {sum(levels) / len(levels):.1f} "
            f"| {sum(routes) / len(routes):.1f} |"
        )


def print_fanout(rows: list[dict[str, str]], threshold: int, limit: int) -> None:
    nets: dict[str, tuple[int, int, float]] = {}
    for row in rows:
        net = row.get("max_fanout_net") or ""
        fanout = int(as_float(row.get("max_fanout")))
        if not net or fanout < threshold:
            continue
        count, _, worst = nets.get(net, (0, fanout, 0.0))
        nets[net] = (count + 1, fanout, min(worst, as_float(row.get("slack_ns"))))
    if not nets:
        print(f"\nno path reports a net with fanout >= {threshold}")
        return
    print(f"\n| fanout | paths | worst slack | net |")
    print("|---:|---:|---:|---|")
    for net, (count, fanout, worst) in sorted(nets.items(), key=lambda kv: -kv[1][1])[:limit]:
        print(f"| {fanout} | {count} | {worst:.3f} | {mc(net)} |")


def print_diff(current: list[dict[str, str]], baseline: list[dict[str, str]], limit: int) -> None:
    def by_cluster(rows: list[dict[str, str]]) -> dict[str, tuple[int, float]]:
        buckets: dict[str, list[float]] = defaultdict(list)
        for row in rows:
            buckets[row.get("cluster", "") or "unknown"].append(as_float(row.get("slack_ns")))
        return {name: (len(values), min(values)) for name, values in buckets.items()}

    now, before = by_cluster(current), by_cluster(baseline)
    print("\n| cluster | paths before -> after | worst slack before -> after | delta |")
    print("|---|---:|---:|---:|")
    rows = []
    for name in set(now) | set(before):
        old_count, old_worst = before.get(name, (0, float("nan")))
        new_count, new_worst = now.get(name, (0, float("nan")))
        delta = (new_worst - old_worst) if old_count and new_count else float("nan")
        rows.append((delta if delta == delta else -999, name, old_count, new_count, old_worst, new_worst, delta))
    for _, name, old_count, new_count, old_worst, new_worst, delta in sorted(rows)[:limit]:
        fmt = lambda v: "-" if v != v else f"{v:.3f}"
        print(f"| {mc(name)} | {old_count} -> {new_count} | {fmt(old_worst)} -> {fmt(new_worst)} | {fmt(delta)} |")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build-root", type=Path, required=True, help="build/vivado/<run>")
    parser.add_argument("--kind", default="setup", choices=("setup", "hold"))
    parser.add_argument("--category", help="comma-separated categories, e.g. LSU_DCCM,LSU")
    parser.add_argument("--cluster", help="substring match on the cluster label")
    parser.add_argument("--scope", help="substring match on source/destination hierarchy scope")
    parser.add_argument("--max-slack", type=float, help="only paths with slack <= this value")
    parser.add_argument("--violated", action="store_true", help="only VIOLATED paths")
    parser.add_argument(
        "--group",
        choices=("category", "cluster", "source_scope", "destination_scope", "launch_clock", "capture_clock"),
        help="aggregate instead of listing individual paths",
    )
    parser.add_argument("--fanout", type=int, help="list nets with max_fanout >= N instead of paths")
    parser.add_argument("--diff", type=Path, help="compare cluster worst slack against another build root")
    parser.add_argument("--limit", type=int, default=15)
    args = parser.parse_args()

    rows = apply_filters(load(args.build_root, args.kind), args)
    print(f"# {args.kind} paths: {len(rows)} selected from {args.build_root.as_posix()}/analysis")
    if not rows:
        return 1
    if args.diff:
        print_diff(rows, apply_filters(load(args.diff, args.kind), args), args.limit)
    elif args.fanout is not None:
        print_fanout(rows, args.fanout, args.limit)
    elif args.group:
        print_groups(rows, args.group, args.limit)
    else:
        print_paths(rows, args.limit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
