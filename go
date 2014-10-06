(cd toolchain && sh go) || exit
iverilog -g2 -s testbench verilog/*.v || exit
./a.out
