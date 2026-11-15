# Lab 03: Three ways to lose a latch

Writeup: [`docs/labs/lab-03-three-ways-to-lose-a-latch-overview.md`](../../docs/labs/lab-03-three-ways-to-lose-a-latch-overview.md)

The package runs inside the workbench `hpretl/iic-osic-tools:2026.08` (Yosys 0.68, Verilator
5.050, Icarus Verilog 14.0). None of the targets take arguments, and the Makefile already knows
every path it needs, so you don't have to type any.

```bash
cd labs/lab-03-three-ways-to-lose-a-latch
make            # all six targets below, about 2 s
```

| Target | What it runs |
|---|---|
| `make latch` | Synthesizes the same incomplete `case` under four headers; prints the exit code, the `PROC_DLATCH` line and the cell list for each |
| `make lint` | `verilator --lint-only -Wall` on the same four files |
| `make sim` | Icarus: the latched design at `level = 2'b11`, then the synthesized `unique` netlist at the same input |
| `make flops` | `<=` vs `=` in `always_ff`, counted as `sky130_fd_sc_hd__dfxtp_1`, plus a shift-register simulation |
| `make comb` | `<=` vs `=` in `always_comb`: identical netlists, different simulation |
| `make width` | The bug lint does not catch: `200 + 100 = 44` |
| `make clean` | Removes the logs, netlists and compiled testbenches from `results/`, and `src/obj_dir` |

## Files

| File | What it is |
|---|---|
| `src/bar_comb.sv` | Battery meter, incomplete `case`, `always_comb`. Fails to synthesize, on purpose. |
| `src/bar_star.sv` | Same `case`, `always @*`. Synthesizes to 2 × `$_DLATCH_N_`. |
| `src/bar_unique.sv` | Same `case`, `unique case`. No latch, no error, `bar[3]` tied to 0. |
| `src/bar_fixed.sv` | Same `case` plus `default:`. 2 cells, correct at all four inputs. |
| `src/bar_latch.sv` | Same `case` under `always_latch`: a latch you asked for. |
| `src/shift_nb.sv`, `src/shift_b.sv`, `src/shift_b_rev.sv` | Three statements, `<=` / `=` / `=` reordered → 3 / 1 / 3 flip-flops. |
| `src/comb_nb.sv`, `src/comb_b.sv` | `<=` vs `=` inside `always_comb`. |
| `src/add8.sv`, `src/add9.sv`, `src/add_trunc.sv` | The silent carry loss, the fix, and a width mismatch lint does see. |
| `src/tb_*.sv` | Icarus testbenches. Not synthesizable, and not meant to be. |
| `src/u_return_id.sv`, `src/u_delay.sv`, `src/u_unique_nodefault.sv` | The three Yosys reactions from [Synthesizable SystemVerilog](../../docs/guide/the-hardware-dialect.md). Used in Part 1 of the writeup. |
| `examples/dut.sv`, `examples/tb.sv`, `examples/t_display.sv`, `examples/t_initial.sv` | The other examples from that page. Used in Part 1 of the writeup. |

The Makefile writes every Yosys log, netlist and compiled testbench to `results/`, which is
gitignored apart from `.gitkeep`.

## Reference numbers (Yosys 0.68, sky130A)

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

> [`docs/guide/the-latch-you-didnt-ask-for.md`](../../docs/guide/the-latch-you-didnt-ask-for.md)
> and [`docs/guide/blocking-vs-nonblocking.md`](../../docs/guide/blocking-vs-nonblocking.md) quote
> these numbers, so if you change any source file here, re-run `make` and update both pages to
> match.

## Files that are wrong on purpose

`bar_comb.sv`, `bar_star.sv`, `bar_unique.sv`, `comb_nb.sv`, `shift_b.sv`, `shift_b_rev.sv`,
`add8.sv`, `add_trunc.sv`, `u_delay.sv` and `u_unique_nodefault.sv` are deliberately wrong: each one
is there to show a mistake, so don't copy them into your own designs. `bar_fixed.sv`,
`shift_nb.sv`, `comb_b.sv` and `add9.sv` are written the way this course expects you to write
yours.
