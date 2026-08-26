# A standard cell is a real thing

**Question this page answers:** *What actually IS a standard cell?*

You have been pasting this path since [Lab 01](labs/lab-01-one-adder-two-targets.md):

```
/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

You know that pointing at it makes `stat` print square micrometres instead of a bare cell
count. You may be assuming it contains something abstract — a model, an estimate, a
placeholder for real hardware.

It does not. It is a **catalogue of physical objects**, and you can count them.

## Measure it

Open a terminal in the workbench and ask three questions:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
ls -lh $LIB
wc -l $LIB
grep -c '^    cell (' $LIB
```

```
-rw-r--r-- 1 root root 13M Apr 16 21:44 /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
173157 /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
428
```

**13 megabytes. 173,157 lines. 428 cells.**

That is the whole vocabulary. Not "a few hundred typical gates" — exactly 428, sitting on
your disk, and you just counted them. Every gate in every design that uses this library is one
of those 428.

> Big chips also contain things that are *not* standard cells, and they live in sibling
> directories: `ls /foss/pdks/sky130A/libs.ref/` also shows `sky130_sram_macros` (memory
> blocks), `sky130_fd_io` (the pads that connect to the outside world), and `sky130_fd_pr`
> (raw transistors, for analog). Everything you build in DD103 comes out of this one file.

## Your design ordered seven of them

Run the counter from [the last page](guide/synthesis-is-translation.md) and look only at what
came back:

```bash
yosys -p "read_verilog -sv counter.sv; synth -top counter;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
          stat -liberty $LIB" 2>&1 | awk '/^6\. Printing statistics/,0' | grep sky130
```

```
        1    6.256   sky130_fd_sc_hd__a31oi_1
        4  100.096   sky130_fd_sc_hd__dfrtp_1
        1    6.256   sky130_fd_sc_hd__lpflow_isobufsrc_1
        1    3.754   sky130_fd_sc_hd__nand2_1
        1    6.256   sky130_fd_sc_hd__nand4_1
        2   17.517   sky130_fd_sc_hd__xnor2_1
        1    8.758   sky130_fd_sc_hd__xor2_1
```

**Seven distinct types out of 428.** The `ripple4.sv` from
[Lab 01](labs/lab-01-one-adder-two-targets.md) used **two**: `maj3_1` and `xnor2_1`.

Synthesis is not open-ended invention. It is ordering from a menu, and the menu is short.

## Open one entry

You already met `sky130_fd_sc_hd__maj3_1` — it was four of the twelve cells in your ripple
adder, at **10.01 µm²** each. Go and read its catalogue entry:

```bash
awk '/cell \("sky130_fd_sc_hd__maj3_1"\)/,/^    }$/' $LIB | wc -l
```

```
350
```

**350 lines for one gate.** Pull out the six that carry the meaning:

```bash
awk '/cell \("sky130_fd_sc_hd__maj3_1"\)/,/^    }$/' $LIB \
  | grep -E '^        area :|^        cell_footprint|^        pin \(|^            direction :|^            function :'
```

```
        area : 10.009600000;
        cell_footprint : "sky130_fd_sc_hd__maj3";
        pin ("A") {
            direction : "input";
        pin ("B") {
            direction : "input";
        pin ("C") {
            direction : "input";
        pin ("X") {
            direction : "output";
            function : "(A&B) | (A&C) | (B&C)";
```

Read the `function` line out loud. **`(A&B) | (A&C) | (B&C)`** — X is high when *at least two
of the three inputs are high*. That is the majority function, it is exactly the carry-out of
a full adder, and it is why your adder came back with four of these.

The entry declares four things a synthesizer needs: **what it computes**, **how big it is**,
**what its pins are called**, and — in the other 344 lines — **how long it takes**.

## The area is not an estimate

`area : 10.0096` looks like a modelled figure. It is not. The same cell has a second entry in
the physical library, and that one is a rectangle:

```bash
grep -A5 '^MACRO sky130_fd_sc_hd__maj3_1$' \
  /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
```

```
MACRO sky130_fd_sc_hd__maj3_1
  CLASS CORE ;
  FOREIGN sky130_fd_sc_hd__maj3_1 ;
  ORIGIN 0.000 0.000 ;
  SIZE 3.680 BY 2.720 ;
  SYMMETRY X Y R90 ;
```

$$3.680 \times 2.720 = 10.0096$$

The area in the liberty file is the width times the height of an actual rectangle of silicon,
to four decimal places. Nothing was rounded, modelled, or guessed. **This cell is 3.68 µm
across.** A human hair is around 70 µm; you could line up nineteen of these across one.

## Why they are called *standard* cells

Ask the physical library for every cell's dimensions at once:

```bash
LEF=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
grep '^  SIZE' $LEF | awk '{print $4}' | sort | uniq -c
```

```
    430 2.720
      7 5.440
```

**430 of the 437 layouts are exactly 2.720 µm tall.** The other seven are exactly double.

Now the widths:

```bash
grep '^  SIZE' $LEF | awk '{print $2}' | sort -g -u | head -4
```

```
0.460
0.920
1.380
1.840
```

Every width is a multiple of **0.460 µm**. `maj3_1` at 3.680 is eight of them.

That is the whole idea, and it is the reason for the name. Cells are drawn to a **fixed
height and a quantised width** so that they snap side by side into rows like text on a page,
with power and ground rails lining up automatically at the top and bottom of every row.
Placement then becomes a problem of arranging tiles, not of drawing transistors.

The alternative — every gate a different shape — is what people did before 1980, by hand,
with tape.

## Somebody drew this

The liberty entry is a description. Two directories over is the thing being described.

The transistors:

```bash
REF=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd
awk '/^\.SUBCKT sky130_fd_sc_hd__maj3_1 /,/^\.ENDS/' $REF/cdl/sky130_fd_sc_hd.cdl | head -6
```

```
.SUBCKT sky130_fd_sc_hd__maj3_1 A B C VGND VNB VPB VPWR X
*.PININFO A:I B:I C:I VGND:I VNB:I VPB:I VPWR:I X:O
MMIN2 X y VGND VNB nfet_01v8 m=1 w=0.65 l=0.15 mult=1 sa=0.265
+ sb=0.265 sd=0.28 topography=normal area=0.063 perim=1.14
MMN10 y B sndNBa VNB nfet_01v8 m=1 w=0.42 l=0.15 mult=1 sa=0.265
+ sb=0.265 sd=0.28 topography=normal area=0.063 perim=1.14
```

```bash
awk '/^\.SUBCKT sky130_fd_sc_hd__maj3_1 /,/^\.ENDS/' $REF/cdl/sky130_fd_sc_hd.cdl | grep -c '^MM'
```

```
14
```

**Fourteen transistors**, seven n-type and seven p-type, each with a stated channel width
(`w=0.65`, `w=0.42`) that somebody chose.

And the layout:

```bash
ls -lh $REF/mag/sky130_fd_sc_hd__maj3_1.mag
grep -c '^rect' $REF/mag/sky130_fd_sc_hd__maj3_1.mag
grep '^<< ' $REF/mag/sky130_fd_sc_hd__maj3_1.mag | tr -d '<>' | tr '\n' ' '
```

```
-rw-r--r-- 1 root root 7.4K Apr 16 21:44 /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/mag/sky130_fd_sc_hd__maj3_1.mag
267
 nwell   pwell   scnmos   scpmoshvt   ndiff   pdiff   ndiffc   pdiffc   poly   polycont   locali   viali   metal1   labels   properties   end
```

**267 rectangles**, in a 7.4 KB file, describing a shape 3.68 µm by 2.72 µm. Sixteen sections
are listed; thirteen of them are real mask layers — `nwell`, `poly`, `metal1` and the rest —
while `labels`, `properties` and `end` are bookkeeping.

That is what a standard cell is. Not an abstraction of a gate — a **specific arrangement of
267 polygons that a person laid out**, that a real foundry knows how to print, and that has
been printed on real wafers. When `stat` charges you 10.01 µm², it is charging you for this.

## The 344 lines you skipped are measurements

Go back to the liberty entry and count its tables:

```bash
awk '/cell \("sky130_fd_sc_hd__maj3_1"\)/,/^    }$/' $LIB | grep -c 'values('
```

```
24
```

Twenty-four tables. Here is one of them:

```
                cell_rise ("del_1_7_7") {
                    index_1("0.0100000000, 0.0230506000, 0.0531329000, 0.1224740000, …");
                    index_2("0.0005000000, 0.0013016700, 0.0033886700, 0.0088218400, …");
                    values("0.1064958000, 0.1147213000, 0.1330062000, 0.1734156000, …", \
                        …
```

`index_1` is how fast the input edge arrives. `index_2` is how much capacitance hangs off the
output. `values` is the resulting delay in nanoseconds, for all 49 combinations. Delay is not
one number — it depends on what is driving you and what you are driving, so the library ships
a **7 × 7 grid** and the timing tools interpolate.

Twenty-four such tables, forty-nine numbers each: **1,176 measured numbers for one three-input
gate.** Across the library:

```bash
grep -c 'values(' $LIB
```

```
11101
```

Eleven thousand tables. That is where the 13 MB went, and it is why building a standard cell
library is a multi-year job: every point in every one of those grids came from a circuit
simulation, run against transistor models that the foundry calibrated against real silicon.

## The menu has variants

`maj3_1` has siblings:

| Cell | Liberty area | Layout |
|---|---|---|
| `sky130_fd_sc_hd__maj3_1` | 10.0096 µm² | 3.680 × 2.720 |
| `sky130_fd_sc_hd__maj3_2` | 11.2608 µm² | 4.140 × 2.720 |
| `sky130_fd_sc_hd__maj3_4` | 13.7632 µm² | 5.060 × 2.720 |

Same function, same three inputs, same `cell_footprint`. The suffix is **drive strength**, and
you can see exactly what changes. Ask the transistor netlist for the channel widths:

```bash
for C in maj3_1 maj3_2 maj3_4; do
  echo -n "$C: "
  awk "/^\.SUBCKT sky130_fd_sc_hd__$C /,/^\.ENDS/" $REF/cdl/sky130_fd_sc_hd.cdl \
    | grep -o 'w=[0-9.]*' | sort | uniq -c | tr '\n' ' '
  echo
done
```

```
maj3_1:      12 w=0.42       1 w=0.65       1 w=1.0
maj3_2:       6 w=0.42       6 w=0.64       1 w=0.65       1 w=1.0
maj3_4:       7 w=0.65       7 w=1.0
```

**The same fourteen transistors every time — just wider.** A wider channel passes more
current, so it charges whatever the output is driving faster, and it needs more room:
`maj3_4` costs 37% more area than `maj3_1` and computes exactly the same function. It is the
same word said louder.

That is why there are 428 cells but only 143 distinct functions:

```bash
grep 'cell_footprint :' $LIB | sort -u | wc -l
```

```
143
```

**143 things the library can compute, 428 ways to buy them.** Picking the right drive
strength is not your job — it is what `abc` and the placer argue about, and it is most of what
"timing optimization" means in practice.

## The item you did not order

There is a cell in the catalogue called `sky130_fd_sc_hd__fa_1`:

```bash
awk '/cell \("sky130_fd_sc_hd__fa_1"\)/,/^    }$/' $LIB \
  | grep -E '^        area :|^            function :' | grep -v power_down
```

```
        area : 20.019200000;
            function : "(A&B) | (A&CIN) | (B&CIN)";
            function : "(A&!B&!CIN) | (!A&B&!CIN) | (!A&!B&CIN) | (A&B&CIN)";
```

Two outputs, `COUT` and `SUM`. It is a **complete one-bit full adder as a single cell** —
literally the module you wrote in DD102 — at **20.02 µm²**.

Your `fulladder.sv` did not synthesize to it. It came back as `maj3_1` + `xor3_1`:

```
        2   33.782 cells
        1    10.01   sky130_fd_sc_hd__maj3_1
        1   23.773   sky130_fd_sc_hd__xor3_1
```

**33.78 µm², against a 20.02 µm² cell sitting unused in the same file.** ABC even mentions it
while reading the library:

```
ABC: Warning: Detected 9 multi-output cells (for example, "sky130_fd_sc_hd__fa_1").
```

ABC's mapper covers a netlist with **single-output** gates, and it says out loud that it found
nine cells that are not that shape. It then mapped your full adder without using one.

> Do not read this as "Yosys is bad". Read it as: **the library and the tool are separate
> things, and the tool decides which part of the library you can reach.** Commercial mappers
> handle multi-output cells; a different open flow might too. The catalogue is fixed; what you
> can order from it depends on who is taking the order.

## One library, eighteen versions of it

The file you have been using is one of many:

```bash
ls /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/ | wc -l
du -sh /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/
```

```
18
329M	/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/
```

Eighteen files, 329 MB, **the same 428 cells every time**. What changes is the conditions the
timing was characterised under, and the filename says which:

`sky130_fd_sc_hd__` **`tt`** `_` **`025C`** `_` **`1v80`** `.lib`

- **`tt`** — *typical-typical*: transistors came out of the fab at nominal speed. The
  neighbours are `ff` (fast) and `ss` (slow).
- **`025C`** — characterised at 25 °C. Others go to −40 °C and 100 °C.
- **`1v80`** — a 1.80 V supply. Others run from 1.28 V to 1.95 V.

The liberty file agrees with its own name:

```bash
grep -m3 -E 'nom_temperature|nom_voltage|nom_process' $LIB
```

```
    nom_process : 1.0000000000;
    nom_temperature : 25.000000000;
    nom_voltage : 1.8000000000;
```

A chip has to work across all of them. DD103 uses `tt_025C_1v80` throughout because it is the
middle of the range and one corner is enough to learn on — but a real design "closes timing"
against several of these files at once, and the `ss` ones (slow transistors, low voltage) are
where setup timing usually fails.

## Decoding the rest of the name

While you are here, the prefix is not noise either:

| Piece | Means |
|---|---|
| `sky130` | SkyWater's 130 nm process |
| `fd` | *foundry* — SkyWater drew these themselves |
| `sc` | *standard cell* |
| `hd` | *high density* — the 2.720 µm row height. The same PDK also ships `sky130_fd_sc_hvl`, a high-voltage family on a 4.070 µm row: `grep '^  SIZE' …/sky130_fd_sc_hvl/lef/*.lef` to see it |
| `__maj3` | the function |
| `_1` | drive strength |

`sky130_fd_sc_hd__maj3_1` is a sentence: *SkyWater's own 130 nm high-density standard-cell
three-input majority gate, weakest drive.*

## Try this

Find the biggest and smallest things in the catalogue:

```bash
awk '/^    cell \(/{n=$0} /^        area :/{print $3, n}' $LIB | sort -g | head -3
awk '/^    cell \(/{n=$0} /^        area :/{print $3, n}' $LIB | sort -g | tail -3
```

**What you should see:**

```
2.5024000000;     cell ("sky130_fd_sc_hd__diode_2") {
3.7536000000;     cell ("sky130_fd_sc_hd__buf_1") {
3.7536000000;     cell ("sky130_fd_sc_hd__clkbuf_1") {
41.289600000;     cell ("sky130_fd_sc_hd__sdfbbn_2") {
41.289600000;     cell ("sky130_fd_sc_hd__sedfxbp_2") {
45.043200000;     cell ("sky130_fd_sc_hd__lpflow_isobufsrc_16") {
```

**Why an engineer cares:** the entire catalogue spans **2.50 µm² to 45.04 µm² — a factor of
18.** There is no cell a hundred times bigger than another, because they all have to fit the
same row. So a design's area grows by using **more cells**, not dramatically bigger ones —
which is why "how many cells?" and "how many µm²?" get asked in the same breath, and why a
cell count alone already tells you roughly what you are dealing with.

Notice also which end is which. Two of the three largest entries are flip-flops — `sdfbbn_2`
and `sedfxbp_2`, both 41.29 µm² — while `nand2_1` is 3.75 µm². Even the plain reset flop your
counter actually used, `dfrtp_1`, is **25.02 µm²: about seven NAND gates each.**

**A bit of memory costs several times what a bit of logic costs.** That ratio is why your
counter — four flip-flops and seven gates — spent **67.23% of its area on remembering** and
only the rest on computing.

## What to remember

- 428 cells, 13 MB, 173,157 lines. A fixed menu you can count.
- A cell entry declares a **boolean function**, an **area**, **pins**, and 24 tables of
  measured timing.
- The area is a real rectangle: `maj3_1` is **3.680 × 2.720 = 10.0096 µm²**, drawn as 267
  polygons on 13 layers by a person.
- Every cell is **2.720 µm tall** and a multiple of **0.460 µm** wide. That is what makes them
  *standard*.
- `_1` / `_2` / `_4` is drive strength: 143 functions, 428 variants.
- A flip-flop costs several plain gates: `dfrtp_1` is **25.02 µm²**, `nand2_1` is
  **3.75 µm²**.

Next: [Reading `stat` like a receipt](guide/reading-stat.md), where that last point turns into
a number you will quote in every design review — and where the line
`of which used for sequential elements` finally earns its place.
