#!/usr/bin/env python3
"""Read a Yosys `stat -json -liberty` file and tell you whether you succeeded.

    python3 src/check_stat.py results/blinker.json                # just report
    python3 src/check_stat.py results/blinker.json --expect blinker  # report + verdict
    python3 src/check_stat.py --table results/*.json              # side-by-side

Nobody is grading this lab. This script is the grader. It reads the same four
keys the receipt printed -- num_cells, area, sequential_area, num_cells_by_type
-- and says PASS or FAIL against numbers measured on
hpretl/iic-osic-tools:2026.08 (Yosys 0.68, sky130A).

Exit status 0 = pass, 1 = fail. That makes it usable from a Makefile.
"""

import argparse
import json
import os
import sys

# Reference numbers, all measured on the pinned image. Yours should match to
# the digit; the tolerances exist so a future Yosys patch release nudging one
# cell does not tell you that you failed.
EXPECTED = {
    #  name          cells  flops    area     seq_area
    "blinker":      (   27,     8,  316.55,   201.44),
    "blinker_nofsm":(   27,     6,  264.00,   150.14),
    "explicit":     (   26,     6,  265.25,   150.14),
    "fast":         (   46,     8,  380.36,   201.44),
    "fulladder":    (    2,     0,   33.78,     0.00),
    "ripple4":      (   12,     0,  110.11,     0.00),
    "ripple4_hier": (    8,     0,  135.13,     0.00),
}

CELL_TOL = 0.25   # +/- 25 % on cell count
AREA_TOL = 0.10   # +/- 10 % on area


def load(path):
    """Pull the four numbers that matter out of a stat -json file."""
    with open(path) as f:
        d = json.load(f)["design"]        # "design" sums the whole design,
                                          # so you never have to guess the
                                          # module name (it is "\\blinker",
                                          # with a literal backslash).
    by_type = d["num_cells_by_type"]
    flops = sum(n for t, n in by_type.items() if "__df" in t or "__edf" in t)
    unmapped = {t: n for t, n in by_type.items()
                if t.startswith("$") and t != "$scopeinfo"}
    return {
        "cells": d["num_cells"],
        "flops": flops,
        "area": d["area"],
        "seq": d["sequential_area"],
        "unmapped": unmapped,
    }


def report(path, s):
    pct = 100 * s["seq"] / s["area"] if s["area"] else 0.0
    print(f"{os.path.basename(path)}")
    print(f"  cells      : {s['cells']}")
    print(f"  flip-flops : {s['flops']}")
    print(f"  area       : {s['area']:.2f} um^2")
    print(f"  sequential : {s['seq']:.2f} um^2 ({pct:.1f}%)")


def verdict(s, name):
    """Return a list of complaints. Empty list means pass."""
    bad = []

    if s["unmapped"]:
        names = ", ".join(sorted(s["unmapped"]))
        bad.append(f"unmapped cells in the netlist: {names}\n"
                   f"      A type starting with '$' has no liberty entry, so it "
                   f"contributed 0 um^2.\n"
                   f"      Your area is too small by however much those cells "
                   f"were worth. Did you\n"
                   f"      remember dfflibmap?")

    if name not in EXPECTED:
        known = ", ".join(sorted(EXPECTED))
        bad.append(f"no reference numbers for '{name}'. Known: {known}")
        return bad

    cells, flops, area, seq = EXPECTED[name]

    if abs(s["cells"] - cells) > CELL_TOL * cells:
        bad.append(f"cell count {s['cells']}, expected about {cells}")
    if s["flops"] != flops:
        bad.append(f"flip-flop count {s['flops']}, expected exactly {flops}")
    if area and abs(s["area"] - area) > AREA_TOL * area:
        bad.append(f"area {s['area']:.2f} um^2, expected about {area} um^2")
    if seq and abs(s["seq"] - seq) > AREA_TOL * seq:
        bad.append(f"sequential area {s['seq']:.2f} um^2, expected about {seq}")

    return bad


def table(paths):
    print(f"{'file':<30}{'cells':>7}{'flops':>7}{'area (um^2)':>14}{'seq %':>8}")
    print("-" * 66)
    for p in paths:
        s = load(p)
        pct = 100 * s["seq"] / s["area"] if s["area"] else 0.0
        flag = "  <- unmapped!" if s["unmapped"] else ""
        print(f"{os.path.basename(p):<30}{s['cells']:>7}{s['flops']:>7}"
              f"{s['area']:>14.2f}{pct:>7.1f}%{flag}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("json", nargs="+", help="stat -json -liberty output file(s)")
    ap.add_argument("--expect", metavar="NAME",
                    help="check against reference numbers: "
                         + ", ".join(sorted(EXPECTED)))
    ap.add_argument("--table", action="store_true",
                    help="one line per file, no verdict")
    args = ap.parse_args()

    if args.table:
        table(args.json)
        return 0

    failed = False
    for path in args.json:
        s = load(path)
        report(path, s)
        if args.expect:
            bad = verdict(s, args.expect)
            if bad:
                failed = True
                print("  FAIL")
                for b in bad:
                    print(f"    - {b}")
            else:
                print("  PASS  (matches the reference run)")
        print()
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
