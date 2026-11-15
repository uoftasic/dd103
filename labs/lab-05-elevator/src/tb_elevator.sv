// -----------------------------------------------------------------------------
// tb_elevator.sv  --  DD103 Lab 05
//
// Eight checks. The shipped skeleton passes five and fails three -- those three
// failures ARE the assignment. When every line says PASS you are done with the
// RTL half of the lab and can start hardening.
//
//   iverilog -g2012 -o results/tb.vvp src/tb_elevator.sv src/elevator.sv
//   vvp results/tb.vvp
//
// Note how every button press is driven on the FALLING edge and every output is
// sampled 1 ns AFTER the rising edge. Drive and sample on the same edge and you
// are racing your own design -- the simulator is allowed to run either one
// first, and it will not tell you which it picked.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_elevator;

    logic       clk = 1'b0;
    logic       rst_n;
    logic [3:0] call;

    logic [1:0] floor;
    logic       moving_up, moving_dn, door_open;
    logic [6:0] seg;

    int fails = 0;
    int door_ticks;

    elevator dut (
        .clk (clk), .rst_n (rst_n), .call (call),
        .floor (floor), .moving_up (moving_up), .moving_dn (moving_dn),
        .door_open (door_open), .seg (seg)
    );

    always #10 clk = ~clk;              // 20 ns period, matches config.json

    task automatic check(input string name, input bit ok);
        if (ok) $display("  PASS  %s", name);
        else begin
            $display("  FAIL  %s", name);
            fails++;
        end
    endtask

    task automatic tick(input int n);
        repeat (n) @(posedge clk);
        #1;
    endtask

    // hold `mask` across exactly one rising edge, then let go
    task automatic tap(input logic [3:0] mask);
        @(negedge clk); call = mask;
        @(negedge clk); call = 4'b0000;
        #1;
    endtask

    // hold `mask` until the doors open at floor `f`, or give up
    task automatic hold_until(input logic [3:0] mask, input logic [1:0] f,
                              input int limit, output bit ok);
        int n;
        @(negedge clk); call = mask;
        n  = 0;
        ok = 1'b0;
        while (n < limit) begin
            @(posedge clk); #1;
            if (door_open && floor == f) begin ok = 1'b1; return; end
            n++;
        end
    endtask

    // wait for the doors to open at floor `f` with nobody pressing anything
    task automatic wait_doors(input logic [1:0] f, input int limit, output bit ok);
        int n;
        n  = 0;
        ok = 1'b0;
        while (n < limit) begin
            @(posedge clk); #1;
            if (door_open && floor == f) begin ok = 1'b1; return; end
            n++;
        end
    endtask

    initial begin
        bit ok;

        $dumpfile("results/elevator.vcd");
        $dumpvars(0, tb_elevator);

        call  = 4'b0000;
        rst_n = 1'b0;
        tick(2);

        // --- T1: reset ------------------------------------------------------
        check("T1 reset: floor 0, doors shut, display shows 1",
              (floor == 2'd0) && (door_open == 1'b0) && (seg == 7'b0000110));
        @(negedge clk); rst_n = 1'b1;

        // --- T2: a HELD call. Works with or without a queue. -----------------
        $display("T2  hold call[2] until the car arrives");
        hold_until(4'b0100, 2'd2, 30, ok);
        check("T2 held call to floor 2 is served", ok);
        check("T2 display shows 3 at floor 2", seg == 7'b1001111);

        // --- T3: a one-cycle tap WHILE THE CAR IS BUSY. Needs the queue. -----
        // The doors are open at floor 2 right now. Press 3 for exactly one
        // rising edge and let go. A machine with no memory of button presses
        // will never hear it.
        $display("T3  tap call[3] for one cycle while the doors are open at floor 2");
        tap(4'b1000);
        wait_doors(2'd3, 40, ok);
        check("T3 one-cycle call to floor 3 is remembered (call queue)", ok);
        tick(12);

        // --- T4: the doors have to stay open. Needs the dwell timer. ---------
        $display("T4  tap call[0] and time the doors");
        tap(4'b0001);
        wait_doors(2'd0, 30, ok);
        check("T4 floor 0 reached", ok);
        door_ticks = 0;
        while (door_open && door_ticks < 40) begin
            door_ticks++;
            @(posedge clk); #1;
        end
        $display("      doors stayed open for %0d ticks", door_ticks);
        check("T4 doors stay open at least 4 ticks (dwell timer)", door_ticks >= 4);
        tick(12);

        // --- T5: two taps at once, served lowest floor first ------------------
        $display("T5  tap call[1] and call[3] in the same cycle");
        tap(4'b1010);
        wait_doors(2'd1, 30, ok);
        check("T5 floor 1 served first", ok);
        wait_doors(2'd3, 40, ok);
        check("T5 floor 3 served afterwards", ok);

        tick(4);
        $display("");
        if (fails == 0) $display("ALL CHECKS PASSED");
        else            $display("%0d CHECK(S) FAILED", fails);
        $display("");
        $finish;
    end

endmodule
