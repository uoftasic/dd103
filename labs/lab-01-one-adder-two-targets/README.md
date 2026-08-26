# Lab 01 — One adder, two targets

Writeup: [`docs/labs/lab-01-one-adder-two-targets.md`](../../docs/labs/lab-01-one-adder-two-targets.md)

One `ripple4.sv`. Two synthesizers. Two answers that do not look like each other.

Runs inside the workbench `hpretl/iic-osic-tools:2026.04` — Yosys **0.64**,
nextpnr-ice40 **0.10**. Check yours with `yosys -V`.

```bash
cd labs/lab-01-one-adder-two-targets
make            # both flows, then a summary of your three numbers
```

| Target | `make` | Tools |
|---|---|---|
| Lattice iCE40 UP5K FPGA | `make fpga` | `yosys synth_ice40` → `nextpnr-ice40` → `icepack` |
| SKY130 ASIC | `make asic` | `yosys synth` → `abc -liberty` |

There is no third target, and no vendor toolchain to install. DD103 needs **one
Docker image and a browser** — both flows above are already inside the workbench.

## Files

| File | What it is |
|---|---|
| `src/ripple4.sv` | The 4-bit ripple-carry adder from DD102. **Replace this with your own** — that is the point of the lab. |
| `src/fulladder.sv` | One slice. `ripple4` instantiates four of them. |
| `fpga.ys` | The iCE40 script. No liberty file: on an FPGA the library *is* the chip. |
| `asic.ys` | The SKY130 script. Liberty path is baked in so you never retype it. |
| `Makefile` | `fpga`, `asic`, `table`, `clean`. |
| `results/` | Everything the tools write. Gitignored except `.gitkeep`. |

## Bringing your own adder

Drop your DD102 files into `src/` and keep the module named `ripple4` with ports
`a`, `b`, `cin`, `sum`, `cout`. If you split it differently, edit the
`read_verilog` line at the top of both `.ys` files.

If your `ripple4.sv` instantiates a `fulladder` and you forget to read that file
too, Yosys stops with:

```
ERROR: Module `\fulladder' referenced in module `\ripple4' in cell `\slice[3].fa' is not part of the design.
```

## Two things in the output that are not bugs

**`abc` prints 94 lines of this before it does anything useful** — 63 of them
about flip-flops and latches:

```
ABC: Scl_LibertyReadGenlib() skipped sequential cell "sky130_fd_sc_hd__dfbbn_1".
```

Harmless. ABC only maps combinational logic; flip-flops are somebody else's job
(`dfflibmap`, which you will meet in Lab 02).

**`stat` says `Area for cell type $scopeinfo is unknown!`** — also harmless.
`flatten` dissolved your four `fulladder` instances into one flat module and left
one `$scopeinfo` marker per dissolved instance so it can still tell you which
slice a cell came from. They are notes, not hardware. `write_verilog` does not
emit them.

## Reference numbers (Yosys 0.64, sky130A, iCE40 UP5K)

```
FPGA  8 × SB_LUT4  →  10 / 5280 ICESTORM_LC  →  104,090-byte bitstream
ASIC  4 × sky130_fd_sc_hd__maj3_1 + 8 × sky130_fd_sc_hd__xnor2_1
      = 12 cells, 110.1056 µm²
```

If your adder is written differently, your numbers will differ. Write down what
*you* got; the writeup tells you what to make of it.
