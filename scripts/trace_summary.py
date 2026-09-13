#!/usr/bin/env python3
"""Print a counterexample VCD from SymbiYosys as a table, one row per step.

Usage: python3 scripts/trace_summary.py evidence/bug_counterexample.vcd
Only the Python standard library is used.
"""
import sys

SIGNALS = ["rst_n", "we", "addr", "wdata", "halt", "state", "mtime", "mtimecmp", "mtip"]


def parse(path):
    """Return one dict of signal values per solver step, using the smt_step counter."""
    ids, values, by_step = {}, {}, {}
    step_id = None
    with open(path) as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "$var":
                if parts[4] == "smt_step":
                    step_id = parts[3]
                elif parts[4] in SIGNALS and parts[4] not in ids.values():
                    ids[parts[3]] = parts[4]
            elif parts[0].startswith("#"):
                if "smt_step" in values:
                    by_step[values["smt_step"]] = dict(values)
            elif parts[0][0] == "b" and len(parts) == 2:
                v = int(parts[0][1:].replace("x", "0"), 2)
                if parts[1] == step_id:
                    values["smt_step"] = v
                elif parts[1] in ids:
                    values[ids[parts[1]]] = v
            elif parts[0][0] in "01" and parts[0][1:] in ids:
                values[ids[parts[0][1:]]] = int(parts[0][0])
    if "smt_step" in values:
        by_step[values["smt_step"]] = dict(values)
    return [by_step[k] for k in sorted(by_step)]


def main():
    rows = parse(sys.argv[1])
    print("step  " + "  ".join(f"{s:>9}" for s in SIGNALS))
    for r in rows:
        print(f"{r['smt_step']:>4}  " + "  ".join(f"{r.get(s, 0):>9}" for s in SIGNALS))


if __name__ == "__main__":
    main()
