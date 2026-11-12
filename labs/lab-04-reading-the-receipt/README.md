# Lab 04: Reading the receipt

Writeup: [`docs/labs/lab-04-reading-the-receipt-overview.md`](../../docs/labs/lab-04-reading-the-receipt-overview.md)

Four experiments on two designs, each a prediction you make before you look, plus a timing
analysis of the ripple adder.

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-04-reading-the-receipt
yosys -V          # expect: Yosys 0.68
make
```

| Target | What it runs |
|---|---|
| `make` | `predict`, `broken`, `scripts`, `gap`, then `table` |
| `make predict` | Experiment 1: the blinker receipt, with and without FSM re-encoding |
| `make broken` | Experiment 2: `baseline.ys` without `dfflibmap`, then the self-check on it |
| `make scripts` | Experiment 3: five synthesis scripts on one source file |
| `make gap` | Experiment 4: one full adder alone vs four chained, flattened and not |
| `make check` | re-run the self-check on JSON you already have |
| `make table` | reprint the summary from JSON you already have |
| `make clean` | empty `results/` |

The timing analysis is not a `make` target. The writeup runs it as
`NETLIST=results/gates4.v sta -exit scripts/timing.tcl`.

## Files

| File | What it is |
|---|---|
| `src/blinker.sv` | 4-state controller + 4-bit countdown. The design behind [Reading the `stat` report](../../docs/guide/reading-stat.md). |
| `src/fulladder.sv`, `src/ripple4.sv` | The DD102 adder, carried over from Lab 01, for the area-gap experiment. |
| `src/check_stat.py` | Reads `stat -json -liberty` output and says PASS or FAIL. This is the grader. |
| `scripts/baseline.ys` | The receipt, done right. |
| `scripts/nofsm.ys` | Same, with `synth -nofsm`. |
| `scripts/broken.ys` | `baseline.ys` with the `dfflibmap` line deleted. Exits 0 with a wrong area. |
| `scripts/explicit.ys` | `synth` written out by hand as `proc / opt / fsm / techmap / opt`. |
| `scripts/explicit_nodffe.ys` | The same, with one flag changed. Two more flip-flops. |
| `scripts/flat.ys` | `synth -flatten`. |
| `scripts/fast.ys` | `synth`, then ABC's three-command fast script (Yosys 0.68 removed `abc -fast`). |
| `scripts/gap_one.ys`, `scripts/gap_four.ys` | One full adder, then four of them chained and flattened. |
| `scripts/gap_hier.ys` | The same four, with the module boundaries left standing. |
| `src/ripple.sv` | Not built by `make`. The same adder with its width as a parameter, for [Carry delay and static timing](../../docs/guide/the-carry-has-to-walk.md). |
| `scripts/timing.tcl` | Not built by `make`. The OpenSTA script for the timing part of the writeup. |

## Reference numbers

Measured on `hpretl/iic-osic-tools:2026.08` with Yosys 0.68, Python 3.12.3 and `sky130A`.
`src/check_stat.py` knows these numbers and tells you if yours drift.

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

`blinker_broken.json` is supposed to fail. `make broken` runs the checker on it so you can see what
a FAIL looks like before you earn one by accident.

> [`docs/guide/reading-stat.md`](../../docs/guide/reading-stat.md) and the lab writeup quote
> `src/blinker.sv` and its numbers. If you change the RTL, re-run `make` and update both.
