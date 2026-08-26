// Three statements, blocking.
module shift_b (
    input  logic clk,
    input  logic d,
    output logic q
);
    logic a, b;
    always_ff @(posedge clk) begin
        a = d;
        b = a;
        q = b;
    end
endmodule
