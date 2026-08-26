module add_trunc (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] sum
);
    assign sum = {1'b0, a} + b;
endmodule
