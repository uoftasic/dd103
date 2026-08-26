# Lab 03 — Three ways to lose a latch

Writeup: [`docs/labs/lab-03-three-ways-to-lose-a-latch.md`](../../docs/labs/lab-03-three-ways-to-lose-a-latch.md)

Everything runs in the workbench (`hpretl/iic-osic-tools:2026.04` — Yosys 0.64,
Verilator 5.046, Icarus Verilog 14.0). No arguments, no paths to retype.

```bash
cd labs/lab-03-three-ways-to-lose-a-latch
make            # all six sections, ~2 s
```

| Target | What it runs |
|---|---|
| `make latch` | Synthesizes the same incomplete `case` under four headers; prints exit code, the `PROC_DLATCH` line, and the cell list for each |
| `make lint` | `verilator --lint-only -Wall` on the same four files |
| `make sim` | Icarus: the latched design at `level = 2'b11`, then the **synthesized** `unique` netlist at the same input |
| `make flops` | `<=` vs `=` in `always_ff`, counted as `sky130_fd_sc_hd__dfxtp_1`, plus a shift-register simulation |
| `make comb` | `<=` vs `=` in `always_comb` — identical netlists, different simulation |
| `make width` | The bug lint does not catch: `200 + 100 = 44` |
| `make clean` | Removes everything under `results/` |

## Sources

| File | What it is |
|---|---|
| `src/bar_comb.sv` | Battery meter, incomplete `case`, `always_comb`. **Fails to synthesize** — that is the point |
| `src/bar_star.sv` | Same `case`, `always @*`. Synthesizes to 2 × `$_DLATCH_N_` |
| `src/bar_unique.sv` | Same `case`, `unique case`. No latch, no error, `bar[3]` tied to 0 |
| `src/bar_fixed.sv` | Same `case` plus `default:`. 2 cells, correct at all four inputs |
| `src/bar_latch.sv` | Same `case` under `always_latch` — a latch you actually asked for |
| `src/shift_nb.sv`, `src/shift_b.sv`, `src/shift_b_rev.sv` | Three statements, `<=` / `=` / `=` reordered → 3 / 1 / 3 flip-flops |
| `src/comb_nb.sv`, `src/comb_b.sv` | `<=` vs `=` inside `always_comb` |
| `src/add8.sv`, `src/add9.sv`, `src/add_trunc.sv` | The silent carry loss, the fix, and a width mismatch lint *does* see |
| `src/tb_*.sv` | Icarus testbenches. Not synthesizable, and not meant to be |
| `src/u_return_id.sv`, `src/u_delay.sv`, `src/u_unique_nodefault.sv` | The three examples quoted by [The hardware dialect](../../docs/guide/the-hardware-dialect.md) |

`results/` holds every Yosys log, netlist and compiled testbench the Makefile produces. It is
gitignored apart from `.gitkeep`.

## Reference numbers (Yosys 0.64, sky130A)

```
bar_comb     exit 1   ERROR: Latch inferred ... from always_comb process
bar_star     exit 0   2 x $_DLATCH_N_,  5 cells
bar_unique   exit 0   No latch inferred,  2 cells,  bar[3] = 1'b0
bar_fixed    exit 0   No latch inferred,  2 cells

shift_nb     3 x sky130_fd_sc_hd__dfxtp_1    60.0576 um^2
shift_b      1 x sky130_fd_sc_hd__dfxtp_1    20.0192 um^2
shift_b_rev  3 x sky130_fd_sc_hd__dfxtp_1    60.0576 um^2

add8         lint clean, 195.1872 um^2, 200 + 100 = 44
add9         lint clean, 205.1968 um^2, 200 + 100 = 300
```

> These numbers are quoted verbatim by
> [`docs/guide/the-latch-you-didnt-ask-for.md`](../../docs/guide/the-latch-you-didnt-ask-for.md)
> and [`docs/guide/blocking-vs-nonblocking.md`](../../docs/guide/blocking-vs-nonblocking.md).
> If you change any source file here, re-run `make` and update both pages.

## Note for anyone reading `src/` for style

`bar_comb.sv`, `bar_star.sv`, `bar_unique.sv`, `comb_nb.sv`, `shift_b.sv`, `shift_b_rev.sv`,
`add8.sv`, `add_trunc.sv`, `u_delay.sv` and `u_unique_nodefault.sv` are **deliberately wrong**.
Do not copy them into your own designs. `bar_fixed.sv`, `shift_nb.sv`, `comb_b.sv` and
`add9.sv` are the ones written the way this course expects.
