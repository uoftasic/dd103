// A #5 delay. Synthesis throws it away without a word.
module u_delay (input logic d, output logic q);
    always @(d) begin
        #5 q = d;
    end
endmodule
