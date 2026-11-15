# Lab 05: Elevator to GDSII

You'll finish a four-floor elevator controller from a state table and take it all the way to a
`.gds` file: a real chip layout that is DRC clean and LVS clean, has zero antenna violations, and
is rendered as a picture at the end. You start from `src/elevator.sv`, a three-state elevator
that works but is a bad elevator in two specific ways, and fixing those two things is the design
half of the lab.

Time: about 4–5 hours, not counting Going further.

Package: [`labs/lab-05-elevator/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-05-elevator)

## Before you start

- Finish [Lab 04](../labs/lab-04-reading-the-receipt-overview.md) first, so that `stat -liberty`
  is familiar.
- Read [Writing a state machine](../guide/state-machine-is-a-table.md) and
  [From netlist to layout](../guide/from-gates-to-geometry.md).
- Check your versions: `yosys -V` should say `Yosys 0.68` and `librelane --version` should say
  `LibreLane v3.1.0.dev3`.
- Each LibreLane run directory is about 65 MB, so budget a few hundred megabytes of disk and
  delete the run tags you no longer need.

Start in the package directory:

```bash
mod dd103
cd labs/lab-05-elevator
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

## Part 1: Warm up on the vending machine

How many flip-flops does Yosys build for a three-bit state register, and what happens when a
state machine's `always_comb` is incomplete? You'll answer both on the vending machine from
[Writing a state machine](../guide/state-machine-is-a-table.md), which ships in
`examples/vending.sv`.

1. Synthesize it:

   ```bash
   cd examples
   yosys -p "read_verilog -sv vending.sv; synth -top vending;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see `17  231.472 cells`, five `sky130_fd_sc_hd__dfrtp_1` and one
   `sky130_fd_sc_hd__dfstp_2`, and `65.41%` sequential. That is six flip-flops for a state
   register that only needs three bits, and the next step shows why.

2. Find the FSM passes in the log:

   ```bash
   yosys -p "read_verilog -sv vending.sv; synth -top vending" 2>&1 | grep -A3 'FSM_DETECT pass'
   yosys -p "read_verilog -sv vending.sv; synth -top vending" 2>&1 | grep -c 'transition:'
   yosys -p "read_verilog -sv vending.sv; synth -top vending" 2>&1 | grep -A9 'FSM_RECODE pass'
   ```

   You should see `Found FSM state register vending.state.`, a count of `14` transitions, and
   `mapping auto encoding to `one-hot` for this FSM.` followed by six one-hot codes. Pick two
   `transition:` lines from the full log and match them to rows of the table in the guide.

3. Turn the FSM pass off:

   ```bash
   yosys -p "read_verilog -sv vending.sv; synth -top vending -nofsm;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see `13  137.632 cells` and `54.55%` sequential.

4. Force binary encoding. `synth` has no flag for the encoding, so the command below spells out
   the coarse passes one by one. Notice the `opt -nodffe -nosdff` before `fsm`:

   ```bash
   yosys -p "read_verilog -sv vending.sv; hierarchy -top vending; proc;
             opt_expr; opt_clean; opt -nodffe -nosdff;
             fsm -encoding binary;
             opt; wreduce; peepopt; opt_clean; alumacc; share; opt;
             memory -nomap; opt_clean; techmap; opt -fast;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see three `sky130_fd_sc_hd__dfrtp_1` and a chip area of `187.680000`. Compare the
   area with the one-hot run in step 1.

   <details>
   <summary>Answer</summary>

   Binary is smaller here, 187.68 µm² against the one-hot run's 231.472, because it uses three
   flip-flops instead of six.

   </details>

5. Lint it:

   ```bash
   verilator --lint-only -Wall vending.sv
   ```

   You should see a verilation report and no warnings.

6. Break it on purpose. In `vending.sv`, delete the three default assignments at the top of the
   `always_comb` (`next = state;`, `dispense = 1'b0;`, `refund = 1'b0;`) and the
   `default: next = IDLE;` line. Write down what you expect Yosys and Verilator to say, then run
   `synth` and the linter again:

   ```bash
   yosys -p "read_verilog -sv vending.sv; synth -top vending" 2>&1 | grep -B1 ERROR
   verilator --lint-only -Wall vending.sv
   ```

   You should see `ERROR: Latch inferred for signal `\vending.\dispense' from always_comb process`
   from Yosys, and from Verilator a `CASEINCOMPLETE` warning with `(example pattern 0x6)` and
   `LATCH` warnings for `next`, `dispense` and `refund`. Then put the file back:

   ```bash
   git checkout vending.sv
   cd ..
   ```

You should be back in `labs/lab-05-elevator` with `vending.sv` unchanged.

## Part 2: The skeleton

What does the shipped elevator do, and which checks does it fail? The finished elevator is a
Moore machine that has to remember three things:

| Register | Width | What it holds |
|---|---|---|
| `state` | 3 bits | where in the cycle the machine is |
| `pending` | 4 bits | which floors have calls nobody has answered yet (the call queue) |
| `dwell` | 4 bits | how many more ticks the doors have to stay open (the timer) |

The skeleton in `src/elevator.sv` has only `state`, with three states: `IDLE`, `MOVING` and
`DOORS` (the table below calls that last one `DOOR_OPEN`). You add `pending` in Part 3 and `dwell`
in Part 4, and the `TODO` comments in the file mark where each change goes.

The machine takes one step per clock tick. In a real building `clk` would come from a divider so
that a step lasted about half a second; here a tick is 20 ns, because that is the period the
testbench and `config.json` agree on.

This is the table you are implementing, with one row per state, and it is the spec for every
change you make in Parts 3 and 4:

| State | means | leaves when | `next` | `moving_up` | `moving_dn` | `door_open` |
|---|---|---|---|---|---|---|
| `IDLE` | parked, queue empty | `pending` is non-zero | `MOVING`, or `DOOR_OPEN` if already there | 0 | 0 | 0 |
| `MOVING` | travelling one floor per tick | `floor == target` | `DOOR_OPEN` | `target > floor` | `target < floor` | 0 |
| `DOOR_OPEN` | arrived; this call is answered | immediately | `DWELL` | 0 | 0 | 1 |
| `DWELL` | doors held open, counting down | `dwell == 0` | `DOOR_SHUT` | 0 | 0 | 1 |
| `DOOR_SHUT` | doors closing | immediately | `IDLE` | 0 | 0 | 0 |

`DOOR_SHUT` looks pointless, since all it does is go to `IDLE`. It's there so that `door_open`
falls one tick before the machine is free to take the next call. A Moore output is a property of
the state, so the clean way to get that extra tick is an extra state, rather than a condition
spread across two of the others.

The elevator always serves the lowest pending floor next. That is a design decision rather than
the only correct answer, and one of the Going further exercises argues with it.

1. Lint the skeleton, then simulate it:

   ```bash
   make lint
   make sim
   ```

2. Before you edit anything, keep a copy of the skeleton for Part 5:

   ```bash
   cp src/elevator.sv results/elevator_skeleton.sv
   ```

You should see lint exit 0 on the code we shipped, and then six checks, three of which fail:

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

The skeleton lints clean, synthesizes, and hardens to a valid chip, so every tool check passes
even though it strands people on floor 3. The only thing that catches the problem is a test that
describes what the machine is for.

## Part 3: The call queue (TODO 1)

How does the elevator remember a call after the button is released? Right now the priority
encoder reads `call` directly, so if you press a button and let go while the machine is busy,
the call is forgotten and the elevator never comes.

1. Declare `logic [3:0] pending;` and reset it to `4'd0`.
2. Point the priority encoder at `pending` instead of `call`.
3. Add a signal `serve` that your `always_comb` raises for one tick in `DOOR_OPEN`. Declare it as
   `logic`, and give it a default of `1'b0` at the top of the `always_comb`, alongside the
   defaults that are already there.
4. Give `pending` exactly one assignment in the `always_ff`:

   ```systemverilog
   pending <= (pending | call) & ~(serve ? (4'd1 << floor) : 4'd0);
   ```

5. Run `make sim`.

You should see T3 and the second half of T5 pass.

Two things want to write `pending`: the buttons set bits in it, and the doors clear one. Why does
step 4 give it a single assignment instead of two `if` statements?

<details>
<summary>Answer</summary>

If you write it as two separate `if` statements in the same `always_ff`, the last one wins, so a
button press that lands on the same tick as a service is lost. With one register and one
assignment, both effects are in the same expression and neither can overwrite the other. Every
status register in every chip is written this way.

</details>

## Part 4: A fifth state and a timer (TODO 2 and 3)

How do you hold the doors open for a fixed number of ticks?

1. Add `DWELL` and `DOOR_SHUT` to the `typedef enum`, and make each state's `next` and
   `door_open` follow the table in Part 2. The `TODO(3)` comment in the `DOORS` branch marks the
   place where you stop the machine from leaving that state after a single tick.
2. Declare `logic [3:0] dwell;`, and two control lines, `logic dwell_load;` and
   `logic dwell_dec;`, each with a default of `1'b0` at the top of the `always_comb`.
3. In the `always_comb`, raise `dwell_load` in `DOOR_OPEN`, and `dwell_dec` in `DWELL` while
   `dwell != 0`.
4. Drive `dwell` from those two control lines in the `always_ff`:

   ```systemverilog
   if      (dwell_load) dwell <= DWELL_TICKS[3:0];
   else if (dwell_dec)  dwell <= dwell - 4'd1;
   ```

5. Delete the two `lint_off` / `lint_on` pragma lines around `DWELL_TICKS` at the top of the file,
   as the comment there says, and run `make lint`. Those pragmas were hiding an unused-parameter
   warning, so if lint still passes without them, your timer really does use `DWELL_TICKS`.
6. Run `make sim`.

You should see:

```
T4  tap call[0] and time the doors
  PASS  T4 floor 0 reached
      doors stayed open for 6 ticks
  PASS  T4 doors stay open at least 4 ticks (dwell timer)
...
ALL CHECKS PASSED
```

`DWELL_TICKS` is 4, but the doors stayed open for six ticks. Where do the six come from?

<details>
<summary>Answer</summary>

The doors are open for one tick in `DOOR_OPEN`, and then for five more in `DWELL` while the
counter goes 4, 3, 2, 1, 0.

</details>

Notice that the `always_ff` makes no decisions of its own; it only reads two wires that the
`always_comb` has already worked out. So when the machine misbehaves, there is only one block
you need to look at, the one with the `case` in it.

If Icarus says `This assignment requires an explicit cast.`, or Verilator stops on a comment with
`%Error-BADVLTPRAGMA`, neither one means your logic is wrong; see
[Troubleshooting](../reference/troubleshooting.md#icarus-wants-an-explicit-cast).

## Part 5: Compare the receipts

What did the call queue, the timer and two more states cost in silicon?

1. The skeleton has 7 flip-flops. Write down how many you expect your finished design to have.

2. Run `make synth` on your finished design:

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

3. Compare with the skeleton's numbers below. (If you want to reproduce them, run the Yosys
   command from the `synth` target in the `Makefile` on the copy you saved in Part 2.)

| | Skeleton (3 states) | Finished (5 states) |
|---|---|---|
| cells | 43 | 76 |
| area | 382.87 µm² | 765.73 µm² |
| flip-flops | 7 | 17 |
| sequential share | 46.08 % | 55.72 % |

You should see that the finished design is roughly twice the size of the skeleton. Where did the
ten extra flip-flops come from?

<details>
<summary>Answer</summary>

Eight of them are `pending` and `dwell`, four bits each. The other two come from the state
machine: Yosys makes the state register one-hot, with one bit per state, and you went from three
states to five. With `-nofsm`, which leaves the 3-bit state register alone (see Going further),
the finished design has 15.

The seventeen flops are 22 % of the cells but 55.72 % of the area. A `dfrtp_1` costs 25.02 µm²
and a `nand2_1` costs 3.75, so the state is the expensive part of the design. That is why
engineers argue about minimizing states, and you now have a number of your own to argue with.

</details>

## Part 6: The RTL view

Which diagram of the finished design is worth drawing?

1. Run `make show`, then open `results/elevator_rtl.svg` in the browser or with `xdg-open`.
2. Search the SVG for your own signal names: `floor`, `target`, `pending`, `dwell`, `state`,
   `serve`, `any_pending`, `first_pending`, `door_open`, `moving_up`, `seg`.

You should see a wide strip (6503 × 1566 pt for the finished design) with your names on the
wires, and five register boxes, one for each of your five multi-bit state elements.

Don't run `show` on the gate netlist. On this design it comes out 883 × 9018 pt, a vertical
ribbon ten times taller than it is wide with 76 unlabelled boxes in it. The gate view in
[Lab 02](../labs/lab-02-rtl-becomes-gates-overview.md) was readable only because it was a two-cell
full adder. Once a design this size is mapped to cells, the useful way to look at it is as a
layout, which you'll do in Part 9.

## Part 7: RTL to GDSII

What does it take to turn your elevator into a layout, and how do you know it built the chip you
meant? We've already written `config.json` for you, but read it before you run it:

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

There are three things in it to notice:

- `PDK` and `STD_CELL_LIBRARY` are pinned, because the image's default PDK is `ihp-sg13g2`, a
  different technology. If you leave those two keys out, the flow still runs and exits 0, and it
  builds your chip out of `sg13g2_*` cells without reporting any error.
- `VERILOG_FILES` names one file rather than `dir::src/*.sv`. Upstream examples use the glob, but
  here it would also pick up `tb_elevator.sv` and ask LibreLane to build silicon out of your
  testbench.
- There is no `DIE_AREA`. Instead the floorplanner sizes the chip from `FP_CORE_UTIL`: you ask
  for 35 % core utilization and let it work out the rectangle.

1. Harden the design:

   ```bash
   make harden TAG=v1
   ```

   You'll see 80 stages scroll past, and then this:

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

   On a 6-core laptop with 7.5 GB of RAM this took 59 seconds of wall-clock time and peaked at
   525 MB. If yours takes noticeably longer, that means your design got bigger, not that
   anything is broken.

   A dozen `WARNING` lines follow. They are normal, and
   [Troubleshooting](../reference/troubleshooting.md#warning-lines-after-make-harden) lists them.
   The three ✅ lines are the results that matter, and you'll check them properly in Part 8.

2. Confirm you built the chip you meant to:

   ```bash
   grep -m1 "Liberty frontend" runs/v1/06-yosys-synthesis/yosys-synthesis.log
   grep '"PDK"' runs/v1/resolved.json
   ```

You should see a liberty path under `/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/` and
`"PDK": "sky130A",`. If the path says `ihp-sg13g2` instead, the flow is not reading your `PDK`
key.

> Use a new tag every time you harden, as in `make harden TAG=v2`. If you re-run with the same
> tag, LibreLane appends onto the finished run instead of starting over; see
> [Troubleshooting](../reference/troubleshooting.md#re-running-make-harden-with-the-same-tag).

## Part 8: The report card

Is the chip clean, and what is on it besides your logic?

1. Print the metrics:

   ```bash
   make metrics TAG=v1
   ```

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

   LibreLane exits 0 even on runs that have antenna violations in them, because the exit code
   only tells you that the flow finished. The four zeros at the bottom tell you whether the chip
   is good, and they are what "signoff clean" means.

2. Read the three sign-off reports directly:

   ```bash
   cat runs/v1/65-magic-drc/reports/drc.magic.rpt
   tail -5 runs/v1/71-netgen-lvs/reports/lvs.netgen.rpt
   cat runs/v1/47-openroad-checkantennas-1/reports/antenna_summary.rpt
   ```

   You should see `[INFO] COUNT: 0`, then `Final result: Circuits match uniquely.`, then an
   antenna table with a header and no rows.

3. Count the cell classes on the die:

   ```bash
   python3 -c "
   import json
   m = json.load(open('runs/v1/final/metrics.json'))
   for k, v in sorted(m.items()):
       if 'count__class' in k: print(k.split(':')[-1], v)
   print('design__instance__count', m['design__instance__count'])"
   grep -c sky130_fd_sc_hd runs/v1/final/nl/elevator.nl.v
   ```

   You should see `sequential_cell 17`, and a `grep -c` count equal to
   `design__instance__count`, which means every instance on the die is a SKY130 cell. A count of
   `0` would mean you hardened a different technology.

Three of the metrics need some explaining. Answer each question below from your own run.

`design__instance__count__stdcell` is 148, where Yosys said 76. What are the other 72?

<details>
<summary>Answer</summary>

They are real cells that the flow added after synthesis: 30 well taps, a clock tree, hold-fix
delay cells and antenna diodes. The table in the answer to the last of these three questions
counts each kind, and the logs show what was inserted:

```
[INFO CTS-0018]     Created 3 clock buffers.
[INFO RSZ-0046] Found 11 endpoints with hold violations.
[INFO RSZ-0032] Inserted 14 hold buffers.
```

So the flow found eleven hold violations, none of which you wrote. A hold violation is data
arriving at a flip-flop too early: the previous stage was so fast that the new value overtook the
clock edge. The fix is to slow the path down on purpose, which is why the layout
contains 32 timing-repair buffers costing 320.31 µm². It's also why `timing__hold__ws` came out
at +0.108 ns, only just positive, because positive by a small margin is what the resizer aims
for.

</details>

`timing__setup__ws` is +11.66 ns on a 20 ns clock. Roughly how fast could this elevator run?

<details>
<summary>Answer</summary>

Your longest path takes about 8.3 ns (20 − 11.66), so this elevator would run at roughly
120 MHz. That leaves 11.66 ns of headroom it isn't using, which you could spend on more floors or
a smarter scheduler.

</details>

The finished layout contains 481 physical cells, and `metrics.json` counts 148 of them as
standard-cell instances. How many of the 481 compute anything?

<details>
<summary>Answer</summary>

Only 118 of the 148 do:

| | count | what it is |
|---|---|---|
| `decap` | 265 | decoupling capacitors, which store charge locally for the power rails |
| `fill` | 68 | nothing at all; filler that keeps the rows continuous |
| `tapvpwrvgnd` | 30 | well taps, which tie the substrate to the rails |
| `dfrtp` / `dfstp` | 17 | your flip-flops |
| `clkdlybuf` / `dlygate` / `clkbuf` / `buf` | 37 | the clock tree and hold repair |
| `diode` | 6 | antenna protection |
| everything else | 58 | your logic |

Decap, fill and taps account for 363 of the 481, so more than two thirds of the cells in your
chip are there to make the silicon manufacturable rather than to make the elevator work. That is
normal. It is also why an area number from `stat` always underestimates the rectangle you end up
paying for: 765.73 µm² of cells landed in a 4553.88 µm² die.

</details>

## Part 9: The layout

What does your chip look like, and which file is the deliverable? The flow has already rendered
the layout to an image for you, so you don't need a screenshot or an X server.

1. Find the render, then open it in the noVNC desktop's browser or with `xdg-open`:

   ```bash
   ls -l runs/v1/final/render/elevator.png
   ```

   ![The elevator, hardened](../assets/img/lab05-elevator-render.png)

2. Check the GDS:

   ```bash
   ls -l runs/v1/final/gds/elevator.gds
   ```

   ```
   -rw-r--r-- 1 designer designers 420588 ... runs/v1/final/gds/elevator.gds
   ```

You should see a rectangle 62.335 × 73.055 µm: rows of standard cells, magenta power straps
running vertically, a thicket of routing, and pins on the edges. If you zoom in far enough you
can make out the individual cells. A human hair is 60–80 µm across, so your entire elevator
controller is narrower than one hair.

The 411 KB GDS file is the deliverable. It holds the polygons, layer by layer, that a foundry
would use to make masks. Everything else in `final/`
(`def/ lef/ lib/ nl/ sdc/ sdf/ spef/ spice/ vh/`) is the paperwork that goes with it: the
netlist someone else would simulate, the timing
model someone else would build on, and the abstract view someone else would place next to their
own block.

## Finishing

### You're done when

`make sim` prints `ALL CHECKS PASSED` for your `src/elevator.sv`, and `make metrics` on your
hardened run shows 0 for all four error counts, positive setup and hold slack, and a synthesis
log that names `sky130_fd_sc_hd`, not `sg13g2`.

Fill in this table from your own run, so that you have a record of it:

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

If your cells and area are within about 20 % of ours, you built the same kind of thing we did.
Once all six of your own checks pass, compare your design with the
[reference implementation](https://github.com/uoftasic/dd103/tree/main/labs/lab-05-elevator/solutions).

### Questions

1. Your numbers won't match ours exactly. Why not, and which ones have to?

   <details>
   <summary>Answer</summary>

   A different call-scheduling rule, or one extra state, moves every number, so there's no
   reason they should match. The ones that must match are these: all six checks pass, the four
   error counts are zero, setup and hold slack are both positive, and the synthesis log names
   `sky130_fd_sc_hd`, not `sg13g2`.

   </details>

### Submit

Nothing to submit. Do keep two files from this lab, though: `elevator.sv` and
`runs/<tag>/final/metrics.json`.

## Going further (optional)

- Write `tb_vending.sv` for the Part 1 vending machine yourself. Hold `rst_n` low for two
  cycles, pulse `nickel` or `dime` for one cycle at a time, and `$display` whenever `dispense` goes high. Run it with
  `iverilog -g2012 -o ../results/tb_vending.vvp tb_vending.sv vending.sv` and
  `vvp ../results/tb_vending.vvp` from `examples/`. Two dimes and four nickels should each
  dispense with `refund=0`, and a nickel then two dimes should dispense with `refund=1`.
- Delete a state. Merge `DOOR_SHUT` into `DWELL` and re-run `make synth`, so that you lose a
  state and gain a condition in its place. Before you look, write down whether you expect the
  chip to shrink.
- Argue with the scheduler. Serving the lowest pending floor first means somebody on floor 3
  waits forever if people on floors 0 and 1 keep pressing their buttons. Real elevators use SCAN:
  keep going in the direction you were going, serve every call on the way, and then reverse.
  Implement it, re-run `make sim` (the six checks still pass, since SCAN is a superset), and see
  what it costs in cells.
- Let the tool re-encode, or stop it. `synth -top elevator -nofsm` leaves your 3-bit state
  register alone instead of making it one-hot, and gives 79 cells, 756.98 µm² and 15 flip-flops
  against the default's 76 / 765.73 / 17. That is two fewer flops and three more gates, for a
  design 1.1 % smaller. On this design the choice between binary and one-hot is worth almost
  nothing, and that's more useful to know than either side of the argument.
- Push the clock. Set `"CLOCK_PERIOD": 4.0` in `config.json` and harden again with a new tag.
  You have 11.66 ns of slack to spend, so find out where it runs out, and read
  `runs/<tag>/56-openroad-stapostpnr/` for the path that failed first.
- Grow it: add eight floors, a door-obstruction input, or an overload sensor. The flow handled 76
  cells in 59 seconds, but detailed routing time grows steeply with design size, so keep it under
  a few thousand cells and re-check the wall-clock time as you go.
- Compare with someone else. Two people who both passed all six checks will still have different
  cell counts, die sizes and slack, so work out together which of your design decisions caused
  the biggest gap.

Next on the [Course path](../index.md#course-path): this was the last row, and the end of DD103.
[DD104: Pre-Silicon Verification](https://uoftasic.com/dd104/) opens by putting your numbers next to
an 8-bit CPU's, a few thousand cells against your 76, and asking you to find the bugs in it.
