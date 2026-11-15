// mem.sv -- "The warehouse and the empty lot": a 2 KB array, both ways.
//
// The FPGA has block RAM sitting on the die whether you use it or not.
// SKY130 has no memory in the standard-cell library, so every bit becomes a
// flip-flop and every read becomes a multiplexer tree.
//
//   yosys -p "read_verilog -sv mem.sv; synth_ice40 -top mem; stat"
//     -> 53 cells: 29 SB_DFF, 20 SB_LUT4, 4 SB_RAM40_4K
//
//   LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
//   yosys -p "read_verilog -sv mem.sv; synth -top mem; dfflibmap -liberty $LIB; \
//             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
//     -> 27684 cells: 16384 edfxtp_1 (= 2048 x 8), 2748 mux4_2
//        Chip area for module '\mem': 606554.233600     (about 12 seconds to run)

module mem (
    input  logic        clk,
    input  logic        we,
    input  logic [10:0] addr,
    input  logic [7:0]  din,
    output logic [7:0]  dout
);
    logic [7:0] store [0:2047];

    always_ff @(posedge clk) begin
        if (we) store[addr] <= din;
        dout <= store[addr];
    end
endmodule
