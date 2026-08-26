// Three statements, non-blocking.
module shift_nb (
    input  logic clk,
    input  logic d,
    output logic q
);
    logic a, b;
    always_ff @(posedge clk) begin
        a <= d;
        b <= a;
        q <= b;
    end
endmodule
