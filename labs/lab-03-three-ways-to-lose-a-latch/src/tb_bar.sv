// Walk level 0,1,2,3,2 and print what the bar graph shows.
module tb_bar;
    logic [1:0] level;
    logic [3:0] bar_s, bar_f;
    bar_star  u_s (.level(level), .bar(bar_s));
    bar_fixed u_f (.level(level), .bar(bar_f));
    initial begin
        $display("level   bar_star   bar_fixed");
        level = 2'b00; #1; $display("   %2b       %4b        %4b", level, bar_s, bar_f);
        level = 2'b01; #1; $display("   %2b       %4b        %4b", level, bar_s, bar_f);
        level = 2'b10; #1; $display("   %2b       %4b        %4b", level, bar_s, bar_f);
        level = 2'b11; #1; $display("   %2b       %4b        %4b", level, bar_s, bar_f);
        level = 2'b00; #1; $display("   %2b       %4b        %4b", level, bar_s, bar_f);
        $finish;
    end
endmodule
