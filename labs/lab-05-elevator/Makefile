# Lab 05 — Elevator to GDSII
# Runs inside hpretl/iic-osic-tools:2026.08
# (Verilator 5.050, Icarus 14.0, Yosys 0.68, LibreLane 3.1.0.dev3).
#
#   make lint     verilator --lint-only -Wall            ~0.01 s
#   make sim      iverilog + vvp, six checks             ~0.1 s
#   make synth    yosys -> sky130 cells, read the receipt ~0.5 s
#   make harden   librelane config.json -> GDSII         ~1 min
#   make show     the RTL diagram (NOT the gate diagram — see the writeup)
#   make view     open your layout in KLayout (noVNC desktop only)
#   make clean    delete results/, keep runs/

LIB := /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
RES := results
TAG ?= v1

.PHONY: all lint sim synth harden show view metrics clean distclean

all: lint sim synth

## lint — the gate. Nothing else runs until this exits 0.
lint:
	@echo "== verilator --lint-only -Wall =="
	verilator --lint-only -Wall src/elevator.sv
	@echo "   lint clean (exit 0)"

## sim — six checks. The shipped skeleton fails three of them on purpose.
sim: | $(RES)
	@echo "== iverilog + vvp =="
	iverilog -g2012 -o $(RES)/tb.vvp src/tb_elevator.sv src/elevator.sv
	@vvp $(RES)/tb.vvp | tee $(RES)/sim.log
	@grep -q "ALL CHECKS PASSED" $(RES)/sim.log || { \
	  echo "  -> not done yet. Fix the TODO blocks in src/elevator.sv."; exit 1; }

## synth — map to real SKY130 cells and print the receipt
synth: | $(RES)
	@echo "== yosys -> sky130_fd_sc_hd =="
	@echo "   (abc warns 'Detected 9 multi-output cells' in results/synth.log. Normal.)"
	yosys -p "read_verilog -sv src/elevator.sv; \
	          synth -top elevator; \
	          dfflibmap -liberty $(LIB); \
	          abc -liberty $(LIB); \
	          opt_clean; \
	          write_verilog -noattr $(RES)/elevator_sky130.v; \
	          tee -o $(RES)/stat.txt stat -liberty $(LIB)" > $(RES)/synth.log 2>&1
	@sed -n '/=== elevator ===/,$$p' $(RES)/stat.txt

## show — the RTL view. Do not try this on the gate netlist; see the writeup.
show: | $(RES)
	yosys -p "read_verilog -sv src/elevator.sv; \
	          hierarchy -top elevator; proc; opt; \
	          show -format svg -prefix $(RES)/elevator_rtl -notitle" > $(RES)/show.log 2>&1
	@ls -l $(RES)/elevator_rtl.svg

## harden — RTL to GDSII. Bump TAG on every re-run: make harden TAG=v2
harden:
	@echo "== librelane config.json  (run tag: $(TAG)) =="
	librelane --run-tag $(TAG) config.json

## metrics — the five numbers to write down, straight out of the report card
metrics:
	@python3 -c "import json,sys; \
	m=json.load(open('runs/$(TAG)/final/metrics.json')); \
	k=['design__die__area','design__core__area','design__instance__utilization', \
	   'timing__setup__ws','timing__hold__ws','route__wirelength', \
	   'design__instance__count__stdcell','antenna__violating__nets', \
	   'magic__drc_error__count','klayout__drc_error__count','design__lvs_error__count']; \
	[print('%-38s %s' % (x, m.get(x,'MISSING'))) for x in k]"

## view — the GUI. Only works inside the noVNC desktop.
view:
	librelane --flow openinklayout --last-run config.json

$(RES):
	@mkdir -p $(RES)

clean:
	rm -f $(RES)/*.vvp $(RES)/*.vcd $(RES)/*.log $(RES)/*.txt $(RES)/*.v $(RES)/*.svg $(RES)/*.dot

distclean: clean
	rm -rf runs
