# Lab 01: One adder, two targets

Writeup: [`docs/labs/lab-01-one-adder-two-targets-overview.md`](../../docs/labs/lab-01-one-adder-two-targets-overview.md)

This lab takes one adder, `ripple4.sv`, and synthesizes it twice: once for an iCE40 FPGA and once
for SKY130 standard cells.

It runs inside the workbench `hpretl/iic-osic-tools:2026.08` (Yosys 0.68, nextpnr-ice40 0.11.1),
and you can check your Yosys version with `yosys -V`. Both flows already ship in the workbench, so
there is no vendor toolchain to install.

```bash
cd labs/lab-01-one-adder-two-targets
make            # both flows, then a summary of your numbers
```

| Target | What it runs |
|---|---|
| `make` | `fpga`, `asic`, then `table` |
| `make fpga` | Lattice iCE40 UP5K: `yosys synth_ice40` → `nextpnr-ice40` → `icepack` |
| `make asic` | SKY130: `yosys synth` → `abc -liberty` |
| `make table` | reprint the summary from logs you already have |
| `make clean` | delete everything in `results/`, keep sources |

## Files

| File | What it is |
|---|---|
| `src/ripple4.sv` | The 4-bit ripple-carry adder from DD102. Replace it with your own. |
| `src/fulladder.sv` | One slice. `ripple4` instantiates four of them. |
| `examples/mem.sv` | A 2 KB memory, used in Part 7 of the writeup. Not built by `make`. |
| `fpga.ys` | The iCE40 script. No liberty file: on an FPGA the library is the chip. |
| `asic.ys` | The SKY130 script, with the liberty path filled in. |
| `Makefile` | `fpga`, `asic`, `table`, `clean`. |
| `results/` | Everything the tools write. Gitignored except `.gitkeep`. |

## Using your own adder

Copy your DD102 files into `src/` and keep the module named `ripple4`, with ports `a`, `b`,
`cin`, `sum` and `cout`, because both scripts expect that name. If your design is split across
different files, edit the `read_verilog` line at the top of both `.ys` files to read them.

If your `ripple4.sv` instantiates a `fulladder` but the script does not read the file that defines
it, Yosys stops with:

```
ERROR: Module `\fulladder' referenced in module `\ripple4' in cell `\slice[3].fa' is not part of the design.
```

## Output that is not an error

- `abc` prints 94 lines of `ABC: Scl_LibertyReadGenlib() skipped ...` before it does anything
  useful, and 63 of them are about flip-flops and latches. ABC maps only combinational logic, so
  it skips those cells in the library.
- `stat` prints `Area for cell type $scopeinfo is unknown!`. The `$scopeinfo` cells are markers
  that `flatten` leaves behind, not hardware, and `write_verilog` does not emit them.

## Reference numbers (Yosys 0.68, sky130A, iCE40 UP5K)

```
FPGA  8 × SB_LUT4  →  10 / 5280 ICESTORM_LC  →  104,090-byte bitstream
ASIC  4 × sky130_fd_sc_hd__maj3_1 + 8 × sky130_fd_sc_hd__xnor2_1
      = 12 cells, 110.1056 µm²
```

If your adder is written differently, your numbers will differ. Write down what you got, and the
writeup will help you make sense of it.
