module comb_b (input logic [3:0] a, output logic [3:0] y);
    logic [3:0] t;
    always_comb begin
        t = a & 4'hC;
        y = t | 4'h1;
    end
endmodule
