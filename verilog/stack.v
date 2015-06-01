`include "common.h"

module stack
  #(parameter DEPTH=4)
  (input wire clk,
  /* verilator lint_off UNUSED */
  input wire resetq,
  /* verilator lint_on UNUSED */
  input wire [DEPTH-1:0] ra,
  output wire [`WIDTH-1:0] rd,
  input wire we,
  input wire [DEPTH-1:0] wa,
  input wire [`WIDTH-1:0] wd);

  reg [`WIDTH-1:0] store[0:(2**DEPTH)-1];

  always @(posedge clk)
    if (we)
      store[wa] <= wd;

  assign rd = store[ra];
endmodule
