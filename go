(cd toolchain && sh go) || exit
iverilog -I verilog/ -g2 -s testbench verilog/testbench.v verilog/top.v verilog/j1.v verilog/stack.v || exit
./a.out

make && obj_dir/Vj1 build/firmware/demo0.hex
