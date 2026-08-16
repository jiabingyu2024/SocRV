from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RTL_ROOT = ROOT / "rtl"
RTL_SUFFIXES = {".sv", ".svh", ".v", ".vh"}
KEEP_COMMENT_MARKERS = (
    "spdx-license-identifier",
    "copyright",
    "verilator",
    "synopsys",
    "synthesis translate",
    "translate_off",
    "translate_on",
)
IDENTIFIER_RENAMES = {
    "icache_err_pkt_t": "fetch_error_pkt_t",
    "ic_hit_f2": "tcm_fetch_valid_f2",
    "ic_data_f2": "fetch_data_f2",
    "ic_fetch_val_f2": "fetch_byte_valid_f2",
    "ic_access_fault_f2": "fetch_access_fault_f2",
    "ic_crit_wd_rdy": "critical_word_ready",
    "ic_rd_parity_final_err": "fetch_parity_error",
    "ic_error_f2": "fetch_error_f2",
    "ifu_pmu_ic_miss": "ifu_pmu_fetch_miss",
    "ifu_pmu_ic_hit": "ifu_pmu_fetch_hit",
    "ifu_icache_error_index": "ifu_fetch_error_index",
    "ifu_icache_sb_error_val": "ifu_fetch_single_bit_error",
    "ifu_icache_fetch_f2": "fetch_parity_qualifier_f2",
    "ifu_icache_error_val": "ifu_fetch_parity_error_valid",
}


def keep_comment(comment: str) -> bool:
    lowered = comment.lower()
    return any(marker in lowered for marker in KEEP_COMMENT_MARKERS)


def strip_comments(source: str) -> str:
    output = []
    index = 0
    in_string = False
    escaped = False

    while index < len(source):
        char = source[index]

        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
            output.append(char)
            index += 1
            continue

        if source.startswith("//", index):
            end = source.find("\n", index)
            if end == -1:
                end = len(source)
            comment = source[index:end]
            if keep_comment(comment):
                output.append(comment)
            index = end
            continue

        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            if end == -1:
                raise ValueError("unterminated block comment")
            end += 2
            comment = source[index:end]
            if keep_comment(comment):
                output.append(comment)
            else:
                output.append(" ")
                output.extend(char for char in comment if char in "\r\n")
            index = end
            continue

        output.append(char)
        index += 1

    cleaned_lines = []
    blank_run = 0
    for line in "".join(output).splitlines(keepends=True):
        ending = ""
        body = line
        if line.endswith("\r\n"):
            body, ending = line[:-2], "\r\n"
        elif line.endswith("\n") or line.endswith("\r"):
            body, ending = line[:-1], line[-1]
        body = body.rstrip(" \t")
        if body:
            blank_run = 0
            cleaned_lines.append(body + ending)
        else:
            blank_run += 1
            if blank_run <= 2:
                cleaned_lines.append(ending)
    return "".join(cleaned_lines)


def rtl_sources() -> list[Path]:
    return [
        path
        for path in RTL_ROOT.rglob("*")
        if path.is_file()
        and path.suffix.lower() in RTL_SUFFIXES
        and "third_party" not in path.parts
    ]


def main() -> None:
    changed = 0
    for path in rtl_sources():
        source = path.read_text(encoding="utf-8")
        for old_name, new_name in IDENTIFIER_RENAMES.items():
            source = source.replace(old_name, new_name)
        cleaned = strip_comments(source)
        original = path.read_text(encoding="utf-8")
        if cleaned != original:
            path.write_text(cleaned, encoding="utf-8", newline="")
            changed += 1
    print(f"Cleaned {changed} RTL source files")


if __name__ == "__main__":
    main()
