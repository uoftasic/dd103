# Lab 03 — Three ways to lose a latch

Full runnable package:
[`labs/lab-03-three-ways-to-lose-a-latch/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-03-three-ways-to-lose-a-latch).

One `case` statement with a branch missing. Four module headers. Four completely different
outcomes, only one of which involves the tool telling you.

## Prerequisites

- [IC101](https://uoftasic.com/ic101/) complete — you are working inside
  `hpretl/iic-osic-tools:2026.08`. Check with `yosys -V` → `0.64`.
- [Lab 02 — RTL becomes gates](labs/lab-02-rtl-becomes-gates-overview.md) done, so `stat` output is
  not new to you.
- Read Part III: [The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) →
  [Blocking vs non-blocking](guide/blocking-vs-nonblocking.md).

## Objectives

- Produce all four outcomes of an incomplete `case` yourself, and quote the exact line each
  tool printed
- Explain why `unique` makes an error go away without making the design correct
- Count flip-flops to settle `=` vs `<=` instead of quoting a rule
- Run `verilator --lint-only -Wall` as a gate, and exhibit one bug it does not catch

## Theory (short)

An `always_comb` block that can finish without assigning an output is asking for the old value
to be held. Holding requires memory, so the synthesizer builds a **latch** — a level-sensitive
memory whose enable is whatever condition happened to be left over, which no timing tool has
been told about.

`always_comb` makes that a hard error. `always @*` does not. `unique` disables the check and
converts the missing branch into a don't-care, which the optimizer is then free to resolve any
way it likes.

In a clocked block, `=` lets each statement see the previous statement's result, so a chain of
assignments collapses into one flip-flop. `<=` samples every right-hand side before writing
any left-hand side, which is what a row of flip-flops physically does.

## Procedure

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-03-three-ways-to-lose-a-latch
make            # everything, about 2 seconds
```

Or one step at a time: `make latch`, `make lint`, `make sim`, `make flops`, `make comb`,
`make width`.

The design under test is a battery meter: 2-bit `level` in, 4-bit `bar` out, three cases
written and `2'b11` missing. `src/bar_comb.sv`, `src/bar_star.sv`, `src/bar_unique.sv` and
`src/bar_fixed.sv` differ **only** in their header line and, for `bar_fixed`, one `default:`.

### Step 1 — Four headers, one `case`

- **Try this:** `make latch`, then `diff src/bar_comb.sv src/bar_star.sv` to convince yourself
  nothing else changed.
- **What you should see:** four blocks, and four different sentences from the same Yosys pass:

```
--- bar_comb (exit 1) ---
ERROR: Latch inferred for signal `\bar_comb.\bar' from always_comb process ...
--- bar_star (exit 0) ---
Latch inferred for signal `\bar_star.\bar' from process ...
        2   $_DLATCH_N_
--- bar_unique (exit 0) ---
No latch inferred for signal `\bar_unique.\bar' from process ...
        2 cells
--- bar_fixed (exit 0) ---
No latch inferred for signal `\bar_fixed.\bar' from process ...
        2 cells
```

- **Why an engineer cares:** three of those four exited 0. Exit code is not a review.

### Step 2 — Make the latch misbehave

- **Try this:** `make sim`. The testbench walks `level` through `0, 1, 2, 3, 0`.
- **What you should see:**

```
level   bar_star   bar_fixed
   00       0001        0001
   01       0011        0011
   10       0111        0111
   11       0111        1111
   00       0001        0001
```

- **Why an engineer cares:** at `level = 3` the latched design shows `0111` — the reading from
  the line above. Any test that never drives `level = 3` passes. Any test that drives it *after*
  `2'b10` sees a plausible-looking wrong answer rather than an X.

### Step 3 — Find out what `unique` sold you

- **Try this:** the second half of `make sim` synthesizes `bar_unique.sv` and simulates the
  **netlist**, not the source. Then read `results/bar_unique_net.v`.
- **What you should see:**

```
level   bar (synthesized)
   00       0001
   01       0011
   10       0111
   11       0001
```

and, in the netlist, `assign { bar[3], bar[0] } = 2'h1;` — `bar[3]` tied to constant 0.

- **Why an engineer cares:** the top LED is not driven by anything. A full battery displays as
  empty. Yosys reported *"No latch inferred"* and it was telling the truth.

### Step 4 — The lint gate

- **Try this:** `make lint`.
- **What you should see:** `bar_comb`, `bar_star` and `bar_unique` each produce
  `%Warning-CASEINCOMPLETE` and `%Warning-LATCH` and exit 1. `bar_fixed` prints a verilation
  report and exits 0.
- **Why an engineer cares:** Verilator names the signal, the line, the column, the missing
  case value (`example pattern 0x3`) and a URL — and unlike Yosys it is **not fooled by
  `unique`**. From here on, `verilator --lint-only -Wall` returning 0 is the precondition for
  running synthesis at all. It takes 4 ms.

### Step 5 — Count flip-flops instead of arguing

- **Try this:** `make flops`, then `make comb`.
- **What you should see:**

```
shift_nb             3   60.058   sky130_fd_sc_hd__dfxtp_1
shift_b              1   20.019   sky130_fd_sc_hd__dfxtp_1
shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
```

`shift_b` and `shift_b_rev` contain the same three blocking assignments in different orders.
`make comb` then shows the mirror-image error: `<=` inside `always_comb` builds correct
hardware and simulates one delta cycle behind, every cycle.

- **Why an engineer cares:** with `=`, the order you typed your statements is part of the
  netlist. Reordering lines for readability changes the chip.

### Step 6 — The one lint misses

- **Try this:** `make width`.
- **What you should see:**

```
add8.sv: LINT CLEAN (exit 0)
   Chip area for module '\add8': 195.187200
200 + 100 = 44
```

- **Why an engineer cares:** eight bits plus eight bits is nine bits. `add8.sv` declares an
  eight-bit `sum`, so the carry is never computed — not truncated, never built. Verilator,
  Yosys and Icarus all say nothing, because nothing is inconsistent. Widening `sum` to `[8:0]`
  costs one `sky130_fd_sc_hd__maj3_1`, **10.01 µm²**, and gets you `300`. **Lint clean does
  not mean correct.**

## Expected results

The lab is done when this table is filled in **from your own terminal**, with the tool's
words rather than yours:

| Header | Exit code | What Yosys built | The line the tool printed |
|---|---|---|---|
| `always_comb`, no `default:` | | | |
| `always @*`, no `default:` | | | |
| `always_comb unique case` | | | |
| `always_comb` with `default:` | | | |
| `always_latch` (see *Going further*) | | | |

Then these, which each want one number:

| Question | Your answer |
|---|---|
| Cells in the correct (`bar_fixed`) design vs the latched one | |
| What `bar_unique` outputs at `level = 2'b11` | |
| Flip-flops from three `<=` statements vs three `=` statements | |
| SKY130 area of each | |
| Area `add8` reports, and what `200 + 100` gives | |
| Extra area buying the ninth bit | |

Checks that your run matched ours:

- `make` completes in about **2 seconds** and never stops on an error
- `make latch` shows exactly one `exit 1`, and it is `bar_comb`
- `make lint` shows exactly one clean file, and it is `bar_fixed`
- `results/bar_star.log` contains `$_DLATCH_N_`; `results/bar_fixed.log` does not

## Going further

- Map `bar_star.sv` to SKY130 and read the receipt:
  `dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB`. The latches
  never become cells — you get `Area for cell type $_DLATCH_N_ is unknown!` and a chip area
  that omits them. Compare against the real latch cell `sky130_fd_sc_hd__dlxtp_1`,
  **15.0144 µm²** each.
- Synthesize `src/bar_latch.sv` — the same incomplete `case` under `always_latch`. Yosys
  builds the identical two latches and exits **0**, because this time you asked. Verilator
  drops its `LATCH` warning and keeps `CASEINCOMPLETE`.
- Shuffle the three non-blocking statements in `src/shift_nb.sv` into any order. The flop count
  does not move.

## Links

- [Lab package](https://github.com/uoftasic/dd103/tree/main/labs/lab-03-three-ways-to-lose-a-latch)
- Guide: [The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) ·
  [Blocking vs non-blocking](guide/blocking-vs-nonblocking.md)
- Reference: [The synthesizable subset](reference/synthesizable-subset.md)
- Next lab: [Lab 04 — Reading the receipt](labs/lab-04-reading-the-receipt-overview.md)
