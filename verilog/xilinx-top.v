`default_nettype none

// A 1024x16 RAM with one write port and one read port
module ram16k(
  input wire        clk,

  input wire        write,
  input wire[9:0]  waddr,
  input wire[15:0]   din,

  input  wire[13:0] raddr,
  output wire[15:0]  dout);

  //synthesis attribute ram_style of mem is block
  reg    [15:0]  mem[0:511]; //pragma attribute mem ram_block TRUE
  reg    [9:0]  raddr_reg;

  initial begin
    $readmemh("../build/firmware/demo0.hex", mem);
  end

  always @ (posedge clk)
    if (write)
      mem[waddr]  <= din;  

  always @ (posedge clk)
    raddr_reg  <= raddr;

  assign dout = mem[{1'b0, raddr_reg}];
endmodule

module top(
  input wire CLK,
  output wire DUO_LED,
  input  wire DUO_SW1,
  input  wire RXD,
  output wire TXD
  );
  localparam MHZ = 200;

  // wire fclk = CLK;

//  // Convert 25MHz input clock to 65MHz by multiplying by 13/5.
//  wire ck_fb, fclk;
//  DCM #(
//     .CLKFX_MULTIPLY(2),
//     .CLKFX_DIVIDE(2),
//     .DFS_FREQUENCY_MODE("LOW"),
//     .DUTY_CYCLE_CORRECTION("TRUE"),
//     .STARTUP_WAIT("TRUE")
//  ) DCM_inst (
//     .CLKIN(CLK),     // Clock input (from IBUFG, BUFG or DCM)
//     .CLK0(ck_fb),    
//     .CLKFX(fclk), 
//     .CLKFB(ck_fb),    // DCM clock feedback
//     .RST(0)
//  );

  wire fclk;

DCM_CLKGEN #(
.CLKFX_MD_MAX(0.0), // Specify maximum M/D ratio for timing anlysis
.CLKFX_DIVIDE(32), // Divide value - D - (1-256)
.CLKFX_MULTIPLY(MHZ), // Multiply value - M - (2-256)
.CLKIN_PERIOD(31.25), // Input clock period specified in nS
.SPREAD_SPECTRUM("NONE"), // Spread Spectrum mode "NONE", "CENTER_LOW_SPREAD", "CENTER_HIGH_SPREAD",
// "VIDEO_LINK_M0", "VIDEO_LINK_M1" or "VIDEO_LINK_M2"
.STARTUP_WAIT("FALSE") // Delay config DONE until DCM_CLKGEN LOCKED (TRUE/FALSE)
)
DCM_CLKGEN_inst (
.CLKFX(fclk), // 1-bit output: Generated clock output
// .CLKFX180(CLKFX180), // 1-bit output: Generated clock output 180 degree out of phase from CLKFX.
// .CLKFXDV(CLKFXDV), // 1-bit output: Divided clock output
// .LOCKED(LOCKED), // 1-bit output: Locked output
// .PROGDONE(PROGDONE), // 1-bit output: Active high output to indicate the successful re-programming
// .STATUS(STATUS), // 2-bit output: DCM_CLKGEN status
.CLKIN(CLK), // 1-bit input: Input clock
.FREEZEDCM(0), // 1-bit input: Prevents frequency adjustments to input clock
.PROGCLK(0), // 1-bit input: Clock input for M/D reconfiguration
.PROGDATA(0), // 1-bit input: Serial data input for M/D reconfiguration
.PROGEN(0), // 1-bit input: Active high program enable
.RST(0) // 1-bit input: Reset input pin
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

  // assign vga_red = 0;
  // assign vga_green = 0;
  // assign vga_blue = 0;
  // assign vga_hsync_n = 0;
  // assign vga_vsync_n = 0;
  // // assign MISO = 0;
  // assign AUDIOL = 0;
  // assign AUDIOR = 0;
  // assign flashMOSI = 0;
  // assign flashSCK = 0;
  // assign flashSSEL = 0;

  wire [15:0] mem_addr;
  wire mem_wr;
  wire [15:0] dout;

  wire [8:0] code_addr;
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
     .dout(dout),
     .io_din({uart0_data, 5'd0, uart0_valid, uart0_busy, DUO_SW1}),

     .code_addr(code_addr),
     .insn(insn)
     );

  ram16k ram(.clk(fclk), .write(0), .waddr(0),
    .raddr(code_addr), .din(16'habcf), .dout(insn));

  reg io_wr_;
  reg [15:0] mem_addr_, dout_;
  always @(posedge fclk)
    {io_wr_, mem_addr_, dout_} <= {io_wr, mem_addr, dout};

  assign uart0_wr = io_wr_ & (mem_addr_ == 16'h0000);
  assign uart0_rd = io_wr_ & (mem_addr_ == 16'h0001);

endmodule
