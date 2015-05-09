
$(SUBDIRS):
	$(MAKE) -C $@

all: obj_dir/Vj1 $(SUBDIRS)

VERILOGS=verilog/j1.v verilog/stack.v

obj_dir/Vj1: $(VERILOGS) sim_main.cpp Makefile
	verilator -Wall --cc --trace -Iverilog/ $(VERILOGS) --top-module j1 --exe sim_main.cpp
	# verilator --cc --trace $(VERILOGS) --top-module j1 --exe sim_main.cpp
	$(MAKE) -C obj_dir OPT_FAST="-O2" -f Vj1.mk Vj1

.PHONY: all
