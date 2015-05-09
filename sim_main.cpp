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

    uint16_t ram[1024];
    FILE *hex = fopen(argv[1], "r");
    for (i = 0; i < 1024; i++) {
      unsigned int v;
      if (fscanf(hex, "%x\n", &v) != 1) {
        fprintf(stderr, "invalid hex value at line %d\n", i + 1);
        exit(1);
      }
      ram[i] = v;
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
        ram[(a & 2047) / 2] = top->dout;
      top->clk = 1;
      top->eval();
      t += 20;

      top->mem_din = ram[(a & 2047) / 2];
      top->insn = ram[b];
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
