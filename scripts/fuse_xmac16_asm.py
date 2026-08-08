#!/usr/bin/env python3
"""Fuse generic signed-16 multiply/accumulate DAGs in GCC assembly."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

INSN = re.compile(r"^(?P<indent>\s*)(?P<op>[a-z][a-z0-9.]*)\s+(?P<args>[^#]+?)(?:\s*#.*)?$")


def operands(line: str):
    m = INSN.match(line.rstrip())
    if not m or line.lstrip().startswith("."):
        return None
    return m.group("op"), [x.strip() for x in m.group("args").split(",")], m.group("indent")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    lines = args.input.read_text(encoding="utf-8").splitlines()
    ins = [(i, operands(line)) for i, line in enumerate(lines)]
    ins = [(i, x) for i, x in ins if x is not None]
    dead: set[int] = set()
    fused_bf = fused_mac = 0

    # p=x*y; a=(p>>2)&15; b=(p>>5)&127; b=a*b; acc+=b
    for k in range(len(ins) - 6):
        # GCC may schedule one pointer update between the first multiply and
        # the extraction chain. It is independent and remains in place.
        candidates = [ins[k:k + 7]]
        if k + 8 <= len(ins):
            candidates.append([ins[k], *ins[k + 2:k + 8]])
        for chunk in candidates:
            if any(i in dead for i, _ in chunk):
                continue
            (i0,(o0,a0,ind)),(i1,(o1,a1,_)),(i2,(o2,a2,_)),(i3,(o3,a3,_)), \
            (i4,(o4,a4,_)),(i5,(o5,a5,_)),(i6,(o6,a6,_)) = chunk
            if not (o0 == "mul" and o1 == "srai" and o2 == "srai" and
                    o3 == "andi" and o4 == "andi" and o5 == "mul" and o6 == "add"):
                continue
            if not all(len(x) == 3 for x in (a0,a1,a2,a3,a4,a5,a6)):
                continue
            p,x,y = a0
            left,right = a1[0],a2[0]
            acc = a6[0]
            if not (a1[1:] == [p,"2"] and a2[1:] == [p,"5"] and
                    a3 == [left,left,"15"] and a4 == [right,right,"127"] and
                    a5 == [right,left,right] and a6 == [acc,acc,right]):
                continue
            lines[i0] = f"{ind}.insn r 0x0b, 0, 1, {acc}, {x}, {y} # bfmacc16"
            for i,_ in chunk[1:]:
                lines[i] = ""
                dead.add(i)
            fused_bf += 1
            break

    # tmp=x*y; acc=acc+tmp
    for k in range(len(ins) - 1):
        for distance in (1, 2):
            if k + distance >= len(ins):
                continue
            (i0,(o0,a0,ind)),(i1,(o1,a1,_)) = ins[k],ins[k + distance]
            if i0 in dead or i1 in dead or o0 != "mul" or o1 != "add":
                continue
            if len(a0) != 3 or len(a1) != 3:
                continue
            tmp,x,y = a0
            acc = a1[0]
            if a1 != [acc,acc,tmp]:
                continue
            # A single intervening scheduling instruction must not overwrite
            # the product or accumulator.
            if distance == 2:
                _, midargs, _ = ins[k + 1][1]
                if midargs and midargs[0] in (tmp, acc):
                    continue
            lines[i0] = f"{ind}.insn r 0x0b, 0, 0, {acc}, {x}, {y} # macc16"
            lines[i1] = ""
            dead.add(i1)
            fused_mac += 1
            break

    if fused_bf == 0 or fused_mac == 0:
        raise SystemExit(f"fusion patterns missing: bfmacc16={fused_bf}, macc16={fused_mac}")
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"xmac16 fusion: bfmacc16={fused_bf}, macc16={fused_mac}")


if __name__ == "__main__":
    main()
