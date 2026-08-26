// The same incomplete case, declared as a latch on purpose.
module bar_latch (
    input  logic [1:0] level,
    output logic [3:0] bar
);
    always_latch begin
        case (level)
            2'b00: bar = 4'b0001;
            2'b01: bar = 4'b0011;
            2'b10: bar = 4'b0111;
        endcase
    end
endmodule
