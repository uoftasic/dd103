// The synthesizable half: a structure. One register, nothing else.
module dut (
    input  logic       clk,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) q <= d;
endmodule
