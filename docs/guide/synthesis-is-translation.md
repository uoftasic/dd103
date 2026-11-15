# What synthesis does

This page walks through what Yosys does to your SystemVerilog between reading the file and
printing the final list of cells. It only shows tool output, so you don't need to run anything
while you read. You'll run every step shown here yourself, on the same counter, in
[Lab 02, Part 3](../labs/lab-02-rtl-becomes-gates-overview.md#part-3-watch-synth-work-on-a-counter).

A synthesis run on even a small design prints roughly six hundred lines. None of them says
`ERROR`, and at the bottom there is a number. If you scroll back up you'll find `PROC_ARST`,
`WREDUCE`, `ALUMACC`, `dch -f` and a warning about multi-output cells, which is a lot to make
sense of. All six hundred lines come from just six steps, though, and one of those six does most
of the work.

## The example design

Here is a 4-bit counter with an enable and an asynchronous reset. It is `src/counter.sv` in the
[Lab 02](../labs/lab-02-rtl-becomes-gates-overview.md) package
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

The ASIC flow for it is a single Yosys command line: `read_verilog -sv`, then
`synth -top counter`, `dfflibmap -liberty`, `abc -liberty`, `opt_clean` and `stat -liberty`, with
every `-liberty` pointed at the SKY130 liberty file. On this counter it prints 627 lines. Yosys
numbers every pass it runs, so if you keep only the lines that start with a number, you're left
with the top-level steps:

```
1. Executing Verilog-2005 frontend: counter.sv
2. Executing SYNTH pass.
3. Executing DFFLIBMAP pass (mapping DFF cells to sequential cells from liberty file).
4. Executing ABC pass (technology mapping using ABC).
5. Executing OPT_CLEAN pass (remove unused cells and wires).
6. Printing statistics.
```

That makes six steps. The first one says "Verilog-2005 frontend" even though the file is `.sv`,
because Yosys's front end grew out of a Verilog-2005 parser; the `-sv` flag asks it to accept
SystemVerilog as well.

## Synthesis as translation

Your source says "add one to `count`", but SKY130 has no word for "add". Its whole vocabulary is
a few hundred fixed nouns such as `xnor2_1`, `maj3_1`, `a31oi_1` and `nand4_1`, and anything you
want to say has to be said with those.

So Yosys works like a translator into a language with a small, fixed dictionary: it has to say
what you meant using only the words that exist. The result has an accent. There is no error in it
and no meaning has been lost, but the sentence has the shape the target language forces on it.

If you send the same sentence to an iCE40 FPGA, the accent changes to `SB_LUT4`, `SB_CARRY` and
`SB_RAM40_4K`. The meaning stays the same, but the nouns available to express it are different.
That difference is the subject of [FPGA and ASIC targets](../guide/warehouse-and-empty-lot.md).

## Inside `synth`

Step 2, `synth`, does almost all of the work. It runs passes of its own, numbered `2.1`, `2.2`
and so on:

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

That is twenty-six passes. `synth` is really shorthand for a script somebody else wrote, and you
could type its contents in yourself, which is what
[Lab 04](../labs/lab-04-reading-the-receipt-overview.md) has you do.

Eleven of the twenty-six are some flavour of `opt`. Yosys optimizes after every structural change
rather than once at the end, because each structural change leaves behind new unused logic that
can be thrown away.

> **Version note.** Everything on this page is Yosys 0.68, as shipped in
> `hpretl/iic-osic-tools:2026.08`. The pass names stay the same from one version to the next, but
> the numbering changes. If your sub-pass numbers don't match the list above (here `2.13` is
> `SHARE`), you're running a different version of Yosys.

## The five main passes

You can write the whole flow in one line:

`proc` → `opt` → `techmap` → `dfflibmap` → `abc`

Most of the other sub-passes of `synth` are either one of these under a more specific name or a
housekeeping pass. (`dfflibmap` isn't part of `synth` at all; it's step 3.) Here is what each of
the five does, along with `hierarchy`, which always runs first:

| Pass | What it does |
|---|---|
| `hierarchy` | Decides which module is the top and connects up the instances below it. |
| `proc` | Turns your `always` blocks into cells. Before `proc` an `always_ff` is a description of behaviour; after it, it's a multiplexer and a flip-flop. |
| `opt` | Throws away work that isn't needed: it folds constants, deletes unreachable cells, and merges two identical cells into one. |
| `techmap` | Splits wide cells into single-bit ones, so a 4-bit `$add` becomes a pile of one-bit gates. |
| `dfflibmap` | Replaces every generic flip-flop with a named flip-flop from the liberty file. It touches flip-flops and nothing else. |
| `abc` | Replaces everything that isn't a flip-flop with named cells from the liberty file. It handles combinational logic only. |

## How the design changes shape

If you stop after each pass and run `stat`, you can see what each one did to the counter:

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

After `hierarchy` there are two cells. Your `always_ff` block hasn't been touched yet; it is
still a process, which is why `stat` can't see any flip-flops.

After `proc` there are five. The `if/else if` has become a `$mux`, the `!rst_n` a `$not`, and
`count <= …` a `$adff`, which is a D flip-flop with an asynchronous reset. At this point your
control flow has been turned into hardware.

After `opt` the count is back down to two. `opt` noticed that a mux feeding a flip-flop's D
input, choosing between the flop's own output and a new value, is really an enable. It folded the
`$mux`, `$not`, `$logic_not` and `$adff` into a single `$adffe`, one flip-flop with a built-in
enable pin. In other words, `opt` recognised an idiom you wrote as control flow and named it as
one piece of hardware. Whether SKY130 actually has that piece of hardware is a separate question;
as you'll see below, SKY130 has no single cell for it.

After `techmap` there are forty-eight. The count went up because `techmap` split the 4-bit
`$add` and the 4-bit `$adffe` into single-bit gates, since SKY130 has no 4-bit cells of any
kind. In names such as `$_AND_`, `$_XOR_` and `$_DFFE_PN0P_`, the leading underscore means the
cell is generic: a one-bit gate that doesn't belong to any technology yet. None of these
forty-eight gates is a SKY130 cell.

## Two mappers

The netlist is now a mix of combinational gates and flip-flops, and two different passes, run
as separate commands, convert them into SKY130 cells:

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

`dfflibmap` mapped the flops and `abc` mapped everything else, and neither touched the other's
cells. (Why `dfflibmap` mapped `$_DFF_PN0_` rather than the `$_DFFE_PN0P_` that `opt` built is
the subject of the next subsection.)

The reason there are two mappers is that ABC is a Boolean optimizer. It works by rewriting logic
functions, so it needs every cell it handles to be a function of its inputs. Here is what the
liberty file says about two cells, `maj3_1` from your Lab 01 adder and `dfrtp_1` from the
counter:

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

`maj3_1` declares a Boolean expression, but `dfrtp_1` declares no function at all; what it
declares is state, and a Boolean rewriter has nothing it can rewrite in that. So ABC is given
only the combinational logic, and a separate, much simpler pass matches flip-flops by the shape
of their clock, reset and enable. That is why the flow has two mapping commands, and it's also
why forgetting one of them fails in such a confusing way.

### Flip-flop shapes in the library

`dfflibmap` mapped `$_DFF_PN0_`, a plain flop with an asynchronous reset, rather than the
`$_DFFE_PN0P_` enable flop that `opt` built. To see why, look higher up in its output, where it
lists every flip-flop shape that SKY130 has a cell for:

```
    \sky130_fd_sc_hd__dfrtp_1 _DFF_PN0_ (.CLK( C), .D( D), .Q( Q), .RESET_B( R));
    \sky130_fd_sc_hd__edfxtp_1 _DFFE_PP_ (.CLK( C), .D( D), .DE( E), .Q( Q));
    ...
    unmapped dff cell: $_DFFE_PN_
```

SKY130's only enable flop, `edfxtp_1`, has no reset pin. Your counter needs both an enable and
an asynchronous reset, and no single cell provides both, so `dfflibmap` used the reset flop and
rebuilt the enable out of logic. That is where the four `$_MUX_` in the half-mapped design at the
end of this page come from, and eventually the `a31oi_1`, `nand2_1` and `nand4_1` in the final
cell list. (These are different from the four `$_MUX_` that `techmap` produced: the `abc` inside
`synth` had already folded those into six generic gates, as [Two ABC runs](#two-abc-runs)
shows.)

It was the library that made this decision, not your code. If you synthesized the same RTL for a
target that has a flop with both an enable and a reset, those extra cells wouldn't appear.

## Leaving out `dfflibmap`

Deleting just that one command from the flow produces no error at all. The exit status is 0, and
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
the generic `$_DFFE_PN0P_`. SKY130 has no cell by that name, so `stat` has no area to give
them. It says so once, in the warning line, and then reports a total that leaves them out.

With `dfflibmap` in place, the same design comes out as:

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

That is 37.54 µm² against 148.89 µm². Leaving out one line of the flow under-reported the design
by a factor of four, and the only sign of it was a single warning line among 600-odd.

`Area for cell type … is unknown!` always means the same thing: a cell in your netlist isn't in
the liberty file. Ninety percent of the time it's a generic `$_…_` cell, and ninety percent of
those are flip-flops you forgot to map. (The harmless exception is `$scopeinfo`, which you met in
Lab 01; it's a bookkeeping marker rather than hardware.)

Area is the number you'll quote in every design review, and a missing `dfflibmap` is the easiest
way to quote one that is wrong by 4×. On any design with a clock, check that
`of which used for sequential elements` is not `0.00%`.

## ABC and the liberty file {#abcs-skipped-cell-warnings}

In step 4, before ABC maps anything, it loads the cell library and prints a warning:

```
4.1. Extracting gate netlist of module `\counter' to `<abc-temp-dir>/input.blif'..
ABC: using cached merged SCL: /tmp/yosys-liberty-scl-cache/yosys_merged_951f6b0f.scl (1 files)
...
ABC: + read_blif <abc-temp-dir>/input.blif
ABC: + read_scl /tmp/yosys-liberty-scl-cache/yosys_merged_951f6b0f.scl
ABC: Warning: Detected 9 multi-output cells (for example, "sky130_fd_sc_hd__fa_1").
```

ABC isn't reading the 13 MB liberty file here. The first time you run `abc -liberty` on a
library, Yosys converts the file into ABC's own compact format, an `.scl` file, and keeps it in
`/tmp/yosys-liberty-scl-cache/`. Every later run loads that copy instead and says so in the
`using cached merged SCL` line, which is why that line is missing from the very first run after
you start the desktop.

The warning is about the nine cells in the library that have more than one output, such as the
full adder `fa_1`, and
[Lab 01's Going further](../labs/lab-01-one-adder-two-targets-overview.md#going-further-optional)
explains why ABC doesn't use it. Like the rest of this block, it's normal output on a successful
run, and it appears every time you use `abc -liberty` on SKY130. If a run really does fail, Yosys
prints a line beginning with `ERROR:` and stops.

ABC can't use every other cell in the library either. You can see which ones it leaves out by
asking it to read the liberty file itself, with `yosys-abc -c "read_lib -w $LIB"` (`yosys-abc`
is the copy of ABC that ships with Yosys, and `LIB` is set as in Lab 02). It prints a line for
every cell it skips, 94 of them, like these:

```
Scl_LibertyReadGenlib() skipped cell "sky130_fd_sc_hd__decap_12" without logic function.
Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfrtp_1".
Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfxtp_1".
Scl_LibertyReadGenlib() skipped three-state cell "sky130_fd_sc_hd__ebufn_1".
```

and then the totals:

```
Library "sky130_fd_sc_hd__tt_025C_1v80" from "…tt_025C_1v80.lib" has 334 cells
     (94 skipped: 63 seq; 13 tri-state; 18 no func; 0 dont_use; …).  Time = 0.15 sec
```

The library has 428 cells (the next page counts them), so ABC can use 334 of them and skips the
other 94. Of those 94, 63 are flip-flops and latches, the kind of cell that `dfflibmap` handled
one step earlier. ABC isn't rejecting them; it's the combinational mapper, and they aren't
combinational logic, so it leaves them out of consideration. That's why
`sky130_fd_sc_hd__dfrtp_1` is on ABC's skipped list even though `dfflibmap` used four of them in
this same flow: the two tools do different jobs with the same library.

The other 31 are cells with no logic to speak of: `decap` (filler capacitors), `diode` (antenna
protection), and `ebufn`/`einv` (tri-state buffers, which have a third output state that Boolean
algebra has no symbol for).

## Two ABC runs

The sub-pass list includes `2.22. Executing ABC pass` inside `synth`, and then you run
`abc -liberty` yourself as step 4. These are two separate calls to ABC.

The one inside `synth` isn't given a liberty file, so it optimizes into a generic set of gates:

```
ABC RESULTS:               AND cells:        1
ABC RESULTS:              NAND cells:        1
ABC RESULTS:               NOT cells:        1
ABC RESULTS:              XNOR cells:        1
ABC RESULTS:               XOR cells:        2
```

Those six technology-neutral gates are what the 48 from `techmap` boil down to. Your
`abc -liberty` then optimizes again, this time knowing which cells SKY130 has and what each one
costs, and ends up with seven real cells. Because the second run can make choices that the first
had no basis for, it isn't redundant.

## A half-mapped design

A `stat` placed between `dfflibmap` and `abc` shows the design halfway through mapping:

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

Four real `sky130_fd_sc_hd__dfrtp_1` cells sit next to ten generic gates in the same netlist.
This is the mirror image of the run without `dfflibmap`: there the sequential area was `0.00%`,
and here it is `100.00%`, because the flops are the only cells with a known area.

Every stage of a chip flow leaves the design in a legal but half-finished state, and stopping to
look at one of those states lets you debug the flow instead of guessing. `stat` costs nothing to
run, so use it between any two passes you want to compare.

## Summary

- A run has six top-level steps, and one of them, `synth`, has twenty-six sub-passes of its own.
- `proc` turns behaviour into hardware, `opt` deletes logic that isn't needed, and `techmap`
  splits wide cells into narrow ones.
- `dfflibmap` maps flip-flops and `abc` maps combinational logic. They are separate commands, and
  forgetting `dfflibmap` made this counter's area come out 4× too small.
- ABC's `Detected 9 multi-output cells` warning is normal output; a line starting with `ERROR:`
  means the run really failed.

Next: [Standard cells](../guide/standard-cells-are-real.md). Every command on this page pointed
`-liberty` at the same 13 MB file, and the next page opens it up.
