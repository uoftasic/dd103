# Reading the `stat` report

This page explains how to read the block of numbers `stat` prints at the end of a synthesis run,
and how to tell when its total is wrong. You'll produce every report here yourself in
[Lab 04](labs/lab-04-reading-the-receipt-overview.md), Parts 1 to 3 and Part 6.

In [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) you watched your RTL turn into named
SKY130 cells, and Yosys printed a block of numbers at the end. That block works like a receipt:
line items, quantities, prices, and a total. Once you can read it, "how big is my design?" has a
number you can defend.

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

You get quantities: four of these, eight of those. That is a shopping list, and a shopping list
can't tell you what the shopping costs.

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

Same netlist, same cells. A second column appeared, and a total at the bottom. Nothing about your
design changed and nothing was re-synthesized. The liberty file only supplied a price list.

## Where the second column comes from

[Standard cells](guide/standard-cells-are-real.md) opened that 13 MB file and counted its 428
entries. Only one line of each entry matters here, the area. For `maj3_1` it is:

```
        area : 10.009600000;
```

That is where the `40.038` came from: `stat` counted four `maj3_1`, looked up `10.0096`, and
multiplied. The same lookup for `xnor2_1` gives `8.7584`. Checking the whole receipt by hand
takes ten seconds:

$$4 \times 10.0096 = 40.0384 \qquad 8 \times 8.7584 = 70.0672 \qquad \text{total} = 110.1056\ \mu\text{m}^2$$

So the middle column is the area of the whole line, not the price of one cell. Divide by the
count to get the unit price.

> A micrometre (µm) is a thousandth of a millimetre. Your entire 4-bit adder is 110 µm², about
> 10.5 µm on a side, roughly a seventh of the width of a human hair.

## `$scopeinfo` and the cell count

`16 cells` is not the real count. There are twelve cells. The other four are `$scopeinfo`:
bookkeeping objects Yosys leaves behind to remember which `generate` block a piece of logic came
from. They have no transistors, no area and no existence on silicon, which is why `stat` says it
can't price them.

Deleting them with `delete t:\$scopeinfo` before `stat` gives:

```
       12  110.106 cells
        4   40.038   sky130_fd_sc_hd__maj3_1
        8   70.067   sky130_fd_sc_hd__xnor2_1

   Chip area for module '\ripple4': 110.105600
```

Twelve cells. The warning is gone and the total did not move.

> **Mind the backslash.** Inside `yosys -p "…"`, your shell expands `$scopeinfo`, an unset
> variable, into nothing, and Yosys receives `delete t:`. That matches no cells, deletes nothing,
> and reports nothing: you get `16 cells` again with no error, and conclude the command doesn't
> work. Write `t:\$scopeinfo`.

## A design with state

The adder has no memory, so its sequential line reads `0.00%`. Here is the core of `blinker.sv`,
a four-state controller with a countdown timer. The full file is in the
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

Here is the receipt, from the full flow with `dfflibmap` (which maps flip-flops to real cells;
`abc` alone does not):

```
=== blinker ===

       27  316.554 cells
        1    10.01   sky130_fd_sc_hd__a21bo_1
        2   15.014   sky130_fd_sc_hd__a21o_1
        1    8.758   sky130_fd_sc_hd__a31o_1
        1    6.256   sky130_fd_sc_hd__and2_0
        2    7.507   sky130_fd_sc_hd__clkinv_1
        7  175.168   sky130_fd_sc_hd__dfrtp_1
        1   26.275   sky130_fd_sc_hd__dfstp_2
        1    6.256   sky130_fd_sc_hd__lpflow_isobufsrc_1
        1    3.754   sky130_fd_sc_hd__nand2_1
        2   12.512   sky130_fd_sc_hd__nand2b_1
        1    3.754   sky130_fd_sc_hd__nor2_1
        2    10.01   sky130_fd_sc_hd__nor3_1
        2    10.01   sky130_fd_sc_hd__o21ai_0
        1    8.758   sky130_fd_sc_hd__o41ai_1
        2   12.512   sky130_fd_sc_hd__or3_1

   Chip area for module '\blinker': 316.553600
     of which used for sequential elements: 201.443200 (63.64%)
```

There are eight flip-flops: seven `dfrtp_1` plus one `dfstp_2`. Every cell whose name starts
with `df` is a flip-flop. The prediction of six reasoned about your code, and Yosys rewrote it.

## FSM re-encoding

Yosys ran a pass called `fsm` that recognised `state` as a state register and re-encoded it. The
log shows it:

```
2.7.6. Executing FSM_RECODE pass (re-assigning FSM state encoding).
Recoding FSM `$fsm$\state$54' from module `\blinker' using `auto' encoding:
  mapping auto encoding to `one-hot` for this FSM.
  00 -> ---1
  10 -> --1-
  01 -> -1--
  11 -> 1---
```

Your two-bit binary state became one-hot: four states, four bits, exactly one of them high at a
time. Four state bits plus four counter bits is eight.

That also explains the odd cell out. In one-hot, `IDLE` is `---1`, so the low state bit has to
come out of reset high. A flop that resets high is a set flop, `dfstp_2`, not a reset flop,
`dfrtp_1`. You can read the reset condition off one line of the receipt.

With the pass turned off (`synth -top blinker -nofsm`), the prediction comes back:

```
       27  264.003 cells
        ...
        6  150.144   sky130_fd_sc_hd__dfrtp_1
        ...

   Chip area for module '\blinker': 264.003200
     of which used for sequential elements: 150.144000 (56.87%)
```

Six flops, and 264.00 µm² instead of 316.55.

So the tool made it 20 % bigger here. One-hot spends two extra flip-flops to buy cheaper
decoding, because "am I in `RUN`?" becomes reading one wire instead of comparing two. On a
four-state machine that trade loses. On a twenty-state machine with wide output logic it usually
wins, and Yosys's `auto` heuristic is tuned for the general case, not for yours.

The point is not to use `-nofsm`. The netlist is not a transcription of your code, and the
receipt is where you find out what it actually is.

## Flip-flop cost

Look at the last two lines of the blinker receipt again:

```
   Chip area for module '\blinker': 316.553600
     of which used for sequential elements: 201.443200 (63.64%)
```

Eight cells out of twenty-seven take 64 % of the silicon. The price list shows why:

| Cell | What it is | Area |
|---|---|---|
| `sky130_fd_sc_hd__nor2_1` | 2-input NOR | 3.7536 µm² |
| `sky130_fd_sc_hd__nand2_1` | 2-input NAND | 3.7536 µm² |
| `sky130_fd_sc_hd__inv_1` | inverter | 3.7536 µm² |
| `sky130_fd_sc_hd__dfxtp_1` | plain D flip-flop | 20.0192 µm² |
| `sky130_fd_sc_hd__dfrtp_1` | D flip-flop, async reset | 25.024 µm² |
| `sky130_fd_sc_hd__dfstp_2` | D flip-flop, async set, 2× drive | 26.2752 µm² |

One flip-flop costs more than five NAND gates, because it is more than five NAND gates: 24
transistors against 4, counted from the PDK as on the
[Standard cells](guide/standard-cells-are-real.md) page. Adding an asynchronous reset input costs
another 5 µm² on top, more than a whole NOR gate.

The blinker's sequential total checks out by hand:

$$7 \times 25.024 + 1 \times 26.2752 = 175.168 + 26.2752 = 201.4432\ \mu\text{m}^2$$

The other nineteen cells, every gate that decides anything, share 115.11 µm². This design spends
nearly two thirds of its area remembering where it is, and one third deciding where to go next.

That ratio is the most useful number on the receipt. When it climbs, you are storing more than
you are computing, and the cheapest optimization available is usually to store less.

## Cell area and die area

`Chip area` is a misleading label. It is the sum of the standard cells and nothing else: no
wires, no power grid, no gaps, no room for the router to work.

The same `blinker.sv`, run all the way through LibreLane to a real layout with the flow's default
floorplan settings (no `FP_CORE_UTIL` of your own), reports this:

| | |
|---|---|
| Yosys `stat -liberty` | 316.55 µm² |
| standard cells placed, after buffers, taps and fill | 575.55 µm² |
| core area | 750.72 µm² |
| die area | 1929.33 µm² (38.89 × 49.61 µm) |

The 316 µm² design needs a 1929 µm² chip, about 6.1×. The layout has 109 placed instances against
`stat`'s 27 cells, though the flow still counted the same 8 sequential cells. The rest is
timing-repair buffers, clock buffers, well taps, filler cells, and the empty space that keeps
utilization below 100 % so the router can get wires through.

So use `stat -liberty` for what it is good at: comparing two versions of your own design. If a
change drops the number from 316 to 264, that saving is real and will survive to the die. Don't
quote the number as the size of a chip. [From netlist to layout](guide/from-gates-to-geometry.md)
is where the die number comes from.

## The machine-readable receipt

Every lab in this course checks itself without an instructor, and this is how. `stat -json`
writes the receipt as JSON to the console, so you put `tee -o <file>` in front of it to capture
it, as in `tee -o blinker.json stat -json -liberty $LIB`. Trimmed, `blinker.json` looks like
this:

```json
{
   "creator": "Yosys 0.68 (git sha1 38e001a6f, ...)",
   "modules": {
      "\\blinker": {
         "num_cells":         27,
         "area":              316.553600,
         "sequential_area":    201.443200,
         "num_cells_by_type": {
            "sky130_fd_sc_hd__dfrtp_1": 7,
            "sky130_fd_sc_hd__dfstp_2": 1,
            "sky130_fd_sc_hd__nand2b_1": 2,
            "sky130_fd_sc_hd__nor2_1": 1
         }
      }
   },
      "design": {
         "num_cells":         27,
         "area":              316.553600,
         "sequential_area":    201.443200,
         "num_cells_by_type": {
            "sky130_fd_sc_hd__dfrtp_1": 7,
            "sky130_fd_sc_hd__dfstp_2": 1
         }
      }
}
```

Eleven more cell types and eight more `num_*` keys have been cut from both objects to fit; run it
and read the real thing. Four keys carry everything the text receipt showed you:

| Key | What it is |
|---|---|
| `num_cells` | the cell count, including `$scopeinfo`, so delete those first |
| `area` | the `Chip area` total, in µm² |
| `sequential_area` | the flip-flop share, in µm²; divide it yourself for the percentage |
| `num_cells_by_type` | the line items, as a name → count map |

The module key is `"\\blinker"`, with a literal backslash, because that is how Yosys spells a
user-written name. There is also a second copy of the same numbers under a top-level `"design"`
key that sums the whole design. Read `["design"]` and you never have to guess the module name:

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
cells      : 27
flip-flops : 8
area       : 316.55 um^2
sequential : 201.44 um^2 (63.6%)
```

Those seven statements are enough for a lab to tell you that you got it right. The lab version is
[`src/check_stat.py`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt),
which adds reference numbers and a PASS/FAIL on top.

## Unmapped cells

Delete `dfflibmap` from the blinker flow and run it again. Nothing errors, and the exit status
is 0:

```
       25  102.598 cells
        4        -   $_DFFE_PN0P_
        3        -   $_DFF_PN0_
        1        -   $_DFF_PN1_
        ...

   Area for cell type $_DFFE_PN0P_ is unknown!
   Area for cell type $_DFF_PN0_ is unknown!
   Area for cell type $_DFF_PN1_ is unknown!

   Chip area for module '\blinker': 102.598400
     of which used for sequential elements: 0.000000 (0.00%)
```

That is 102.60 µm² instead of 316.55, and 0.00 % sequential in a design that is two-thirds
flip-flops. The cause is the one from
[What synthesis does](guide/synthesis-is-translation.md#two-mappers): `abc` maps combinational
logic, `dfflibmap` maps flip-flops, and a generic `$_DFF_*` cell with no liberty entry contributes
zero to the total. On a design this size it happens without anything that looks like an error.

The giveaway is a cell type starting with `$_`. A `$_` name in your final cell list means
something did not get mapped, and your area is too small by however much it was worth.
`$scopeinfo` is the one harmless exception; anything else with a `$` is a hole in the total.
Chase every `is unknown!` line before you believe a number.

## Summary

| Line on the receipt | What it means |
|---|---|
| `N cells` | count; subtract `$scopeinfo`, and worry if you see a `$_` name |
| middle column | area of that whole line, not of one cell |
| `Chip area` | sum of standard cells, in µm². Not the die. |
| `of which … sequential` | the flip-flop share, the number worth watching |
| `Area for cell type … is unknown!` | your total is wrong; find out why |

Next: [Carry delay and static timing](guide/the-carry-has-to-walk.md).
