# Lab 04: Reading the receipt

You'll check a `stat` receipt by hand, then run four experiments that each ask you to write a
number down before you run the command. Each one is set up so that the number you write down
will be wrong, and working out why it's wrong is the lesson. You'll finish by timing the ripple
adder with OpenSTA and predicting the delay of a 64-bit one. The question that runs through the
whole lab is how you know a number is right when nobody is going to check it for you.

Time: about 3 hours, not counting Going further.

Package: [`labs/lab-04-reading-the-receipt/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt)

## Before you start

- You should have finished [Lab 02](../labs/lab-02-rtl-becomes-gates-overview.md), where you
  watched RTL become SKY130 cells, and `yosys -V` should say `Yosys 0.68`.
- Read [Reading the `stat` report](../guide/reading-stat.md) and
  [Carry delay and static timing](../guide/the-carry-has-to-walk.md).

Start every part from the package directory. These three lines load the course, take you there
and point `LIB` at the typical-corner liberty file:

```bash
mod dd103
cd labs/lab-04-reading-the-receipt
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

All `stat -liberty` does is one piece of arithmetic:

$$\text{area} = \sum_{\text{cell types } t} n_t \times a_t$$

where $n_t$ is how many cells of type $t$ the netlist contains and $a_t$ is the `area :` line
for that cell in the liberty file. That leaves two ways for the answer to be wrong:

1. $n_t$ isn't what you think it is, because synthesis rewrote your design.
2. $a_t$ doesn't exist, because a cell never got mapped to the technology, and Yosys counts the
   missing area as zero.

`make` runs Parts 2 to 5 in about five seconds, and each part also has its own target if you
want to run it by itself.

## Part 1: Prices on the receipt

Where does the area on a `stat` receipt come from?

1. Run `stat` on the mapped 4-bit adder without the liberty file, then with it:

   ```bash
   yosys -p "read_verilog -sv src/ripple4.sv src/fulladder.sv; synth -top ripple4; flatten;
             abc -liberty $LIB; opt_clean; stat"
   yosys -p "read_verilog -sv src/ripple4.sv src/fulladder.sv; synth -top ripple4; flatten;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   The first prints cell counts only. The second adds an area column and reports
   `16  110.106 cells`, four of which are `$scopeinfo`, along with an
   `Area for cell type $scopeinfo is unknown!` warning and `Chip area ... 110.105600`.

2. Look up the unit price of `maj3_1`:

   ```bash
   grep -A200 'cell ("sky130_fd_sc_hd__maj3_1")' $LIB | grep -m1 area
   ```

   You should see `area : 10.009600000;`, and the same lookup for `xnor2_1` gives `8.7584`. Use
   those two prices and the counts from step 1 to check the whole receipt by hand.

   <details>
   <summary>Answer</summary>

   $4 \times 10.0096 + 8 \times 8.7584 = 110.1056$

   </details>

3. Now remove the `$scopeinfo` bookkeeping cells before counting. Keep the backslash in front of
   `$scopeinfo`:

   ```bash
   yosys -p "read_verilog -sv src/ripple4.sv src/fulladder.sv; synth -top ripple4; flatten;
             abc -liberty $LIB; opt_clean; delete t:\$scopeinfo; stat -liberty $LIB"
   ```

You should see `12  110.106 cells`, no `is unknown!` warning, and the same total. If you still
see `16`, the backslash was missing, so the shell swallowed `$scopeinfo` before Yosys ever saw
it.

## Part 2: Predict the flip-flop count

How many flip-flops does a design with six bits of state get?

1. Open [`src/blinker.sv`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/src/blinker.sv),
   a four-state controller with a countdown timer. Look only at the `always_ff` block.

2. Count the bits assigned with `<=`. There are two state variables: `state`, a `logic [1:0]`
   enum, and `count`, a `logic [3:0]`. Every bit that has to survive a clock edge needs a
   flip-flop, so the number of bits is your prediction. Write it on paper.

3. Run:

   ```bash
   make predict
   ```

   It prints the receipt first:

   ```
          28  316.554 cells
           2   15.014   sky130_fd_sc_hd__a21o_1
           3   11.261   sky130_fd_sc_hd__clkinv_1
           7  175.168   sky130_fd_sc_hd__dfrtp_1
           1   26.275   sky130_fd_sc_hd__dfstp_2
           ...
      Chip area for module '\blinker': 316.553600
        of which used for sequential elements: 201.443200 (63.64%)
   ```

   Every cell whose name starts with `df` is a flip-flop, so the receipt says there are 8: seven
   `dfrtp_1` and one `dfstp_2`.

4. Read the next block, in which the same target pulls out the part of the synthesis log that
   explains what happened:

   ```
   2.7.1. Executing FSM_DETECT pass (finding FSMs in design).
   Found FSM state register blinker.state.
   ...
   2.7.6. Executing FSM_RECODE pass (re-assigning FSM state encoding).
   Recoding FSM `$fsm$\state$54' from module `\blinker' using `auto' encoding:
     mapping auto encoding to `one-hot` for this FSM.
     00 -> ---1
     10 -> --1-
     01 -> -1--
     11 -> 1---
   ```

   Where did the two extra flip-flops come from, and why is one of them a `dfstp_2`?

   <details>
   <summary>Answer</summary>

   Yosys re-encoded `state` as one-hot, which uses one bit per state, so four states take four
   bits. Four state bits plus four counter bits make eight. In one-hot, `IDLE` is `---1`, so the
   low state bit has to come out of reset high, and a flop that resets high is a set flop, which
   here is the `dfstp_2`. [Reading the `stat`
   report](../guide/reading-stat.md#fsm-re-encoding) walks through both.

   </details>

5. `make predict` also ran `scripts/nofsm.ys`, the same flow with `synth -nofsm`, which turns
   FSM re-encoding off. Read that block:

   ```
          27  264.003 cells
           6  150.144   sky130_fd_sc_hd__dfrtp_1
      Chip area for module '\blinker': 264.003200
        of which used for sequential elements: 150.144000 (56.87%)
   ```

   With re-encoding off, the flip-flop count is the six you predicted. Which encoding gave the
   smaller design, and what should you take from it?

   <details>
   <summary>Answer</summary>

   The binary encoding did, at 264.00 µm² against 316.55. One-hot spent two extra flip-flops
   (50 µm²) to make the decoding cheaper, and on a four-state machine that trade doesn't pay.
   That doesn't mean you should always use `-nofsm`. What you should take from it is that you
   have to go and look at the netlist, because every number you quote comes from it.

   </details>

6. Look up the prices of a few flip-flops and simple gates, to see why flip-flops are so
   expensive:

   ```bash
   for c in dfxtp_1 dfrtp_1 dfstp_2 nor2_1 nand2_1 inv_1; do
     echo -n "$c  "; grep -A200 "cell (\"sky130_fd_sc_hd__$c\")" $LIB | grep -m1 area
   done
   ```

You should see `dfrtp_1` at `25.024000000` and `nand2_1` at `3.7536000000`. Use these prices to
work out the sequential total, and check it against the receipt's `201.443200`.

<details>
<summary>Answer</summary>

$$7 \times 25.024 + 1 \times 26.2752 = 201.4432\ \mu\text{m}^2 \quad\text{of}\quad 316.5536$$

So eight cells out of twenty-eight take up 63.64 % of the silicon, and the twenty cells that
actually decide anything share the other 115.11 µm².

</details>

## Part 3: Leaving out `dfflibmap`

What happens to the receipt when one mapping command is missing?

[`scripts/broken.ys`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/scripts/broken.ys)
is `scripts/baseline.ys`, the script `make predict` ran in Part 2, with exactly one line deleted:

```
dfflibmap -liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

1. Write down what you expect to break.

2. Run:

   ```bash
   make broken
   ```

You should see the run succeed, with exit status 0 and a receipt that looks normal at first
glance:

```
yosys scripts/broken.ys -> exit status 0   (yes. zero.)
       26  105.101 cells
   Area for cell type $_DFFE_PN0P_ is unknown!
   Area for cell type $_DFF_PN0_ is unknown!
   Area for cell type $_DFF_PN1_ is unknown!
   Chip area for module '\blinker': 105.100800
     of which used for sequential elements: 0.000000 (0.00%)
```

The receipt says 105.10 µm² instead of 316.55, and 0.00 % sequential for a design that is two
thirds flip-flops. It's short by 211.45 µm², which is 67 % of the design, and yet the run exited
with status zero. Why?

<details>
<summary>Answer</summary>

`abc -liberty` maps combinational logic only. Without `dfflibmap`, the flip-flops stay as
`$_DFF_*` cells, which are Yosys's internal technology-independent placeholders. They have no
liberty entry, so each one contributes zero area.

</details>

> **Rule** (from [Reading the `stat` report](../guide/reading-stat.md#unmapped-cells)): a cell
> type in your final netlist that starts with `$_` was never mapped, so your area is too small by
> whatever that cell would have cost. `$scopeinfo` is the one harmless exception, and every
> `is unknown!` line needs tracking down before you believe a number.

After that, the same target runs the self-check on the broken JSON, and Part 6 explains what it
prints.

## Part 4: Five synthesis scripts

Which script gives "the" area of `blinker.sv`?

1. Before you run anything, read the descriptions of the five scripts and decide which one gives
   the area:

   | Script | What it does |
   |---|---|
   | `explicit.ys` | `synth` written out by hand: `proc / opt / fsm / memory / techmap / opt` |
   | `explicit_nodffe.ys` | the same, but with `opt -nodffe -nosdff` before `fsm` |
   | `baseline.ys` | plain `synth -top blinker` |
   | `flat.ys` | `synth -top blinker -flatten` |
   | `fast.ys` | `synth`, then ABC's three-command fast script |

2. Run:

   ```bash
   make scripts
   ```

   ```
   file                            cells  flops   area (um^2)   seq %
   ------------------------------------------------------------------
   blinker_explicit.json              25      6        262.75   57.1%
   blinker_explicit_nodffe.json       30      8        327.81   61.5%
   blinker.json                       28      8        316.55   63.6%
   blinker_flat.json                  28      8        316.55   63.6%
   blinker_fast.json                  44      8        374.11   53.8%
   ```

3. The hand-written `explicit.ys` ends up with only six flip-flops, so it lost the FSM somewhere.
   Find out why:

   ```bash
   grep -A1 FSM_DETECT results/baseline.log
   grep -A1 FSM_DETECT results/explicit.log
   ```

   You should see `Found FSM state register blinker.state.` after the first header and nothing
   after the second. What did `explicit.ys` do differently?

   <details>
   <summary>Answer</summary>

   Plain `opt` folds the clock enable into a `$dffe` cell before `fsm` runs, and `fsm_detect`
   then no longer recognises `state` as a state register. `synth` runs `opt -nodffe -nosdff` at
   that point instead, so that this doesn't happen. Adding those two flags to that one line of
   `explicit.ys` brings the FSM back, and that's the `explicit_nodffe` row: the change on one
   line is worth two flip-flops and 65.06 µm².

   </details>

4. Compare the ABC command scripts, which are the `ABC: +` lines in `results/baseline.log` and
   `results/fast.log`:

   ```
   baseline: strash / &get -n / &fraig -x / &put / scorr / dc2 / dretime /
             strash / &get -n / &dch -f / &nf / &put
   fast:     strash / dretime / map
   ```

You should see five areas between 263 and 374 µm², which is a 42 % spread from a single source
file that never changed. Which row is the area of `blinker.sv`?

<details>
<summary>Answer</summary>

None of them is the one correct row. `-flatten` made no difference here because `blinker` has
no submodules, but on `ripple4` in Part 5 flattening changes everything. The fast script runs
three ABC commands instead of twelve, and it made the design about 18 % bigger, so you bought
synthesis runtime with silicon.

The question "how big is it?" has no answer until you add "under which script?". LibreLane
exposes this knob as `SYNTH_STRATEGY`, which is why two competent people can report different
areas for the same RTL and both be right. Every time you quote an area, quote the script that
produced it alongside the number.

</details>

## Part 5: The area gap

Why is `ripple4` smaller than four full adders? This part goes back to the DD102 adder, which is
in this package as `src/fulladder.sv` and `src/ripple4.sv`. In
[Lab 01](../labs/lab-01-one-adder-two-targets-overview.md), Part 6, you predicted the chained
adder's area as four times one `fulladder` (33.7824 µm²), and the measured 110.1056 µm² came out
18.5 % smaller than that.

1. `make gap` runs three scripts: one `fulladder` alone, four chained and flattened, and
   `scripts/gap_hier.ys`, which is the same four with the `flatten` line removed, so that ABC
   optimizes each `fulladder` on its own. Before you run it, write down what you expect
   `gap_hier.ys` to report.

2. Run:

   ```bash
   make gap
   ```

   It synthesizes one `fulladder` alone first:

   ```
           2   33.782 cells
           1    10.01   sky130_fd_sc_hd__maj3_1
           1   23.773   sky130_fd_sc_hd__xor3_1
      Chip area for module '\fulladder': 33.782400
   ```

   Multiply that area by four and write the result on the blank line the Makefile prints.

3. Read the chained result:

   ```
          12  110.106 cells
           4   40.038   sky130_fd_sc_hd__maj3_1
           8   70.067   sky130_fd_sc_hd__xnor2_1
      Chip area for module '\ripple4': 110.105600
   ```

   That's 110.11 µm², 18.5 % less than your $4 \times 33.7824 = 135.1296\ \mu\text{m}^2$. The
   four `maj3_1` are still there, because carry-out is still the majority function, so the
   difference has to come from somewhere else. Use the two cell lists to account for all of it.

   <details>
   <summary>Answer</summary>

   The difference is all in the sum. On its own, ABC builds `a ^ b ^ cin` from one `xor3_1`, but
   in the chain it builds each sum from two `xnor2_1`:

   $$\underbrace{23.7728}_{\texttt{xor3\_1}} - \underbrace{2 \times 8.7584}_{\texttt{2 × xnor2\_1}} = 6.256 \qquad 4 \times 6.256 = 25.024\ \mu\text{m}^2$$

   and $135.1296 - 110.1056 = 25.024$, so the entire gap is that one cell swap, made four times.
   Two `xnor2_1` are smaller than a single `xor3_1`, but one logic level deeper. In a full adder
   on its own, the sum is the critical path, so ABC pays for the fast cell. In a chain the carry
   is the critical path and the sum has slack to spare, so ABC spends that slack on area.

   </details>

4. Read the last run, from `gap_hier.ys`, and compare it with what you wrote in step 1:

   ```
           8   135.13 cells
           4   40.038   sky130_fd_sc_hd__maj3_1
           4   95.091   sky130_fd_sc_hd__xor3_1
      Chip area for top module '\ripple4': 135.129600
   ```

You should see 135.1296 µm², which matches your prediction to the last digit. What does that
tell you about predicting a design's area from its parts?

<details>
<summary>Answer</summary>

Adding up the parts gives exactly the answer the tool gives when you stop it from looking across
the module boundaries you drew. Once it can look across them, a block costs less in context than
it does alone. That is the point Lab 01, Part 6 left you with, and now you've measured both
sides of it. It's why you can't answer "how big is my design?" from a spreadsheet of parts, and
why datasheet areas are always given for a whole block.

</details>

## Part 6: The self-check

How does a script tell a good receipt from a bad one? No instructor checks your numbers in this
course, so instead there's
[`src/check_stat.py`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/src/check_stat.py),
which checks them for you.

Every script in this lab ends with `tee -o results/<name>.json stat -json -liberty <the liberty
file>`, which captures the receipt as JSON. The checker reads four keys from that file
(`num_cells`, `area`, `sequential_area` and `num_cells_by_type`) under the top-level `"design"`
object, and [Reading the `stat` report](../guide/reading-stat.md#the-machine-readable-receipt)
shows what the file looks like.

1. Run the checker on the good run:

   ```bash
   python3 src/check_stat.py results/blinker.json --expect blinker
   ```

   ```
   blinker.json
     cells      : 28
     flip-flops : 8
     area       : 316.55 um^2
     sequential : 201.44 um^2 (63.6%)
     PASS  (matches the reference run)
   ```

   It exits with status 0 on a pass and 1 on a fail, so a `Makefile` can stop when a check fails.

2. Now run the checker on the unmapped run from Part 3, which is what the end of `make broken`
   did:

   ```bash
   python3 src/check_stat.py results/blinker_broken.json --expect blinker
   ```

   ```
   blinker_broken.json
     cells      : 26
     flip-flops : 0
     area       : 105.10 um^2
     sequential : 0.00 um^2 (0.0%)
     FAIL
       - unmapped cells in the netlist: $_DFFE_PN0P_, $_DFF_PN0_, $_DFF_PN1_
         A type starting with '$' has no liberty entry, so it contributed 0 um^2.
         Your area is too small by however much those cells were worth. Did you
         remember dfflibmap?
       - flip-flop count 0, expected exactly 8
       - area 105.10 um^2, expected about 316.55 um^2
       - sequential area 0.00 um^2, expected about 201.44
   ```

You should see `PASS` for `blinker.json` and `FAIL` for `blinker_broken.json`. Reading a FAIL is
a skill, and the best time to practise it is on one you caused on purpose, when you already know
what went wrong.

## Part 7: Time the adder

How does the worst path through a ripple adder grow with its width? This part runs the analysis
from [Carry delay and static timing](../guide/the-carry-has-to-walk.md) on `src/ripple.sv`, using
`scripts/timing.tcl`.

1. Check the timing tool:

   ```bash
   sta -version
   ```

   You should see `3.1.0`.

2. Synthesize the 4-bit adder and write the gate-level netlist:

   ```bash
   yosys -q -p "read_verilog -sv src/ripple.sv src/fulladder.sv
                chparam -set N 4 ripple
                synth -top ripple
                flatten
                abc -liberty $LIB
                opt_clean
                write_verilog -noattr results/gates4.v"
   ```

3. Ask for the worst path:

   ```bash
   NETLIST=results/gates4.v sta -exit scripts/timing.tcl
   ```

   You should see `Startpoint: b[0]`, `Endpoint: cout`, four `sky130_fd_sc_hd__maj3_1` in a row,
   and `1.481   data arrival time`.

4. Repeat steps 2 and 3 with `N` set to 8, 16 and 32, changing the netlist name to match
   (`results/gates8.v` and so on), and fill in this table:

   | N | worst path (ns) |
   |---|---|
   | 4 | |
   | 8 | |
   | 16 | |
   | 32 | |

   You should get 1.481, 3.049, 6.184 and 12.455 ns. Subtract neighbouring rows and divide by the
   number of extra bits. What do you get each time?

   <details>
   <summary>Answer</summary>

   You get 0.392 ns every time, so each extra bit adds the same delay to the worst path.

   </details>

5. Predict $T(64)$ with $T(N) = 0.370 + 0.392\,(N-2) + 0.328$, the formula from
   [Carry delay and static timing](../guide/the-carry-has-to-walk.md), and write your prediction
   down. Then measure it:

   ```bash
   yosys -q -p "read_verilog -sv src/ripple.sv src/fulladder.sv; chparam -set N 64 ripple;
                synth -top ripple; flatten; abc -liberty $LIB; opt_clean;
                write_verilog -noattr results/gates64.v"
   NETLIST=results/gates64.v sta -exit scripts/timing.tcl | grep "data arrival"
   ```

   You should see `24.996   data arrival time`. How close was your prediction?

   <details>
   <summary>Answer</summary>

   The formula gives 25.002 ns, which is within six picoseconds of the measured 24.996 ns.

   </details>

6. The script uses a 100 ns clock period. Make copies of it with more realistic periods of 2 ns
   and 1 ns, and read the slack:

   ```bash
   for P in 2 1; do
     sed "s/-period 100/-period $P/" scripts/timing.tcl > results/timing_$P.tcl
     echo "period $P ns:"
     NETLIST=results/gates4.v sta -exit results/timing_$P.tcl | grep -E 'slack'
   done
   ```

   You should see `0.519   slack (MET)` at 2 ns and `-0.481   slack (VIOLATED)` at 1 ns.

7. Now time the same netlist at two other process corners:

   ```bash
   for C in ss_n40C_1v28 ff_100C_1v65; do
     sed "s/tt_025C_1v80/$C/" scripts/timing.tcl > results/timing_$C.tcl
     echo "$C:"
     NETLIST=results/gates4.v sta -exit results/timing_$C.tcl | grep "data arrival"
   done
   ```

You should see `13.249` ns at the slow corner and `1.000` ns at the fast corner, against
`1.481` ns at typical. The netlist is the same in all three runs, and it's nine times slower at
the slow corner than at typical.

## Finishing

### You're done when

Each of your written predictions (Parts 2, 3, 4, 5 and 7) has the tool's number next to it, and
your Part 7 table is filled in from your own runs.

`make table` reprints the summary of every run in this lab, and the package README lists the
reference values to compare against.

### Questions

Answer each in one sentence, using your own numbers. The step in parentheses has the answer.

1. Why does `blinker.sv` have eight flip-flops when you wrote six bits of state? (Part 2, step 4)
2. What is wrong with `105.10 µm²`, and what in the output told you? (Part 3)
3. Which of `262.75`, `316.55` and `374.11` is the area of `blinker.sv`? (Part 4)
4. Why is `ripple4` smaller than four `fulladder`s, and what makes it exactly `135.1296` again?
   (Part 5, steps 3 and 4)
5. What is the worst path of your 4-bit adder at the typical corner, and what is the slack with
   a 2 ns clock? (Part 7, steps 3 and 6)
6. `stat` says `blinker.sv` is 316.55 µm². Is that the size of the chip it would become?

   <details>
   <summary>Answer</summary>

   No. `Chip area` is the sum of the standard-cell areas and nothing else. When LibreLane takes
   the same `blinker.sv` all the way to a layout, with the flow's default floorplan settings, it
   reports 1929.33 µm² of die (38.89 × 49.61 µm) and 109 placed instances, against `stat`'s 28
   cells. The difference is made up of clock buffers, timing-repair buffers, well taps, filler
   and the empty space the router needs, while the 8 sequential cells are the same in both. So
   use `stat -liberty` to compare two versions of your own design, not to size a chip.
   [From netlist to layout](../guide/from-gates-to-geometry.md) is where the die number comes from, and [Lab 05](../labs/lab-05-elevator-overview.md) is where you produce one.

   </details>

### Submit

Nothing to submit.

## Going further (optional)

- Pass `-group_count 10` to `report_checks` in a copy of `timing.tcl` to see the next nine
  paths after the worst one.
- Put the adder between two registers, as in
  [Carry delay and static timing](../guide/the-carry-has-to-walk.md#registered-adder-and-minimum-clock-period),
  synthesize it with `dfflibmap -liberty $LIB` before `abc`, and time it with
  `create_clock -name clk -period 3.0 [get_ports clk]` and `report_clock_min_period`. Compare
  your `period_min` with the 2.96 ns on that page.
- Save the `stat_min.py` script from [Reading the `stat` report](../guide/reading-stat.md#the-machine-readable-receipt)
  as `results/stat_min.py` and run it on `results/blinker.json`.

Next on the [Course path](../index.md#course-path): read
[Writing a state machine](../guide/state-machine-is-a-table.md) and
[From netlist to layout](../guide/from-gates-to-geometry.md), then do
[Lab 05: Elevator to GDSII](../labs/lab-05-elevator-overview.md).
