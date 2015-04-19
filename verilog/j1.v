`include "common.h"

module j1(
   input wire clk,
   input wire resetq,

   output wire io_wr,
   output wire [`WIDTH-1:0] mem_addr,
   output wire mem_wr,
   output wire [`WIDTH-1:0] dout,

   input  wire [`WIDTH-1:0] io_din,

   output wire [8:0] code_addr,
   input  wire [15:0] insn
   );
  parameter FIRMWARE = "build/firmware/";
  parameter INIT = "demo0.hex";

  reg [3:0] dsp;      // Data stack pointer
  reg [3:0] dspN;
  reg [`WIDTH-1:0] st0;     // Top of data stack
  reg [`WIDTH-1:0] st0N;
  wire dstkW;         // D stack write

  reg [8:0] pc, pcN;      
  reg [3:0] rsp, rspN;
  reg rstkW;          // R stack write
  reg [`WIDTH-1:0] rstkD;   // R stack write value
  reg reboot = 1;
  wire [8:0] pc_plus_1 = pc + 1;

  assign mem_addr = st0N;
  assign code_addr = pcN;
  wire [`WIDTH-1:0] mem_din = 16'h5678;

  // The D and R stacks
  wire [`WIDTH-1:0] st1;
  wire [`WIDTH-1:0] rst0;
  stack dstack(.clk(clk), .resetq(resetq), .ra(dsp), .rd(st1), .we(dstkW), .wa(dspN), .wd(st0));
  stack rstack(.clk(clk), .resetq(resetq), .ra(rsp), .rd(rst0), .we(rstkW), .wa(rspN), .wd(rstkD));

  always @*
  begin
    // Compute the new value of st0
    casez ({insn[15:8]})
      8'b1??_?????: st0N = { 1'b0, insn[14:0] };    // literal
      8'b000_?????: st0N = st0;                     // jump
      8'b010_?????: st0N = st0;                     // call
      8'b001_?????: st0N = st1;                     // conditional jump
      8'b011_00000: st0N = st0;                     // ALU operations...
      8'b011_00001: st0N = st1;
      8'b011_00010: st0N = st0 + st1;
      8'b011_00011: st0N = st0 & st1;
      8'b011_00100: st0N = st0 | st1;
      8'b011_00101: st0N = st0 ^ st1;
      8'b011_00110: st0N = ~st0;
      8'b011_00111: st0N = {16{(st1 == st0)}};
      8'b011_01000: st0N = {16{($signed(st1) < $signed(st0))}};
      8'b011_01001: st0N = st1 >> st0[3:0];
      8'b011_01010: st0N = st0 - 1;
      8'b011_01011: st0N = rst0;
      8'b011_01100: st0N = mem_din;
      8'b011_01101: st0N = io_din;
      8'b011_01110: st0N = {8'd0, rsp, dsp};
      8'b011_01111: st0N = {16{(st1 < st0)}};
      8'b011_10001: st0N = st1 << st0[3:0];
      default: st0N = {`WIDTH{1'bx}};
    endcase
  end

  wire is_alu = (insn[15:13] == 3'b011);
  wire is_lit = (insn[15]);

  wire func_T_N =   (insn[6:4] == 1);
  wire func_T_R =   (insn[6:4] == 2);
  wire func_write = (insn[6:4] == 3);
  wire func_iow =   (insn[6:4] == 4);

  assign mem_wr = !reboot & is_alu & func_write;
  assign dout = st1;
  assign io_wr = !reboot & is_alu & func_iow;

  assign dstkW = is_lit | (is_alu & func_T_N);

  wire [1:0] dd = insn[1:0];  // D stack delta
  wire [1:0] rd = insn[3:2];  // R stack delta

  always @*
  begin
    if (is_lit) begin                       // literal
      dspN = dsp + 1;
      rspN = rsp;
      rstkW = 0;
      rstkD = {`WIDTH{1'bx}};
    end else if (is_alu) begin             // ALU
      dspN = dsp + {dd[1], dd[1], dd};
      rspN = rsp + {rd[1], rd[1], rd};
      rstkW = func_T_R;
      rstkD = st0;
    end else begin                          // jump/call
      // predicated jump is like DROP
      if (insn[15:13] == 3'b001) begin
        dspN = dsp - 1;
      end else begin
        dspN = dsp;
      end
      if (insn[15:13] == 3'b010) begin // call
        rspN = rsp + 1;
        rstkW = 1;
        rstkD = {7'b000000, pc_plus_1};
      end else begin
        rspN = rsp;
        rstkW = 0;
        rstkD = {`WIDTH{1'bx}};
      end
    end

    /*
    if (reboot)
      pcN = 0;
    else if ((insn[15:13] == 3'b000) |
            ((insn[15:13] == 3'b001) & (|st0 == 0)) |
            (insn[15:13] == 3'b010))
      pcN = insn[8:0];
    else if (is_alu & insn[7])
      pcN = rst0[8:0];
    else
      pcN = pc_plus_1;
    */

    casez ({reboot, insn[15:13], insn[7], |st0})
    6'b1_???_?_?:   pcN = 0;
    6'b0_000_?_?,
    6'b0_010_?_?,
    6'b0_001_?_0:   pcN = insn[8:0];
    6'b0_011_1_?:   pcN = rst0[8:0];
    default:        pcN = pc_plus_1;
    endcase

  end

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      reboot <= 1;
      pc <= 0;
      dsp <= 0;
      st0 <= 0;
      rsp <= 0;
    end else begin
      reboot <= 0;
      pc <= pcN;
      dsp <= dspN;
      st0 <= st0N;
      rsp <= rspN;
    end
  end
endmodule
