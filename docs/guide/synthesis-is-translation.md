# Synthesis is translation with an accent

**Question this page answers:** *What is Yosys actually doing while all that text scrolls
past?*

You ran one command. Roughly seven hundred lines went by, none of them said `ERROR`, and at
the bottom was a number. If you scrolled back up you found `PROC_ARST`, `WREDUCE`,
`ALUMACC`, `dch -f`, and a hundred lines about cells being *skipped*.

It is not seven hundred things. It is **six**, and one of them is doing most of the work.

## Count them yourself

Here is a 4-bit counter with an enable and an async reset. Eleven lines, nothing clever — it is
`src/counter.sv` in the [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) package
([on GitHub](https://github.com/uoftasic/dd103/tree/main/labs/lab-02-rtl-becomes-gates/src/counter.sv)).
Copy it next to you and every command below runs as written.

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

Run the ASIC flow on it and measure the flood:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "read_verilog -sv counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
          stat -liberty $LIB" 2>&1 | wc -l
```

```
726
```

Now ask only for the top-level steps. Yosys numbers every pass it runs, so one `grep` strips
the flood down to the skeleton:

```bash
yosys -p "read_verilog -sv counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
          stat -liberty $LIB" 2>&1 | grep -E '^[0-9]+\. '
```

```
1. Executing Verilog-2005 frontend: counter.sv
2. Executing SYNTH pass.
3. Executing DFFLIBMAP pass (mapping DFF cells to sequential cells from liberty file).
4. Executing ABC pass (technology mapping using ABC).
5. Executing OPT_CLEAN pass (remove unused cells and wires).
6. Printing statistics.
```

Six steps. 726 lines. The whole flow fits on a Post-it.

## Why "translation with an accent"

Your source says *"add one to `count`"*. SKY130 has no word for *add*. Its vocabulary is
`xnor2_1`, `maj3_1`, `a31oi_1`, `nand4_1` — a few hundred fixed nouns, and nothing else.

So Yosys is a translator working into a language with a **small, fixed dictionary**. It has
to say what you meant using only words that exist. That is the accent: not an error, not a
loss of meaning, just the shape the target language forces on the sentence.

Send the same sentence to an iCE40 and the accent changes — `SB_LUT4`, `SB_CARRY`,
`SB_RAM40_4K`. Same meaning, different available nouns. That is
[the warehouse and the empty lot](guide/warehouse-and-empty-lot.md) said in one word.

## `synth` is not a step, it is a macro

Step 2 is doing almost everything. Ask it to show its own numbering:

```bash
yosys -p "read_verilog -sv counter.sv; synth -top counter" 2>&1 | grep -E '^2\.[0-9]+\. '
```

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

Twenty-six passes. `synth` is a **shorthand for a script somebody else wrote**, and you can
type its contents yourself — which is exactly what
[Lab 04](labs/lab-04-reading-the-receipt-overview.md) makes you do.

Eleven of those twenty-six are some flavour of `opt`. Optimization is not a step at the end;
it runs after every structural change, because every structural change creates new garbage
to throw away.

## The five names that matter

The whole flow, as a sentence you can hold in your head:

**`proc` → `opt` → `techmap` → `dfflibmap` → `abc`**

Everything else in that list of twenty-six is one of those five wearing a more specific name,
or a housekeeping pass. Here is each one's job, plus `hierarchy`, which always goes first:

| Pass | Its job, in one line |
|---|---|
| `hierarchy` | Decide which module is the top and connect the instances below it. |
| `proc` | Turn your `always` blocks into cells. Before `proc` an `always_ff` is *behaviour*; after it, it is a multiplexer and a flip-flop. |
| `opt` | Throw work away — fold constants, delete unreachable cells, merge two identical cells into one. |
| `techmap` | Shred wide cells into single-bit ones. A 4-bit `$add` becomes a pile of one-bit gates. |
| `dfflibmap` | Replace every generic flip-flop with a **named flip-flop** from the liberty file. Flip-flops only. |
| `abc` | Replace everything that is **not** a flip-flop with named cells from the liberty file. Combinational logic only. |

## Watch the design change shape

Stop after each pass and count cells. Run these four in a row:

```bash
for S in "hierarchy -top counter" \
         "hierarchy -top counter; proc" \
         "hierarchy -top counter; proc; opt" \
         "hierarchy -top counter; proc; opt; techmap"; do
  echo "### $S"
  yosys -p "read_verilog -sv counter.sv; $S; stat" 2>/dev/null | sed -n '/cells$/,/^$/p'
done
```

**What you should see:**

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

Read that as four sentences.

**After `hierarchy`:** two cells. Your `always_ff` block has not been touched — it is still a
*process*, which is why `stat` cannot see the flip-flops yet.

**After `proc`:** five. The `if/else if` became a `$mux`, the `!rst_n` became a `$not`, and
`count <= …` became `$adff` — a D flip-flop with async reset. Your control flow is now
hardware.

**After `opt`:** back down to two. `opt` noticed that a mux feeding a flip-flop's D input,
selecting between the flop's own output and something new, *is* an enable — and folded the
`$mux`, `$not`, `$logic_not` and `$adff` into a single `$adffe`: one flip-flop with a
built-in enable pin. That is `opt` recognising an idiom you wrote as control flow and naming
it as one piece of hardware. Whether SKY130 can actually sell you that piece is a separate
question, and the answer below is *no*.

**After `techmap`:** forty-eight. That is not a regression. `techmap` takes the 4-bit `$add`
and the 4-bit `$adffe` and splits them into **single-bit** gates, because SKY130 has no 4-bit
anything. `$_AND_`, `$_XOR_`, `$_DFFE_PN0P_` — the leading underscore means *generic*: a
one-bit gate that does not belong to any technology yet.

Forty-eight generic gates is the last point at which your design is still technology-neutral.

## Two mappers, not one

Here is the thing that will bite you in Lab 04.

Your netlist at this point is a mix of combinational gates and flip-flops. **Two different
tools convert them into SKY130 cells**, and they run as separate commands:

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

`dfflibmap` did the flops. `abc` did everything else. Neither touched the other's cells.

**Why two?** Because ABC is a *boolean* optimizer. It works by rewriting logic functions, and
it needs every cell to be a function of its inputs. Look at what the liberty file says these
two cells are:

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

`maj3_1` declares a boolean expression. `dfrtp_1` declares no function at all — it declares
**state**. There is nothing there for a boolean rewriter to rewrite, so ABC is handed the
combinational logic and nothing else, and a separate, much simpler pass matches flip-flops by
their clock/reset/enable shape.

That is why the flow has two mapping commands instead of one, and why forgetting one of them
fails so strangely.

### The library gets a vote

Notice what `dfflibmap` reported: it mapped `$_DFF_PN0_`, a plain flop with an async reset —
not the `$_DFFE_PN0P_` enable flop that `opt` built. Scroll up in its output and you can see
why. It lists every flip-flop shape SKY130 has a cell for:

```
    \sky130_fd_sc_hd__dfrtp_1 _DFF_PN0_ (.CLK( C), .D( D), .Q( Q), .RESET_B( R));
    \sky130_fd_sc_hd__edfxtp_1 _DFFE_PP_ (.CLK( C), .D( D), .DE( E), .Q( Q));
    ...
    unmapped dff cell: $_DFFE_PN_
```

SKY130's one enable flop, `edfxtp_1`, **has no reset pin**. Your counter needs enable *and*
async reset, and no single cell does both — so `dfflibmap` bought the reset flop and rebuilt
the enable out of logic. That is where the four `$_MUX_` cells, and eventually the
`a31oi_1` / `nand2_1` / `nand4_1` in your final receipt, came from.

**The library, not your code, decided that.** Same RTL, a target with an enable-and-reset
flop, and those cells never appear.

## Leave out `dfflibmap` and see what happens

Delete exactly one command from the flow:

```bash
yosys -p "read_verilog -sv counter.sv; synth -top counter;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

Nothing errors. Exit status is 0. And the receipt says:

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

ABC mapped the six combinational gates perfectly and walked straight past the four
flip-flops, which are still generic `$_DFFE_PN0P_`. There is no cell in SKY130 called
`$_DFFE_PN0P_`, so `stat` cannot price them, says so once, and quietly reports a total that
leaves them out.

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

**37.54 µm² versus 148.89 µm².** One missing line under-reported the design by a factor of
four, and the only sign was a single line of warning in the middle of 700-odd.

> `Area for cell type … is unknown!` always means the same thing: a cell in your netlist is
> not in the liberty file. Ninety percent of the time it is a generic `$_…_` cell, and ninety
> percent of *those* are flip-flops you forgot to map.

**Why an engineer cares:** area is the number you will quote in every design review, and this
is the easiest way in the world to quote one that is wrong by 4×. Check that
`of which used for sequential elements` is not `0.00%` on any design that has a clock.

## The wall of warnings that is not a wall of errors

Scroll into step 4 and you will hit this:

```
ABC: + read_lib -w /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
ABC: Parsing finished successfully.  Parsing time =     0.07 sec
ABC: Scl_LibertyReadGenlib() skipped cell "sky130_fd_sc_hd__decap_12" without logic function.
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfrtp_1".
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfxtp_1".
ABC: Scl_LibertyReadGenlib() skipped three-state cell "sky130_fd_sc_hd__ebufn_1".
```

…and so on for **94 lines**. Expect to hit this at least once, and expect it to look like
your run just failed.

It did not. Count what those lines actually are:

```bash
yosys -p "read_verilog -sv counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
          stat -liberty $LIB" 2>&1 | grep -c 'Scl_LibertyReadGenlib'
```

```
94
```

And ABC itself tells you the total on the line right after the wall:

```
ABC: Library "sky130_fd_sc_hd__tt_025C_1v80" from "…tt_025C_1v80.lib" has 334 cells
     (94 skipped: 63 seq; 13 tri-state; 18 no func; 0 dont_use; …).  Time = 0.12 sec
```

334 usable, 94 skipped. **63 of the 94 are flip-flops and latches** — the exact cells
`dfflibmap` already placed one step earlier. ABC is not rejecting them; it is declining to
consider them, because it is the combinational mapper and they are not combinational logic.

Note that `sky130_fd_sc_hd__dfrtp_1` appears in that skipped list *in the same run* where
`dfflibmap` used four of them. Two tools, two jobs, one library.

The other 31 are cells with no logic to speak of: `decap` (filler capacitors), `diode`
(antenna protection), and `ebufn`/`einv` (tri-state buffers, which have a third output state
that boolean algebra has no symbol for). None of them are things you asked for.

> **This is normal output on a successful run.** It appears every single time you use
> `abc -liberty` on SKY130 and it appears before ABC does anything useful. If your run
> actually failed, Yosys prints a line beginning with `ERROR:` and stops — `Scl_…` lines are
> not that.

## The question you were too embarrassed to ask

**Why does ABC run twice?**

Because it does. Look at the sub-pass list again: `2.22. Executing ABC pass` is inside
`synth`, and then you run `abc -liberty` yourself as step 4. They are not the same call.

The one inside `synth` has no liberty file, so it optimizes into a generic gate set:

```
ABC RESULTS:               AND cells:        1
ABC RESULTS:              NAND cells:        1
ABC RESULTS:               NOT cells:        1
ABC RESULTS:              XNOR cells:        1
ABC RESULTS:               XOR cells:        2
```

Six technology-neutral gates — that is the 48 from `techmap` boiled down. Your `abc -liberty`
then does the same optimization again, this time knowing what SKY130 actually stocks and what
each item costs, and lands on seven real cells.

Optimize first without a price list, then again with one. It is not redundant; the second
pass can make choices the first had no basis for.

> **Version note.** Everything above is Yosys **0.64**, as shipped in
> `hpretl/iic-osic-tools:2026.04`. Check with `yosys -V`. Pass names are stable across
> versions but pass *numbering* is not — if your `2.14` is an `OPT` where this page shows a
> `SHARE`, you are on a different Yosys, and the internet's advice about option names will
> not apply to you either.

## Try this

Put a `stat` between `dfflibmap` and `abc` and look at the design halfway through mapping:

```bash
yosys -p "read_verilog -sv counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; stat -liberty $LIB" 2>&1 | tail -22
```

**What you should see:**

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

Four real `sky130_fd_sc_hd__dfrtp_1` sitting next to ten generic gates, in the same netlist,
at the same time. A half-translated design — and the mirror image of the broken run above.
There, sequential area was `0.00%`; here it is `100.00%`, because the only cells with a price
are the flops.

**Why an engineer cares:** every stage of a chip flow leaves the design in a legal but
half-finished state, and being able to stop and look at one is how you debug the flow instead
of guessing at it. `stat` is free. Put it everywhere.

## What to remember

- Six top-level steps; `synth` is twenty-six of them wearing a trenchcoat.
- `proc` makes hardware out of behaviour. `opt` deletes. `techmap` splits wide into narrow.
- **`dfflibmap` does flip-flops. `abc` does combinational logic. They are separate commands
  and forgetting one costs you 4× on your area number.**
- 94 `Scl_LibertyReadGenlib()` lines are normal. `ERROR:` is not.

Next: [A standard cell is a real thing](guide/standard-cells-are-real.md) — every command on
this page pointed `-liberty` at the same 13 MB file without ever opening it. Go and find out
what is inside, and who drew it.
