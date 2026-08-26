# Lab 05 — Elevator to GDSII

Full runnable package:
[`labs/lab-05-elevator/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-05-elevator).

Four floors, five states, and at the end of it a `.gds` file — a real chip layout, DRC clean,
LVS clean, zero antenna violations, rendered as a picture you can put on a poster.

You are not starting from a blank file. `src/elevator.sv` is already a working three-state
elevator. It is also a **bad** elevator, in two specific ways, and fixing those two things is
the lab.

## Prerequisites

- [IC101](https://uoftasic.com/ic101/) complete — you are inside
  `hpretl/iic-osic-tools:2026.04`. Check with `yosys -V` → `0.64` and
  `librelane --version` → `LibreLane v3.0.2`.
- [Lab 04 — Reading the receipt](labs/lab-04-reading-the-receipt-overview.md) done. `stat -liberty`
  should not be new.
- Read the capstone guide pages first:
  [A state machine is a table with a memory](guide/state-machine-is-a-table.md) →
  [From gates to geometry](guide/from-gates-to-geometry.md).
- **Disk:** each LibreLane run directory is about **65 MB**. Budget a few hundred megabytes
  and delete old run tags.

## Objectives

- Transcribe a five-row state table into the four-block FSM recipe, and get all six testbench
  checks to pass
- Add two state elements — a call queue and a countdown timer — and measure what they cost in
  flip-flops and square micrometres
- Run `librelane config.json` to completion and read `metrics.json` instead of the exit code
- Produce `runs/<tag>/final/gds/elevator.gds` and the KLayout render beside it

## Theory (short)

An elevator is a Moore machine with three things to remember:

| Register | Width | What it holds |
|---|---|---|
| `state` | 3 bits | where in the cycle the machine is |
| `pending` | 4 bits | which floors have unanswered calls — **the call queue** |
| `dwell` | 4 bits | how many ticks the doors still have to stay open — **the timer** |

One clock tick is one "step". In a real building `clk` would come from a divider so a step is
about half a second; here it is 20 ns because that is what the testbench and `config.json`
agree on.

**The table you are transcribing.** Five rows, one per state:

| State | means | leaves when | `next` | `moving_up` | `moving_dn` | `door_open` |
|---|---|---|---|---|---|---|
| `IDLE` | parked, queue empty | `pending` is non-zero | `MOVING`, or `DOOR_OPEN` if already there | 0 | 0 | 0 |
| `MOVING` | travelling one floor per tick | `floor == target` | `DOOR_OPEN` | `target > floor` | `target < floor` | 0 |
| `DOOR_OPEN` | arrived; this call is answered | immediately | `DWELL` | 0 | 0 | **1** |
| `DWELL` | doors held open, counting down | `dwell == 0` | `DOOR_SHUT` | 0 | 0 | **1** |
| `DOOR_SHUT` | doors closing | immediately | `IDLE` | 0 | 0 | 0 |

`DOOR_SHUT` looks pointless — it does nothing but go to `IDLE`. It exists so that `door_open`
falls one tick *before* the machine is free to take the next call. That is what a Moore output
buys you: the output is a property of the state, so you get a clean extra state instead of a
condition smeared across two of them.

Which floor is `target`? **Lowest pending floor wins.** That is a decision, not a fact, and
"Going further" argues with it.

## Procedure

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-05-elevator
```

### Step 0 — Find out what you were handed

- **Try this:** `make lint`, then `make sim`.
- **What you should see:** lint exits 0 on code you did not write. Then six checks, three of
  which fail:

```
  PASS  T1 reset: floor 0, doors shut, display shows 1
T2  hold call[2] until the car arrives
  PASS  T2 held call to floor 2 is served
  PASS  T2 display shows 3 at floor 2
T3  tap call[3] for one cycle while the doors are open at floor 2
  FAIL  T3 one-cycle call to floor 3 is remembered (call queue)
T4  tap call[0] and time the doors
  PASS  T4 floor 0 reached
      doors stayed open for 1 ticks
  FAIL  T4 doors stay open at least 4 ticks (dwell timer)
T5  tap call[1] and call[3] in the same cycle
  PASS  T5 floor 1 served first
  FAIL  T5 floor 3 served afterwards

3 CHECK(S) FAILED
  -> not done yet. Fix the TODO blocks in src/elevator.sv.
make: *** [Makefile:32: sim] Error 1
```

- **Why an engineer cares:** the skeleton lints clean, synthesizes, and hardens to a valid
  chip. It is *correct* in every sense a tool can check, and it still strands people on floor
  3. **Lint clean does not mean right, and neither does a GDS.** The only thing that caught it
  was a test that described what the machine is *for*.

### Step 1 — TODO(1): the call queue

Right now the priority encoder reads `call` directly. Press a button and let go, and if the
machine happened to be busy that tick, nobody is coming.

- **Try this:** declare `logic [3:0] pending;`, reset it to `4'd0`, point the priority encoder
  at `pending` instead of `call`, and give it exactly **one** assignment in the `always_ff`:

```systemverilog
pending <= (pending | call) & ~(serve ? (4'd1 << floor) : 4'd0);
```

  where `serve` is a new signal your `always_comb` raises for one tick in `DOOR_OPEN`.

- **What you should see:** T3 and the second half of T5 turn green.
- **Why an engineer cares:** two things want to write `pending` — the buttons setting bits and
  the doors clearing one. Written as two separate `if` statements in the same `always_ff`, the
  last one silently wins and a press that lands on the same tick as a service is lost. One
  register, one assignment, both effects in the expression. Get used to that shape; it is how
  every status register in every chip is written.

### Step 2 — TODO(2) and TODO(3): a fifth state and a timer

- **Try this:** add `DWELL` (and `DOOR_SHUT`) to the `typedef enum`, declare
  `logic [3:0] dwell;`, and drive it from two combinational control lines — `dwell_load` in
  `DOOR_OPEN`, `dwell_dec` in `DWELL` while `dwell != 0`:

```systemverilog
if      (dwell_load) dwell <= DWELL_TICKS[3:0];
else if (dwell_dec)  dwell <= dwell - 4'd1;
```

- **What you should see:**

```
T4  tap call[0] and time the doors
  PASS  T4 floor 0 reached
      doors stayed open for 6 ticks
  PASS  T4 doors stay open at least 4 ticks (dwell timer)
...
ALL CHECKS PASSED
```

  Six, not four: one tick in `DOOR_OPEN` plus five in `DWELL` while the counter walks
  4, 3, 2, 1, 0.

- **Why an engineer cares:** no decision lives in the `always_ff`. It reads two wires that the
  `always_comb` already worked out. When your machine misbehaves you then have exactly one
  block to stare at, and it is the one with the `case` in it.

> **Two errors you will hit, from tools that disagree with each other.**
>
> Icarus rejects an enum assigned through a ternary:
>
> ```
> src/elevator.sv:89: error: This assignment requires an explicit cast.
> ```
>
> That is `next = (a == b) ? DOORS : MOVING;`. Verilator accepts it; `iverilog -g2012` does
> not. Write it as `if`/`else` and both are happy.
>
> And if you write a comment that *starts* with the word `verilator`, Verilator reads it as a
> directive aimed at itself:
>
> ```
> %Error-BADVLTPRAGMA: solutions/elevator.sv:12:1: Unknown verilator comment:
>                      '/*verilator --lint-only -Wall -> exit 0*/'
> ```
>
> Expect to hit at least one of these. Neither is a bug in your logic.

### Step 3 — Read the receipt, twice

- **Try this:** `make synth` on the finished design, then again on the skeleton — keep a copy
  of it before you start editing, or just compare against the numbers below.
- **What you should see**, on the finished elevator:

```
=== elevator ===

       76  765.734 cells
        ...
       16  400.384   sky130_fd_sc_hd__dfrtp_1
        1   26.275   sky130_fd_sc_hd__dfstp_2
        ...
   Chip area for module '\elevator': 765.734400
     of which used for sequential elements: 426.659200 (55.72%)
```

| | Skeleton (3 states) | Finished (5 states) |
|---|---|---|
| cells | 43 | **76** |
| area | 382.87 µm² | **765.73 µm²** |
| flip-flops | 7 | **17** |
| sequential share | 46.08 % | **55.72 %** |

- **Why an engineer cares:** eight extra flip-flops — four for `pending`, four for `dwell` —
  and the chip **doubled**. Seventeen flops are 22 % of the cells and **55.72 % of the area**:
  more than half of this chip is remembering where it is, not deciding where to go. A
  `dfrtp_1` costs 25.02 µm²; a `nand2_1` costs 3.75. **State is the expensive thing.** That is
  the entire reason engineers argue about minimizing states, and you now have your own number
  for it.

### Step 4 — Look at it, but only the RTL view

- **Try this:** `make show`, then open `results/elevator_rtl.svg` in the browser or in
  `xdg-open`.
- **What you should see:** a wide landscape strip — **6503 × 1566 pt** for the finished design
  — with your own names on the wires. Search the SVG for them: `floor`, `target`, `pending`,
  `dwell`, `state`, `serve`, `any_pending`, `first_pending`, `door_open`, `moving_up`, `seg`.
  Five register boxes, for your five multi-bit state elements.
- **Do not** run `show` on the gate netlist. Measured on this design, the gate-level diagram
  comes out **883 × 9018 pt** — a vertical ribbon ten times taller than it is wide, with 76
  unlabelled boxes in it. It is not a diagram, it is a wall. The readable gate view in
  [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) was a **two-cell** full adder, and that is about
  the size where `show` stops helping.
- **Why an engineer cares:** the RTL view is the one that still has your vocabulary in it. Once
  the design is mapped to cells, the picture belongs to the layout tools, and the way you look
  at it is a KLayout render — which is Step 7.

### Step 5 — RTL to GDSII

`config.json` is already written. Read it before you run it:

```json
{
  "DESIGN_NAME": "elevator",
  "VERILOG_FILES": ["dir::src/elevator.sv"],

  "PDK": "sky130A",
  "STD_CELL_LIBRARY": "sky130_fd_sc_hd",

  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 20.0,

  "FP_CORE_UTIL": 35,
  "PL_TARGET_DENSITY_PCT": 45,

  "RUN_HEURISTIC_DIODE_INSERTION": true,
  "RUN_ANTENNA_REPAIR": true
}
```

Three things in there are not decoration.

**`PDK` and `STD_CELL_LIBRARY` are pinned.** The image's default PDK is `ihp-sg13g2`, a
completely different technology. Leave those two keys out and the flow runs happily, exits 0,
and hands you a chip built out of `sg13g2_*` cells. Nothing errors. You would not find out.

**`VERILOG_FILES` names one file, not `dir::src/*.sv`.** The glob is what upstream examples
use, and here it would sweep up `tb_elevator.sv` and ask LibreLane to build silicon out of your
testbench.

**No `DIE_AREA`.** The floorplanner sizes the chip from `FP_CORE_UTIL` — you are asking for a
35 % core utilization and letting it work out the rectangle.

- **Try this:**

```bash
make harden TAG=v1
```

- **What you should see:** 80 stages scroll past, and then:

```
* Antenna
Passed ✅

* LVS
Passed ✅

* DRC
Passed ✅

[00:48:11] INFO     Saving views to '/work/runs/v1/final'…
[00:48:11] INFO     Flow complete.
Classic - Stage 80 - Report Manufacturability ━━━━━━━━━━━━━━━━━━━━ 80/80 0:00:57
```

  On a 6-core laptop with 7.5 GB of RAM this took **59 seconds wall clock** and peaked at
  **525 MB**. It is not an overnight job. If yours takes noticeably longer, your design got
  bigger, not broken.

  Then a dozen `WARNING` lines. They are normal on a design with no SDC file and no power
  source location — `'PNR_SDC_FILE' is not defined`, `found 2 floating nets`,
  `LEF58_ENCLOSURE with no CUTCLASS is not supported`. None of them is a failure. The failures
  are the three ✅ lines above, and Step 6 is how you check them properly.

- **Confirm you built the chip you meant to:**

```bash
grep -m1 "Liberty frontend" runs/v1/06-yosys-synthesis/yosys-synthesis.log
```

```
1. Executing Liberty frontend: /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

  If that path says `ihp-sg13g2`, your `PDK` key is not being read.

> Re-running with the same tag does **not** start over. LibreLane prints
> `INFO Using existing run at 'v1'` and appends stages **78, 79, 80…** onto the finished run,
> which is confusing and doubles the disk. Bump the tag every time:
> `make harden TAG=v2`. And do not reach for `--overwrite` — it crashes with a Python
> traceback when `runs/` does not exist yet.

### Step 6 — The report card, not the exit code

- **Try this:** `make metrics TAG=v1`.
- **What you should see:**

```
design__die__area                      4553.88
design__core__area                     2499.9
design__instance__utilization          0.550551
timing__setup__ws                      11.664674889496723
timing__hold__ws                       0.10763004681033471
route__wirelength                      1989
design__instance__count__stdcell       148
antenna__violating__nets               0
magic__drc_error__count                0
klayout__drc_error__count              0
design__lvs_error__count               0
```

- **Why an engineer cares:** LibreLane exits 0 on runs with antenna violations in them. The
  exit code tells you the *flow* finished, not that the *chip* is good. `metrics.json` is the
  thing to check, and those four zeros at the bottom are what "signoff clean" actually means.

Three of those numbers deserve a second look.

**`design__instance__count__stdcell` is 148.** Yosys said 76. The extra instances are real
cells that the flow added after synthesis: a clock tree, hold-fix delay cells, and antenna
diodes. Look at what got inserted:

```
[INFO CTS-0018]     Created 3 clock buffers.
[INFO RSZ-0046] Found 11 endpoints with hold violations.
[INFO RSZ-0032] Inserted 14 hold buffers.
```

Eleven hold violations you never wrote. A hold violation is data arriving at a flip-flop
*too early* — the previous stage was so fast that the new value overtook the clock edge. The
fix is to deliberately slow the path down, which is why the layout contains 32 timing-repair
buffers costing 320.31 µm², and why `timing__hold__ws` came out at **+0.108 ns**: just barely
positive, because that is exactly what the resizer was aiming for.

**`timing__setup__ws` is +11.66 ns on a 20 ns clock.** Your longest path takes about 8.3 ns, so
this elevator would run at roughly 120 MHz. It has 11.66 ns of headroom it is not using — which
is a design decision you could go spend, on more floors or a smarter scheduler.

**The finished layout contains 481 physical cells**, of which `metrics.json` counts 148 as
standard-cell instances — and only 118 of those compute anything at all:

| | count | what it is |
|---|---|---|
| `decap` | 265 | decoupling capacitors — local charge storage for the power rails |
| `fill` | 68 | nothing at all; filler so the rows are continuous |
| `tapvpwrvgnd` | 30 | well taps, tying the substrate to the rails |
| `dfrtp` / `dfstp` | 17 | your flip-flops |
| `clkdlybuf` / `dlygate` / `clkbuf` / `buf` | 37 | clock tree and hold repair |
| `diode` | 6 | antenna protection |
| everything else | 58 | your logic |

Decap, fill and taps are 363 of the 481. **More than two-thirds of the cells in your chip
exist to make the silicon manufacturable, not to make the elevator work.** That is normal, and
it is why an area number from `stat` is always an underestimate of the rectangle you end up
paying for: 765.73 µm² of cells landed in a 4553.88 µm² die.

### Step 7 — Go and look at your chip

The flow already rendered it. No screenshot choreography, no X server needed:

```bash
ls -l runs/v1/final/render/elevator.png
```

![The elevator, hardened](../assets/img/lab05-elevator-render.png)

- **What you should see:** a rectangle **62.335 × 73.055 µm**. Rows of standard cells, magenta
  power straps running vertically, a thicket of routing, and pins on the edges. Zoom in far
  enough and the individual cells resolve.
- **Why an engineer cares:** a human hair is 60–80 µm across. **Your entire elevator
  controller is narrower than one hair.** That number is the honest scale of everything this
  course has been about, and the picture is the receipt.

The GDS itself is next door:

```bash
ls -l runs/v1/final/gds/elevator.gds
```

```
-rw-r--r-- 1 designer designers 420588 ... runs/v1/final/gds/elevator.gds
```

**411 KB. That file is the deliverable.** It is the polygons, layer by layer, that a foundry
would use to make masks. Everything else in `final/` — `def/ lef/ lib/ nl/ sdc/ sdf/ spef/
spice/ vh/` — is the paperwork that goes with it: the netlist someone else would simulate, the
timing model someone else would build on top of you, the abstract view someone else would
place next to their block.

## Expected results

You are done when this table is filled in from **your own** run:

| | Your number | Ours |
|---|---|---|
| `make sim` result | | `ALL CHECKS PASSED` |
| `verilator --lint-only -Wall` exit code | | 0 |
| cells / area from `make synth` | | 76 / 765.73 µm² |
| flip-flops, and their share of the area | | 17 / 55.72 % |
| die area | | 4553.88 µm² |
| die size in µm | | 62.335 × 73.055 |
| setup worst slack | | +11.66 ns |
| hold worst slack | | +0.108 ns |
| DRC (magic), DRC (klayout), LVS, antenna | | 0, 0, 0, 0 |
| wall-clock time for `make harden` | | 59 s |
| `runs/<tag>/final/gds/elevator.gds` exists | | 420,588 bytes |

Your numbers will not match ours exactly, and should not — a different call-scheduling rule or
one extra state moves everything. What must match:

- all six checks pass
- the four error counts are **zero**
- setup and hold slack are both **positive**
- the synthesis log names `sky130_fd_sc_hd`, not `sg13g2`

If you are within about 20 % on cells and area, you built the same kind of thing we did.

## Going further

- **Delete a state.** Merge `DOOR_SHUT` into `DWELL` and re-run `make synth`. You lose a state
  and gain a condition. Did the chip get smaller? Write down the number before you look.
- **Argue with the scheduler.** Lowest-pending-floor-first means somebody on floor 3 waits
  forever if floors 0 and 1 keep pressing. Real elevators use **SCAN**: keep going the way you
  were going, serve everything on the way, then reverse. Implement it, re-run `make sim` (the
  six checks still pass — SCAN is a superset), and see what it costs in cells.
- **Let the tool re-encode, or stop it.** `synth -top elevator -nofsm` leaves your 3-bit state
  register alone instead of one-hotting it: **79 cells, 756.98 µm², 15 flip-flops** against the
  default's 76 / 765.73 / 17. Two fewer flops, three more gates, 1.1 % smaller. On this design
  the famous binary-vs-one-hot trade is worth almost nothing — which is a more useful thing to
  know than either side of the argument.
- **Push the clock.** Set `"CLOCK_PERIOD": 4.0` in `config.json` and harden again. You have
  11.66 ns of slack to spend; find out where it runs out and read
  `runs/<tag>/56-openroad-stapostpnr/` for the path that gave up first.
- **Grow it.** Eight floors, a door-obstruction input, an overload sensor. The flow handled 76
  cells in 59 seconds, but detailed routing scales steeply — keep it under a few thousand cells
  and re-check the wall-clock time as you go.
- **Compare with someone else.** Two people who both passed all six checks will have different
  cell counts, different die sizes and different slack. Find out which of your two decisions
  caused the biggest gap.

## Links

- [Lab package](https://github.com/uoftasic/dd103/tree/main/labs/lab-05-elevator) ·
  [reference implementation](https://github.com/uoftasic/dd103/tree/main/labs/lab-05-elevator/solutions)
  — **after** all six of your own checks pass, not before
- Guide: [A state machine is a table with a memory](guide/state-machine-is-a-table.md) ·
  [From gates to geometry](guide/from-gates-to-geometry.md)
- Reference: [The synthesizable subset](reference/synthesizable-subset.md) ·
  [OpenLane, OpenLane 2, LibreLane](reference/the-name-history.md)
- Previous lab: [Lab 04 — Reading the receipt](labs/lab-04-reading-the-receipt-overview.md)

---

**That is DD103.** Keep two files: `elevator.sv`, and `runs/<tag>/final/metrics.json`. DD104
opens by putting your numbers next to an 8-bit CPU's — a few thousand cells against your 76 —
and asking you to find the bugs in it.
