from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import subprocess
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from pathlib import Path
from statistics import mean
from typing import Iterable

from lib.manifest import read_json, write_json_atomic
from lib.repo import repo_path


NUMBER = r"[-+]?\d+(?:\.\d+)?"
TIMING_SUMMARY_RE = re.compile(
    rf"WNS\(ns\).*?\n\s*-+.*?\n\s*({NUMBER})\s+({NUMBER})\s+(\d+)\s+(\d+)\s+"
    rf"({NUMBER})\s+({NUMBER})\s+(\d+)\s+(\d+)",
    re.DOTALL,
)
SLACK_RE = re.compile(rf"^Slack \(([^)]+)\)\s*:\s*({NUMBER})ns", re.MULTILINE)
ARRAY_INDEX_RE = re.compile(r"\[[^\]]+\]")
GENERATED_ID_RE = re.compile(r"(?:__parameterized\w*|_reg|_replica|_dup)?_?\d+$", re.IGNORECASE)


@dataclass
class TimingPath:
    kind: str
    status: str
    slack_ns: float
    source: str
    destination: str
    path_group: str = ""
    path_type: str = ""
    launch_clock: str = ""
    capture_clock: str = ""
    requirement_ns: float | None = None
    datapath_delay_ns: float | None = None
    logic_delay_ns: float | None = None
    route_delay_ns: float | None = None
    logic_percent: float | None = None
    route_percent: float | None = None
    logic_levels: int | None = None
    clock_skew_ns: float | None = None
    clock_uncertainty_ns: float | None = None
    cell_counts: dict[str, int] = field(default_factory=dict)
    max_fanout: int | None = None
    max_fanout_net: str = ""
    category: str = ""
    source_scope: str = ""
    destination_scope: str = ""
    cluster: str = ""


def _field(block: str, name: str) -> str:
    match = re.search(rf"^\s*{re.escape(name)}:\s*(.+?)\s*$", block, re.MULTILINE)
    return match.group(1).strip() if match else ""


def _float_field(block: str, name: str) -> float | None:
    match = re.search(rf"^\s*{re.escape(name)}:\s*({NUMBER})ns", block, re.MULTILINE)
    return float(match.group(1)) if match else None


def _clock_after(block: str, label: str) -> str:
    match = re.search(
        rf"^\s*{re.escape(label)}:\s*.*?\n\s*\([^\n]*?clocked by\s+(\S+)",
        block,
        re.MULTILINE,
    )
    return match.group(1) if match else ""


def _canonical_scope(path: str) -> str:
    if not path:
        return "unknown"
    value = ARRAY_INDEX_RE.sub("[*]", path.strip())
    value = re.sub(r"/(?:C|D|Q|CE|R|S)$", "", value)
    parts = [part for part in value.split("/") if part]
    if not parts:
        return "unknown"

    start = 0
    for marker in ("veer", "core", "u_soc"):
        if marker in parts:
            start = parts.index(marker) + 1
            break
    selected: list[str] = []
    for part in parts[start:]:
        clean = GENERATED_ID_RE.sub("", part)
        if not clean or clean in {"genblock", "dffs"}:
            continue
        selected.append(clean)
        if len(selected) >= 3:
            break
    return "/".join(selected or parts[-3:])


def _datapath_region(block: str) -> str:
    """Return only the data path table of a timing block.

    A setup/hold block contains the source clock path, the data path and the
    destination clock path, each delimited by a dashed separator. Scanning the
    whole block makes the clock buffer net (fanout = every core register) win
    every max-fanout comparison, which hides the real high-fanout data signals.
    """
    lines = block.splitlines()
    separators = [i for i, line in enumerate(lines) if "---" in line and set(line.strip()) <= {"-", " "}]
    if len(separators) >= 3:
        return "\n".join(lines[separators[1] + 1 : separators[2]])
    if len(separators) >= 2:
        return "\n".join(lines[separators[1] + 1 :])
    return block


def _category(source: str, destination: str) -> str:
    text = f"{source} {destination}".lower()
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
        if any(needle in text for needle in needles):
            return name
    return "OTHER"


def parse_timing_paths(path: Path, kind: str) -> list[TimingPath]:
    text = path.read_text(encoding="utf-8", errors="replace")
    starts = [match.start() for match in SLACK_RE.finditer(text)]
    if not starts:
        return []
    starts.append(len(text))
    records: list[TimingPath] = []
    for index in range(len(starts) - 1):
        block = text[starts[index] : starts[index + 1]]
        slack_match = SLACK_RE.search(block)
        if not slack_match:
            continue
        source = _field(block, "Source").split("  (")[0].strip()
        destination = _field(block, "Destination").split("  (")[0].strip()
        data_match = re.search(
            rf"Data Path Delay:\s*({NUMBER})ns\s*\(logic\s*({NUMBER})ns\s*\(({NUMBER})%\)\s*"
            rf"route\s*({NUMBER})ns\s*\(({NUMBER})%\)\)",
            block,
        )
        levels_match = re.search(r"Logic Levels:\s*(\d+)\s*\(([^)]*)\)", block)
        cell_counts: dict[str, int] = {}
        if levels_match:
            for cell, count in re.findall(r"([A-Za-z0-9_]+)=(\d+)", levels_match.group(2)):
                cell_counts[cell] = int(count)

        fanout = None
        fanout_net = ""
        for match in re.finditer(r"net \(fo=(\d+)[^)]*\).*?\s(\S+)\s*$", _datapath_region(block), re.MULTILINE):
            current = int(match.group(1))
            if fanout is None or current > fanout:
                fanout = current
                fanout_net = match.group(2)

        source_scope = _canonical_scope(source)
        destination_scope = _canonical_scope(destination)
        category = _category(source, destination)
        launch_clock = _clock_after(block, "Source")
        capture_clock = _clock_after(block, "Destination")
        path_group = _field(block, "Path Group")
        clock_pair = f"{launch_clock or path_group}->{capture_clock or path_group}"
        cluster = f"{category} | {source_scope} -> {destination_scope} | {clock_pair}"
        records.append(
            TimingPath(
                kind=kind,
                status=slack_match.group(1).strip(),
                slack_ns=float(slack_match.group(2)),
                source=source,
                destination=destination,
                path_group=path_group,
                path_type=_field(block, "Path Type"),
                launch_clock=launch_clock,
                capture_clock=capture_clock,
                requirement_ns=_float_field(block, "Requirement"),
                datapath_delay_ns=float(data_match.group(1)) if data_match else None,
                logic_delay_ns=float(data_match.group(2)) if data_match else None,
                logic_percent=float(data_match.group(3)) if data_match else None,
                route_delay_ns=float(data_match.group(4)) if data_match else None,
                route_percent=float(data_match.group(5)) if data_match else None,
                logic_levels=int(levels_match.group(1)) if levels_match else None,
                clock_skew_ns=_float_field(block, "Clock Path Skew"),
                clock_uncertainty_ns=_float_field(block, "Clock Uncertainty"),
                cell_counts=cell_counts,
                max_fanout=fanout,
                max_fanout_net=fanout_net,
                category=category,
                source_scope=source_scope,
                destination_scope=destination_scope,
                cluster=cluster,
            )
        )
    return records


def parse_timing_summary(path: Path | None) -> dict[str, object]:
    if not path or not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8", errors="replace")
    match = TIMING_SUMMARY_RE.search(text)
    if not match:
        return {"path": path.as_posix(), "parsed": False}
    return {
        "path": path.as_posix(),
        "parsed": True,
        "wns_ns": float(match.group(1)),
        "tns_ns": float(match.group(2)),
        "setup_failing_endpoints": int(match.group(3)),
        "setup_total_endpoints": int(match.group(4)),
        "whs_ns": float(match.group(5)),
        "ths_ns": float(match.group(6)),
        "hold_failing_endpoints": int(match.group(7)),
        "hold_total_endpoints": int(match.group(8)),
        "constraints_met": "All user specified timing constraints are met." in text,
        "unconstrained_register_pins": _first_int(text, r"There are\s+(\d+)\s+register/latch pins with no clock"),
    }


def _first_int(text: str, pattern: str) -> int | None:
    match = re.search(pattern, text)
    return int(match.group(1)) if match else None


def parse_utilization(path: Path | None) -> dict[str, object]:
    if not path or not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8", errors="replace")
    match = re.search(
        r"^\|\s*fpga_top\s*\|\s*\(top\)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|",
        text,
        re.MULTILINE,
    )
    if not match:
        return {"path": path.as_posix(), "parsed": False}
    return {
        "path": path.as_posix(),
        "parsed": True,
        "total_luts": int(match.group(1)),
        "logic_luts": int(match.group(2)),
        "lutram": int(match.group(3)),
        "srl": int(match.group(4)),
        "ff": int(match.group(5)),
        "ramb36": int(match.group(6)),
        "ramb18": int(match.group(7)),
        "dsp": int(match.group(8)),
    }


def parse_clock_interaction(path: Path | None) -> list[dict[str, object]]:
    if not path or not path.is_file():
        return []
    rows: list[dict[str, object]] = []
    pattern = re.compile(
        rf"^\s*(\S+)\s+(\S+)\s+(rise|fall)\s+-\s+(rise|fall)\s+({NUMBER})\s+({NUMBER})\s+(\d+)\s+(\d+)\s+({NUMBER})\s+(\S+)\s+(\S+)\s*$"
    )
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = pattern.match(line)
        if not match:
            continue
        rows.append(
            {
                "from_clock": match.group(1),
                "to_clock": match.group(2),
                "edges": f"{match.group(3)}-{match.group(4)}",
                "wns_ns": float(match.group(5)),
                "tns_ns": float(match.group(6)),
                "failing_endpoints": int(match.group(7)),
                "total_endpoints": int(match.group(8)),
                "requirement_ns": float(match.group(9)),
                "classification": match.group(10),
                "constraints": match.group(11),
            }
        )
    return rows


def parse_cdc(path: Path | None) -> dict[str, object]:
    if not path or not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8", errors="replace")
    rows = []
    for line in text.splitlines():
        match = re.match(
            r"^\s*(Info|Warning|Critical Warning|Error)\s+(\S+)\s+(\S+)\s+(.+?)\s+(None|\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$",
            line,
        )
        if match:
            rows.append(
                {
                    "severity": match.group(1),
                    "source_clock": match.group(2),
                    "destination_clock": match.group(3),
                    "cdc_type": match.group(4).strip(),
                    "exceptions": match.group(5),
                    "endpoints": int(match.group(6)),
                    "safe": int(match.group(7)),
                    "unsafe": int(match.group(8)),
                    "unknown": int(match.group(9)),
                    "no_async_reg": int(match.group(10)),
                }
            )
    return {
        "path": path.as_posix(),
        "rows": rows,
        "unsafe": sum(int(row["unsafe"]) for row in rows),
        "unknown": sum(int(row["unknown"]) for row in rows),
        "no_async_reg": sum(int(row["no_async_reg"]) for row in rows),
    }


def aggregate_clusters(paths: Iterable[TimingPath]) -> list[dict[str, object]]:
    groups: dict[str, list[TimingPath]] = defaultdict(list)
    for path in paths:
        groups[path.cluster].append(path)
    clusters: list[dict[str, object]] = []
    for name, records in groups.items():
        cells: Counter[str] = Counter()
        fanout_nets: Counter[str] = Counter()
        for record in records:
            cells.update(record.cell_counts)
            if record.max_fanout_net:
                fanout_nets[record.max_fanout_net] = max(
                    fanout_nets[record.max_fanout_net], record.max_fanout or 0
                )
        worst_records = sorted(records, key=lambda item: item.slack_ns)[:3]
        clusters.append(
            {
                "name": name,
                "category": records[0].category,
                "count": len(records),
                "violating_count": sum(record.slack_ns < 0 for record in records),
                "worst_slack_ns": min(record.slack_ns for record in records),
                "mean_slack_ns": mean(record.slack_ns for record in records),
                "best_slack_ns": max(record.slack_ns for record in records),
                "mean_logic_levels": _mean_optional(record.logic_levels for record in records),
                "max_logic_levels": _max_optional(record.logic_levels for record in records),
                "mean_logic_percent": _mean_optional(record.logic_percent for record in records),
                "mean_route_percent": _mean_optional(record.route_percent for record in records),
                "dominant_cells": cells.most_common(6),
                "high_fanout_nets": fanout_nets.most_common(5),
                "representative_paths": [
                    {
                        "slack_ns": record.slack_ns,
                        "source": record.source,
                        "destination": record.destination,
                        "logic_levels": record.logic_levels,
                        "logic_percent": record.logic_percent,
                        "route_percent": record.route_percent,
                    }
                    for record in worst_records
                ],
            }
        )
    return sorted(clusters, key=lambda item: (float(item["worst_slack_ns"]), -int(item["count"])))


def _mean_optional(values: Iterable[float | int | None]) -> float | None:
    present = [float(value) for value in values if value is not None]
    return mean(present) if present else None


def _max_optional(values: Iterable[float | int | None]) -> float | None:
    present = [float(value) for value in values if value is not None]
    return max(present) if present else None


def _find_report(report_dir: Path, names: Iterable[str]) -> Path | None:
    for name in names:
        path = report_dir / name
        if path.is_file():
            return path
    return None


def resolve_reports(build_root: Path, stage: str) -> dict[str, Path | None]:
    report_dir = build_root / "project" / "reports"
    analysis_raw = build_root / "analysis" / "raw"
    prefix = "post_impl" if stage == "impl" else "post_synth"
    setup = _find_report(
        report_dir,
        (f"{prefix}_setup_violations.rpt", f"{prefix}_setup_paths.rpt"),
    )
    hold = _find_report(
        report_dir,
        (f"{prefix}_hold_violations.rpt", f"{prefix}_hold_paths.rpt"),
    )
    if analysis_raw.is_dir():
        setup = _find_report(analysis_raw, ("all_setup_violations.rpt",)) or setup
        hold = _find_report(analysis_raw, ("all_hold_violations.rpt",)) or hold
    if stage == "impl" and setup is None:
        setup = _find_report(report_dir, ("post_impl_timing_paths.rpt",))
    return {
        "report_dir": report_dir,
        "setup": setup,
        "hold": hold,
        "summary": _find_report(report_dir, (f"{prefix}_timing_summary.rpt",)),
        "utilization": _find_report(report_dir, (f"{prefix}_utilization.rpt",)),
        "clock_interaction": _find_report(report_dir, (f"{prefix}_clock_interaction.rpt",)),
        "cdc": _find_report(report_dir, (f"{prefix}_cdc.rpt",)),
    }


def find_vivado() -> Path:
    override = os.environ.get("VIVADO")
    candidates = [
        Path(override) if override else None,
        Path(r"D:\AppMajor\xilinx\Vivado\2023.2\bin\vivado.bat"),
    ]
    for candidate in candidates:
        if candidate and candidate.is_file():
            return candidate
    raise ValueError("Vivado batch launcher was not found; set VIVADO")


def export_all_violations(build_root: Path, stage: str) -> None:
    project = build_root / "project" / "socrv.xpr"
    if not project.is_file():
        raise ValueError(f"Vivado project is missing: {project}")
    output = build_root / "analysis" / "raw"
    output.mkdir(parents=True, exist_ok=True)
    command = [
        str(find_vivado()),
        "-mode",
        "batch",
        "-source",
        str(repo_path("scripts", "report_all_violations.tcl")),
        "-tclargs",
        str(project),
        str(output),
        stage,
    ]
    completed = subprocess.run(command, cwd=build_root, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"Vivado report export failed with exit code {completed.returncode}")


def write_paths_csv(path: Path, records: list[TimingPath]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "kind", "status", "slack_ns", "category", "cluster", "source", "destination",
        "source_scope", "destination_scope", "launch_clock", "capture_clock", "path_group",
        "requirement_ns", "datapath_delay_ns", "logic_delay_ns", "route_delay_ns",
        "logic_percent", "route_percent", "logic_levels", "clock_skew_ns",
        "clock_uncertainty_ns", "max_fanout", "max_fanout_net", "cell_counts",
    ]
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for record in records:
            row = asdict(record)
            row["cell_counts"] = json.dumps(record.cell_counts, sort_keys=True)
            writer.writerow({key: row.get(key) for key in fields})


def compare_documents(current: dict[str, object], baseline: dict[str, object]) -> dict[str, object]:
    result: dict[str, object] = {"baseline": baseline.get("build_root", "")}
    current_timing = current.get("timing", {})
    baseline_timing = baseline.get("timing", {})
    timing_delta = {}
    for key in ("wns_ns", "tns_ns", "whs_ns", "ths_ns"):
        before = baseline_timing.get(key) if isinstance(baseline_timing, dict) else None
        after = current_timing.get(key) if isinstance(current_timing, dict) else None
        if isinstance(before, (int, float)) and isinstance(after, (int, float)):
            timing_delta[key] = after - before
    result["timing_delta"] = timing_delta

    current_clusters = {item["name"]: item for item in current.get("setup_clusters", [])}
    baseline_clusters = {item["name"]: item for item in baseline.get("setup_clusters", [])}
    changes = []
    for name in sorted(set(current_clusters) | set(baseline_clusters)):
        now = current_clusters.get(name)
        old = baseline_clusters.get(name)
        changes.append(
            {
                "name": name,
                "count_before": old.get("count", 0) if old else 0,
                "count_after": now.get("count", 0) if now else 0,
                "worst_slack_before_ns": old.get("worst_slack_ns") if old else None,
                "worst_slack_after_ns": now.get("worst_slack_ns") if now else None,
                "worst_slack_delta_ns": (
                    float(now["worst_slack_ns"]) - float(old["worst_slack_ns"])
                    if now and old
                    else None
                ),
            }
        )
    result["cluster_changes"] = sorted(
        changes,
        key=lambda item: (
            item["worst_slack_after_ns"] is None,
            item["worst_slack_after_ns"] if item["worst_slack_after_ns"] is not None else math.inf,
        ),
    )
    return result


def _fmt(value: object, digits: int = 3) -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def render_markdown(document: dict[str, object], top_clusters: int) -> str:
    timing = document.get("timing", {})
    utilization = document.get("utilization", {})
    cdc = document.get("cdc", {})
    lines = [
        "# Vivado AI timing summary",
        "",
        f"- Build: `{document['build_root']}`",
        f"- Stage: `{document['stage']}`",
        f"- Setup report: `{document['reports'].get('setup') or '-'}`",
        f"- Hold report: `{document['reports'].get('hold') or '-'}`",
        f"- Parsed setup/hold paths: **{document['setup_path_count']} / {document['hold_path_count']}**",
        "",
        "## Timing and resources",
        "",
        "| WNS | TNS | Setup failing | WHS | THS | Hold failing | LUT | FF | RAMB36 | RAMB18 | DSP |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        "| "
        + " | ".join(
            [
                _fmt(timing.get("wns_ns")), _fmt(timing.get("tns_ns")), _fmt(timing.get("setup_failing_endpoints"), 0),
                _fmt(timing.get("whs_ns")), _fmt(timing.get("ths_ns")), _fmt(timing.get("hold_failing_endpoints"), 0),
                _fmt(utilization.get("total_luts"), 0), _fmt(utilization.get("ff"), 0),
                _fmt(utilization.get("ramb36"), 0), _fmt(utilization.get("ramb18"), 0), _fmt(utilization.get("dsp"), 0),
            ]
        )
        + " |",
        "",
        f"- Timing constraints met: **{timing.get('constraints_met', '-')}**",
        f"- Unconstrained register/latch pins: **{_fmt(timing.get('unconstrained_register_pins'), 0)}**",
        f"- CDC unsafe / unknown / no ASYNC_REG: **{_fmt(cdc.get('unsafe'), 0)} / {_fmt(cdc.get('unknown'), 0)} / {_fmt(cdc.get('no_async_reg'), 0)}**",
        "",
        "## Setup path clusters",
        "",
        "| # | Cluster | Paths | Violating | Worst slack | Mean slack | Levels avg/max | Logic/route |",
        "|---:|---|---:|---:|---:|---:|---:|---:|",
    ]
    for index, cluster in enumerate(document.get("setup_clusters", [])[:top_clusters], 1):
        lines.append(
            f"| {index} | `{cluster['name']}` | {cluster['count']} | {cluster['violating_count']} | "
            f"{_fmt(cluster['worst_slack_ns'])} | {_fmt(cluster['mean_slack_ns'])} | "
            f"{_fmt(cluster['mean_logic_levels'], 1)}/{_fmt(cluster['max_logic_levels'], 0)} | "
            f"{_fmt(cluster['mean_logic_percent'], 1)}%/{_fmt(cluster['mean_route_percent'], 1)}% |"
        )
    lines.extend(["", "## Worst representative setup paths", ""])
    for cluster in document.get("setup_clusters", [])[: min(top_clusters, 12)]:
        representative = cluster.get("representative_paths", [])
        if not representative:
            continue
        item = representative[0]
        lines.extend(
            [
                f"### `{cluster['name']}`",
                "",
                f"- slack `{_fmt(item.get('slack_ns'))} ns`, logic levels `{_fmt(item.get('logic_levels'), 0)}`, logic/route `{_fmt(item.get('logic_percent'), 1)}%/{_fmt(item.get('route_percent'), 1)}%`",
                f"- source: `{item.get('source', '')}`",
                f"- destination: `{item.get('destination', '')}`",
                "",
            ]
        )
    comparison = document.get("comparison")
    if isinstance(comparison, dict):
        lines.extend(["## Baseline comparison", ""])
        delta = comparison.get("timing_delta", {})
        lines.append(
            f"- WNS delta `{_fmt(delta.get('wns_ns'))} ns`, TNS delta `{_fmt(delta.get('tns_ns'))} ns`, "
            f"WHS delta `{_fmt(delta.get('whs_ns'))} ns`, THS delta `{_fmt(delta.get('ths_ns'))} ns`."
        )
        lines.extend(
            [
                "",
                "| Cluster | Count before -> after | Worst slack before -> after | Slack delta |",
                "|---|---:|---:|---:|",
            ]
        )
        for item in comparison.get("cluster_changes", [])[:top_clusters]:
            lines.append(
                f"| `{item['name']}` | {item['count_before']} -> {item['count_after']} | "
                f"{_fmt(item['worst_slack_before_ns'])} -> {_fmt(item['worst_slack_after_ns'])} | "
                f"{_fmt(item['worst_slack_delta_ns'])} |"
            )
    lines.extend(
        [
            "",
            "## Files for the next RTL iteration",
            "",
            "Read these compact files first; only open the raw `.rpt` for a representative path that still needs cell-by-cell inspection:",
            "",
            f"- `{document['artifacts']['json']}`",
            f"- `{document['artifacts']['markdown']}`",
            f"- `{document['artifacts']['setup_csv']}`",
            f"- `{document['artifacts']['hold_csv']}`",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parse and cluster Vivado timing reports into compact AI-readable JSON/Markdown/CSV."
    )
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--stage", choices=("auto", "synth", "impl"), default="auto")
    parser.add_argument("--export-all", action="store_true", help="ask Vivado to export every violating endpoint before clustering")
    parser.add_argument("--compare", type=Path, help="previous timing_summary.json")
    parser.add_argument("--top-clusters", type=int, default=20)
    args = parser.parse_args()

    build_root = args.build_root.resolve()
    if args.stage == "auto":
        impl_summary = build_root / "project" / "reports" / "post_impl_timing_summary.rpt"
        stage = "impl" if impl_summary.is_file() else "synth"
    else:
        stage = args.stage
    try:
        if args.export_all:
            export_all_violations(build_root, stage)
        reports = resolve_reports(build_root, stage)
        setup_report = reports["setup"]
        if not isinstance(setup_report, Path) or not setup_report.is_file():
            raise ValueError(f"no {stage} setup timing-path report found below {build_root}")
        hold_report = reports["hold"]
        setup_paths = parse_timing_paths(setup_report, "setup")
        hold_paths = parse_timing_paths(hold_report, "hold") if isinstance(hold_report, Path) and hold_report.is_file() else []
        analysis_dir = build_root / "analysis"
        json_path = analysis_dir / "timing_summary.json"
        markdown_path = analysis_dir / "timing_summary.md"
        setup_csv = analysis_dir / "setup_paths.csv"
        hold_csv = analysis_dir / "hold_paths.csv"
        write_paths_csv(setup_csv, setup_paths)
        write_paths_csv(hold_csv, hold_paths)
        document: dict[str, object] = {
            "schema_version": 1,
            "kind": "vivado-timing-analysis",
            "build_root": build_root.as_posix(),
            "stage": stage,
            "reports": {
                key: value.as_posix() if isinstance(value, Path) else None
                for key, value in reports.items()
                if key != "report_dir"
            },
            "timing": parse_timing_summary(reports["summary"]),
            "utilization": parse_utilization(reports["utilization"]),
            "clock_interaction": parse_clock_interaction(reports["clock_interaction"]),
            "cdc": parse_cdc(reports["cdc"]),
            "setup_path_count": len(setup_paths),
            "hold_path_count": len(hold_paths),
            "setup_clusters": aggregate_clusters(setup_paths),
            "hold_clusters": aggregate_clusters(hold_paths),
            "artifacts": {
                "json": json_path.as_posix(),
                "markdown": markdown_path.as_posix(),
                "setup_csv": setup_csv.as_posix(),
                "hold_csv": hold_csv.as_posix(),
            },
        }
        if args.compare:
            document["comparison"] = compare_documents(document, read_json(args.compare.resolve()))
        write_json_atomic(json_path, document)
        markdown_path.write_text(render_markdown(document, args.top_clusters), encoding="utf-8", newline="\n")
    except (OSError, RuntimeError, ValueError) as error:
        parser.error(str(error))
    print(f"Vivado timing summary: {markdown_path}")
    print(f"Vivado timing JSON: {json_path}")
    print(f"Parsed setup/hold paths: {len(setup_paths)}/{len(hold_paths)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
