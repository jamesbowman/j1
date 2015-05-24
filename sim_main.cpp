#include <stdio.h>
#include "Vj1.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    Vj1* top = new Vj1;
    int i;

    // Verilated::traceEverOn(true);
    // VerilatedVcdC* tfp = new VerilatedVcdC;
    // top->trace (tfp, 99);
    // tfp->open ("simx.vcd");

    if (argc != 2) {
      fprintf(stderr, "usage: sim <hex-file>\n");
      exit(1);
    }

    union {
      uint32_t ram32[4096];
      uint16_t ram16[8192];
    };

    FILE *hex = fopen(argv[1], "r");
    for (i = 0; i < 4096; i++) {
      unsigned int v;
      if (fscanf(hex, "%x\n", &v) != 1) {
        fprintf(stderr, "invalid hex value at line %d\n", i + 1);
        exit(1);
      }
      ram32[i] = v;
    }

    FILE *log = fopen("log", "w");
    int t = 0;

    top->resetq = 0;
    top->eval();
    top->resetq = 1;
    top->eval();

    for (i = 0; i < 100000000; i++) {
      uint16_t a = top->mem_addr;
      uint16_t b = top->code_addr;
      if (top->mem_wr)
        ram32[(a & 16383) / 4] = top->dout;
      top->clk = 1;
      top->eval();
      t += 20;

      top->mem_din = ram32[(a & 16383) / 4];
      top->insn = ram16[b];
      top->clk = 0;
      top->eval();
      t += 20;
      if (top->io_wr) {
        putchar(top->dout);
        putc(top->dout, log);
        if (top->dout == '#')
          break;
      }
#if 0
      if (top->io_inp && (top->io_n == 2)) {
        top->io_din = getchar();
      }
#endif
    }
    printf("\nSimulation ended after %d cycles\n", i);
    delete top;
    // tfp->close();
    fclose(log);

    exit(0);
}
