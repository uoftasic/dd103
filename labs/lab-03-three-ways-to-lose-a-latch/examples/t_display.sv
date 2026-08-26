// t_display.sv -- "The hardware dialect": what $display becomes in a mapped netlist.
//
// $display is a margin note. Yosys does not throw it away -- it keeps it as a
// $print cell, which rides all the way through technology mapping and then has
// no area, because no SKY130 standard cell prints to a terminal.
//
//   LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
//   yosys -p "read_verilog -sv t_display.sv; synth -top t_display; \
//             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
//
// Expect: 5 cells, 1 $print, 4 sky130_fd_sc_hd__dfxtp_1, chip area 80.076800,
//         and "Area for cell type $print is unknown!".

module t_display (
    input  logic       clk,
    input  logic [3:0] d,
    output logic [3:0] q
);
    always_ff @(posedge clk) begin
        q <= d;
        $display("d = %0d", d);
    end
endmodule
