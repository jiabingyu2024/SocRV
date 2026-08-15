#!/usr/bin/env python3
"""Fuse stable CoreMark assembly idioms into SocRV custom-0 instructions."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


INSTRUCTION = re.compile(r"^(?P<indent>\s*)(?P<op>[a-z][a-z0-9.]*)\s+(?P<args>[^#]+?)\s*(?:#.*)?$")


def parsed_instruction(line: str) -> tuple[str, list[str]] | None:
    match = INSTRUCTION.match(line.rstrip("\n"))
    if match is None:
        return None
    operation = match.group("op")
    if operation.startswith("."):
        return None
    arguments = [argument.strip() for argument in match.group("args").split(",")]
    return operation, arguments


def fuse_bfmul16(lines: list[str]) -> int:
    instruction_lines = [index for index, line in enumerate(lines) if parsed_instruction(line)]
    replacements = 0
    consumed: set[int] = set()

    def seek(after: int, predicate: object, distance: int = 5) -> int | None:
        for position in range(after + 1, min(after + 1 + distance, len(instruction_lines))):
            instruction = parsed_instruction(lines[instruction_lines[position]])
            if instruction is not None and predicate(instruction):  # type: ignore[operator]
                return position
        return None

    for cursor, first_index in enumerate(instruction_lines):
        if first_index in consumed:
            continue
        first = parsed_instruction(lines[first_index])
        if first is None:
            continue
        op0, a0 = first
        if op0 != "mul" or len(a0) != 3:
            continue

        p1 = seek(cursor, lambda ins: ins[0] == "srai" and len(ins[1]) == 3 and ins[1][1] == a0[0] and ins[1][2] == "2")
        if p1 is None:
            continue
        op1, a1 = parsed_instruction(lines[instruction_lines[p1]])  # type: ignore[misc]
        p2 = seek(p1, lambda ins: ins[0] == "srai" and len(ins[1]) == 3 and ins[1][1] == a0[0] and ins[1][2] == "5")
        if p2 is None:
            continue
        op2, a2 = parsed_instruction(lines[instruction_lines[p2]])  # type: ignore[misc]
        p3 = seek(p2, lambda ins: ins[0] == "andi" and len(ins[1]) == 3 and ins[1][1] == a1[0] and ins[1][2] == "15")
        if p3 is None:
            continue
        op3, a3 = parsed_instruction(lines[instruction_lines[p3]])  # type: ignore[misc]
        p4 = seek(p3, lambda ins: ins[0] == "andi" and len(ins[1]) == 3 and ins[1][1] == a2[0] and ins[1][2] == "127")
        if p4 is None:
            continue
        op4, a4 = parsed_instruction(lines[instruction_lines[p4]])  # type: ignore[misc]
        p5 = seek(p4, lambda ins: ins[0] == "mul" and len(ins[1]) == 3 and {ins[1][1], ins[1][2]} == {a3[0], a4[0]})
        if p5 is None:
            continue
        op5, a5 = parsed_instruction(lines[instruction_lines[p5]])  # type: ignore[misc]

        positions = [cursor, p1, p2, p3, p4, p5]
        indices = [instruction_lines[position] for position in positions]
        if any(index in consumed for index in indices):
            continue

        indent = re.match(r"^\s*", lines[indices[0]]).group(0)  # type: ignore[union-attr]
        lines[indices[0]] = (
            f"{indent}.insn r 0x0b, 0, 0, {a5[0]}, {a0[1]}, {a0[2]}"
            " # bfmul16\n"
        )
        for index in indices[1:]:
            lines[index] = f"{indent}# removed by bfmul16 fusion\n"
        consumed.update(indices)
        replacements += 1
    return replacements


def replace_function(lines: list[str], name: str, body: list[str]) -> bool:
    start = next((index for index, line in enumerate(lines) if line.strip() == f"{name}:"), None)
    if start is None:
        return False
    end = next(
        (
            index
            for index in range(start + 1, len(lines))
            if re.match(rf"\s*\.size\s+{re.escape(name)}\s*,", lines[index])
        ),
        None,
    )
    if end is None:
        return False
    replacement = [
        lines[start],
        "\t.cfi_startproc\n",
        *body,
        "\t.cfi_endproc\n",
    ]
    lines[start:end] = replacement
    return True


def replace_crc_helpers(lines: list[str]) -> int:
    replacements = 0
    replacements += replace_function(
        lines,
        "crcu8",
        [
            "\t.insn r 0x0b, 1, 0, a0, a1, a0 # crc8step crc=a1 data=a0\n",
            "\tret\n",
        ],
    )
    replacements += replace_function(
        lines,
        "crcu16",
        [
            "\tsrli t0, a0, 8\n",
            "\tandi a0, a0, 255\n",
            "\t.insn r 0x0b, 1, 0, a1, a1, a0 # crc8step byte 0\n",
            "\t.insn r 0x0b, 1, 0, a0, a1, t0 # crc8step byte 1\n",
            "\tret\n",
        ],
    )
    replacements += replace_function(
        lines,
        "crc16",
        [
            # crcu16 consumes only a0[15:0], so the old slli/srli truncation
            # pair was redundant once the helper is emitted explicitly.
            "\ttail crcu16\n",
        ],
    )
    replacements += replace_function(
        lines,
        "crcu32",
        [
            "\tmv t0, a0\n",
            "\tandi t1, t0, 255\n",
            "\t.insn r 0x0b, 1, 0, a1, a1, t1 # crc8step byte 0\n",
            "\tsrli t1, t0, 8\n",
            "\t.insn r 0x0b, 1, 0, a1, a1, t1 # crc8step byte 1\n",
            "\tsrli t1, t0, 16\n",
            "\t.insn r 0x0b, 1, 0, a1, a1, t1 # crc8step byte 2\n",
            "\tsrli t1, t0, 24\n",
            "\t.insn r 0x0b, 1, 0, a0, a1, t1 # crc8step byte 3\n",
            "\tret\n",
        ],
    )
    return replacements


def fuse_isdigit8(lines: list[str]) -> int:
    """Fuse unsigned ASCII digit range checks in core_state.c.

    The matcher requires a local `li reg,9` feeding the range branch.  It
    rewrites the arithmetic and branch but intentionally keeps the `li`: that
    register can remain live on another CFG edge in GCC's state machine.  A
    dead constant load is preferable to an unsafe cross-basic-block liveness
    assumption.
    """

    instruction_lines = [index for index, line in enumerate(lines) if parsed_instruction(line)]
    replacements = 0
    consumed: set[int] = set()
    for cursor, add_index in enumerate(instruction_lines):
        if add_index in consumed:
            continue
        first = parsed_instruction(lines[add_index])
        if first is None:
            continue
        op0, a0 = first
        if op0 != "addi" or len(a0) != 3 or a0[2] != "-48":
            continue
        if cursor + 1 >= len(instruction_lines):
            continue
        and_index = instruction_lines[cursor + 1]
        second = parsed_instruction(lines[and_index])
        if second is None:
            continue
        op1, a1 = second
        if (
            op1 != "andi"
            or len(a1) != 3
            or a1[1] != a0[0]
            or a1[2] not in {"255", "0xff"}
        ):
            continue

        result = a1[0]
        limit_register: str | None = None
        branch_position: int | None = None
        branch_taken_for_digit = False
        for position in range(cursor + 2, min(cursor + 14, len(instruction_lines))):
            instruction = parsed_instruction(lines[instruction_lines[position]])
            if instruction is None:
                continue
            operation, arguments = instruction
            if operation == "li" and len(arguments) == 2 and arguments[1] == "9":
                limit_register = arguments[0]
                continue
            if limit_register is None or len(arguments) != 3:
                continue
            if operation == "bgtu" and arguments[:2] == [result, limit_register]:
                branch_position = position
                branch_taken_for_digit = False
                break
            if operation == "bltu" and arguments[:2] == [limit_register, result]:
                branch_position = position
                branch_taken_for_digit = False
                break
            if operation == "bleu" and arguments[:2] == [result, limit_register]:
                branch_position = position
                branch_taken_for_digit = True
                break
            if operation == "bgeu" and arguments[:2] == [limit_register, result]:
                branch_position = position
                branch_taken_for_digit = True
                break
        if branch_position is None:
            continue

        branch_index = instruction_lines[branch_position]
        branch = parsed_instruction(lines[branch_index])
        assert branch is not None
        target = branch[1][2]
        indent = re.match(r"^\s*", lines[add_index]).group(0)  # type: ignore[union-attr]
        lines[add_index] = (
            f"{indent}.insn r 0x0b, 2, 0, {result}, {a0[1]}, zero"
            " # isdigit8\n"
        )
        lines[and_index] = f"{indent}# removed by isdigit8 fusion\n"
        branch_op = "bnez" if branch_taken_for_digit else "beqz"
        lines[branch_index] = f"{indent}{branch_op} {result}, {target} # isdigit8 branch\n"
        consumed.update({add_index, and_index, branch_index})
        replacements += 1
    return replacements


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind", choices=("matrix", "crc", "state"), required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    lines = args.input.read_text(encoding="utf-8").splitlines(keepends=True)
    if args.kind == "matrix":
        count = fuse_bfmul16(lines)
    elif args.kind == "crc":
        count = replace_crc_helpers(lines)
    else:
        count = fuse_isdigit8(lines)
    if count == 0:
        parser.error(f"no {args.kind} fusion candidate found in {args.input}")
    args.output.write_text("".join(lines), encoding="utf-8")
    if args.kind != "matrix":
        print(f"{args.kind}: fused {count} candidate(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
