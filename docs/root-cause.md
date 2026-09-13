# Root cause

## Symptom

A timer interrupt is missed when the core has interrupts disabled at the moment
`mtime` reaches `mtimecmp`.

## What the specification requires

The RISC-V privileged specification defines the machine timer interrupt as pending
while `mtime >= mtimecmp`. Software clears it by writing a larger `mtimecmp`. A core
with interrupts disabled relies on the interrupt still being pending when it enables
them again.

## What the design did

```systemverilog
assign mtip = (mtime == mtimecmp);   // seeded bug
```

`mtime` increases by one on every count. Equality holds on exactly one count, so MTIP
was high for one count and then dropped. A core that looked at MTIP during that count
saw the interrupt. A core that looked later did not. The same line also breaks the case
where software writes a `mtimecmp` that is already in the past: `mtime` is already
greater, equality never holds, and MTIP is never set.

## Why the old regression passed

`test_mtip_rises_at_compare` waits until MTIP is high once and stops. The bug does make
MTIP high once. No test checked that MTIP stays high, and no test wrote a `mtimecmp` in
the past.

## How it was found

1. `tb/test_bug_report.py` turns the report into two checks that follow the
   specification. Both fail on the seeded bug (`evidence/01_sim_seeded_bug.log`).
2. `a_mtip_stays_pending` states the requirement as a property. Bounded model checking
   on the seeded bug returns a counterexample (`evidence/02_formal_seeded_bug.log`,
   `evidence/02_counterexample.vcd`): MTIP is set when `mtime` equals `mtimecmp` and
   drops on the next count with no register write in between.

## Fix

```systemverilog
assign mtip = (mtime >= mtimecmp);
```

## Confirmation

- Both bug report tests pass, with the rest of the regression (7 of 7,
  `evidence/04_sim_fixed_all_tests.log`).
- `a_mtip_stays_pending` is proven for every reachable state by k induction
  (`evidence/05_formal_prove_fixed.log`).
- The trigger of the property is reached (`c_mtip_stays_trigger`,
  `evidence/06_formal_cover.log`), and the property fails when the bug is put back
  (`evidence/07_assertions_live.txt`), so the proof is not empty.
