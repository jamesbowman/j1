`default_nettype none


module bram_tdp #(
    parameter DATA = 72,
    parameter ADDR = 10
) (
    // Port A
    input   wire                a_clk,
    input   wire                a_wr,
    input   wire    [ADDR-1:0]  a_addr,
    input   wire    [DATA-1:0]  a_din,
    output  reg     [DATA-1:0]  a_dout,
     
    // Port B
    input   wire                b_clk,
    input   wire                b_wr,
    input   wire    [ADDR-1:0]  b_addr,
    input   wire    [DATA-1:0]  b_din,
    output  reg     [DATA-1:0]  b_dout
);
 
// Shared memory
reg [DATA-1:0] mem [(2**ADDR)-1:0];
  initial begin
    $readmemh("../build/firmware/demo0.hex", mem);
  end
 
// Port A
always @(posedge a_clk) begin
    a_dout      <= mem[a_addr];
    if(a_wr) begin
        a_dout      <= a_din;
        mem[a_addr] <= a_din;
    end
end
 
// Port B
always @(posedge b_clk) begin
    b_dout      <= mem[b_addr];
    if(b_wr) begin
        b_dout      <= b_din;
        mem[b_addr] <= b_din;
    end
end
 
endmodule

// A 16Kbyte RAM (4096x32) with one write port and one read port
module ram16k0(
  input wire        clk,

  input  wire[15:0] a_addr,
  output wire[31:0] a_q,
  input  wire[31:0] a_d,
  input  wire       a_wr,

  input  wire[12:0] b_addr,
  output wire[15:0] b_q);

  //synthesis attribute ram_style of mem is block
  reg    [31:0]  mem[0:4095]; //pragma attribute mem ram_block TRUE
  initial begin
    $readmemh("../build/firmware/demo0.hex", mem);
  end

  always @ (posedge clk)
    if (a_wr)
      mem[a_addr[13:2]] <= a_d;  

  reg    [15:0]  a_addr_;
  always @ (posedge clk)
    a_addr_  <= a_addr;
  assign a_q = mem[a_addr_[13:2]];

  reg    [12:0]  raddr_reg;
  always @ (posedge clk)
    raddr_reg  <= b_addr;
  wire [31:0] insn32 = mem[raddr_reg[12:1]];
  assign b_q = raddr_reg[0] ? insn32[31:16] : insn32[15:0];
endmodule

module ram16k(
  input wire        clk,

  input  wire[15:0] a_addr,
  output wire[31:0] a_q,
  input  wire[31:0] a_d,
  input  wire       a_wr,

  input  wire[12:0] b_addr,
  output wire[15:0] b_q);

  wire [31:0] insn32;

  bram_tdp #(.DATA(32), .ADDR(12)) nram (
    .a_clk(clk),
    .a_wr(a_wr),
    .a_addr(a_addr[13:2]),
    .a_din(a_d),
    .a_dout(a_q),

    .b_clk(clk),
    .b_wr(1'b0),
    .b_addr(b_addr[12:1]),
    .b_din(32'd0),
    .b_dout(insn32));

  reg ba_;
  always @(posedge clk)
    ba_ <= b_addr[0];
  assign b_q = ba_ ? insn32[31:16] : insn32[15:0];

endmodule


module top(
  input wire CLK,
  output wire DUO_LED,
  input  wire DUO_SW1,
  input  wire RXD,
  output wire TXD,
  input  wire DTR
  );
  localparam MHZ = 40;

  wire fclk;

  DCM_CLKGEN #(
  .CLKFX_MD_MAX(0.0),     // Specify maximum M/D ratio for timing anlysis
  .CLKFX_DIVIDE(32),      // Divide value - D - (1-256)
  .CLKFX_MULTIPLY(MHZ),   // Multiply value - M - (2-256)
  .CLKIN_PERIOD(31.25),   // Input clock period specified in nS
  .STARTUP_WAIT("FALSE")  // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
  )
  DCM_CLKGEN_inst (
  .CLKFX(fclk),           // 1-bit output: Generated clock output
  .CLKIN(CLK),            // 1-bit input: Input clock
  .FREEZEDCM(0),          // 1-bit input: Prevents frequency adjustments to input clock
  .PROGCLK(0),            // 1-bit input: Clock input for M/D reconfiguration
  .PROGDATA(0),           // 1-bit input: Serial data input for M/D reconfiguration
  .PROGEN(0),             // 1-bit input: Active high program enable
  .RST(0)                 // 1-bit input: Reset input pin
  );

  reg [25:0] counter;
  always @(posedge fclk)
    counter <= counter + 26'd1;
  assign DUO_LED = counter[25];

  // ------------------------------------------------------------------------

  wire uart0_valid, uart0_busy;
  wire [7:0] uart0_data;
  wire uart0_rd, uart0_wr;
  reg [31:0] baud = 32'd115200;
  wire UART0_RX;
  buart #(.CLKFREQ(MHZ * 1000000)) _uart0 (
     .clk(fclk),
     .resetq(1'b1),
     .baud(baud),
     .rx(RXD),
     .tx(TXD),
     .rd(uart0_rd),
     .wr(uart0_wr),
     .valid(uart0_valid),
     .busy(uart0_busy),
     .tx_data(dout_[7:0]),
     .rx_data(uart0_data));

  wire [15:0] mem_addr;
  wire [31:0] mem_din;
  wire mem_wr;
  wire [31:0] dout;

  wire [12:0] code_addr;
  wire [15:0] insn;

  wire io_wr;

  wire resetq = DTR;

  j1 _j1 (
     .clk(fclk),
     .resetq(resetq),

     .io_wr(io_wr),
     .mem_addr(mem_addr),
     .mem_wr(mem_wr),
     .mem_din(mem_din),
     .dout(dout),
     .io_din({16'd0, uart0_data, 4'd0, DTR, uart0_valid, uart0_busy, DUO_SW1}),

     .code_addr(code_addr),
     .insn(insn)
     );

  ram16k ram(.clk(fclk),
             .a_addr(mem_addr),
             .a_q(mem_din),
             .a_wr(mem_wr),
             .a_d(dout),
             .b_addr(code_addr),
             .b_q(insn));

  reg io_wr_;
  reg [15:0] mem_addr_;
  reg [31:0] dout_;
  always @(posedge fclk)
    {io_wr_, mem_addr_, dout_} <= {io_wr, mem_addr, dout};

  assign uart0_wr = io_wr_ & (mem_addr_ == 16'h0000);
  assign uart0_rd = io_wr_ & (mem_addr_ == 16'h0002);

endmodule
