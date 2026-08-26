package alu_pkg;
    typedef enum logic [1:0] { OP_ADD, OP_SUB, OP_AND, OP_XOR } op_e;
    localparam int WIDTH = 8;
endpackage

module alu
    import alu_pkg::*;
(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  op_e              op,
    output logic [WIDTH-1:0] y,
    output logic             zero
);
    function automatic logic [WIDTH-1:0] apply (input op_e o,
                                                input logic [WIDTH-1:0] x,
                                                input logic [WIDTH-1:0] z);
        case (o)
            OP_ADD: return x + z;
            OP_SUB: return x - z;
            OP_AND: return x & z;
            OP_XOR: return x ^ z;
        endcase
        return '0;
    endfunction

    always_comb begin
        y    = apply(op, a, b);
        zero = (y == '0);
    end
endmodule
