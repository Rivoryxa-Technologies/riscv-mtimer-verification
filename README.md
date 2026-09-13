# riscv-mtimer-verification

One verification problem, taken from a bug report to a fix you can check yourself.

The design is a RISC-V machine timer: the `mtime` and `mtimecmp` registers, a clock
prescaler, and a debug halt input. A bug is seeded on purpose. This repository shows:

1. the failure, reproduced in simulation, and how the old regression missed it
2. a formal counterexample trace
3. the root cause
4. the fix, proven with an unbounded formal proof
5. the coverage holes left by the old regression, and what happened to each one
6. a checked waiver for the one hole that cannot matter in the real system
7. proof that every property is actually exercised and can fail
8. one script that reruns all of it and checks every expected result

Everything runs on open source tools. Every claim in this README is checked by
`scripts/reproduce.sh`, and the logs from our run are in `evidence/`.

> This is a small block with a deliberately seeded bug. It demonstrates the method.
> It is not a result on a production RISC-V core. See [What this does not show](#what-this-does-not-show).

## The bug report

> The timer interrupt is sometimes missed. If the core has interrupts disabled when
> mtime reaches mtimecmp, the interrupt is gone by the time they are enabled again.

The RISC-V privileged specification says the machine timer interrupt (MTIP) is
pending while `mtime >= mtimecmp`. It must stay pending until software writes a new
`mtimecmp`, not disappear on the next tick.

## Run everything

```bash
pip install -r requirements.txt     # cocotb 2.1.0 (click is only needed for SymbiYosys from source)
scripts/reproduce.sh                # or: make reproduce
```

Needs on your PATH: `sby`, `yosys`, `yosys-smtbmc`, `z3`, `verilator`,
`verilator_coverage`, `python3`, and `make`. The
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases) provides the
formal tools and Verilator. The script ends with `ALL CHECKS PASSED` and exits with
status 0, or names each check that did not pass and exits with status 1.

Expected result, 23 checks:

```
PASS  old regression passes on the seeded bug (3 of 3)
PASS  bug report test fails on the seeded bug: MTIP drops after compare
PASS  bug report test fails on the seeded bug: mtimecmp written in the past
PASS  simulation totals on the seeded bug: 5 tests, 3 pass, 2 fail
PASS  formal finds a counterexample to a_mtip_stays_pending on the seeded bug
PASS  formal run on the seeded bug used z3
PASS  coverage before: hole A is uncovered
PASS  coverage before: hole B is uncovered
PASS  coverage before: hole C is uncovered
PASS  coverage before: hole D is uncovered
PASS  fixed RTL: 7 tests, 7 pass, 0 fail
PASS  coverage after: hole A is covered by a directed test
PASS  coverage after: hole D is covered by a directed test
PASS  coverage after: only holes B and C remain
PASS  fixed RTL: a_mtip_stays_pending and a_state_legal proven by k induction
PASS  cover reached: c_mtip_stays_trigger
PASS  cover reached: c_mtip_after_compare
PASS  cover reached: c_resume
PASS  cover reached: c_div_zero_running
PASS  a_mtip_stays_pending fails on the seeded bug
PASS  a_state_legal fails on a mutant that enters state 2'b11
PASS  waiver: no allowed clock setting gives div = 0 or a value above 65535 (unsat)
PASS  waiver check is not vacuous: widened limits give a bad setting (sat)
23 checks passed
ALL CHECKS PASSED
```

## Step by step

### 1. The failure, before the fix

`rtl/mtimer.sv` built with `+define+SEEDED_BUG`.

| Test | Result | Log |
|---|---|---|
| Old regression: counts, prescaler, MTIP rises at compare | 3 pass | `evidence/01_sim_seeded_bug.log` |
| Bug report: MTIP stays pending after compare | fail | same |
| Bug report: mtimecmp written in the past | fail | same |

The old regression only checked that MTIP rises at some point. With the bug, MTIP
does rise, for one cycle, so the old tests passed. The two new tests check what the
specification requires, and both fail.

### 2. The counterexample

Property, in `formal/mtimer_props.svh`:

```systemverilog
// Once pending, MTIP stays pending until software writes mtime or mtimecmp.
// The only exception is mtime wrapping from all ones to zero.
a_mtip_stays_pending: assert (!($past(mtip) && !$past(we) && $past(mtime) != '1) || mtip);
```

`sby -f formal/mtimer.sby bug_bmc` fails it. The trace is in
`evidence/02_counterexample.vcd`. `scripts/trace_summary.py` prints it as a table
(`evidence/02_counterexample_table.txt`). Read it like this: software writes
`mtimecmp = 1`; `mtime` reaches 1 and MTIP is set; on the next count `mtime` becomes 2
and MTIP drops, although nothing wrote `mtime` or `mtimecmp`. SymbiYosys reports the
failure one step later, because assertions in a clocked block are checked on the
following step. The solver is free to pick values for inputs that do not matter, so
your trace can show different values in those columns.

### 3. Root cause

See [docs/root-cause.md](docs/root-cause.md). In short: MTIP was computed as
`mtime == mtimecmp`, which is true only on the single count where the two are equal.
The specification requires `mtime >= mtimecmp`.

### 4. The fix, and the proof

The fixed line in `rtl/mtimer.sv` is `assign mtip = (mtime >= mtimecmp);`.

- Simulation: all 7 tests pass (`evidence/04_sim_fixed_all_tests.log`).
- Formal: `sby -f formal/mtimer.sby prove` proves `a_mtip_stays_pending` and
  `a_state_legal` by k induction, which covers every reachable state
  (`evidence/05_formal_prove_fixed.log`).

### 5. Coverage holes and what happened to each

Verilator line coverage of the old regression on the fixed RTL left four holes
(`evidence/03_uncovered_lines_before.txt`). Each is marked in `rtl/mtimer.sv`.

| Hole | Code | Outcome | Evidence |
|---|---|---|---|
| A | release after a debug halt, resume cycle | **Reached** by a new directed test, `test_halt_stops_and_resumes_counting` | `evidence/04_uncovered_lines_after.txt` no longer lists it |
| B | `default` branch of the state machine, encoding `2'b11` | **Proven unreachable**: `a_state_legal` proven by k induction | `evidence/05_formal_prove_fixed.log` |
| C | `div == 0`, no prescaling | **Waived with a check**: reachable in the RTL, never written by the firmware driver | `evidence/06_formal_cover.log`, `evidence/08_waiver.txt` |
| D | read of the unused address 3 | **Reached** by a new directed test, `test_read_unused_address` | `evidence/04_uncovered_lines_after.txt` no longer lists it |

Details in [docs/coverage-dispositions.md](docs/coverage-dispositions.md).

### 6. The checked waiver

Hole C cannot be proven unreachable, because it is reachable: the cover
`c_div_zero_running` shows software can write `div = 0`. The waiver rests on the
firmware instead. `sw/mtimer_driver.h` is the only code that writes `div`, and it
writes `clk_hz / tick_hz` using the limits in `sw/board_limits.h`.
`waiver/div_never_zero.smt2` asks z3 for any allowed setting that gives 0 or a value
too large for the 16 bit register. z3 answers `unsat`: there is none.
`waiver/check_is_not_vacuous.smt2` widens the limits and z3 answers `sat` with a bad
setting, which shows the check can fail.

### 7. Why the results are valid

See [docs/why-the-results-are-valid.md](docs/why-the-results-are-valid.md). Summary:

- **The properties are exercised.** Four cover statements are reached, including the
  exact trigger of `a_mtip_stays_pending`.
- **The properties can fail.** `a_mtip_stays_pending` fails on the seeded bug.
  `a_state_legal` fails on a mutant that enters `2'b11`
  (`formal/check_assertions_are_live.sh`, `evidence/07_assertions_live.txt`).
- **The waiver check can fail.** Widened limits give `sat`.
- **Nothing depends on our machine.** `scripts/reproduce.sh` reruns every step from a
  fresh clone and checks every expected result.

## Layout

```
rtl/mtimer.sv                      the design; +define+SEEDED_BUG selects the bug
formal/mtimer_props.svh            properties and covers, included under ifdef FORMAL
formal/mtimer.sby                  tasks: bug_bmc, prove, cover (engine smtbmc z3)
formal/check_assertions_are_live.sh  shows each assertion can fail
tb/test_regression.py              the old regression
tb/test_bug_report.py              tests written from the bug report
tb/test_holes.py                   directed tests for holes A and D
tb/mtimer_env.py, tb/Makefile      cocotb helpers and build (Verilator, line coverage)
sw/board_limits.h, sw/mtimer_driver.h  firmware side of the waiver
waiver/*.smt2                      z3 checks for the waiver
scripts/reproduce.sh               runs everything and checks every result
scripts/trace_summary.py           prints a counterexample VCD as a table
evidence/                          logs and trace from our run
docs/                              root cause, coverage dispositions, validity
```

## Environment of our run

| Tool | Version |
|---|---|
| SymbiYosys | YosysHQ/sby git commit b1a1e98 (4 August 2026) |
| Yosys and yosys-smtbmc | 0.67+post (git sha1 b8e7da6f) |
| z3 | 4.16.0 |
| Verilator | 5.050 |
| cocotb | 2.1.0 |
| Python | 3.14.2 |
| OS | macOS (Darwin 25.6.0) |

`evidence/00_environment.txt` is written by the script on every run. Other versions of
these tools should give the same verdicts. Times, paths, and the solver's choice of
values for inputs that do not matter will differ.

## What this does not show

- The design is small and the bug was seeded on purpose. It shows the method, not a
  result on a production RISC-V core.
- The waiver is only as good as its assumptions: that `sw/mtimer_driver.h` is the only
  code that writes `div`, and that every supported board stays inside
  `sw/board_limits.h`. Firmware that bypasses the driver voids it.
- Line coverage shows which lines ran, not that their behaviour was checked. The
  checking comes from the tests and the properties.
- `a_mtip_stays_pending` excludes the wrap of `mtime` from all ones to zero, which takes
  2^64 counts. Behaviour at the wrap is not checked here.
- Properties are pulled in with `` `include `` under `ifdef FORMAL` because open source
  Yosys ignores SystemVerilog `bind` statements. With a tool that supports `bind`, the
  same properties can be bound from a separate file instead.

## License

MIT. See `LICENSE`.
