# Coverage dispositions

Coverage: Verilator line coverage (`--coverage-line`) of `tb/test_regression.py` on the
fixed RTL, annotated with `verilator_coverage --annotate`. Uncovered lines are listed in
`evidence/03_uncovered_lines_before.txt`. Each hole is marked with a comment in
`rtl/mtimer.sv`.

Every hole ends in one of three outcomes: reached by a test, proven unreachable, or
waived with a check.

## Hole A: release after a debug halt

- Code: `S_HALTED` and `S_RESUME` branches of the state machine.
- Reachable: yes. The old regression never raised `halt`.
- Outcome: **reached** by `test_halt_stops_and_resumes_counting` in `tb/test_holes.py`.
  The test also checks the behaviour: `mtime` holds while halted and counts again after
  release.
- Evidence: the lines are absent from `evidence/04_uncovered_lines_after.txt`. The cover
  `c_resume` is also reached in formal.

## Hole B: unused state encoding 2'b11

- Code: the `default` branch of the state machine.
- Reachable: no. No transition assigns `2'b11`.
- Outcome: **proven unreachable** by `a_state_legal: assert (state != 2'b11);`, proven
  by k induction for every reachable state.
- Evidence: `evidence/05_formal_prove_fixed.log`. The assertion is live: it fails on a
  mutant whose resume cycle enters `2'b11` (`evidence/07_assertions_live.txt`).
- Why the line stays in the RTL: it returns the state machine to a known state if the
  register is ever corrupted, which is common practice. It stays uncovered by design.

## Hole C: div = 0

- Code: the `div == '0` branch of the prescaler.
- Reachable: yes, in the RTL. The cover `c_div_zero_running` is reached
  (`evidence/06_formal_cover.log`), so this hole cannot be proven unreachable.
- Outcome: **waived with a check.** In the real system only `sw/mtimer_driver.h` writes
  `div`, and it writes `BOARD_CLK_HZ / BOARD_TICK_HZ` with both values limited by
  `sw/board_limits.h` at build time.
- Check: `waiver/div_never_zero.smt2` models the C division and the limits and asks z3
  for a setting that gives `div = 0` or a value larger than 65535. Result: `unsat`, none
  exists. `waiver/check_is_not_vacuous.smt2` widens the tick limit and gets `sat` with a
  concrete bad setting, which shows the check can fail.
- Assumptions the waiver depends on: no other code writes `div`, and no supported board
  goes outside `sw/board_limits.h`. If either changes, the waiver must be checked again.
- Evidence: `evidence/08_waiver.txt`.

## Hole D: read of unused address 3

- Code: the `default` branch of the read multiplexer.
- Reachable: yes. Software can read any address.
- Outcome: **reached** by `test_read_unused_address`, which also checks the value is 0.
- Evidence: the line is absent from `evidence/04_uncovered_lines_after.txt`.

## After

`evidence/04_uncovered_lines_after.txt` lists only holes B and C, which are closed by a
proof and a checked waiver.
