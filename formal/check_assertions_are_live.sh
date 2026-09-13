#!/usr/bin/env bash
# Checks that the assertions can fail. A proof that cannot fail proves nothing.
#  1. a_mtip_stays_pending must FAIL on the seeded bug (task bug_bmc).
#  2. a_state_legal must FAIL on a mutant that enters the unused state 2'b11.
set -u
cd "$(dirname "$0")"
SBY=${SBY:-sby}

$SBY -f mtimer.sby bug_bmc > /dev/null 2>&1
grep -q "failed assertion mtimer.a_mtip_stays_pending" mtimer_bug_bmc/logfile.txt \
  && echo "live: a_mtip_stays_pending fails on the seeded bug" \
  || { echo "NOT LIVE: a_mtip_stays_pending did not fail on the seeded bug"; exit 1; }

rm -rf mutant && mkdir -p mutant
sed "s/state <= S_RUN;                  \/\/ hole A: resume cycle/state <= 2'b11;/" ../rtl/mtimer.sv > mutant/mtimer.sv
cp mtimer_props.svh mutant/
cat > mutant/mutant.sby <<'SBYEOF'
[options]
mode bmc
depth 12
[engines]
smtbmc z3
[script]
read -formal -I. mtimer.sv
prep -top mtimer
[files]
mtimer.sv
mtimer_props.svh
SBYEOF
(cd mutant && $SBY -f mutant.sby > /dev/null 2>&1)
grep -q "failed assertion mtimer.a_state_legal" mutant/mutant/logfile.txt \
  && echo "live: a_state_legal fails on a mutant that enters state 2'b11" \
  || { echo "NOT LIVE: a_state_legal did not fail on the mutant"; exit 1; }
