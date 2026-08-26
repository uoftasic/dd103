// Same three statements, blocking, written bottom-up.
module shift_b_rev (
    input  logic clk,
    input  logic d,
    output logic q
);
    logic a, b;
    always_ff @(posedge clk) begin
        q = b;
        b = a;
        a = d;
    end
endmodule
