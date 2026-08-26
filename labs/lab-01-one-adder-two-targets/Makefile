# Lab 01 — One adder, two targets
# Runs inside hpretl/iic-osic-tools:2026.04 (Yosys 0.64, nextpnr-ice40 0.10).
#
#   make          both flows, then the side-by-side summary
#   make fpga     yosys synth_ice40 -> nextpnr-ice40 -> icepack
#   make asic     yosys synth -> abc -liberty sky130
#   make table    reprint the summary from logs you already have
#   make clean    delete results/, keep sources

RES := results

.PHONY: all fpga asic table clean

all: fpga asic table

## fpga — the rented warehouse: LUTs, placement, a bitstream
fpga: | $(RES)
	@echo "=============================================================="
	@echo " FPGA TARGET — Lattice iCE40 UP5K, package sg48"
	@echo "=============================================================="
	yosys fpga.ys | tee $(RES)/fpga-synth.log
	nextpnr-ice40 --up5k --package sg48 \
	    --json $(RES)/ripple4.json --asc $(RES)/ripple4.asc --freq 50 \
	    2>&1 | tee $(RES)/fpga-pnr.log
	icepack $(RES)/ripple4.asc $(RES)/ripple4.bin
	@ls -l $(RES)/ripple4.bin

## asic — the empty lot: real cells, real square micrometres
asic: | $(RES)
	@echo "=============================================================="
	@echo " ASIC TARGET — SKY130, sky130_fd_sc_hd standard cells"
	@echo "=============================================================="
	@echo " (abc prints 94 'Scl_LibertyReadGenlib() skipped' lines. Normal.)"
	yosys asic.ys | tee $(RES)/asic.log

## table — the three numbers you write down
table:
	@echo ""
	@echo "=============================================================="
	@echo " YOUR NUMBERS"
	@echo "=============================================================="
	@printf "FPGA  logic cells : "; grep -oE "ICESTORM_LC: *[0-9]+/ *[0-9]+" $(RES)/fpga-pnr.log | tail -1
	@printf "FPGA  LUT4s       : "; grep -E "SB_LUT4" $(RES)/fpga-synth.log | tail -1
	@printf "FPGA  bitstream   : "; stat -c "%s bytes" $(RES)/ripple4.bin
	@echo   "ASIC  cells       :"
	@grep -E "sky130_fd_sc_hd__" $(RES)/asic.log | tail -2
	@printf "ASIC  area        : "; grep "Chip area" $(RES)/asic.log | tail -1

$(RES):
	@mkdir -p $(RES)

clean:
	rm -f $(RES)/*.log $(RES)/*.json $(RES)/*.asc $(RES)/*.bin $(RES)/*.v
