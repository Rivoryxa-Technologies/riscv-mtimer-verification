; waiver/div_never_zero.smt2
; Checked waiver for coverage hole C (rtl/mtimer.sv, div == 0 branch).
;
; Claim: for every clock setting allowed by sw/board_limits.h, the value
; mtimer_init() writes to div (clk_hz / tick_hz, C unsigned division) is at
; least 1 and fits in the 16 bit div register. So firmware built with this
; driver never writes div = 0, and never writes a truncated value.
;
; We ask z3 for a counterexample. "unsat" means none exists.

(declare-const clk_hz Int)
(declare-const tick_hz Int)
(declare-const div_value Int)

; Limits from sw/board_limits.h
(assert (and (>= clk_hz 1000000) (<= clk_hz 100000000)))
(assert (and (>= tick_hz 10000) (<= tick_hz 1000000)))

; C unsigned division of positive integers: div_value = floor(clk_hz / tick_hz)
(assert (<= (* div_value tick_hz) clk_hz))
(assert (< clk_hz (* (+ div_value 1) tick_hz)))
(assert (>= div_value 0))

; Negation of the claim: div is zero, or does not fit in 16 bits.
(assert (or (= div_value 0) (> div_value 65535)))

(check-sat)
