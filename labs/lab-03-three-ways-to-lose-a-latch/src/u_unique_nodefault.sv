// `unique` on an incomplete case: no error, and not the circuit you wrote.
module u_unique_nodefault (input logic [1:0] s, output logic [1:0] y);
    always_comb begin
        unique case (s)
            2'b00: y = 2'b01;
            2'b01: y = 2'b10;
            2'b10: y = 2'b11;
        endcase
    end
endmodule
