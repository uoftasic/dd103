# Lab 03 — Three ways to lose a latch
# Runs inside hpretl/iic-osic-tools:2026.04 (Yosys 0.64, Verilator 5.046, Icarus 14.0).
#
#   make          everything, in order
#   make latch    the three-way synthesis contrast
#   make lint     the lint gate
#   make sim      what the latch actually does
#   make flops    blocking vs non-blocking, counted
#   make comb     the mirror-image mistake, in always_comb
#   make width    the trap lint does not catch

LIB  := /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
RES  := $(CURDIR)/results
BARS := bar_comb bar_star bar_unique bar_fixed

.PHONY: all latch lint sim flops comb width clean

all: latch lint sim flops comb width

## latch — synthesize the same incomplete case under four headers
latch:
	@mkdir -p $(RES)
	@echo "=============================================================="
	@echo " SYNTHESIS: one incomplete case, four headers"
	@echo "=============================================================="
	@cd src && for m in $(BARS); do \
	  yosys -p "read_verilog -sv $$m.sv; synth -top $$m; stat" > $(RES)/$$m.log 2>&1; \
	  rc=$$?; \
	  echo "--- $$m (exit $$rc) ---"; \
	  grep -E "atch inferred" $(RES)/$$m.log || echo "  (proc_dlatch said nothing)"; \
	  awk '/^3\. Printing statistics/,0' $(RES)/$$m.log \
	    | grep -E "cells$$|\\\$$_" || true; \
	done

## lint — the gate. Nothing gets synthesized until this is silent.
lint:
	@echo "=============================================================="
	@echo " LINT: verilator --lint-only -Wall"
	@echo "=============================================================="
	@cd src && for m in $(BARS); do \
	  echo "--- $$m ---"; \
	  verilator --lint-only -Wall $$m.sv && echo "  clean (exit 0)"; \
	done; true

## sim — what a latch actually does when you drive the missing case
sim:
	@mkdir -p $(RES)
	@echo "=============================================================="
	@echo " SIMULATION: drive level = 2'b11, the branch nobody wrote"
	@echo "=============================================================="
	@cd src && iverilog -g2012 -o $(RES)/bar.vvp tb_bar.sv bar_star.sv bar_fixed.sv
	@$(RES)/bar.vvp
	@cd src && yosys -qp "read_verilog -sv bar_unique.sv; synth -top bar_unique; \
	            write_verilog -noattr $(RES)/bar_unique_net.v" 2>/dev/null
	@cd src && iverilog -g2012 -o $(RES)/uniq.vvp tb_unique.sv $(RES)/bar_unique_net.v
	@$(RES)/uniq.vvp

## flops — blocking vs non-blocking, settled by counting
flops:
	@mkdir -p $(RES)
	@echo "=============================================================="
	@echo " FLIP-FLOP COUNT: the same three statements, two operators"
	@echo "=============================================================="
	@cd src && for m in shift_nb shift_b shift_b_rev; do \
	  yosys -p "read_verilog -sv $$m.sv; synth -top $$m; \
	            dfflibmap -liberty $(LIB); abc -liberty $(LIB); opt_clean; \
	            stat -liberty $(LIB)" > $(RES)/$$m.log 2>&1; \
	  printf "%-12s %s\n" "$$m" "$$(grep -E 'dfxtp_1' $(RES)/$$m.log | tail -1)"; \
	done
	@cd src && iverilog -g2012 -o $(RES)/shift.vvp tb_shift.sv shift_nb.sv shift_b.sv
	@$(RES)/shift.vvp

## comb — the mirror-image mistake: `<=` inside always_comb
comb:
	@mkdir -p $(RES)
	@echo "=============================================================="
	@echo " ALWAYS_COMB: same logic, '=' vs '<='"
	@echo "=============================================================="
	@cd src && for m in comb_b comb_nb; do \
	  yosys -qp "read_verilog -sv $$m.sv; synth -top $$m; \
	             write_verilog -noattr $(RES)/$$m.v" 2>/dev/null; \
	  echo "--- $$m netlist ---"; \
	  grep -a "assign" $(RES)/$$m.v; \
	  verilator --lint-only -Wall $$m.sv 2>&1 | grep -E "COMBDLY|Exiting" || echo "  lint clean"; \
	done
	@cd src && iverilog -g2012 -o $(RES)/comb.vvp tb_comb.sv comb_nb.sv comb_b.sv
	@$(RES)/comb.vvp

## width — the trap that lint does NOT catch
width:
	@mkdir -p $(RES)
	@echo "=============================================================="
	@echo " THE ONE LINT MISSES: eight bits in, eight bits out"
	@echo "=============================================================="
	@cd src && verilator --lint-only -Wall add8.sv && echo "add8.sv: LINT CLEAN (exit 0)"
	@cd src && yosys -qp "read_verilog -sv add8.sv; synth -top add8; abc -liberty $(LIB); \
	            opt_clean; tee -o $(RES)/add8.stat stat -liberty $(LIB)" > /dev/null 2>&1
	@grep "Chip area" $(RES)/add8.stat
	@cd src && iverilog -g2012 -o $(RES)/add8.vvp tb_add8.sv add8.sv
	@$(RES)/add8.vvp
	@echo "--- and now with a ninth bit to put the carry in ---"
	@cd src && yosys -qp "read_verilog -sv add9.sv; synth -top add9; abc -liberty $(LIB); \
	            opt_clean; tee -o $(RES)/add9.stat stat -liberty $(LIB)" > /dev/null 2>&1
	@grep "Chip area" $(RES)/add9.stat
	@cd src && iverilog -g2012 -o $(RES)/add9.vvp tb_add9.sv add9.sv
	@$(RES)/add9.vvp
	@echo "--- a width MISMATCH, which lint does see ---"
	@cd src && verilator --lint-only -Wall add_trunc.sv || true

clean:
	rm -rf $(RES)/*.log $(RES)/*.vvp $(RES)/*.v $(RES)/*.stat src/obj_dir
