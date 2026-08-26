module tb_add9;
    logic [7:0] a, b; logic [8:0] sum;
    add9 dut (.a(a), .b(b), .sum(sum));
    initial begin
        a = 8'd200; b = 8'd100; #1; $display("200 + 100 = %0d", sum);
        a = 8'd255; b = 8'd1;   #1; $display("255 +   1 = %0d", sum);
        $finish;
    end
endmodule
