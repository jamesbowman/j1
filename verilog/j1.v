`default_nettype none

module regfile_16_16_r_w( 
  input clk,
  input resetq,
  input [3:0] ra,
  output [15:0] rd,
  input we,
  input [3:0] wa,
  input [15:0] wd);

  reg [15:0] store[0:15];
  assign rd = store[ra];

  always @(posedge clk)
    if (we)
      store[wa] <= wd;

endmodule

module j1(
   input clk,
   input resetq
   );
  parameter FIRMWARE = "<firmware>";
  parameter INIT = "<hexfile>";

  wire pause = 0;

  wire [8:0] insn_addr;

  wire [15:0] mem_addr;
  wire mem_wr;
  wire [15:0] mem_dout;

  reg [3:0] dsp;      // Data stack pointer
  reg [3:0] _dsp;
  reg [15:0] st0;     // Top of data stack
  reg [15:0] _st0;
  wire dstkW;         // D stack write

  reg [8:0] pc;
  reg [8:0] _pc;
  reg [3:0] rsp;
  reg [3:0] _rsp;
  reg rstkW;          // R stack write
  reg [15:0] rstkD;   // R stack write value
  reg reboot;

  wire [8:0] pc_plus_1 = pc + 1;

  reg [15:0] ram[0:511] /* verilator public_flat */;
  initial
    $readmemh({FIRMWARE, INIT}, ram);

  reg [15:0] insn;
  reg [15:0] mem_din;
  always @(posedge clk) begin
    insn <= ram[insn_addr];
    // mem_din <= ram[mem_addr[8:0]];
    if (mem_wr)
      ram[mem_addr[8:0]] <= mem_dout;
  end

  // The D and R stacks
  wire [15:0] st1;
  wire [15:0] rst0;
  regfile_16_16_r_w dstack(.clk(clk), .resetq(resetq), .ra(dsp), .rd(st1), .we(!pause & dstkW), .wa(_dsp), .wd(st0));
  regfile_16_16_r_w rstack(.clk(clk), .resetq(resetq), .ra(rsp), .rd(rst0), .we(!pause & rstkW), .wa(_rsp), .wd(rstkD));

  // st0sel is the ALU operation.  For branch and call the operation
  // is T, for 0branch it is N.  For ALU ops it is loaded from the instruction
  // field.
  reg [4:0] st0sel;
  always @*
  begin
    case (insn[14:13])
      2'b00: st0sel = 0;          // ubranch
      2'b10: st0sel = 0;          // call
      2'b01: st0sel = 1;          // 0branch
      2'b11: st0sel = {insn[12:8]}; // ALU
      default: st0sel = 5'bxxxxx;
    endcase

    // Compute the new value of T.
    if (insn[15])
      _st0 = { 1'b0, insn[14:0] };
    else
      case (st0sel)
        5'b00000: _st0 = st0;
        5'b00001: _st0 = st1;
        5'b00010: _st0 = st0 + st1;
        5'b00011: _st0 = st0 & st1;
        5'b00100: _st0 = st0 | st1;
        5'b00101: _st0 = st0 ^ st1;
        5'b00110: _st0 = ~st0;
        5'b00111: _st0 = {16{(st1 == st0)}};
        5'b01000: _st0 = {16{($signed(st1) < $signed(st0))}};
        5'b01001: _st0 = st1 >>> st0[3:0];
        5'b01010: _st0 = st0 - 1;
        5'b01011: _st0 = rst0;
        5'b01100: _st0 = mem_din;
        5'b01101: _st0 = 0;
        5'b01111: _st0 = {16{(st1 < st0)}};
        
        5'b10001: _st0 = st1 << st0[3:0];
        
        default: _st0 = 16'hxxxx;
      endcase
  end

  wire is_alu = (insn[15:13] == 3'b011);
  wire is_lit = (insn[15]);

  wire func_T_N =   (insn[6:4] == 1);
  wire func_T_R =   (insn[6:4] == 2);
  wire func_write = (insn[6:4] == 3);
  wire func_iow =   (insn[6:4] == 4);

  assign mem_wr = !reboot & is_alu & func_write;
  assign mem_addr = _st0;
  assign mem_dout = st1;

  assign dstkW = is_lit | (is_alu & func_T_N);

  wire [1:0] dd = insn[1:0];  // D stack delta
  wire [1:0] rd = insn[3:2];  // R stack delta

  always @*
  begin
    if (is_lit) begin                       // literal
      _dsp = dsp + 1;
      _rsp = rsp;
      rstkW = 0;
      rstkD = 16'bx;
    end else if (is_alu) begin             // ALU
      _dsp = dsp + {dd[1], dd[1], dd};
      _rsp = rsp + {rd[1], rd[1], rd};
      rstkW = func_T_R;
      rstkD = st0;
    end else begin                          // jump/call
      // predicated jump is like DROP
      if (insn[15:13] == 3'b001) begin
        _dsp = dsp - 1;
      end else begin
        _dsp = dsp;
      end
      if (insn[15:13] == 3'b010) begin // call
        _rsp = rsp + 1;
        rstkW = 1;
        rstkD = {6'b000000, pc_plus_1};
      end else begin
        _rsp = rsp;
        rstkW = 0;
        rstkD = 16'bx;
      end
    end

    if (reboot)
      _pc = 0;
    else if ((insn[15:13] == 3'b000) |
            ((insn[15:13] == 3'b001) & (|st0 == 0)) |
            (insn[15:13] == 3'b010))
      _pc = insn[8:0];
    else if (is_alu & insn[7])
      _pc = rst0[8:0];
    else
      _pc = pc_plus_1;
  end

  assign insn_addr = pause ? pc : _pc;
  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      reboot <= 1;
      pc <= 0;
      dsp <= 0;
      st0 <= 0;
      rsp <= 0;
    end else if (!pause) begin
      reboot <= 0;
      pc <= _pc;
      dsp <= _dsp;
      st0 <= _st0;
      rsp <= _rsp;
    end
  end

  wire io_wr = !reboot & is_alu & func_iow;

endmodule
