// Battery bar graph: 2-bit level in, 4 LEDs out.
// The 2'b11 branch is missing on purpose.
module bar_star (
    input  logic [1:0] level,
    output logic [3:0] bar
);
    always @* begin
        case (level)
            2'b00: bar = 4'b0001;
            2'b01: bar = 4'b0011;
            2'b10: bar = 4'b0111;
        endcase
    end
endmodule
