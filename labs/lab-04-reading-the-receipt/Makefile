# Lab 04 — Reading the receipt
# Runs inside hpretl/iic-osic-tools:2026.04 (Yosys 0.64, Python 3.12).
#
#   make            all four experiments, in order, then the summary table
#   make predict    experiment 1 — you say 6 flops, the receipt says 8
#   make broken     experiment 2 — delete dfflibmap, get a wrong total
#   make scripts    experiment 3 — five synthesis scripts, one source file
#   make gap        experiment 4 — 4 x one adder is not one 4-bit adder
#   make check      re-run the self-check on JSON you already have
#   make table      reprint the summary from JSON you already have
#   make clean      delete results/, keep sources

RES   := results
CHECK := python3 src/check_stat.py

# `synth` prints its own statistics halfway through, so a naive grep shows you
# the wrong block. This keeps only the LAST "Printing statistics" section.
LAST   = awk '/Printing statistics/{b=""} {b=b $$0 ORS} END{printf "%s", b}'

.PHONY: all predict broken scripts gap check table clean

all: predict broken scripts gap table

## predict — experiment 1: count your flip-flops, then count Yosys's
predict: | $(RES)
	@echo "=============================================================="
	@echo " 1. PREDICT, THEN MEASURE"
	@echo "    Write your flip-flop prediction down BEFORE reading this."
	@echo "=============================================================="
	yosys scripts/baseline.ys > $(RES)/baseline.log 2>&1
	@$(LAST) $(RES)/baseline.log | grep -E "cells$$|sky130|Chip area|sequential elem"
	@echo ""
	@echo "--- and again with FSM re-encoding switched off ---"
	yosys scripts/nofsm.ys > $(RES)/nofsm.log 2>&1
	@$(LAST) $(RES)/nofsm.log | grep -E "cells$$|dfrtp|Chip area|sequential elem"
	@echo ""
	@echo "--- why: ask the log what the fsm pass did ---"
	@grep -A6 "FSM_RECODE pass" $(RES)/baseline.log | head -9
	@$(CHECK) $(RES)/blinker.json --expect blinker

## broken — experiment 2: one deleted line, no error, a wrong number
broken: | $(RES)
	@echo "=============================================================="
	@echo " 2. THE DELIBERATE FAILURE — scripts/broken.ys has no dfflibmap"
	@echo "=============================================================="
	@yosys scripts/broken.ys > $(RES)/broken.log 2>&1; \
	  echo "yosys scripts/broken.ys -> exit status $$?   (yes. zero.)"
	@$(LAST) $(RES)/broken.log | grep -E "cells$$|\$$_|is unknown|Chip area|sequential elem"
	@echo ""
	@echo "--- what the self-check makes of that ---"
	@$(CHECK) $(RES)/blinker_broken.json --expect blinker || true

## scripts — experiment 3: the script is a design decision
scripts: | $(RES)
	@echo "=============================================================="
	@echo " 3. FIVE SCRIPTS, ONE blinker.sv"
	@echo "=============================================================="
	yosys scripts/explicit.ys        > $(RES)/explicit.log 2>&1
	yosys scripts/explicit_nodffe.ys > $(RES)/explicit_nodffe.log 2>&1
	yosys scripts/flat.ys            > $(RES)/flat.log 2>&1
	yosys scripts/fast.ys            > $(RES)/fast.log 2>&1
	@$(CHECK) --table $(RES)/blinker_explicit.json $(RES)/blinker_explicit_nodffe.json \
	    $(RES)/blinker.json $(RES)/blinker_flat.json $(RES)/blinker_fast.json

## gap — experiment 4: one adder priced alone vs four priced together
gap: | $(RES)
	@echo "=============================================================="
	@echo " 4. THE AREA GAP — predict 4 x fulladder, then measure ripple4"
	@echo "=============================================================="
	yosys scripts/gap_one.ys  > $(RES)/gap_one.log 2>&1
	@$(LAST) $(RES)/gap_one.log | grep -E "cells$$|sky130|Chip area"
	@echo ""
	@echo "    your prediction for four of them: ____________ um^2"
	@echo ""
	yosys scripts/gap_four.ys > $(RES)/gap_four.log 2>&1
	@$(LAST) $(RES)/gap_four.log | grep -E "cells$$|sky130|Chip area"
	@echo ""
	@echo "--- and now the same four adders with the boundaries left alone ---"
	yosys scripts/gap_hier.ys > $(RES)/gap_hier.log 2>&1
	@$(LAST) $(RES)/gap_hier.log | grep -E "^ +[0-9]+ +[0-9.]+ (cells|  sky130)|Chip area for top"
	@$(CHECK) $(RES)/fulladder.json    --expect fulladder
	@$(CHECK) $(RES)/ripple4.json      --expect ripple4
	@$(CHECK) $(RES)/ripple4_hier.json --expect ripple4_hier

## check — the self-check on its own, on results you already produced
check:
	@$(CHECK) $(RES)/blinker.json    --expect blinker
	@$(CHECK) $(RES)/fulladder.json  --expect fulladder
	@$(CHECK) $(RES)/ripple4.json    --expect ripple4

## table — every run you have, side by side
table:
	@echo ""
	@echo "=============================================================="
	@echo " YOUR NUMBERS"
	@echo "=============================================================="
	@$(CHECK) --table $(wildcard $(RES)/*.json)

$(RES):
	@mkdir -p $(RES)

clean:
	rm -f $(RES)/*.log $(RES)/*.json $(RES)/*.v
