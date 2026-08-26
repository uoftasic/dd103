// Battery bar graph: 2-bit level in, 4 LEDs out.
// Every case has a default. No latch, no surprise.
module bar_fixed (
    input  logic [1:0] level,
    output logic [3:0] bar
);
    always_comb begin
        case (level)
            2'b00: bar = 4'b0001;
            2'b01: bar = 4'b0011;
            2'b10: bar = 4'b0111;
            default: bar = 4'b1111;
        endcase
    end
endmodule
