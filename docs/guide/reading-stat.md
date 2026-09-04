# Reading `stat` like a receipt

**Question this page answers:** *How big is my design?*

In [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) you watched your RTL turn into named SKY130
cells. Yosys printed a block of numbers at the end and you probably skipped it.

That block is a receipt. It has line items, quantities, unit prices, and a total. Once you can
read it, "how big is my design?" stops being a shrug and becomes a number you can defend.

Set this up once — every command on this page uses it:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

## First, a receipt with no prices

Run `stat` on your mapped adder without telling it anything about the technology:

```bash
yosys -p "read_verilog -sv ripple4.sv fulladder.sv; synth -top ripple4; flatten;
          abc -liberty $LIB; opt_clean; stat"
```

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

You get quantities. Four of these, eight of those. That is a shopping list, and a shopping list
cannot tell you what the shopping costs.

## Now the same receipt with prices

Add `-liberty`:

```bash
yosys -p "read_verilog -sv ripple4.sv fulladder.sv; synth -top ripple4; flatten;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

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

Same netlist. Same cells. A second column appeared, and a total at the bottom.

**Nothing about your design changed.** The liberty file did not re-synthesize anything. All it
did was supply a price list.

## Where the second column comes from

[A standard cell is a real thing](guide/standard-cells-are-real.md) opened that 13 MB file and
counted its 428 entries. Only one line of each entry matters here — the area. Look one up
yourself:

```bash
grep -A200 'cell ("sky130_fd_sc_hd__maj3_1")' $LIB | grep -m1 area
```

```
        area : 10.009600000;
```

That is where the `40.038` came from. `stat` counted four `maj3_1`, looked up `10.0096`, and
multiplied. Do the same for `xnor2_1` and you get `8.7584`.

Check the whole receipt by hand — it takes ten seconds and it is worth doing once:

$$4 \times 10.0096 = 40.0384 \qquad 8 \times 8.7584 = 70.0672 \qquad \text{total} = 110.1056\ \mu\text{m}^2$$

The middle column is **the area of that whole line**, not the price of one cell. Divide to get
the unit price.

> **µm² — square micrometres.** A micrometre is a thousandth of a millimetre. Your entire
> 4-bit adder is 110 µm², which is about 10.5 µm on a side — roughly a seventh the width of a
> human hair.

## The `$scopeinfo` line, and why your cell count is wrong

`16 cells` is a lie. You have twelve cells. The other four are `$scopeinfo` — bookkeeping
objects Yosys leaves behind to remember which `generate` block a piece of logic came from.
They have no transistors, no area, and no existence on silicon, which is exactly why `stat`
complains it cannot price them.

Delete them before you count:

```bash
yosys -p "read_verilog -sv ripple4.sv fulladder.sv; synth -top ripple4; flatten;
          abc -liberty $LIB; opt_clean; delete t:\$scopeinfo; stat -liberty $LIB"
```

```
       12  110.106 cells
        4   40.038   sky130_fd_sc_hd__maj3_1
        8   70.067   sky130_fd_sc_hd__xnor2_1

   Chip area for module '\ripple4': 110.105600
```

Twelve. The warning is gone, the total did not move.

> **Mind the backslash.** Inside `yosys -p "…"` your shell expands `$scopeinfo` — an unset
> variable — into nothing, and Yosys receives `delete t:`. That matches no cells, deletes
> nothing, and says nothing about it: you get `16 cells` again and no error, and you conclude
> the trick does not work. Write `t:\$scopeinfo`. Expect to hit this at least once.

## Predict, then measure

The adder has no memory, so its sequential line reads `0.00%`. Time for something that
remembers.

Here is the heart of `blinker.sv` — a four-state controller with a countdown timer. The full
file is in the
[Lab 04 package](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt):

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

**Write your prediction down before you run anything.** Six bits of state are assigned with
`<=` inside an `always_ff`: four for `count`, two for `state`. A bit that survives a clock edge
needs a flip-flop. So: **6 flip-flops.**

Now measure. Note the new line — `dfflibmap` is what maps flip-flops to real cells, and
`abc` alone will not do it:

```bash
yosys -p "read_verilog -sv blinker.sv; synth -top blinker; dfflibmap -liberty $LIB;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

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

**Eight flip-flops.** Seven `dfrtp_1` plus one `dfstp_2` — every cell whose name starts `df`
is a flip-flop. You predicted six. You were not being stupid; you were reasoning about *your*
code, and Yosys rewrote it.

## Why eight

Yosys ran a pass called `fsm` that recognised `state` as a state register and re-encoded it.
Ask the log:

```bash
yosys -p "read_verilog -sv blinker.sv; synth -top blinker" 2>&1 | grep -A6 FSM_RECODE
```

```
2.7.6. Executing FSM_RECODE pass (re-assigning FSM state encoding).
Recoding FSM `$fsm$\state$54' from module `\blinker' using `auto' encoding:
  mapping auto encoding to `one-hot` for this FSM.
  00 -> ---1
  10 -> --1-
  01 -> -1--
  11 -> 1---
```

There it is. Your two-bit binary state became **one-hot**: four states, four bits, exactly one
of them high at a time. Four state bits plus four counter bits is eight.

That also explains the odd cell out. In one-hot, `IDLE` is `---1`, so the low state bit must
come out of reset **high** — and a flop that resets high is a *set* flop, `dfstp_2`, not a
*reset* flop, `dfrtp_1`. One line of the receipt, and you can read your reset condition off it.

Turn the pass off and your prediction comes back:

```bash
yosys -p "read_verilog -sv blinker.sv; synth -top blinker -nofsm; dfflibmap -liberty $LIB;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

```
       27  264.003 cells
        ...
        6  150.144   sky130_fd_sc_hd__dfrtp_1
        ...

   Chip area for module '\blinker': 264.003200
     of which used for sequential elements: 150.144000 (56.87%)
```

Six flops. 264.00 µm² instead of 316.55.

**So the tool made it 20% bigger?** Yes — here. One-hot spends two extra flip-flops to buy
cheaper decoding, because "am I in `RUN`?" becomes reading one wire instead of comparing two.
On a four-state machine that trade loses. On a twenty-state machine with wide output logic it
usually wins, and Yosys's `auto` heuristic is tuned for the general case, not for yours.

The lesson is not "use `-nofsm`". It is that **the netlist is not a transcription of your
code**, and the receipt is where you find out.

## Flip-flops are the expensive part

Look at the two numbers at the bottom of the blinker receipt again:

```
   Chip area for module '\blinker': 316.553600
     of which used for sequential elements: 201.443200 (63.64%)
```

Eight cells out of twenty-seven are **64% of the silicon**. Here is why, straight from the price
list:

```bash
for c in dfxtp_1 dfrtp_1 dfstp_2 nor2_1 nand2_1 inv_1; do
  echo -n "$c  "; grep -A200 "cell (\"sky130_fd_sc_hd__$c\")" $LIB | grep -m1 area
done
```

```
dfxtp_1          area : 20.019200000;
dfrtp_1          area : 25.024000000;
dfstp_2          area : 26.275200000;
nor2_1          area : 3.7536000000;
nand2_1          area : 3.7536000000;
inv_1          area : 3.7536000000;
```

| Cell | What it is | Area |
|---|---|---|
| `sky130_fd_sc_hd__nor2_1` | 2-input NOR | **3.7536 µm²** |
| `sky130_fd_sc_hd__nand2_1` | 2-input NAND | 3.7536 µm² |
| `sky130_fd_sc_hd__inv_1` | inverter | 3.7536 µm² |
| `sky130_fd_sc_hd__dfxtp_1` | plain D flip-flop | **20.0192 µm²** |
| `sky130_fd_sc_hd__dfrtp_1` | D flip-flop, async reset | 25.024 µm² |
| `sky130_fd_sc_hd__dfstp_2` | D flip-flop, async set, 2× drive | 26.2752 µm² |

**One flip-flop costs more than five NAND gates**, because it *is* more than five NAND gates:
24 transistors against 4, counted straight out of the PDK on the
[previous page](guide/standard-cells-are-real.md). Adding an async reset input costs another
5 µm² on top of that, which is more than a whole NOR gate.

Check the blinker's sequential total yourself:

$$7 \times 25.024 + 1 \times 26.2752 = 175.168 + 26.2752 = 201.4432\ \mu\text{m}^2$$

The remaining nineteen cells — every gate that decides *anything* — share 115.11 µm² between
them. **This design spends nearly two thirds of itself remembering where it is, and one third
deciding where to go next.**

That ratio is the single most useful number on the receipt. When it climbs, you are storing
more than you are computing, and the cheapest optimization available to you is usually to store
less.

## Area is the sum of the cells. It is not the die.

`Chip area` is a misleading label. It is the sum of the standard cells and nothing else — no
wires, no power grid, no gaps, no room for the router to work.

The same `blinker.sv`, run all the way through LibreLane to a real layout — with the flow's
default floorplan settings, no `FP_CORE_UTIL` of your own — reports this:

| | |
|---|---|
| Yosys `stat -liberty` | **316.55 µm²** |
| standard cells placed, after buffers, taps and fill | 575.55 µm² |
| core area | 750.72 µm² |
| **die area** | **1929.33 µm²** (38.89 × 49.61 µm) |

**Your 316 µm² design needs a 1929 µm² chip** — about 6.1× — and 109 placed instances against
`stat`'s 27 cells, though the flow still counted the same 8 sequential cells you saw. The rest is timing-repair buffers, clock buffers,
well taps, filler cells, and the empty space that keeps utilization below 100% so the router
can actually get wires through.

So use `stat -liberty` for what it is good at: **comparing two versions of your own design.**
If a change drops the number from 316 to 264, that is real and it will survive to the die. Do
not quote it as the size of a chip. [From gates to geometry](guide/from-gates-to-geometry.md)
is where the die number comes from.

## The machine-readable receipt

Every lab in this course checks itself with no instructor in the room, and this is how. Add
`-json`:

```bash
yosys -p "read_verilog -sv blinker.sv; synth -top blinker; dfflibmap -liberty $LIB;
          abc -liberty $LIB; opt_clean; tee -o blinker.json stat -json -liberty $LIB"
```

`stat -json` writes to the console, so `tee -o <file>` in front of it is how you capture it.
Trimmed, `blinker.json` looks like this:

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

(Eleven more cell types and eight more `num_*` keys have been cut from both objects to fit;
run it and read the real thing.)

Four keys carry everything the text receipt showed you:

| Key | What it is |
|---|---|
| `num_cells` | the cell count — **including `$scopeinfo`, so delete those first** |
| `area` | the `Chip area` total, in µm² |
| `sequential_area` | the flip-flop share, in µm² — divide it yourself for the percentage |
| `num_cells_by_type` | the line items, as a name → count map |

Two things to notice about the shape. The module key is `"\\blinker"` — a literal backslash,
because that is how Yosys spells a user-written name. And there is a **second copy** of the same
numbers under a top-level `"design"` key that sums the whole design. Read `["design"]` and you
never have to guess the module name:

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

Seven statements, and now a lab can tell you that you got it right without an instructor
looking over your shoulder. That idea ships as
[`src/check_stat.py`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt),
with reference numbers and a PASS/FAIL added on top of these seven lines.

## The trap that makes the total quietly wrong

Delete `dfflibmap` from the blinker command and run it again. Nothing errors. Exit status is 0.

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

**102.60 µm² instead of 316.55, and 0.00% sequential in a design that is two-thirds
flip-flops.** You already know why —
[two mappers, not one](guide/synthesis-is-translation.md): `abc` does combinational logic,
`dfflibmap` does flip-flops, and a generic `$_DFF_*` cell with no liberty entry contributes
zero to the total. What is new here is how *quietly* it happens on a design big enough to care.

The dead giveaway is a cell type starting with `$_`. **A `$_` name in your final cell list
means something did not get mapped, and your area is too small by however much it was worth.**
`$scopeinfo` is the one harmless exception; everything else with a `$` is a real hole in the
total. Chase every `is unknown!` line before you believe a number.

[Lab 04 — Reading the receipt](labs/lab-04-reading-the-receipt-overview.md) breaks it on purpose, three
different ways, and has you fill in the numbers from your own runs.

## What to write down

| Line on the receipt | What it means |
|---|---|
| `N cells` | count — subtract `$scopeinfo`, and panic if you see a `$_` name |
| middle column | area of **that line**, not of one cell |
| `Chip area` | sum of standard cells, in µm². Not the die. |
| `of which … sequential` | the flip-flop share. The number worth watching. |
| `Area for cell type … is unknown!` | your total is wrong. Find out why. |

Next: [The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md), where a missing
`else` adds cells to this receipt that you never asked for and cannot simulate away.
