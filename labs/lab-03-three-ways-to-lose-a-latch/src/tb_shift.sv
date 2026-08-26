// Pulse d high for exactly one clock, then watch both q outputs.
module tb_shift;
    logic clk = 0, d = 0;
    logic q_nb, q_b;
    shift_nb u_nb (.clk(clk), .d(d), .q(q_nb));
    shift_b  u_b  (.clk(clk), .d(d), .q(q_b));

    always #5 clk = ~clk;

    initial begin
        repeat (3) @(negedge clk);   // let both designs settle
        d = 1;
        @(negedge clk);
        d = 0;
    end

    initial begin
        $display("time   d   q_nb   q_b");
        repeat (8) begin
            @(posedge clk); #1;
            $display("%4d   %1b    %1b      %1b", $time, d, q_nb, q_b);
        end
        $finish;
    end
endmodule
