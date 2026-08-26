# Lab 04 — Reading the receipt

Writeup: [`docs/labs/lab-04-reading-the-receipt-overview.md`](../../docs/labs/lab-04-reading-the-receipt-overview.md)

Four experiments on two designs. Run them in order — each one is a prediction you make
before you look.

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-04-reading-the-receipt
yosys -V          # expect: Yosys 0.64
make
```

Individual experiments: `make predict`, `make broken`, `make scripts`, `make gap`.
`make check` re-runs the self-check on JSON you already have; `make table` reprints the
summary; `make clean` empties `results/`.

## What's here

| File | What it is |
|---|---|
| `src/blinker.sv` | 4-state controller + 4-bit countdown. The design behind [Reading `stat` like a receipt](../../docs/guide/reading-stat.md). |
| `src/fulladder.sv`, `src/ripple4.sv` | The DD102 adder, carried over from Lab 01, for the area-gap experiment. |
| `src/check_stat.py` | Reads `stat -json -liberty` output and says PASS or FAIL. **This is the grader.** |
| `scripts/baseline.ys` | The receipt, done right. |
| `scripts/nofsm.ys` | Same, with `synth -nofsm`. |
| `scripts/broken.ys` | `baseline.ys` with the `dfflibmap` line deleted. Exits 0 and lies to you. |
| `scripts/explicit.ys` | `synth` written out by hand as `proc / opt / fsm / techmap / opt`. |
| `scripts/explicit_nodffe.ys` | The same, with one flag changed. Two more flip-flops. |
| `scripts/flat.ys` | `synth -flatten`. |
| `scripts/fast.ys` | `abc -fast`. |
| `scripts/gap_one.ys`, `scripts/gap_four.ys` | One full adder, then four of them chained and flattened. |
| `scripts/gap_hier.ys` | The same four, with the module boundaries left standing. |
| `src/ripple.sv` | Not built by `make`. The same adder with its width as a parameter, for [The carry has to walk](../../docs/guide/the-carry-has-to-walk.md). |
| `scripts/timing.tcl` | Not built by `make`. The OpenSTA script that page runs: `NETLIST=gates4.v sta -exit scripts/timing.tcl`. |

## Expected results

Measured on `hpretl/iic-osic-tools:2026.04` — Yosys 0.64, Python 3.12.3, `sky130A`.
`src/check_stat.py` knows these numbers and will tell you if yours drift.

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

`blinker_broken.json` is *supposed* to fail. `make broken` runs the checker on it so you can
see what a FAIL looks like before you ever earn one by accident.

> `src/blinker.sv` and its numbers are quoted by
> [`docs/guide/reading-stat.md`](../../docs/guide/reading-stat.md) and by the lab writeup.
> If you change the RTL, re-run `make` and update both with the new numbers.
