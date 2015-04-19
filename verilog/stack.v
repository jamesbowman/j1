`default_nettype none
`define WIDTH 16

module stack( 
  input wire clk,
  /* verilator lint_off UNUSED */
  input wire resetq,
  /* verilator lint_on UNUSED */
  input wire [3:0] ra,
  output wire [`WIDTH-1:0] rd,
  input wire we,
  input wire [3:0] wa,
  input wire [`WIDTH-1:0] wd);

  reg [`WIDTH-1:0] store[0:15];

  always @(posedge clk)
    if (we)
      store[wa] <= wd;

  assign rd = store[ra];
endmodule
