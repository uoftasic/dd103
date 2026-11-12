# Lab 04: Reading the receipt

You'll check a `stat` receipt by hand, then run four experiments that each ask you to write a
number down before you run the command. Each is set up so that the number you write down is
wrong, and the way it is wrong is the lesson. You'll finish by timing the ripple adder with
OpenSTA. The question running through the lab: how do you know your number is right when nobody
is going to check it for you?

Time: about 3 hours.

Package: [`labs/lab-04-reading-the-receipt/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt)

## Before you start

- [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) is complete: you have watched RTL become
  SKY130 cells. `yosys -V` says `Yosys 0.68`.
- Read [Reading the `stat` report](guide/reading-stat.md) and
  [Carry delay and static timing](guide/the-carry-has-to-walk.md).

Start every part from the package directory:

```bash
mod dd103
cd labs/lab-04-reading-the-receipt
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

`stat -liberty` does one piece of arithmetic:

$$\text{area} = \sum_{\text{cell types } t} n_t \times a_t$$

where $n_t$ is how many cells of type $t$ the netlist contains and $a_t$ is the `area :` line
for that cell in the liberty file. There are two ways for the answer to be wrong:

1. $n_t$ is not what you think, because synthesis rewrote your design. Part 2 is this case.
2. $a_t$ does not exist, because a cell never got mapped to the technology, and Yosys counts it
   as zero. Part 3 is this case.

`make` runs Parts 2 to 5 in about five seconds. Each part also has its own target.

## Part 1: Prices on the receipt

1. Run `stat` on the mapped 4-bit adder without the liberty file, then with it:

   ```bash
   yosys -p "read_verilog -sv src/ripple4.sv src/fulladder.sv; synth -top ripple4; flatten;
             abc -liberty $LIB; opt_clean; stat"
   yosys -p "read_verilog -sv src/ripple4.sv src/fulladder.sv; synth -top ripple4; flatten;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   The first gives counts only. The second adds an area column and `Chip area ... 110.105600`.

2. Look up the unit price of `maj3_1`:

   ```bash
   grep -A200 'cell ("sky130_fd_sc_hd__maj3_1")' $LIB | grep -m1 area
   ```

   You should see `area : 10.009600000;`. Check the whole receipt by hand:
   $4 \times 10.0096 + 8 \times 8.7584 = 110.1056$.

3. Remove the `$scopeinfo` bookkeeping cells before counting. Keep the backslash:

   ```bash
   yosys -p "read_verilog -sv src/ripple4.sv src/fulladder.sv; synth -top ripple4; flatten;
             abc -liberty $LIB; opt_clean; delete t:\$scopeinfo; stat -liberty $LIB"
   ```

You should see `12  110.106 cells`, no `is unknown!` warning, and the same total. If you still
see `16`, the shell swallowed `$scopeinfo` because the backslash was missing.

## Part 2: Predict the flip-flop count

1. Open [`src/blinker.sv`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/src/blinker.sv),
   a four-state controller with a countdown timer. Look only at the `always_ff` block.

2. Count the bits assigned with `<=`. There are two state variables: `state`, a `logic [1:0]`
   enum, and `count`, a `logic [3:0]`. A bit that survives a clock edge needs a flip-flop. Write
   your flip-flop count on paper.

3. Run:

   ```bash
   make predict
   ```

   It prints the receipt first:

   ```
          27  316.554 cells
           1    10.01   sky130_fd_sc_hd__a21bo_1
           2   15.014   sky130_fd_sc_hd__a21o_1
           1    8.758   sky130_fd_sc_hd__a31o_1
           1    6.256   sky130_fd_sc_hd__and2_0
           2    7.507   sky130_fd_sc_hd__clkinv_1
           7  175.168   sky130_fd_sc_hd__dfrtp_1
           1   26.275   sky130_fd_sc_hd__dfstp_2
           ...
      Chip area for module '\blinker': 316.553600
        of which used for sequential elements: 201.443200 (63.64%)
   ```

   You probably wrote 6. The receipt says 8: seven `dfrtp_1` and one `dfstp_2`. Every cell whose
   name starts with `df` is a flip-flop.

4. Read the next block, where the same target asks the log what happened:

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

   One-hot uses four state bits; four state bits plus four counter bits is eight. The odd
   `dfstp_2` is the bit that has to leave reset high. [Reading the `stat`
   report](guide/reading-stat.md#fsm-re-encoding) walks through both.

5. Read the run with FSM re-encoding turned off:

   ```
          27  264.003 cells
           6  150.144   sky130_fd_sc_hd__dfrtp_1
      Chip area for module '\blinker': 264.003200
        of which used for sequential elements: 150.144000 (56.87%)
   ```

   Your prediction comes back. One-hot spent two extra flip-flops (50 µm²) on cheaper decoding,
   and on a four-state machine that trade loses. The lesson is not `-nofsm`; it is that you have
   to go and look at the netlist, because every number you quote comes from it.

6. Look up the prices that make flip-flops expensive:

   ```bash
   for c in dfxtp_1 dfrtp_1 dfstp_2 nor2_1 nand2_1 inv_1; do
     echo -n "$c  "; grep -A200 "cell (\"sky130_fd_sc_hd__$c\")" $LIB | grep -m1 area
   done
   ```

You should see `dfrtp_1` at `25.024000000` and `nand2_1` at `3.7536000000`. Then check the
sequential total:

$$7 \times 25.024 + 1 \times 26.2752 = 201.4432\ \mu\text{m}^2 \quad\text{of}\quad 316.5536$$

Eight cells out of twenty-seven are 63.64 % of the silicon. The nineteen cells that decide
anything share the other 115.11 µm².

## Part 3: Leaving out `dfflibmap`

[`scripts/broken.ys`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/scripts/broken.ys)
is `baseline.ys` with exactly one line deleted:

```
dfflibmap -liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

1. Predict what breaks, then run:

   ```bash
   make broken
   ```

You should see that nothing breaks:

```
yosys scripts/broken.ys -> exit status 0   (yes. zero.)
       25  102.598 cells
   Area for cell type $_DFFE_PN0P_ is unknown!
   Area for cell type $_DFF_PN0_ is unknown!
   Area for cell type $_DFF_PN1_ is unknown!
   Chip area for module '\blinker': 102.598400
     of which used for sequential elements: 0.000000 (0.00%)
```

That is 102.60 µm² instead of 316.55, and 0.00 % sequential in a design that is two thirds
flip-flops. The receipt is short by 213.96 µm², 68 % of the design, and the run exited zero.
`abc -liberty` maps combinational logic only. Without `dfflibmap` the flip-flops stay as
`$_DFF_*`, Yosys's internal technology-independent placeholders, which have no liberty entry and
so contribute zero.

> **Rule:** a cell type starting with `$_` in your final netlist means something did not get
> mapped, and your area is too small by however much it was worth. `$scopeinfo` is the one
> harmless exception. Chase every `is unknown!` line before you believe a number.

The same target then runs the self-check on the broken JSON; Part 6 explains that output.

## Part 4: Five synthesis scripts

Same `blinker.sv`, five synthesis scripts.

1. Before you run anything, decide which script gives "the" area of `blinker.sv`.

2. Run:

   ```bash
   make scripts
   ```

   ```
   file                            cells  flops   area (um^2)   seq %
   ------------------------------------------------------------------
   blinker_explicit.json              26      6        265.25   56.6%
   blinker_explicit_nodffe.json       29      8        332.82   60.5%
   blinker.json                       27      8        316.55   63.6%
   blinker_flat.json                  27      8        316.55   63.6%
   blinker_fast.json                  46      8        380.36   53.0%
   ```

   | Script | What it does | Result |
   |---|---|---|
   | `explicit.ys` | `synth` written out by hand: `proc / opt / fsm / memory / techmap / opt` | 26 cells, 265.25 µm², 6 flops |
   | `explicit_nodffe.ys` | the same, but `opt -nodffe -nosdff` before `fsm` | 29 cells, 332.82 µm², 8 flops |
   | `baseline.ys` | plain `synth -top blinker` | 27 cells, 316.55 µm², 8 flops |
   | `flat.ys` | `synth -top blinker -flatten` | 27 cells, 316.55 µm², 8 flops |
   | `fast.ys` | `synth`, then ABC's three-command fast script | 46 cells, 380.36 µm², 8 flops |

3. Find out why the hand-written script lost the FSM:

   ```bash
   grep -A1 FSM_DETECT results/baseline.log
   grep -A1 FSM_DETECT results/explicit.log
   ```

   You should see `Found FSM state register blinker.state.` after the first header and nothing
   after the second. Plain `opt` folds the clock enable into a `$dffe` cell before `fsm` runs,
   and `fsm_detect` then no longer recognises `state` as a state register. `synth` runs
   `opt -nodffe -nosdff` at that point instead, so that this does not happen. Adding those two
   flags to `explicit.ys` brings the FSM back, which is the `explicit_nodffe` row: one flag on
   one line, two flip-flops and 67 µm².

4. Compare the ABC command scripts in `baseline.log` and `fast.log`:

   ```
   baseline: strash / &get -n / &fraig -x / &put / scorr / dc2 / dretime /
             strash / &get -n / &dch -f / &nf / &put
   fast:     strash / dretime / map
   ```

You should see five areas between 265 and 380 µm², a 43 % spread from one unchanged source file,
and there is no correct row. `-flatten` did nothing here because `blinker` has no submodules;
on `ripple4` in Part 5 flattening changes everything. The fast script, three commands instead of
eleven, made the design about 20 % bigger: you bought synthesis runtime with silicon.

"How big is it?" has no answer without "under which script?" attached. LibreLane exposes this
knob as `SYNTH_STRATEGY`, which is why two competent people can report different areas for the
same RTL and both be right. Quote the script alongside the number, every time.

## Part 5: The area gap

Back to the DD102 adder, which is in this package as `src/fulladder.sv` and `src/ripple4.sv`. You
made this prediction in [Lab 01](labs/lab-01-one-adder-two-targets-overview.md), Part 6, and it
was 18.5 % too high. Here you find the cause and prove it.

1. Run:

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

2. Multiply by four and write it on the blank line the Makefile prints:
   $4 \times 33.7824 = 135.1296\ \mu\text{m}^2$.

3. Read the chained result:

   ```
          12  110.106 cells
           4   40.038   sky130_fd_sc_hd__maj3_1
           8   70.067   sky130_fd_sc_hd__xnor2_1
      Chip area for module '\ripple4': 110.105600
   ```

   That is 110.11 µm², 18.5 % less than predicted. The four `maj3_1` are still there, since
   carry-out is still the majority function. What changed is the sum. Alone, ABC builds
   `a ^ b ^ cin` from one `xor3_1`. In the chain it builds each one from two `xnor2_1`:

   $$\underbrace{23.7728}_{\texttt{xor3\_1}} - \underbrace{2 \times 8.7584}_{\texttt{2 × xnor2\_1}} = 6.256 \qquad 4 \times 6.256 = 25.024\ \mu\text{m}^2$$

   and $135.1296 - 110.1056 = 25.024$. The entire gap is that one cell swap, four times. Two
   `xnor2_1` are smaller but one logic level deeper than a single `xor3_1`. Alone, the sum is the
   critical path, so ABC pays for the fast cell. In a chain the carry is the critical path and
   the sum has slack, so ABC spends that slack on area.

4. Read the last run in `make gap`. `scripts/gap_hier.ys` is the same flow with the `flatten`
   line removed, so ABC optimizes each `fulladder` separately:

   ```
           8   135.13 cells
           4   40.038   sky130_fd_sc_hd__maj3_1
           4   95.091   sky130_fd_sc_hd__xor3_1
      Chip area for top module '\ripple4': 135.129600
   ```

You should see 135.1296 µm², your prediction to the digit. The prediction is the exact answer the
tool gives when you stop it from looking across the module boundaries you drew. A block costs
less in context than it does alone, so "how big is my design?" can't be answered from a
spreadsheet of parts, and datasheet areas are always for a whole block.

## Part 6: The self-check

There is no instructor checking your numbers. There is
[`src/check_stat.py`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/src/check_stat.py).

Every script in this lab ends with `tee -o results/<name>.json stat -json -liberty <the liberty
file>`. `stat -json` prints to the console, so `tee -o` in front of it captures it to a file. The
checker reads four keys from that file (`num_cells`, `area`, `sequential_area` and
`num_cells_by_type`) under the top-level `"design"` object, which sums the whole design so you
never have to spell the module name (`"\\blinker"`, with a literal backslash).

1. Run the checker on the good run:

   ```bash
   python3 src/check_stat.py results/blinker.json --expect blinker
   ```

   ```
   blinker.json
     cells      : 27
     flip-flops : 8
     area       : 316.55 um^2
     sequential : 201.44 um^2 (63.6%)
     PASS  (matches the reference run)
   ```

   It exits 0 on pass and 1 on fail, so a `Makefile` can gate on it.

2. Scroll back to the end of the `make broken` output from Part 3, where the checker read the
   unmapped run:

   ```
   blinker_broken.json
     cells      : 25
     flip-flops : 0
     area       : 102.60 um^2
     sequential : 0.00 um^2 (0.0%)
     FAIL
       - unmapped cells in the netlist: $_DFFE_PN0P_, $_DFF_PN0_, $_DFF_PN1_
         A type starting with '$' has no liberty entry, so it contributed 0 um^2.
         Your area is too small by however much those cells were worth. Did you
         remember dfflibmap?
       - flip-flop count 0, expected exactly 8
       - area 102.60 um^2, expected about 316.55 um^2
       - sequential area 0.00 um^2, expected about 201.44
   ```

You should see `PASS` for `blinker.json` and `FAIL` for `blinker_broken.json`. Reading a FAIL is
a skill, and the best time to practise it is when you caused it on purpose.

## Part 7: Time the adder

This part runs the analysis from [Carry delay and static timing](guide/the-carry-has-to-walk.md)
on `src/ripple.sv`, with `scripts/timing.tcl`.

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
   number of extra bits; you should get 0.392 ns every time.

5. Predict $T(64)$ with $T(N) = 0.370 + 0.392\,(N-2) + 0.328$ and write it down. Then measure it:

   ```bash
   yosys -q -p "read_verilog -sv src/ripple.sv src/fulladder.sv; chparam -set N 64 ripple;
                synth -top ripple; flatten; abc -liberty $LIB; opt_clean;
                write_verilog -noattr results/gates64.v"
   NETLIST=results/gates64.v sta -exit scripts/timing.tcl | grep "data arrival"
   ```

   You should see `24.996   data arrival time`. The formula says 25.002, so you were right to
   six picoseconds.

6. Make copies of the script with realistic clock periods, and read the slack:

   ```bash
   for P in 2 1; do
     sed "s/-period 100/-period $P/" scripts/timing.tcl > results/timing_$P.tcl
     echo "period $P ns:"
     NETLIST=results/gates4.v sta -exit results/timing_$P.tcl | grep -E 'slack'
   done
   ```

   You should see `0.519   slack (MET)` at 2 ns and `-0.481   slack (VIOLATED)` at 1 ns.

7. Try two other process corners:

   ```bash
   for C in ss_n40C_1v28 ff_100C_1v65; do
     sed "s/tt_025C_1v80/$C/" scripts/timing.tcl > results/timing_$C.tcl
     echo "$C:"
     NETLIST=results/gates4.v sta -exit results/timing_$C.tcl | grep "data arrival"
   done
   ```

You should see `13.249` ns at the slow corner and `1.000` ns at the fast corner, against
`1.481` ns at typical: the same netlist, nine times slower at one corner than another.

## Finishing

1. Run `make table`. Every row should match, and `check_stat.py` will say so:

   ```
   file                            cells  flops   area (um^2)   seq %
   ------------------------------------------------------------------
   blinker.json                       27      8        316.55   63.6%
   blinker_nofsm.json                 27      6        264.00   56.9%
   blinker_explicit.json              26      6        265.25   56.6%
   blinker_explicit_nodffe.json       29      8        332.82   60.5%
   blinker_flat.json                  27      8        316.55   63.6%
   blinker_fast.json                  46      8        380.36   53.0%
   blinker_broken.json                25      0        102.60    0.0%  <- unmapped!
   fulladder.json                      2      0         33.78    0.0%
   ripple4.json                       12      0        110.11    0.0%
   ripple4_hier.json                   8      0        135.13    0.0%
   ```

2. Answer these in one sentence each, using your own numbers:

   1. Why does `blinker.sv` have eight flip-flops when you wrote six bits of state?
   2. What is wrong with `102.60 µm²`, and what in the output told you?
   3. Which of `265.25`, `316.55` and `380.36` is the area of `blinker.sv`?
   4. Why is `ripple4` smaller than four `fulladder`s, and what makes it exactly `135.1296`
      again?
   5. What is the worst path of your 4-bit adder at the typical corner, and what is the slack
      with a 2 ns clock?

`Chip area` is the sum of the standard cells and nothing else. The same `blinker.sv` taken all
the way to a layout by LibreLane, with the flow's default floorplan settings, reports 1929.33 µm²
of die (38.89 × 49.61 µm) and 109 placed instances against `stat`'s 27 cells. The difference is
clock buffers, timing-repair buffers, well taps, filler and the empty space the router needs; the
8 sequential cells are the same. Use `stat -liberty` to compare two versions of your own design.
[From netlist to layout](guide/from-gates-to-geometry.md) is where the die number comes from, and
[Lab 05](labs/lab-05-elevator-overview.md) is where you produce one.

## Going further

- Pass `-group_count 10` to `report_checks` in a copy of `timing.tcl` to see the next nine
  paths after the worst one.
- Put the adder between two registers, as in
  [Carry delay and static timing](guide/the-carry-has-to-walk.md#registered-adder-and-minimum-clock-period),
  synthesize it with `dfflibmap -liberty $LIB` before `abc`, and time it with
  `create_clock -name clk -period 3.0 [get_ports clk]` and `report_clock_min_period`. Compare
  your `period_min` with the 2.96 ns on that page.
- Save the seven-line script from [Reading the `stat` report](guide/reading-stat.md#the-machine-readable-receipt)
  as `results/stat_min.py` and run it on `results/blinker.json`.

Next: read [Writing a state machine](guide/state-machine-is-a-table.md) and
[From netlist to layout](guide/from-gates-to-geometry.md) before Lab 05.
