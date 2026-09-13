; waiver/check_is_not_vacuous.smt2
; Same model as div_never_zero.smt2, with the tick limit widened to 1 Hz and
; 100 MHz. This must be "sat": it shows the check is able to find a bad
; setting, so the "unsat" result above is not an accident of the encoding.

(declare-const clk_hz Int)
(declare-const tick_hz Int)
(declare-const div_value Int)

(assert (and (>= clk_hz 1000000) (<= clk_hz 100000000)))
(assert (and (>= tick_hz 1) (<= tick_hz 100000000)))

(assert (<= (* div_value tick_hz) clk_hz))
(assert (< clk_hz (* (+ div_value 1) tick_hz)))
(assert (>= div_value 0))

(assert (or (= div_value 0) (> div_value 65535)))

(check-sat)
(get-value (clk_hz tick_hz div_value))
