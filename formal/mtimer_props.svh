// formal/mtimer_props.svh
// Properties for rtl/mtimer.sv. Included inside the module under `ifdef FORMAL,
// so the design file itself carries no property code.
// (Open source Yosys ignores SystemVerilog bind statements, so bind is not used.)

  reg f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  // Start from reset.
  always @(*) if (!f_past_valid) assume (!rst_n);

  always @(posedge clk) begin
    if (f_past_valid && $past(rst_n) && rst_n) begin
      // Spec: once pending, MTIP stays pending until software writes mtime or
      // mtimecmp. The only exception is mtime wrapping from all ones to zero.
      a_mtip_stays_pending: assert (!($past(mtip) && !$past(we) && $past(mtime) != '1) || mtip);

      // Hole B: the state register never holds the unused encoding 2'b11.
      a_state_legal: assert (state != 2'b11);
    end
  end

  always @(posedge clk) begin
    if (f_past_valid && rst_n) begin
      // Activation: the trigger of a_mtip_stays_pending really occurs, and so does
      // the situation the bug report is about (mtime already past mtimecmp).
      c_mtip_stays_trigger: cover ($past(rst_n) && $past(mtip) && !$past(we) && $past(mtime) != '1);
      c_mtip_after_compare: cover (mtip && mtime > mtimecmp);
      c_resume:             cover (state == S_RESUME);
      // Hole C: div = 0 is reachable in the RTL (so it cannot be proven unreachable).
      c_div_zero_running:   cover (div == '0 && state == S_RUN);
    end
  end
