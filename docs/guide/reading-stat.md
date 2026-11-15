# Reading the `stat` report

This page explains how to read the block of numbers `stat` prints at the end of a synthesis run,
and how to tell when its total is wrong. You'll produce every report here yourself in
[Lab 04](../labs/lab-04-reading-the-receipt-overview.md), Parts 1 to 3 and Part 6.

In [Lab 02](../labs/lab-02-rtl-becomes-gates-overview.md) you watched your RTL turn into named
SKY130 cells, and Yosys printed a block of numbers at the end. That block works like a receipt,
with line items, quantities, prices and a total. Once you can read it, you can answer
"how big is my design?" with a number you can defend.

## A receipt with no prices

Here is `stat` on the mapped 4-bit adder, without telling it anything about the technology:

```
=== ripple4 ===

        +----------Local Count, excluding submodules.
        |
       33 wires
       46 wire bits
       26 public wires
       39 public wire bits
        5 ports
       14 port bits
       16 cells
        4   $scopeinfo
        4   sky130_fd_sc_hd__maj3_1
        8   sky130_fd_sc_hd__xnor2_1
```

What you get is quantities: four of these cells and eight of those. That's a shopping list, and
a shopping list can't tell you what the shopping will cost, because nothing on it says what one
cell is worth.

## The same receipt with prices

Here is the same netlist with `stat -liberty` and the SKY130 liberty file:

```
=== ripple4 ===

        +----------Local Count, excluding submodules.
        |        +-Local Area, excluding submodules.
        |        |
       16  110.106 cells
        4        -   $scopeinfo
        4   40.038   sky130_fd_sc_hd__maj3_1
        8   70.067   sky130_fd_sc_hd__xnor2_1

   Area for cell type $scopeinfo is unknown!

   Chip area for module '\ripple4': 110.105600
     of which used for sequential elements: 0.000000 (0.00%)
```

The netlist and the cells are the same as before, but now there is a second column, and a total
at the bottom. Nothing about your design changed and nothing was re-synthesized; the liberty file
only supplied a price list for the cells that were already there.

## Where the second column comes from

On the [Standard cells](../guide/standard-cells-are-real.md) page we opened that 13 MB file and
counted its 428 entries. Only one line of each entry matters here, the one that gives the cell's
area. For `maj3_1` it is:

```
        area : 10.009600000;
```

That is where the `40.038` came from: `stat` counted four `maj3_1` cells, looked up `10.0096`,
and multiplied the two. The same lookup for `xnor2_1` gives `8.7584`, so you can check the whole
receipt by hand in about ten seconds:

$$4 \times 10.0096 = 40.0384 \qquad 8 \times 8.7584 = 70.0672 \qquad \text{total} = 110.1056\ \mu\text{m}^2$$

So the middle column is the area of the whole line rather than the price of one cell, and to get
the unit price you divide it by the count.

> A micrometre (µm) is a thousandth of a millimetre. Your entire 4-bit adder is 110 µm², which is
> a square about 10.5 µm on a side, or roughly a seventh of the width of a human hair.

## `$scopeinfo` and the cell count

The `16 cells` line overstates the count, because the design really has twelve cells. The other
four are `$scopeinfo`, bookkeeping objects that Yosys leaves behind to remember which `generate`
block a piece of logic came from. They have no transistors and no area, and they don't exist on
the silicon at all, which is why `stat` says it can't price them.

If you delete them with `delete t:\$scopeinfo` before running `stat`, you get this:

```
       12  110.106 cells
        4   40.038   sky130_fd_sc_hd__maj3_1
        8   70.067   sky130_fd_sc_hd__xnor2_1

   Chip area for module '\ripple4': 110.105600
```

Now the count is twelve cells, the warning is gone, and the total hasn't changed, since the four
objects you removed never had any area.

> **Mind the backslash.** Inside `yosys -p "…"`, your shell treats `$scopeinfo` as a variable,
> and since it's unset it expands to nothing, so Yosys receives `delete t:`. That matches no
> cells, so it deletes nothing and reports nothing. You get `16 cells` again with no error, and
> it's easy to conclude that the command doesn't work. Write `t:\$scopeinfo`.

## A design with state

The adder has no memory, so its sequential line reads `0.00%`. For a design that does, here is
the core of `blinker.sv`, a four-state controller with a countdown timer. The full file is in the
[Lab 04 package](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt).

```systemverilog
typedef enum logic [1:0] {IDLE, LOAD, RUN, DONE_S} state_t;
state_t     state;      // 2 bits
logic [3:0] count;      // 4 bits

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 4'd0;
    end else begin
        case (state)
            IDLE:   if (go) state <= LOAD;
            LOAD:   begin count <= 4'd9; state <= RUN; end
            RUN:    if (count == 4'd0) state <= DONE_S;
                    else count <= count - 4'd1;
            DONE_S: state <= IDLE;
        endcase
    end
end
```

Before reading further, predict the flip-flop count. Six bits of state are assigned with `<=`
inside an `always_ff`: four for `count` and two for `state`. A bit that survives a clock edge
needs a flip-flop, so the natural prediction is 6 flip-flops.

Here is the receipt from the full flow, which includes `dfflibmap`. That pass maps flip-flops to
real cells, which `abc` on its own doesn't do:

```
=== blinker ===

       28  316.554 cells
        2   15.014   sky130_fd_sc_hd__a21o_1
        3   11.261   sky130_fd_sc_hd__clkinv_1
        7  175.168   sky130_fd_sc_hd__dfrtp_1
        1   26.275   sky130_fd_sc_hd__dfstp_2
        2    7.507   sky130_fd_sc_hd__nand2_1
        2   12.512   sky130_fd_sc_hd__nand2b_1
        2    7.507   sky130_fd_sc_hd__nor2_1
        2    10.01   sky130_fd_sc_hd__nor3_1
        1    7.507   sky130_fd_sc_hd__o211ai_1
        1    7.507   sky130_fd_sc_hd__o21a_1
        2    10.01   sky130_fd_sc_hd__o21ai_0
        1    7.507   sky130_fd_sc_hd__o21bai_1
        1    8.758   sky130_fd_sc_hd__o41ai_1
        1    10.01   sky130_fd_sc_hd__or4b_1

   Chip area for module '\blinker': 316.553600
     of which used for sequential elements: 201.443200 (63.64%)
```

Every cell whose name starts with `df` is a flip-flop, so there are eight of them: seven
`dfrtp_1` and one `dfstp_2`. The prediction of six was a fair reading of your code, but Yosys
changed how the state is stored, as the next section explains.

## FSM re-encoding

Yosys ran a pass called `fsm`, which recognised `state` as a state register and re-encoded it.
You can see this in the log:

```
2.7.6. Executing FSM_RECODE pass (re-assigning FSM state encoding).
Recoding FSM `$fsm$\state$54' from module `\blinker' using `auto' encoding:
  mapping auto encoding to `one-hot` for this FSM.
  00 -> ---1
  10 -> --1-
  01 -> -1--
  11 -> 1---
```

Your two-bit binary state became one-hot, which uses four bits for four states, with exactly one
of them high at a time. Four state bits plus four counter bits makes eight flip-flops.

That also explains why one flip-flop is a different cell from the rest. In one-hot, `IDLE` is
`---1`, so the low state bit has to come out of reset high. A flop that resets high is a set
flop, `dfstp_2`, rather than a reset flop like `dfrtp_1`, which means you can read the reset
condition off one line of the receipt.

If you turn the pass off (`synth -top blinker -nofsm`), you get the six flip-flops you predicted:

```
       27  264.003 cells
        ...
        6  150.144   sky130_fd_sc_hd__dfrtp_1
        ...

   Chip area for module '\blinker': 264.003200
     of which used for sequential elements: 150.144000 (56.87%)
```

That's six flops and 264.00 µm², against 316.55 µm² with the pass on.

So here the tool made the design 20 % bigger. One-hot spends two extra flip-flops to buy cheaper
decoding, because answering "am I in `RUN`?" means reading one wire instead of comparing two. On
a four-state machine that trade loses. On a twenty-state machine with wide output logic it
usually wins, and Yosys's `auto` heuristic is tuned for the general case rather than for your
design.

None of this means you should use `-nofsm`. What it shows is that the netlist isn't a
transcription of your code, and the receipt is where you find out what the netlist actually is.

## Flip-flop cost

Look at the last two lines of the blinker receipt again:

```
   Chip area for module '\blinker': 316.553600
     of which used for sequential elements: 201.443200 (63.64%)
```

Eight cells out of twenty-eight take 64 % of the silicon, and the price list shows why:

| Cell | What it is | Area |
|---|---|---|
| `sky130_fd_sc_hd__nor2_1` | 2-input NOR | 3.7536 µm² |
| `sky130_fd_sc_hd__nand2_1` | 2-input NAND | 3.7536 µm² |
| `sky130_fd_sc_hd__inv_1` | inverter | 3.7536 µm² |
| `sky130_fd_sc_hd__dfxtp_1` | plain D flip-flop | 20.0192 µm² |
| `sky130_fd_sc_hd__dfrtp_1` | D flip-flop, async reset | 25.024 µm² |
| `sky130_fd_sc_hd__dfstp_2` | D flip-flop, async set, 2× drive | 26.2752 µm² |

One flip-flop costs more than five NAND gates because it contains more than five NAND gates'
worth of transistors: 24 against 4, counted from the PDK in the same way as on the
[Standard cells](../guide/standard-cells-are-real.md) page. Adding an asynchronous reset input
costs another 5 µm² on top of that, which is more than a whole NOR gate.

You can check the blinker's sequential total by hand:

$$7 \times 25.024 + 1 \times 26.2752 = 175.168 + 26.2752 = 201.4432\ \mu\text{m}^2$$

The other twenty cells, which include every gate that decides anything, share 115.11 µm². So
this design spends nearly two thirds of its area remembering where it is, and one third deciding
where to go next.

That ratio is the most useful number on the receipt. When it climbs, you are storing more than
you are computing, and usually the cheapest optimization available is to store less.

## Cell area and die area

`Chip area` is a misleading label, because the number is the sum of the standard cells' areas and
nothing else. It leaves out the wires, the power grid, the gaps between cells and the room the
router needs to work.

The same `blinker.sv`, run all the way through LibreLane to a real layout with the flow's default
floorplan settings (no `FP_CORE_UTIL` of your own), reports this:

| | |
|---|---|
| Yosys `stat -liberty` | 316.55 µm² |
| standard cells placed, after buffers, taps and fill | 575.55 µm² |
| core area | 750.72 µm² |
| die area | 1929.33 µm² (38.89 × 49.61 µm) |

The 316 µm² design needs a 1929 µm² chip, about 6.1 times as much. The layout has 109 placed
instances against `stat`'s 28 cells, though the flow still counted the same 8 sequential cells.
The extra instances are timing-repair buffers, clock buffers, well taps and filler cells, and the
rest of the area is empty space that keeps utilization below 100 % so that the router can get
wires through.

So use `stat -liberty` for what it's good at, which is comparing two versions of your own design.
If a change drops the number from 316 to 264, that saving is real and will survive to the die.
What you shouldn't do is quote the number as the size of a chip.
[From netlist to layout](../guide/from-gates-to-geometry.md) is where the die number comes from.

## The machine-readable receipt

Every lab in this course checks your work without an instructor, and this section shows how.
`stat -json` writes the receipt as JSON to the console, so to capture it in a file you put
`tee -o <file>` in front of it, as in `tee -o blinker.json stat -json -liberty $LIB`. Trimmed,
`blinker.json` looks like this:

```json
{
   "creator": "Yosys 0.68 (git sha1 38e001a6f, ...)",
   "modules": {
      "\\blinker": {
         "num_cells":         28,
         "area":              316.553600,
         "sequential_area":    201.443200,
         "num_cells_by_type": {
            "sky130_fd_sc_hd__dfrtp_1": 7,
            "sky130_fd_sc_hd__dfstp_2": 1,
            "sky130_fd_sc_hd__nand2b_1": 2,
            "sky130_fd_sc_hd__nor2_1": 2
         }
      }
   },
      "design": {
         "num_cells":         28,
         "area":              316.553600,
         "sequential_area":    201.443200,
         "num_cells_by_type": {
            "sky130_fd_sc_hd__dfrtp_1": 7,
            "sky130_fd_sc_hd__dfstp_2": 1
         }
      }
}
```

To make it fit, we cut ten of the receipt's fourteen cell types from the module object and
twelve from the design object, and ten more `num_*` keys from both. The full file is
`results/blinker.json` once you have run `make` in Lab 04. Four keys carry
everything the text receipt showed you:

| Key | What it is |
|---|---|
| `num_cells` | the cell count, which includes `$scopeinfo`, so delete those first |
| `area` | the `Chip area` total, in µm² |
| `sequential_area` | the flip-flop share, in µm²; divide it yourself for the percentage |
| `num_cells_by_type` | the line items, as a name → count map |

The module key is `"\\blinker"`, with a literal backslash, because that is how Yosys spells a
user-written name. There is also a second copy of the same numbers under a top-level `"design"`
key, which sums the whole design. If you read `["design"]`, you never have to guess the module
name:

```python
import json, sys

d = json.load(open(sys.argv[1]))["design"]
flops = sum(n for t, n in d["num_cells_by_type"].items() if "__df" in t or "__edf" in t)

print(f"cells      : {d['num_cells']}")
print(f"flip-flops : {flops}")
print(f"area       : {d['area']:.2f} um^2")
print(f"sequential : {d['sequential_area']:.2f} um^2 "
      f"({100 * d['sequential_area'] / d['area']:.1f}%)")
```

```
$ python3 stat_min.py blinker.json
cells      : 28
flip-flops : 8
area       : 316.55 um^2
sequential : 201.44 um^2 (63.6%)
```

Those seven statements are all a lab needs to tell you that you got it right. The lab's version
is [`src/check_stat.py`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt),
which adds reference numbers and a PASS/FAIL result on top.

## Unmapped cells

If you delete `dfflibmap` from the blinker flow and run it again, nothing reports an error, and
the exit status is 0:

```
       26  105.101 cells
        4        -   $_DFFE_PN0P_
        3        -   $_DFF_PN0_
        1        -   $_DFF_PN1_
        ...

   Area for cell type $_DFFE_PN0P_ is unknown!
   Area for cell type $_DFF_PN0_ is unknown!
   Area for cell type $_DFF_PN1_ is unknown!

   Chip area for module '\blinker': 105.100800
     of which used for sequential elements: 0.000000 (0.00%)
```

The total is 105.10 µm² instead of 316.55, and the sequential share is 0.00 % in a design that
is two-thirds flip-flops. The cause is the one described in
[What synthesis does](../guide/synthesis-is-translation.md#two-mappers): `abc` maps combinational
logic and `dfflibmap` maps flip-flops, so without `dfflibmap` the flip-flops stay as generic
`$_DFF_*` cells. Those have no liberty entry, so each one contributes zero to the total. On a
design this size, that happens without anything that looks like an error.

What gives it away is a cell type whose name starts with `$_`. A `$_` name in your final cell
list means something didn't get mapped, and your area is too small by however much that
something was worth. `$scopeinfo` is the one harmless exception; any other name with a `$` in it
is a hole in the total. Chase down every `is unknown!` line before you believe a number.

## Summary

| Line on the receipt | What it means |
|---|---|
| `N cells` | count; subtract `$scopeinfo`, and worry if you see a `$_` name |
| middle column | area of that whole line, not of one cell |
| `Chip area` | sum of the standard cells, in µm², not the size of the die |
| `of which … sequential` | the flip-flop share, the number worth watching |
| `Area for cell type … is unknown!` | your total is wrong; find out why |

Next: [Carry delay and static timing](../guide/the-carry-has-to-walk.md).
