#!/usr/bin/env bash
# Reproduces every result in this repository from a fresh clone.
# Writes logs to evidence/ and exits non zero if any expected result does not happen.
#
# Needs on PATH: sby (SymbiYosys), yosys, yosys-smtbmc, z3, verilator, verilator_coverage,
# python3 with cocotb installed, and make.
# To use a SymbiYosys checkout instead of an installed sby:  SBY="python3 /path/to/sbysrc/sby.py"
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SBY=${SBY:-sby}
EV="$ROOT/evidence"
mkdir -p "$EV"
: > "$EV/SUMMARY.txt"
FAILED=0

check() {  # check "description" command...
  local what="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "PASS  $what" | tee -a "$EV/SUMMARY.txt"
  else
    echo "FAIL  $what" | tee -a "$EV/SUMMARY.txt"; FAILED=1
  fi
}

sim() {  # sim <log> <bug 0|1> <test modules>
  (cd tb && rm -rf sim_build coverage.dat results.xml \
     && make BUG="$2" COCOTB_TEST_MODULES="$3" > "$1" 2>&1)
  return 0
}

echo "== 0. Environment"
{
  date -u "+run date (UTC): %Y-%m-%d %H:%M"
  uname -sr
  yosys -V
  z3 --version
  verilator --version
  python3 --version
  python3 -c "import cocotb; print('cocotb', cocotb.__version__)"
  echo "sby: ${SBY_VERSION:-version not recorded, set SBY_VERSION}"
} > "$EV/00_environment.txt" 2>&1
cat "$EV/00_environment.txt"

echo "== 1. Seeded bug in simulation: the old regression passes, the bug report tests fail"
sim "$EV/01_sim_seeded_bug.log" 1 test_regression,test_bug_report
check "old regression passes on the seeded bug (3 of 3)" grep -q "test_regression.test_mtip_rises_at_compare *PASS" "$EV/01_sim_seeded_bug.log"
check "bug report test fails on the seeded bug: MTIP drops after compare" grep -q "test_bug_report.test_mtip_stays_pending_after_compare *FAIL" "$EV/01_sim_seeded_bug.log"
check "bug report test fails on the seeded bug: mtimecmp written in the past" grep -q "test_bug_report.test_mtimecmp_written_in_the_past *FAIL" "$EV/01_sim_seeded_bug.log"
check "simulation totals on the seeded bug: 5 tests, 3 pass, 2 fail" grep -q "TESTS=5 PASS=3 FAIL=2" "$EV/01_sim_seeded_bug.log"

echo "== 2. Seeded bug in formal: counterexample"
(cd formal && rm -rf mtimer_bug_bmc && $SBY -f mtimer.sby bug_bmc > /dev/null 2>&1)
cp formal/mtimer_bug_bmc/logfile.txt "$EV/02_formal_seeded_bug.log"
cp formal/mtimer_bug_bmc/engine_0/trace.vcd "$EV/02_counterexample.vcd"
python3 scripts/trace_summary.py "$EV/02_counterexample.vcd" > "$EV/02_counterexample_table.txt"
cat "$EV/02_counterexample_table.txt"
check "formal finds a counterexample to a_mtip_stays_pending on the seeded bug" grep -q "failed assertion mtimer.a_mtip_stays_pending" "$EV/02_formal_seeded_bug.log"
check "formal run on the seeded bug used z3" grep -q "Solver: z3" "$EV/02_formal_seeded_bug.log"

echo "== 3. Coverage of the old regression on the fixed RTL: holes A, B, C, D"
sim "$EV/03_sim_old_regression_fixed.log" 0 test_regression
(cd tb && rm -rf annotated && verilator_coverage --annotate annotated coverage.dat > "$EV/03_coverage_summary_before.txt" 2>&1 \
   && grep -n "%000000" annotated/mtimer.sv > "$EV/03_uncovered_lines_before.txt")
cat "$EV/03_uncovered_lines_before.txt"
for h in A B C D; do
  check "coverage before: hole $h is uncovered" grep -q "hole $h" "$EV/03_uncovered_lines_before.txt"
done

echo "== 4. Fixed RTL, all tests, coverage after the new directed tests"
sim "$EV/04_sim_fixed_all_tests.log" 0 test_regression,test_bug_report,test_holes
(cd tb && rm -rf annotated && verilator_coverage --annotate annotated coverage.dat > "$EV/04_coverage_summary_after.txt" 2>&1 \
   && grep -n "%000000" annotated/mtimer.sv > "$EV/04_uncovered_lines_after.txt")
cat "$EV/04_uncovered_lines_after.txt"
check "fixed RTL: 7 tests, 7 pass, 0 fail" grep -q "TESTS=7 PASS=7 FAIL=0" "$EV/04_sim_fixed_all_tests.log"
check "coverage after: hole A is covered by a directed test" bash -c "! grep -q 'hole A' '$EV/04_uncovered_lines_after.txt'"
check "coverage after: hole D is covered by a directed test" bash -c "! grep -q 'hole D' '$EV/04_uncovered_lines_after.txt'"
check "coverage after: only holes B and C remain" bash -c "grep -q 'hole B' '$EV/04_uncovered_lines_after.txt' && grep -q 'hole C' '$EV/04_uncovered_lines_after.txt' && [ \$(grep -c 'hole' '$EV/04_uncovered_lines_after.txt') -eq 2 ]"

echo "== 5. Fixed RTL in formal: unbounded proof"
(cd formal && rm -rf mtimer_prove && $SBY -f mtimer.sby prove > /dev/null 2>&1)
cp formal/mtimer_prove/logfile.txt "$EV/05_formal_prove_fixed.log"
check "fixed RTL: a_mtip_stays_pending and a_state_legal proven by k induction" grep -q "successful proof by k-induction" "$EV/05_formal_prove_fixed.log"

echo "== 6. Property activation: every cover is reached"
(cd formal && rm -rf mtimer_cover && $SBY -f mtimer.sby cover > /dev/null 2>&1)
cp formal/mtimer_cover/logfile.txt "$EV/06_formal_cover.log"
for c in c_mtip_stays_trigger c_mtip_after_compare c_resume c_div_zero_running; do
  check "cover reached: $c" grep -q "reached cover statement mtimer.$c" "$EV/06_formal_cover.log"
done

echo "== 7. Assertions are live: each one fails when the design is wrong"
SBY="$SBY" formal/check_assertions_are_live.sh > "$EV/07_assertions_live.txt" 2>&1
cat "$EV/07_assertions_live.txt"
check "a_mtip_stays_pending fails on the seeded bug" grep -q "^live: a_mtip_stays_pending" "$EV/07_assertions_live.txt"
check "a_state_legal fails on a mutant that enters state 2'b11" grep -q "^live: a_state_legal" "$EV/07_assertions_live.txt"

echo "== 8. Checked waiver for hole C"
{ echo "waiver/div_never_zero.smt2:"; z3 waiver/div_never_zero.smt2; echo; echo "waiver/check_is_not_vacuous.smt2:"; z3 waiver/check_is_not_vacuous.smt2; } > "$EV/08_waiver.txt" 2>&1
cat "$EV/08_waiver.txt"
check "waiver: no allowed clock setting gives div = 0 or a value above 65535 (unsat)" bash -c "sed -n 2p '$EV/08_waiver.txt' | grep -qx unsat"
check "waiver check is not vacuous: widened limits give a bad setting (sat)" bash -c "grep -A1 'check_is_not_vacuous' '$EV/08_waiver.txt' | grep -qx sat"

echo
cat "$EV/SUMMARY.txt" | grep -c "^PASS" | xargs -I{} echo "{} checks passed"
if [ "$FAILED" -ne 0 ]; then echo "SOME CHECKS FAILED"; exit 1; fi
echo "ALL CHECKS PASSED"
