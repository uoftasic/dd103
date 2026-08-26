# timing.tcl — OpenSTA script for the guide page "The carry has to walk".
#
#   NETLIST=gates4.v sta -exit scripts/timing.tcl
#
# $env(NETLIST) reads a shell variable, so the same script works on every width
# you synthesize. The three delay/clock lines are not decoration: a purely
# combinational block has no flip-flops, so without them STA has nothing to time
# between and answers `No paths found.`
#
# A period of 100 ns is deliberately absurd — it makes slack enormous so that
# `data arrival time` is the only interesting number on the page. That is how you
# MEASURE combinational delay. It is not timing closure.

read_liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog $env(NETLIST)
link_design ripple
create_clock -name clk -period 100
set_input_delay  0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -digits 3
