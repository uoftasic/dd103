// The simulation half: an experiment being run on the circuit.
// #5, $display and $finish all ask for things a chip cannot do.
`timescale 1ns/1ns
module tb;
    logic       clk = 1'b0;
    logic [7:0] d   = 8'd0;
    logic [7:0] q;

    dut u_dut (.clk(clk), .d(d), .q(q));

    always #5 clk = ~clk;

    always @(posedge clk)
        $display("[%0t] captured d = %0d", $time, d);

    initial begin
        repeat (3) begin
            @(negedge clk); d = d + 8'd3;
        end
        @(posedge clk); #1;
        $display("final q = %0d", q);
        $finish;
    end
endmodule
