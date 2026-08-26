// counter.sv — the subject of "Synthesis is translation with an accent".
//
// A 4-bit counter with an enable and an asynchronous, active-low reset.
// Eleven lines, nothing clever. Every pass list and every cell count on that
// guide page came from this file.
//
//   yosys -p "read_verilog -sv counter.sv; synth -top counter" 2>&1 | grep -E '^2\.[0-9]+\. '
//
// `make` does not build this file — it is here so the guide's commands run.

module counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    output logic [3:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)   count <= 4'd0;
        else if (en)  count <= count + 1'b1;
    end
endmodule
