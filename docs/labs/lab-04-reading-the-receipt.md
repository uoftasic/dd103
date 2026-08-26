# Lab 04 — Reading the receipt

Full runnable package:
[`labs/lab-04-reading-the-receipt/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt).

**The question this lab answers:** *How do I know my number is right, when nobody is going to
check it for me?*

You have read [Reading `stat` like a receipt](guide/reading-stat.md). You can point at the
cell count, the middle column, and the total. This lab is where you stop reading receipts and
start being wrong about them on purpose.

Four experiments. Each one asks you to **write a number down before you run the command**. All
four are designed so that the number you write down is wrong, and the way it is wrong is the
lesson.

## Prerequisites

- [IC101](https://uoftasic.com/ic101/) complete — the workbench desktop launches
- DD103 cloned under `workspace/modules/dd103`
- [Lab 02](labs/lab-02-rtl-becomes-gates.md) done: you have watched RTL become SKY130 cells
- Read [A standard cell is a real thing](guide/standard-cells-are-real.md) →
  [Reading `stat` like a receipt](guide/reading-stat.md)
- `yosys -V` says **`0.64`**. If it says anything else, you are not in the workbench.

## Objectives

- Predict a flip-flop count from your own RTL, measure it, and explain the gap
- Recognise an **unmapped** cell type on sight and know that your area is wrong
- Produce four different area numbers from one source file and defend all four
- Run a self-check that tells you whether you succeeded, with no instructor in the room

## Theory (short)

`stat -liberty` does exactly one piece of arithmetic:

$$\text{area} = \sum_{\text{cell types } t} n_t \times a_t$$

where $n_t$ is how many of type $t$ the netlist contains and $a_t$ is the `area :` line for
that cell in the liberty file. That is all. Two ways for the answer to be wrong:

1. $n_t$ is not what you think, because synthesis rewrote your design.
2. $a_t$ does not exist, because a cell never got mapped to the technology — and Yosys
   silently uses **zero**.

Experiment 1 is failure mode 1. Experiment 2 is failure mode 2.

## Procedure

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-04-reading-the-receipt
yosys -V                 # expect: Yosys 0.64
make                     # all four experiments, about five seconds
```

Each experiment is also a target on its own: `make predict`, `make broken`, `make scripts`,
`make gap`.

---

### 1 — Predict, then measure

Open [`src/blinker.sv`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/src/blinker.sv).
It is a four-state controller with a countdown timer. Look only at the `always_ff` block.

- **Try this:** Count the bits assigned with `<=`. There are two state variables: `state`, a
  `logic [1:0]` enum, and `count`, a `logic [3:0]`. A bit that survives a clock edge needs a
  flip-flop. **Write your number on paper.** Then run `make predict`.

- **What you should see:** Not your number.

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

  You wrote **6**. The receipt says **8** — seven `dfrtp_1` and one `dfstp_2`. Every cell whose
  name starts `df` is a flip-flop.

  The same target then asks the log what happened:

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

  One-hot: four states, four bits, exactly one high at a time — four state bits plus four
  counter bits is eight, and the odd `dfstp_2` is the bit that has to leave reset high.
  [Reading `stat` like a receipt](guide/reading-stat.md) walks through both of those. What
  the lab adds is the next command.

  Turn the pass off and your prediction comes back:

```
       27  264.003 cells
        6  150.144   sky130_fd_sc_hd__dfrtp_1
   Chip area for module '\blinker': 264.003200
     of which used for sequential elements: 150.144000 (56.87%)
```

- **Why an engineer cares:** You were not being stupid. You were reasoning about *your* code,
  and the netlist is not a transcription of your code. Every number you will ever quote about
  a design comes from the netlist, so **you have to go and look**.

> **"So one-hot made it 20% bigger — is the tool wrong?"** No: it spent two extra flip-flops
> (50 µm²) on cheaper decoding, and on a four-state machine that trade loses. `-nofsm` is not
> the lesson. Going and looking is the lesson.

Now the number that actually matters:

$$7 \times 25.024 + 1 \times 26.2752 = 201.4432\ \mu\text{m}^2 \quad\text{of}\quad 316.5536$$

**Eight cells out of twenty-seven are 63.64% of the silicon.** The nineteen cells that decide
anything share the other 115.11 µm². This design spends two thirds of itself remembering where
it is and one third deciding where to go next. When that fraction climbs, you are storing more
than you are computing.

---

### 2 — The deliberate failure

[`scripts/broken.ys`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/scripts/broken.ys)
is `baseline.ys` with exactly one line deleted:

```
dfflibmap -liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

- **Try this:** Run `make broken`. Before you look at the output, predict what breaks.

- **What you should see:** Nothing breaks. That is the point.

```
yosys scripts/broken.ys -> exit status 0   (yes. zero.)
       25  102.598 cells
   Area for cell type $_DFFE_PN0P_ is unknown!
   Area for cell type $_DFF_PN0_ is unknown!
   Area for cell type $_DFF_PN1_ is unknown!
   Chip area for module '\blinker': 102.598400
     of which used for sequential elements: 0.000000 (0.00%)
```

  **102.60 µm² instead of 316.55**, and **0.00% sequential** in a design that is two thirds
  flip-flops. The receipt is short by **213.96 µm² — 68% of the design — and it exited zero.**

- **Why an engineer cares:** This is what technology mapping *is*, seen by its absence.
  `abc -liberty` maps **combinational logic only**. The flip-flops are a separate job, done by
  `dfflibmap`, and without it they stay as `$_DFF_*` — Yosys's internal, technology-independent
  placeholders. A placeholder has no liberty entry, so it has no area, so it contributes zero.

> **The rule to memorise:** a cell type starting with `$_` in your final netlist means
> something did not get mapped, and your area is too small by however much it was worth.
> `$scopeinfo` is the one harmless exception. Everything else with a `$` is a hole in your
> total. Chase every `is unknown!` line before you believe a number.

Two mappers, two steps, and only one of them is in the command you copied off a web page.
Expect to hit this at least once for real.

---

### 3 — The script is a design decision

Same `blinker.sv`. Five synthesis scripts. `make scripts` runs all of them and prints:

```
file                            cells  flops   area (um^2)   seq %
------------------------------------------------------------------
blinker_explicit.json              26      6        265.25   56.6%
blinker_explicit_nodffe.json       29      8        332.82   60.5%
blinker.json                       27      8        316.55   63.6%
blinker_flat.json                  27      8        316.55   63.6%
blinker_fast.json                  46      8        380.36   53.0%
```

- **Try this:** Before you read on, decide which row is "the" area of `blinker.sv`.

- **What you should see:** Five numbers between 265 and 380 µm², a **43% spread**, from one
  unchanged source file. There is no correct row.

| Script | What it does | Result |
|---|---|---|
| `explicit.ys` | `synth` written out by hand: `proc / opt / fsm / memory / techmap / opt` | 26 cells, **265.25 µm²**, 6 flops |
| `explicit_nodffe.ys` | the same, but `opt -nodffe -nosdff` before `fsm` | 29 cells, 332.82 µm², **8 flops** |
| `baseline.ys` | plain `synth -top blinker` | 27 cells, 316.55 µm², 8 flops |
| `flat.ys` | `synth -top blinker -flatten` | 27 cells, 316.55 µm², 8 flops |
| `fast.ys` | `synth`, then `abc -fast` | **46 cells**, 380.36 µm², 8 flops |

  Three of those deserve an explanation you can verify yourself.

  **The hand-written script lost the FSM.** Compare the logs:

```
$ grep -A1 FSM_DETECT results/baseline.log
2.7.1. Executing FSM_DETECT pass (finding FSMs in design).
Found FSM state register blinker.state.

$ grep -A1 FSM_DETECT results/explicit.log
5.1. Executing FSM_DETECT pass (finding FSMs in design).
```

  The second one printed the header and stopped. It found nothing to report.

  Plain `opt` folds the clock enable into a `$dffe` cell before `fsm` ever runs, and
  `fsm_detect` no longer recognises `state` as a state register. `synth` runs
  `opt -nodffe -nosdff` there instead, precisely so that does not happen. Add those two flags
  to `explicit.ys` and the FSM comes back — that is the `explicit_nodffe` row, and it is why
  it has 8 flops. **One flag on one line: two flip-flops and 67 µm².**

  **`-flatten` did nothing here** because `blinker` has no submodules to flatten. It is not a
  no-op in general — on `ripple4` in experiment 4 it changes everything.

  **`abc -fast` made it 20% bigger.** The two runs print the ABC command scripts they used:

```
baseline: strash / &get -n / &fraig -x / &put / scorr / dc2 / dretime /
          strash / &get -n / &dch -f / &nf / &put
fast:     strash / dretime / map
```

  Eleven optimization commands versus three. You bought synthesis runtime with silicon.

- **Why an engineer cares:** "How big is it?" has no answer without "under which script?"
  attached. This is exactly the knob LibreLane exposes as `SYNTH_STRATEGY`, and it is why two
  competent people can report different areas for the same RTL and both be telling the truth.
  Quote the script alongside the number, every time.

---

### 4 — Four adders are cheaper than four adders

Back to the DD102 adder, which is in this package as `src/fulladder.sv` and `src/ripple4.sv`.
You made this prediction once already, in [Lab 01](labs/lab-01-one-adder-two-targets.md) step 4,
and it was 18.5% too high. This is where you find out the gap is one cell swap and prove it by
taking it away.

- **Try this:** `make gap` synthesizes one `fulladder` alone first:

```
        2   33.782 cells
        1    10.01   sky130_fd_sc_hd__maj3_1
        1   23.773   sky130_fd_sc_hd__xor3_1
   Chip area for module '\fulladder': 33.782400
```

  A 4-bit ripple adder is four of those in a chain. **Multiply by four and write it down**
  before the next command runs. The Makefile even leaves you a blank line to do it on.

$$4 \times 33.7824 = 135.1296\ \mu\text{m}^2$$

- **What you should see:** Not that.

```
       12  110.106 cells
        4   40.038   sky130_fd_sc_hd__maj3_1
        8   70.067   sky130_fd_sc_hd__xnor2_1
   Chip area for module '\ripple4': 110.105600
```

  **110.11 µm², 18.5% less than you predicted.** Your arithmetic was fine. Your model of what
  a module *is* was wrong.

  Read the cell mix. The four `maj3_1` are still there — carry-out is the majority function of
  the three inputs, and that did not change. What changed is the sum. Alone, ABC builds
  `a ^ b ^ cin` from one `xor3_1`. In the chain it builds each one from **two `xnor2_1`**:

$$\underbrace{23.7728}_{\texttt{xor3\_1}} - \underbrace{2 \times 8.7584}_{\texttt{2 × xnor2\_1}} = 6.256 \qquad 4 \times 6.256 = 25.024\ \mu\text{m}^2$$

  and $135.1296 - 110.1056 = 25.024$. **The entire gap is that one cell swap, four times.**
  Two `xnor2_1` are cheaper in area but one logic level deeper than a single `xor3_1`. Alone,
  the sum is the critical path, so ABC pays for the fast cell. In a chain, the *carry* is the
  critical path — the sum has slack — so ABC spends that slack on area.

  The last command in `make gap` proves the boundary is what did it. `scripts/gap_hier.ys` is
  the same flow with the `flatten` line removed, so ABC optimizes each `fulladder` separately:

```
        8   135.13 cells
        4   40.038   sky130_fd_sc_hd__maj3_1
        4   95.091   sky130_fd_sc_hd__xor3_1
   Chip area for top module '\ripple4': 135.129600
```

  **135.1296 µm², to the digit.** Your prediction was not a bad guess — it is the exact answer
  the tool gives when you forbid it to look across the module boundaries you drew.

- **Why an engineer cares:** A block costs less in context than it does alone. This is why
  "how big is my design?" is not answerable from a spreadsheet of parts, and why area figures
  in a datasheet are always for a whole block, never a sum of sub-blocks. You cannot buy
  hardware by the piece.

---

### The self-check

There is no instructor. There is
[`src/check_stat.py`](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt/src/check_stat.py).

Every script in this lab ends with `tee -o results/<name>.json stat -json -liberty <the
liberty file>`. `stat -json` prints to the console, so `tee -o` in front of it is how you
capture it to a file. The
checker reads four keys out of that file — `num_cells`, `area`, `sequential_area`, and
`num_cells_by_type` — under the top-level `"design"` object, which sums the whole design so
you never have to spell the module name (`"\\blinker"`, with a literal backslash).

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

It exits 0 on pass and 1 on fail, so a `Makefile` can gate on it. And it is trained on the
failure too — `make broken` deliberately feeds it the un-mapped run:

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

Look at that output before you ever earn one by accident. **Reading a FAIL is a skill, and the
best time to practise it is when you caused it on purpose.**

## Expected results

Run `make table`. Every row should match, and `check_stat.py` will say so.

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

You are done when you can answer these in one sentence each, using your own numbers:

1. Why does `blinker.sv` have eight flip-flops when you wrote six bits of state?
2. What is wrong with `102.60 µm²`, and what in the output told you?
3. Which of `265.25`, `316.55` and `380.36` is the area of `blinker.sv`?
4. Why is `ripple4` smaller than four `fulladder`s, and what makes it exactly `135.1296`
   again?

> **One last honesty check on all of these numbers.** `Chip area` is the sum of the standard
> cells and nothing else. The same `blinker.sv` taken all the way to a layout by LibreLane —
> on the flow's default floorplan settings — reports **1929.33 µm²** of die
> (38.89 × 49.61 µm) and **109** placed instances against
> `stat`'s 27 cells — the difference is clock buffers, timing-repair buffers, well taps,
> filler, and the empty space the router needs. Same 8 sequential cells, though. Use
> `stat -liberty` for what it is good at: comparing two versions of *your own* design.
> [From gates to geometry](guide/from-gates-to-geometry.md) is where the die number comes
> from, and [Lab 05](labs/lab-05-elevator.md) is where you produce one.

## Links

- [Lab package](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt)
- Guide: [Reading `stat` like a receipt](guide/reading-stat.md) ·
  [The warehouse and the empty lot](guide/warehouse-and-empty-lot.md)
- Next lab: [Lab 05 — Elevator to GDSII](labs/lab-05-elevator.md), where the receipt you just
  learned to read becomes a chip you can look at.
