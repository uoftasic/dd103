# What synthesis does

This page walks through what Yosys does to your SystemVerilog between reading the file and
printing the final cell list. It shows tool output only; you don't need to run anything while
reading. You'll run every step shown here on the same counter in
[Lab 02, Part 3](labs/lab-02-rtl-becomes-gates-overview.md#part-3-watch-synth-work-on-a-counter).

A synthesis run on a small design prints roughly seven hundred lines. None of them says
`ERROR`, and at the bottom is a number. If you scroll back up you find `PROC_ARST`, `WREDUCE`,
`ALUMACC`, `dch -f`, and a hundred lines about cells being skipped. Those seven hundred lines
come from six steps, and one of the six does most of the work.

## The example design

Here is a 4-bit counter with an enable and an asynchronous reset. It is `src/counter.sv` in the
[Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) package
([on GitHub](https://github.com/uoftasic/dd103/tree/main/labs/lab-02-rtl-becomes-gates/src/counter.sv)).

```systemverilog
module counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    output logic [3:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)   count <= 4'd0;
        else if (en)  count <= count + 1'b1;
    end
endmodule
```

The ASIC flow for it is one Yosys command line: `read_verilog -sv`, then `synth -top counter`,
`dfflibmap -liberty`, `abc -liberty`, `opt_clean` and `stat -liberty`, all pointed at the
SKY130 liberty file. On this counter it prints 726 lines. Yosys numbers every pass it runs, so
filtering for lines that start with a number leaves just the top-level steps:

```
1. Executing Verilog-2005 frontend: counter.sv
2. Executing SYNTH pass.
3. Executing DFFLIBMAP pass (mapping DFF cells to sequential cells from liberty file).
4. Executing ABC pass (technology mapping using ABC).
5. Executing OPT_CLEAN pass (remove unused cells and wires).
6. Printing statistics.
```

Six steps. The first says "Verilog-2005 frontend" even for a `.sv` file because Yosys's front
end grew out of a Verilog-2005 parser; `-sv` asks it to accept SystemVerilog.

## Synthesis as translation

Your source says "add one to `count`". SKY130 has no word for "add". Its vocabulary is
`xnor2_1`, `maj3_1`, `a31oi_1`, `nand4_1`: a few hundred fixed nouns, and nothing else.

So Yosys works like a translator into a language with a small, fixed dictionary. It has to say
what you meant using only words that exist. The result has an accent: no error and no loss of
meaning, just the shape the target language forces on the sentence.

Send the same sentence to an iCE40 and the accent changes to `SB_LUT4`, `SB_CARRY` and
`SB_RAM40_4K`. The meaning is the same; the available nouns are different. That difference is the
subject of [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md).

## Inside `synth`

Step 2 does almost everything. Its own sub-passes are numbered `2.1`, `2.2` and so on:

```
2.1. Executing HIERARCHY pass (managing design hierarchy).
2.2. Executing PROC pass (convert processes to netlists).
2.3. Executing OPT_EXPR pass (perform const folding).
2.4. Executing OPT_CLEAN pass (remove unused cells and wires).
2.5. Executing CHECK pass (checking for obvious problems).
2.6. Executing OPT pass (performing simple optimizations).
2.7. Executing FSM pass (extract and optimize FSM).
2.8. Executing OPT pass (performing simple optimizations).
2.9. Executing WREDUCE pass (reducing word size of cells).
2.10. Executing PEEPOPT pass (run peephole optimizers).
2.11. Executing OPT_CLEAN pass (remove unused cells and wires).
2.12. Executing ALUMACC pass (create $alu and $macc cells).
2.13. Executing SHARE pass (SAT-based resource sharing).
2.14. Executing OPT pass (performing simple optimizations).
2.15. Executing MEMORY pass.
2.16. Executing OPT_CLEAN pass (remove unused cells and wires).
2.17. Executing OPT pass (performing simple optimizations).
2.18. Executing MEMORY_MAP pass (converting memories to logic and flip-flops).
2.19. Executing OPT pass (performing simple optimizations).
2.20. Executing TECHMAP pass (map to technology primitives).
2.21. Executing OPT pass (performing simple optimizations).
2.22. Executing ABC pass (technology mapping using ABC).
2.23. Executing OPT pass (performing simple optimizations).
2.24. Executing HIERARCHY pass (managing design hierarchy).
2.25. Printing statistics.
2.26. Executing CHECK pass (checking for obvious problems).
```

That is twenty-six passes. `synth` is shorthand for a script somebody else wrote, and you can
type its contents yourself, which [Lab 04](labs/lab-04-reading-the-receipt-overview.md) has you
do.

Eleven of the twenty-six are some flavour of `opt`. Optimization runs after every structural
change, not once at the end, because every structural change leaves new unused logic to throw
away.

> **Version note.** Everything on this page is Yosys 0.68, as shipped in
> `hpretl/iic-osic-tools:2026.08`. Pass names are stable across versions, but pass numbering is
> not. If your sub-pass numbers don't match the list above (here `2.13` is `SHARE`), you are on a
> different Yosys.

## The five main passes

The whole flow fits in one line:

`proc` → `opt` → `techmap` → `dfflibmap` → `abc`

Most of the other sub-passes of `synth` are one of these under a more specific name, or a
housekeeping pass. (`dfflibmap` is not in `synth` at all; it is step 3.) Here is what each one
does, plus `hierarchy`, which always runs first:

| Pass | What it does |
|---|---|
| `hierarchy` | Decides which module is the top and connects the instances below it. |
| `proc` | Turns your `always` blocks into cells. Before `proc` an `always_ff` is behaviour; after it, it is a multiplexer and a flip-flop. |
| `opt` | Throws work away: folds constants, deletes unreachable cells, merges two identical cells into one. |
| `techmap` | Splits wide cells into single-bit ones. A 4-bit `$add` becomes a pile of one-bit gates. |
| `dfflibmap` | Replaces every generic flip-flop with a named flip-flop from the liberty file. Flip-flops only. |
| `abc` | Replaces everything that is not a flip-flop with named cells from the liberty file. Combinational logic only. |

## How the design changes shape

Stopping after each pass and running `stat` shows what each one did to the counter:

```
### hierarchy -top counter
        2 cells
        1   $add
        1   $logic_not

### hierarchy -top counter; proc
        5 cells
        1   $add
        1   $adff
        1   $logic_not
        1   $mux
        1   $not

### hierarchy -top counter; proc; opt
        2 cells
        1   $add
        1   $adffe

### hierarchy -top counter; proc; opt; techmap
       48 cells
       14   $_AND_
        4   $_DFFE_PN0P_
        4   $_MUX_
        4   $_NOT_
        9   $_OR_
       13   $_XOR_
```

After `hierarchy` there are two cells. Your `always_ff` block has not been touched: it is still
a process, which is why `stat` can't see the flip-flops yet.

After `proc` there are five. The `if/else if` became a `$mux`, the `!rst_n` became a `$not`, and
`count <= …` became `$adff`, a D flip-flop with asynchronous reset. Your control flow is now
hardware.

After `opt` it is back down to two. `opt` noticed that a mux feeding a flip-flop's D input,
choosing between the flop's own output and a new value, is an enable. It folded the `$mux`,
`$not`, `$logic_not` and `$adff` into a single `$adffe`: one flip-flop with a built-in enable
pin. `opt` recognised an idiom you wrote as control flow and named it as one piece of hardware.
Whether SKY130 actually has that piece is a separate question, and the answer (below) is no.

After `techmap` there are forty-eight. The count went up because `techmap` split the 4-bit
`$add` and the 4-bit `$adffe` into single-bit gates, and SKY130 has no 4-bit anything.
`$_AND_`, `$_XOR_`, `$_DFFE_PN0P_`: the leading underscore means generic, a one-bit gate that
does not belong to any technology yet. None of these forty-eight gates is a SKY130 cell.

## Two mappers

The netlist is now a mix of combinational gates and flip-flops, and two different passes
convert them into SKY130 cells, as separate commands:

```
3. Executing DFFLIBMAP pass (mapping DFF cells to sequential cells from liberty file).
...
Mapping DFF cells in module `\counter':
  mapped 4 $_DFF_PN0_ cells to \sky130_fd_sc_hd__dfrtp_1 cells.

4. Executing ABC pass (technology mapping using ABC).
...
ABC RESULTS:   sky130_fd_sc_hd__a31oi_1 cells:        1
ABC RESULTS:   sky130_fd_sc_hd__lpflow_isobufsrc_1 cells:        1
ABC RESULTS:   sky130_fd_sc_hd__nand2_1 cells:        1
ABC RESULTS:   sky130_fd_sc_hd__nand4_1 cells:        1
ABC RESULTS:   sky130_fd_sc_hd__xnor2_1 cells:        2
ABC RESULTS:   sky130_fd_sc_hd__xor2_1 cells:        1
```

`dfflibmap` did the flops and `abc` did everything else. Neither touched the other's cells.
(Why `dfflibmap` mapped `$_DFF_PN0_` rather than the `$_DFFE_PN0P_` that `opt` built is the next
subsection.)

There are two because ABC is a Boolean optimizer. It works by rewriting logic functions, so it
needs every cell to be a function of its inputs. Here is what the liberty file says about two
cells, `maj3_1` from your Lab 01 adder and `dfrtp_1` from the counter:

```
    cell ("sky130_fd_sc_hd__maj3_1") {
        pin ("X") {
            function : "(A&B) | (A&C) | (B&C)";

    cell ("sky130_fd_sc_hd__dfrtp_1") {
        ff ("IQ","IQ_N") {
            clear : "!RESET_B";
            clocked_on : "CLK";
            next_state : "D";
        }
```

`maj3_1` declares a Boolean expression. `dfrtp_1` declares no function at all; it declares
state. A Boolean rewriter has nothing to rewrite there. So ABC gets the combinational logic and
nothing else, and a separate, much simpler pass matches flip-flops by their clock, reset and
enable shape. That is why the flow has two mapping commands, and why forgetting one of them
fails in such a confusing way.

### Flip-flop shapes in the library

`dfflibmap` mapped `$_DFF_PN0_`, a plain flop with an asynchronous reset, and not the
`$_DFFE_PN0P_` enable flop that `opt` built. Higher up in its output, it lists every flip-flop
shape SKY130 has a cell for:

```
    \sky130_fd_sc_hd__dfrtp_1 _DFF_PN0_ (.CLK( C), .D( D), .Q( Q), .RESET_B( R));
    \sky130_fd_sc_hd__edfxtp_1 _DFFE_PP_ (.CLK( C), .D( D), .DE( E), .Q( Q));
    ...
    unmapped dff cell: $_DFFE_PN_
```

SKY130's one enable flop, `edfxtp_1`, has no reset pin. Your counter needs both an enable and
an asynchronous reset, and no single cell provides both, so `dfflibmap` used the reset flop and
rebuilt the enable out of logic. That is where the four `$_MUX_` in the half-mapped design at the
end of this page came from, and eventually the `a31oi_1`, `nand2_1` and `nand4_1` in the final
cell list. (They are not the four `$_MUX_` from `techmap`: the `abc` inside `synth` had already
folded those into six generic gates, as [Two ABC runs](#two-abc-runs) shows.)

The library made that decision, not your code. With the same RTL on a target that has an
enable-and-reset flop, those cells would not appear.

## Leaving out `dfflibmap`

Delete exactly that one command from the flow and nothing errors. The exit status is 0, and
`stat` prints:

```
       10   37.536 cells
        4        -   $_DFFE_PN0P_
        1    5.005   sky130_fd_sc_hd__a21oi_1
        1    3.754   sky130_fd_sc_hd__clkinv_1
        1    6.256   sky130_fd_sc_hd__lpflow_isobufsrc_1
        1    5.005   sky130_fd_sc_hd__nand3_1
        1    8.758   sky130_fd_sc_hd__xnor2_1
        1    8.758   sky130_fd_sc_hd__xor2_1

   Area for cell type $_DFFE_PN0P_ is unknown!

   Chip area for module '\counter': 37.536000
     of which used for sequential elements: 0.000000 (0.00%)
```

ABC mapped the six combinational gates and left the four flip-flops alone, so they are still
generic `$_DFFE_PN0P_`. SKY130 has no cell called `$_DFFE_PN0P_`, so `stat` can't price them.
It says so once and reports a total that leaves them out.

With `dfflibmap` in place the same design is:

```
       11  148.893 cells
        1    6.256   sky130_fd_sc_hd__a31oi_1
        4  100.096   sky130_fd_sc_hd__dfrtp_1
        1    6.256   sky130_fd_sc_hd__lpflow_isobufsrc_1
        1    3.754   sky130_fd_sc_hd__nand2_1
        1    6.256   sky130_fd_sc_hd__nand4_1
        2   17.517   sky130_fd_sc_hd__xnor2_1
        1    8.758   sky130_fd_sc_hd__xor2_1

   Chip area for module '\counter': 148.892800
     of which used for sequential elements: 100.096000 (67.23%)
```

That is 37.54 µm² against 148.89 µm². One missing line under-reported the design by a factor of
four, and the only sign was a single warning line in the middle of 700-odd.

`Area for cell type … is unknown!` always means the same thing: a cell in your netlist is not in
the liberty file. Ninety percent of the time it is a generic `$_…_` cell, and ninety percent of
those are flip-flops you forgot to map. (`$scopeinfo`, which you met in Lab 01, is the harmless
exception: it is a bookkeeping marker, not hardware.)

Area is the number you'll quote in every design review, and this is the easiest way to quote one
that is wrong by 4×. On any design with a clock, check that
`of which used for sequential elements` is not `0.00%`.

## ABC's skipped-cell warnings

In step 4 you'll see a block like this:

```
ABC: + read_lib -w /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
ABC: Parsing finished successfully.  Parsing time =     0.07 sec
ABC: Scl_LibertyReadGenlib() skipped cell "sky130_fd_sc_hd__decap_12" without logic function.
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfrtp_1".
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfxtp_1".
ABC: Scl_LibertyReadGenlib() skipped three-state cell "sky130_fd_sc_hd__ebufn_1".
```

It goes on for 94 lines, and it looks like your run just failed. It didn't. ABC prints the total
on the line after the block:

```
ABC: Library "sky130_fd_sc_hd__tt_025C_1v80" from "…tt_025C_1v80.lib" has 334 cells
     (94 skipped: 63 seq; 13 tri-state; 18 no func; 0 dont_use; …).  Time = 0.12 sec
```

The library has 428 cells (the next page counts them), so that is 334 usable cells and 94
skipped. 63 of the 94 are flip-flops and latches,
the kind of cell `dfflibmap` handles one step earlier. ABC is not rejecting them. It is the
combinational mapper, and they are not combinational logic, so it leaves them out of
consideration.
`sky130_fd_sc_hd__dfrtp_1` appears in the skipped list in the same run where `dfflibmap` used
four of them: two tools, two jobs, one library.

The other 31 are cells with no logic to speak of: `decap` (filler capacitors), `diode` (antenna
protection), and `ebufn`/`einv` (tri-state buffers, which have a third output state that Boolean
algebra has no symbol for).

These lines are normal output on a successful run. They appear every time you use
`abc -liberty` on SKY130, before ABC does anything useful. If a run actually fails, Yosys prints
a line beginning with `ERROR:` and stops.

## Two ABC runs

The sub-pass list includes `2.22. Executing ABC pass`, inside `synth`, and then you run
`abc -liberty` yourself as step 4. They are separate calls.

The one inside `synth` has no liberty file, so it optimizes into a generic gate set:

```
ABC RESULTS:               AND cells:        1
ABC RESULTS:              NAND cells:        1
ABC RESULTS:               NOT cells:        1
ABC RESULTS:              XNOR cells:        1
ABC RESULTS:               XOR cells:        2
```

Those six technology-neutral gates are the 48 from `techmap` boiled down. Your `abc -liberty`
then optimizes again, this time knowing which cells SKY130 has and what each one costs, and
lands on seven real cells. The second pass can make choices the first had no basis for, so it
is not redundant.

## A half-mapped design

Putting a `stat` between `dfflibmap` and `abc` shows the design halfway through mapping:

```
       14  100.096 cells
        1        -   $_AND_
        4        -   $_MUX_
        1        -   $_NAND_
        1        -   $_NOT_
        1        -   $_XNOR_
        2        -   $_XOR_
        4  100.096   sky130_fd_sc_hd__dfrtp_1

   Area for cell type $_AND_ is unknown!
   Area for cell type $_MUX_ is unknown!
   Area for cell type $_NAND_ is unknown!
   Area for cell type $_NOT_ is unknown!
   Area for cell type $_XNOR_ is unknown!
   Area for cell type $_XOR_ is unknown!

   Chip area for module '\counter': 100.096000
     of which used for sequential elements: 100.096000 (100.00%)
```

Four real `sky130_fd_sc_hd__dfrtp_1` sit next to ten generic gates in the same netlist. This is
the mirror image of the run without `dfflibmap`: there, sequential area was `0.00%`; here it is
`100.00%`, because the only cells with a price are the flops.

Every stage of a chip flow leaves the design in a legal but half-finished state. Stopping to
look at one is how you debug the flow instead of guessing. `stat` costs nothing, so use it
between any two passes you want to compare.

## Summary

- A run has six top-level steps. One of them, `synth`, has twenty-six sub-passes.
- `proc` turns behaviour into hardware, `opt` deletes, and `techmap` splits wide cells into
  narrow ones.
- `dfflibmap` maps flip-flops and `abc` maps combinational logic. They are separate commands;
  forgetting `dfflibmap` under-reported this counter's area by 4×.
- `Scl_LibertyReadGenlib()` lines are normal. `ERROR:` is not.

Next: [Standard cells](guide/standard-cells-are-real.md). Every command on this page pointed
`-liberty` at the same 13 MB file; the next page opens it.
