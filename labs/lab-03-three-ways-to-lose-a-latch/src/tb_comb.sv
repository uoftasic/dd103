module tb_comb;
    logic [3:0] a; logic [3:0] y_nb, y_b;
    comb_nb u_nb (.a(a), .y(y_nb));
    comb_b  u_b  (.a(a), .y(y_b));
    initial begin
        $display("   a   y_nb   y_b");
        a = 4'h0; #1; $display("%4h   %4h  %4h", a, y_nb, y_b);
        a = 4'hF; #1; $display("%4h   %4h  %4h", a, y_nb, y_b);
        a = 4'h3; #1; $display("%4h   %4h  %4h", a, y_nb, y_b);
        $finish;
    end
endmodule
