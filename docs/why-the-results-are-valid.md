# Why the results are valid

A green result is only worth something if it could have been red. Each result here
comes with a reason to believe it.

## The failure is real, not a test artefact

- Two independent methods find it: simulation tests written from the specification
  fail, and formal returns a counterexample for a property written from the same
  specification.
- The old regression passes on the same RTL, which explains how the bug escaped.

## The proof is not empty

A property can pass because its trigger never happens. Two checks rule that out:

1. **Activation.** `c_mtip_stays_trigger` covers exactly the trigger of
   `a_mtip_stays_pending` and is reached. `c_mtip_after_compare` covers `mtime` past
   `mtimecmp` with MTIP set, the situation from the bug report, and is reached.
2. **Liveness.** Each assertion is shown to fail when the design is wrong:
   `a_mtip_stays_pending` on the seeded bug, `a_state_legal` on a mutant that enters
   `2'b11`. See `formal/check_assertions_are_live.sh`.

## The properties are really in the model

Open source Yosys ignores SystemVerilog `bind` statements without an error, so a bound
property would silently never be checked. That is why the properties are included
under `ifdef FORMAL` instead, and why the liveness check above matters: an assertion
that is not in the model cannot fail.

## The proof covers every reachable state

`prove` uses k induction, which proves the assertions for every reachable state, not
only for a bounded number of cycles.

## The waiver is checked, and the check can fail

The waiver rests on a z3 check of the firmware limits, not on a comment. Widening the
limits makes the same check find a bad setting.

## The whole chain reruns

`scripts/reproduce.sh` runs every step from a fresh clone, compares each result with
the expected one, and exits with status 1 if any does not match. Our logs are in
`evidence/`.

## Limits

- Small block, seeded bug. A method demonstration, not a result on a production core.
- The waiver depends on stated firmware assumptions.
- Line coverage shows what ran, not what was checked.
- The wrap of `mtime` at 2^64 counts is excluded from `a_mtip_stays_pending`.
