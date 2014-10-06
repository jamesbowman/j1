`timescale 1ns/1ps
`default_nettype none

module testbench();

  reg clk;
  reg resetq;
  integer t;

  top #(.FIRMWARE("build/firmware/")) dut(.clk(clk), .resetq(resetq));

  initial begin
    clk = 1;
    t = 0;
    resetq = 0;
    #1;
    resetq = 1;

    $dumpfile("test.vcd");
    $dumpvars(0, dut);
  end

  always #5.0 clk = ~clk;

  always @(posedge clk) begin
    t <= t + 1;
    if (t == 300)
      $finish;
  end
endmodule
