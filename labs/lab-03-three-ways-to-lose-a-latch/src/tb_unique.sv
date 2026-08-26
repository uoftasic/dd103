// Simulate the SYNTHESIZED bar_unique netlist, not the source.
module tb_unique;
    logic [1:0] level;
    logic [3:0] bar;
    bar_unique dut (.level(level), .bar(bar));
    initial begin
        $display("level   bar (synthesized)");
        level = 2'b00; #1; $display("   %2b       %4b", level, bar);
        level = 2'b01; #1; $display("   %2b       %4b", level, bar);
        level = 2'b10; #1; $display("   %2b       %4b", level, bar);
        level = 2'b11; #1; $display("   %2b       %4b", level, bar);
        $finish;
    end
endmodule
