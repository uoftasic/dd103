# Lab 02: RTL becomes gates

Lab 01 told you your adder became `4 × maj3_1 + 8 × xnor2_1`, but a list of cell names doesn't
show what is wired to what. In this lab you draw one full adder twice, once in your words and
once in SKY130's, rewrite one line of it and predict what changes, then watch `synth` work on a
counter pass by pass and open the cell library those names come from.

Time: about 2.5 hours, not counting Going further.

Package: [`labs/lab-02-rtl-becomes-gates/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-02-rtl-becomes-gates)

## Before you start

- [Lab 01](../labs/lab-01-one-adder-two-targets-overview.md) is complete, so you have run
  `abc -liberty` at least once and `yosys -V` says `Yosys 0.68`.
- Read [FPGA and ASIC targets](../guide/warehouse-and-empty-lot.md),
  [What synthesis does](../guide/synthesis-is-translation.md) and
  [Standard cells](../guide/standard-cells-are-real.md).
- You need a way to look at an SVG: the noVNC desktop's file manager, or
  `firefox results/*.svg &`.

Start every part from the package directory, in a terminal where you have sourced
`.designinit`:

```bash
mod dd103
cd labs/lab-02-rtl-becomes-gates
```

## Part 1: Two pictures of a full adder

What does one full adder look like before and after it is mapped to SKY130 cells, and which of
your operators became which cell?

Yosys keeps one design in memory and rewrites it in place. `show` draws whatever is in memory at
that moment, so running it at two different points gives two views of the same design:

| After this | The design is made of | Whose names are on it |
|---|---|---|
| `proc; opt` | `$xor`, `$and`, `$or`, `$add`, `$mux` | yours |
| `abc -liberty` | `sky130_fd_sc_hd__*` | the foundry's |

Between those two points, `dfflibmap -liberty` replaces generic flip-flops with library flops.
The full adder has no flip-flops, so here it does nothing; it's in the script because a design
that does have flops needs it, as you'll see in Part 3. After that, `abc -liberty` covers
everything combinational with cells from the liberty file, and it picks them to optimize area.

1. Run the package's script, `show.ys`, which draws one picture after `proc; opt` and one after
   `abc -liberty`. It takes about a second.

   ```bash
   make
   ```

2. Open `results/rtl.svg`. You should see five boxes, and every wire label is something you
   typed.

   ![The full adder after proc; opt — five generic operator boxes](../assets/img/lab02-fulladder-rtl.svg)

   The octagons `a`, `b`, `cin`, `sum` and `cout` are your ports. The boxes are `$2 $xor`,
   `$3 $and`, `$4 $xor`, `$5 $and` and `$6 $or`, from these two lines:

   ```systemverilog
   assign sum  = a ^ b ^ cin;
   assign cout = (a & b) | (cin & (a ^ b));
   ```

   The source has six operators: two `^` in the first line, and one `&`, one `|`, one `&` and
   one `^` in the second. Why are there only five boxes? Follow the fan-out from `$4 $xor`.

   <details>
   <summary>Answer</summary>

   `opt` noticed that `a ^ b` appears in both lines and computed it once. `$4 $xor` has one
   output and two destinations; the black dot is the sharing.

   </details>

   This is the last picture in the flow that still describes your source code, so if your RTL is
   wrong, this is where you can still see the mistake in terms of the code you wrote.

3. Open `results/gates.svg` next to it. You should see two boxes, labelled like this:

   ![The same full adder after abc -liberty — two SKY130 standard cells](../assets/img/lab02-fulladder-gates.svg)

   ```
   $95   sky130_fd_sc_hd__maj3_1     A B C -> X
   $94   sky130_fd_sc_hd__xor3_1     A B C -> X
   ```

   The five ports and their names are the same, because they are the module boundary and nothing
   is allowed to rename them. Everything between them has been replaced by two cells whose names
   you didn't choose and whose pins are called `A`, `B`, `C` and `X`. `stat` prices the two cells,
   and you'll find its report in `results/show.log`:

   ```
   === fulladder ===
           2   33.782 cells
           1    10.01   sky130_fd_sc_hd__maj3_1
           1   23.773   sky130_fd_sc_hd__xor3_1
      Chip area for module '\fulladder': 33.782400
   ```

   The left picture describes behaviour, and the right picture is a bill of materials for
   something a foundry will etch; synthesis is the step that turns the first into the second.

4. Work out which boxes became which cell, bearing in mind that the boxes don't map one-for-one
   onto cells.

   <details>
   <summary>Answer</summary>

   - `sum = a ^ b ^ cin`, a three-input XOR, became one `xor3_1`. SKY130 has a 3-input XOR
     cell, so the two `$xor` boxes collapsed into it.
   - `cout = (a & b) | (cin & (a ^ b))`, three boxes, became one `maj3_1`, because carry-out is
     the majority function: true exactly when at least two of $a$, $b$, $c_{\text{in}}$ are
     true. ABC worked that out from the truth table and found a single cell for it.

   </details>

5. In `src/fulladder.sv`, rewrite the carry as the majority function written out:

   ```systemverilog
   assign cout = (a & b) | (b & cin) | (a & cin);
   ```

   Before you run anything, write down how many boxes you expect in `results/rtl.svg` and which
   cells you expect in `results/gates.svg`.

6. Run `make` and open both pictures again.

   You should see seven boxes in `results/rtl.svg` (three `$and`, two `$or`, two `$xor`), and the
   same two cells in `results/gates.svg`, `sky130_fd_sc_hd__maj3_1` and
   `sky130_fd_sc_hd__xor3_1`, with `Chip area for module '\fulladder': 33.782400`.

   Why did one picture change and the other not?

   <details>
   <summary>Answer</summary>

   The RTL view draws your operators, so a different spelling gives different boxes. Synthesis
   works from the function your logic computes rather than from the way you wrote it, and both
   lines compute the majority function, so they map to the same cells. The same fact works in
   the other direction too: you can't read a gate netlist and recover the RTL you wrote.

   </details>

7. Put the shipped file back and rebuild:

   ```bash
   git checkout src/fulladder.sv
   make
   ```

You should see `results/rtl.svg` with five operator boxes again, `results/gates.svg` with
`sky130_fd_sc_hd__maj3_1` and `sky130_fd_sc_hd__xor3_1`, and `Chip area ... 33.782400` in
`results/show.log`. If `show` fails, or you try the image's `sak-v2svg.sh` script for diagrams,
see [Troubleshooting](../reference/troubleshooting.md).

## Part 2: Diagram size limits

How big can a gate diagram get before it stops helping? It's better to find out here, on four
full adders, than in Lab 05.

1. `make bigger` runs the same two `show` calls on `ripple4`, four full adders instead of one.
   Before you run it, write down how many times bigger you expect the gate view's canvas area
   (width × height) to be.

2. Run it:

   ```bash
   make bigger
   ```

   It prints the canvas size of every SVG in `results/`:

   ```
   ==============================================================
    DIAGRAM CANVAS SIZES  (graphviz points; 72 pt = 1 inch)
   ==============================================================
   results/gates.svg                  width="453pt" height="171pt"
   results/gates_ripple4.svg          width="3189pt" height="1264pt"
   results/rtl.svg                    width="666pt" height="172pt"
   results/rtl_ripple4.svg            width="1265pt" height="648pt"
   ```

3. Open `results/rtl_ripple4.svg`. It shows four boxes labelled `slice[0].fa` to
   `slice[3].fa`, chained through `c`: the ripple adder you would draw on paper.

   ![ripple4 after proc; opt — four fulladder boxes chained through the carry](../assets/img/lab02-ripple4-rtl.svg)

4. Open `results/gates_ripple4.svg`. It is 44 inches wide: twelve cells, a scatter of bit-slice
   splitters, and no visual centre. Squashed to the width of this page it looks like this, and
   zooming in doesn't make it any easier to follow:

   ![ripple4 after abc -liberty — a 3189 pt wide mat of cells](../assets/img/lab02-ripple4-gates.svg)

You should see that the gate view grew 52× in canvas area going from one adder to four, while
the RTL view stayed readable.

For the rest of the course, draw the gate view of one small block only, and the RTL view of
anything bigger. The elevator FSM in [Lab 05](../labs/lab-05-elevator-overview.md) is 76 cells, and
its gate view comes out 883 × 9018 pt, so you'll draw its RTL instead. Experience doesn't make
this limit go away, and it's the reason professional flows show you numbers and layouts rather
than gate schematics.

## Part 3: Watch synth work on a counter

Which pass turns the counter's flip-flops into SKY130 cells, which pass maps its logic, and what
happens to the area when one of them is missing? This part runs the walkthrough from
[What synthesis does](../guide/synthesis-is-translation.md) on `src/counter.sv`, a 4-bit counter
with an enable and an asynchronous reset. Set the liberty path first, because every command
below uses it.

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

1. Run the full ASIC flow on the counter, keeping only the numbered top-level steps:

   ```bash
   yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
             stat -liberty $LIB" 2>&1 | grep -E '^[0-9]+\. '
   ```

   You should see six lines, from `1. Executing Verilog-2005 frontend: src/counter.sv` to
   `6. Printing statistics.`

2. Run the first four passes inside `synth` by hand, stopping after each one to count cells:

   ```bash
   for S in "hierarchy -top counter" \
            "hierarchy -top counter; proc" \
            "hierarchy -top counter; proc; opt" \
            "hierarchy -top counter; proc; opt; techmap"; do
     echo "### $S"
     yosys -p "read_verilog -sv src/counter.sv; $S; stat" 2>/dev/null | sed -n '/cells$/,/^$/p'
   done
   ```

   You should see 2, 5, 2 and then 48 cells. Find the `$adffe` after `opt` and the four
   `$_DFFE_PN0P_` after `techmap`. What did `opt` do between the second and third blocks?

   <details>
   <summary>Answer</summary>

   It recognised the idiom that [What synthesis does](../guide/synthesis-is-translation.md#how-the-design-changes-shape)
   describes: a mux on a flip-flop's D input that chooses between the flop's own output and a new
   value is an enable. So it folded the `$mux`, `$not`, `$logic_not` and `$adff` into a single
   `$adffe`, one flip-flop with a built-in enable pin.

   </details>

3. Now see how the two mappers split the work between them:

   ```bash
   yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
             stat -liberty $LIB" 2>&1 | grep -E 'mapped 4|ABC RESULTS: +sky130'
   ```

   You should see `mapped 4 $_DFF_PN0_ cells to \sky130_fd_sc_hd__dfrtp_1 cells.` from
   `dfflibmap`, then six `ABC RESULTS` lines from `abc`, none of them a flip-flop.

4. See which flip-flop shapes the library has:

   ```bash
   yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
             dfflibmap -liberty $LIB" 2>&1 | grep -E 'unmapped dff|dfrtp_1 _DFF_PN0_|edfxtp_1 _DFFE_PP_'
   ```

   Find `sky130_fd_sc_hd__edfxtp_1 _DFFE_PP_`, the library's only enable flop, and read its pins.
   Then find `unmapped dff cell: $_DFFE_PN_`. Write down why the counter ended up with plain
   `dfrtp_1` flops and extra logic for the enable.

   <details>
   <summary>Answer</summary>

   The counter needs both an enable and an asynchronous reset, and no single SKY130 cell
   provides both: `edfxtp_1` has no reset pin. So `dfflibmap` used the reset flop and the
   enable was rebuilt out of logic. That choice came from what the library offers rather than
   from anything in your code.

   </details>

5. The full flow reports a chip area of `148.892800`. Write down what you expect if you delete
   `dfflibmap` from it: an error, or a number, and if a number, bigger or smaller? Then run it
   and check the exit status:

   ```bash
   yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"; echo "exit=$?"
   ```

   You should see `exit=0`, four `$_DFFE_PN0P_` still in the cell list,
   `Area for cell type $_DFFE_PN0P_ is unknown!`, a chip area of `37.536000` and `0.00%`
   sequential. Why is the area smaller, and which lines would warn you on a design you didn't
   know?

   <details>
   <summary>Answer</summary>

   ABC maps combinational logic only, so the four flip-flops stay generic `$_DFFE_PN0P_`. SKY130
   has no cell by that name, so `stat` can't price them and leaves them out of the total. The
   warnings are `Area for cell type … is unknown!` and `0.00%` sequential on a design with a
   clock.

   </details>

6. Stop after `dfflibmap`, before `abc`, and run `stat` there:

   ```bash
   yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
             dfflibmap -liberty $LIB; stat -liberty $LIB" 2>&1 | tail -22
   ```

You should see 14 cells: four `sky130_fd_sc_hd__dfrtp_1` next to ten generic gates, with
`100.096000 (100.00%)` sequential. This is the mirror image of step 5, because this time the
flops are the only cells that have a price.

## Part 4: Open the cell library

Where does the library keep each fact about one cell, `maj3_1`: what it computes, how big it is,
what transistors it has, what it looks like and how fast it is? This part opens the files
[Standard cells](../guide/standard-cells-are-real.md) describes. Fill in this table as you go:

| Fact about `maj3_1` | File | What it says |
|---|---|---|
| function | | |
| area | | |
| outline (width × height) | | |
| transistors | | |
| drawing (layout polygons) | | |
| timing | | |

Set three paths first:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
REF=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd
LEF=$REF/lef/sky130_fd_sc_hd.lef
```

1. Measure the liberty file:

   ```bash
   ls -lh $LIB
   wc -l $LIB
   grep -c '^    cell (' $LIB
   ```

   You should see `13M`, `173157` lines and `428` cells.

2. Read the `maj3_1` entry:

   ```bash
   awk '/cell \("sky130_fd_sc_hd__maj3_1"\)/,/^    }$/' $LIB | wc -l
   awk '/cell \("sky130_fd_sc_hd__maj3_1"\)/,/^    }$/' $LIB \
     | grep -E '^        area :|^        cell_footprint|^        pin \(|^            direction :|^            function :'
   ```

   You should see `350`, then `area : 10.009600000;`,
   `cell_footprint : "sky130_fd_sc_hd__maj3";`, three input pins, one output pin `X`, and
   `function : "(A&B) | (A&C) | (B&C)";`.

3. Find the same cell as a rectangle in the LEF file:

   ```bash
   grep -A5 '^MACRO sky130_fd_sc_hd__maj3_1$' $LEF
   ```

   You should see `SIZE 3.680 BY 2.720 ;`. Multiply it out and compare with the liberty area.

   <details>
   <summary>Answer</summary>

   $3.680 \times 2.720 = 10.0096$, the liberty area exactly.

   </details>

4. Count the transistors in the cell:

   ```bash
   awk '/^\.SUBCKT sky130_fd_sc_hd__maj3_1 /,/^\.ENDS/' $REF/cdl/sky130_fd_sc_hd.cdl | head -6
   awk '/^\.SUBCKT sky130_fd_sc_hd__maj3_1 /,/^\.ENDS/' $REF/cdl/sky130_fd_sc_hd.cdl | grep -c '^MM'
   ```

   You should see the `.SUBCKT` line with pins `A B C VGND VNB VPB VPWR X`, then `14`.

5. Measure the layout file:

   ```bash
   ls -lh $REF/mag/sky130_fd_sc_hd__maj3_1.mag
   grep -c '^rect' $REF/mag/sky130_fd_sc_hd__maj3_1.mag
   grep '^<< ' $REF/mag/sky130_fd_sc_hd__maj3_1.mag | tr -d '<>' | tr '\n' ' '
   ```

   You should see a 7.4K file, `267` rectangles, and sixteen section names from `nwell` to `end`.

6. Open the cell in Magic. Copy it out of the PDK first, because the PDK tree is read-only and
   Magic dims every layer of a cell it can't edit.

   ```bash
   cp $REF/mag/sky130_fd_sc_hd__maj3_1.mag results/
   magic -d X11 -T sky130A results/sky130_fd_sc_hd__maj3_1.mag
   ```

   `magic130` is the alias `.designinit` sets up for `magic -d X11 -T sky130A`. Magic does not
   zoom to fit when it opens, so type `view` in its console to show the whole cell. You should
   see the picture in [Standard cells](../guide/standard-cells-are-real.md#transistors-and-layout):
   two power rails, fourteen poly stripes crossing diffusion, and pins `A`, `B`, `C` and `X`.

7. Count the timing tables, each a grid of measured delays:

   ```bash
   awk '/cell \("sky130_fd_sc_hd__maj3_1"\)/,/^    }$/' $LIB | grep -c 'values('
   grep -c 'values(' $LIB
   ```

You should see `24` for `maj3_1` and `11101` for the whole library, and a table with a file in
every row.

<details>
<summary>Answer: the table</summary>

| Fact about `maj3_1` | File | What it says |
|---|---|---|
| function | liberty, `sky130_fd_sc_hd__tt_025C_1v80.lib` | `(A&B) \| (A&C) \| (B&C)` |
| area | liberty | `10.009600000` |
| outline (width × height) | LEF, `sky130_fd_sc_hd.lef` | `SIZE 3.680 BY 2.720` |
| transistors | CDL, `sky130_fd_sc_hd.cdl` | 14 |
| drawing (layout polygons) | `mag/sky130_fd_sc_hd__maj3_1.mag` | 267 rectangles |
| timing | liberty | 24 tables |

</details>

## Finishing

### You're done when

Your Part 1 prediction for the rewritten `cout` and your Part 3 prediction for leaving out
`dfflibmap` each have the tool's answer written next to them, and your Part 4 table names a file
for every fact.

To check your run against ours:

| Check | Expected |
|---|---|
| `ls results/*.svg` | `gates.svg` and `rtl.svg` exist |
| `grep -o 'sky130[a-z0-9_]*' results/gates.svg \| sort -u` | `sky130_fd_sc_hd__maj3_1`, `sky130_fd_sc_hd__xor3_1` |
| `grep -c '\$xor' results/rtl.dot` | 2 |
| `grep "Chip area" results/show.log` | `33.782400` |
| `make sizes` after `make bigger` | four SVGs, the largest 3189 pt wide |
| Part 3, step 5 | `exit=0` and a chip area of `37.536000` |
| Part 4, step 1 | `428` cells |

`make` takes about 1 second and peaks around 64 MB; Yosys prints its own `time:` and `MEM:` on
the last line of `results/show.log`. If it takes minutes, you are synthesizing something other
than a full adder.

### Questions

1. In one sentence each, what did `dfflibmap` and `abc` do?

   <details>
   <summary>Answer</summary>

   `dfflibmap` replaced the generic flip-flops with named library flops (the counter's four
   became `sky130_fd_sc_hd__dfrtp_1`), and `abc` replaced everything combinational with named
   cells from the liberty file. See Part 3, step 3.

   </details>

2. Point at a wire in `results/gates.svg` and name the line of SystemVerilog it came from.

   <details>
   <summary>Answer</summary>

   The wire out of `xor3_1` to `sum` comes from `assign sum = a ^ b ^ cin;`, and the wire out
   of `maj3_1` to `cout` comes from the `assign cout` line. See Part 1, step 4.

   </details>

### Submit

Nothing to submit.

## Going further (optional)

More of `synth`, from Part 3, with `LIB` set as in that part:

- Count every line the full flow prints:

  ```bash
  yosys -p "read_verilog -sv src/counter.sv; synth -top counter;
            dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
            stat -liberty $LIB" 2>&1 | wc -l
  ```

- List the sub-passes `synth` runs, and count how many are some form of `OPT`:

  ```bash
  yosys -p "read_verilog -sv src/counter.sv; synth -top counter" 2>&1 | grep -E '^2\.[0-9]+\. '
  ```

  You should see 26 lines, from `2.1. Executing HIERARCHY pass` to `2.26. Executing CHECK pass`.
- See what the `abc` inside `synth` produced, before any liberty file was involved:

  ```bash
  yosys -p "read_verilog -sv src/counter.sv; synth -top counter" 2>&1 | grep 'ABC RESULTS'
  ```

  You should see generic `AND`, `NAND`, `NOT`, `XNOR` and `XOR` counts, six gates in all.

More of the library, from Part 4: [Looking things up in the SKY130
library](../reference/sky130-library-lookups.md) has the commands for the row-height grid, the
`maj3` drive strengths, the `fa_1` full-adder cell, the 18 process corners, the smallest and
largest cells, and the seven cell types the counter used.

Diagrams:

- Both scripts, `show.ys` and `bigger.ys`, open with this line:

  ```tcl
  read_liberty -lib /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
  ```

  With `-lib`, Yosys reads the library only as a catalogue: cell names, pin names and pin
  directions, but no logic. Delete that line from `show.ys` and re-run `make`
  (`git checkout show.ys` puts it back). The netlist and the area are identical, but the picture
  gets worse, because `show` no longer knows which pins are outputs, so it stacks `A B C X` down
  the left side of every cell and draws the arrows on `sum` and `cout` pointing backwards into
  the box. The diagram is only a rendering of the design, and like any rendering it depends on
  its settings.
- For a raster image for slides, `make png` runs `cairosvg` (2.9.0, in the image) at 1200 px
  wide. For anything you'll want to zoom into, use the SVG instead.

Next on the [Course path](../index.md#course-path): read
[Synthesizable SystemVerilog](../guide/the-hardware-dialect.md),
[Inferred latches](../guide/the-latch-you-didnt-ask-for.md) and
[Blocking and non-blocking assignments](../guide/blocking-vs-nonblocking.md), then do
[Lab 03: Three ways to lose a latch](../labs/lab-03-three-ways-to-lose-a-latch-overview.md).
