// rtl/mtimer.sv
// RISC-V machine timer: mtime and mtimecmp registers, a clock prescaler, and a
// debug halt input. The RISC-V privileged specification requires the machine
// timer interrupt (MTIP) to be pending while mtime >= mtimecmp.
//
// Build with +define+SEEDED_BUG to get the bug this repository investigates.
// Build with +define+FORMAL to pull in formal/mtimer_props.svh.
`timescale 1ns/1ps
module mtimer #(
  parameter int DIV_W = 16
)(
  input  logic        clk,
  input  logic        rst_n,
  // Register bus: one write per cycle, combinational read.
  input  logic        we,
  input  logic [1:0]  addr,     // 0 = mtime, 1 = mtimecmp, 2 = div
  input  logic [63:0] wdata,
  output logic [63:0] rdata,
  // Debug halt: mtime stops counting while halt is set.
  input  logic        halt,
  output logic        mtip
);
  localparam logic [1:0] A_MTIME = 2'd0, A_MTIMECMP = 2'd1, A_DIV = 2'd2;
  localparam logic [1:0] S_RUN = 2'd0, S_HALTED = 2'd1, S_RESUME = 2'd2;

  logic [1:0]       state;
  logic [63:0]      mtime;
  logic [63:0]      mtimecmp;
  logic [DIV_W-1:0] div;
  logic [DIV_W-1:0] prescale;

  // Halt handling: counting stops while halted and restarts one cycle after release.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_RUN;
    end else begin
      case (state)
        S_RUN: begin
          if (halt) state <= S_HALTED;
        end
        S_HALTED: begin
          if (!halt) state <= S_RESUME;    // hole A: release after a halt
        end
        S_RESUME: begin
          state <= S_RUN;                  // hole A: resume cycle
        end
        default: begin
          state <= S_RUN;                  // hole B: encoding 2'b11
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mtime    <= '0;
      mtimecmp <= '1;
      div      <= DIV_W'(1);
      prescale <= '0;
    end else begin
      if (we && addr == A_MTIMECMP) mtimecmp <= wdata;
      if (we && addr == A_DIV) begin
        div      <= wdata[DIV_W-1:0];
        prescale <= '0;
      end
      if (we && addr == A_MTIME) begin
        mtime    <= wdata;
        prescale <= '0;
      end else if (state == S_RUN) begin
        // Prescaler: mtime advances once every div clock cycles.
        if (div == '0) begin
          mtime    <= mtime + 64'd1;         // hole C: div = 0 means no prescaling
        end else if (prescale == div - 1'b1) begin
          mtime    <= mtime + 64'd1;
          prescale <= '0;
        end else begin
          prescale <= prescale + 1'b1;
        end
      end
    end
  end

  always_comb begin
    case (addr)
      A_MTIME:    rdata = mtime;
      A_MTIMECMP: rdata = mtimecmp;
      A_DIV:      rdata = 64'(div);
      default:    rdata = '0;             // hole D: read of the unused address 3
    endcase
  end

`ifdef SEEDED_BUG
  // Seeded bug: pending only on the tick where mtime equals mtimecmp.
  assign mtip = (mtime == mtimecmp);
`else
  assign mtip = (mtime >= mtimecmp);
`endif

`ifdef FORMAL
  `include "mtimer_props.svh"
`endif
endmodule
