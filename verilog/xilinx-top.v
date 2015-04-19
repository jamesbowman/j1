`default_nettype none

// A 1024x16 RAM with one write port and one read port
module ram16k(
  input wire        clk,

  input  wire[15:0] a_addr,
  output wire[15:0] a_q,
  input  wire[15:0] a_d,
  input  wire       a_wr,

  input  wire[13:0] b_addr,
  output wire[15:0] b_q);

  //synthesis attribute ram_style of mem is block
  reg    [15:0]  mem[0:1023]; //pragma attribute mem ram_block TRUE
  initial begin
    $readmemh("../build/firmware/demo0.hex", mem, 0, 511);
  end

  always @ (posedge clk)
    if (a_wr)
      mem[a_addr[10:1]] <= a_d;  

  reg    [15:0]  a_addr_;
  always @ (posedge clk)
    a_addr_  <= a_addr;
  assign a_q = mem[a_addr_[10:1]];

  reg    [13:0]  raddr_reg;
  always @ (posedge clk)
    raddr_reg  <= b_addr;
  assign b_q = mem[raddr_reg[9:0]];
endmodule

module top(
  input wire CLK,
  output wire DUO_LED,
  input  wire DUO_SW1,
  input  wire RXD,
  output wire TXD
  );
  localparam MHZ = 200;

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
  wire [15:0] mem_din;
  wire mem_wr;
  wire [15:0] dout;

  wire [12:0] code_addr;
  wire [15:0] insn;

  wire io_wr;

  reg resetq = 1'b0;
  always @(posedge fclk)
    resetq <= 1'b1;

  j1 _j1 (
     .clk(fclk),
     .resetq(resetq),

     .io_wr(io_wr),
     .mem_addr(mem_addr),
     .mem_wr(mem_wr),
     .mem_din(mem_din),
     .dout(dout),
     .io_din({uart0_data, 5'd0, uart0_valid, uart0_busy, DUO_SW1}),

     .code_addr(code_addr),
     .insn(insn)
     );

  ram16k ram(.clk(fclk),
             .a_addr(mem_addr),
             .a_q(mem_din),
             .a_wr(mem_wr),
             .a_d(dout),
             .b_addr(code_addr[8:0]),
             .b_q(insn));

  reg io_wr_;
  reg [15:0] mem_addr_, dout_;
  always @(posedge fclk)
    {io_wr_, mem_addr_, dout_} <= {io_wr, mem_addr, dout};

  assign uart0_wr = io_wr_ & (mem_addr_ == 16'h0000);
  assign uart0_rd = io_wr_ & (mem_addr_ == 16'h0002);

endmodule
