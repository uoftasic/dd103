// t_initial.sv -- "The hardware dialect": initial is an attribute, not a reset.
//
//   yosys -p "read_verilog -sv t_initial.sv; synth -top t_initial" 2>&1 | grep -A3 PROC_INIT
//
// Expect: "Found init rule in ..." and "Set init value: \count = 4'0000".
//
//   LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
//   yosys -p "read_verilog -sv t_initial.sv; synth -top t_initial; \
//             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; \
//             write_verilog /dev/stdout" 2>/dev/null | grep -B2 'output \[3:0\] count'
//
// Expect: (* init = 4'h0 *) on the port. Not one gate of reset logic was built.

module t_initial (
    input  logic       clk,
    output logic [3:0] count
);
    initial count = 4'd0;
    always_ff @(posedge clk) count <= count + 1'b1;
endmodule
