# Lab 02 — RTL becomes gates

Writeup: [`docs/labs/lab-02-rtl-becomes-gates-overview.md`](../../docs/labs/lab-02-rtl-becomes-gates-overview.md)

Two pictures of the same module, taken at two moments in one Yosys session.
The left one carries your signal names. The right one carries SKY130 cell names.

Runs inside the workbench `hpretl/iic-osic-tools:2026.04` — Yosys **0.64**,
graphviz **2.43.0**, cairosvg **2.9.0**.

```bash
cd labs/lab-02-rtl-becomes-gates
make            # results/rtl.svg + results/gates.svg, ~1 s
make bigger     # the same two pictures of ripple4 — the second one is the point
make png        # only if you need a raster for slides
```

Open the SVGs in the noVNC desktop's file manager, or:

```bash
firefox results/rtl.svg results/gates.svg &
```

## Files

| File | What it is |
|---|---|
| `src/fulladder.sv` | The subject. One bit of the DD102 adder — five operators. |
| `src/ripple4.sv` | Four of them in a chain. Used by `make bigger` only. |
| `src/counter.sv` | Not built by `make`. The 4-bit counter every command in [Synthesis is translation with an accent](../../docs/guide/synthesis-is-translation.md) runs on. |
| `src/alu.sv` | Not built by `make`, and **deliberately unreadable by Yosys's built-in parser**. The worked example in [When Yosys says syntax error](../../docs/reference/yosys-syntax-errors.md). Verilator lints it clean; `yosys` stops at `alu.sv:7`. |
| `show.ys` | The money shot: RTL view, then gate view, one session. |
| `bigger.ys` | The same on `ripple4`, to show where diagrams stop working. |
| `Makefile` | `all`, `bigger`, `png`, `sizes`, `clean`. |
| `results/` | SVGs, dots, logs. Gitignored except `.gitkeep`. |

## Why the subject is one full adder and not the whole ripple adder

Graphviz gate diagrams do not scale. Measured on this image, canvas size in
points (72 pt = 1 inch):

| Diagram | Canvas | Readable? |
|---|---|---|
| `rtl.svg` — fulladder, RTL view | 666 × 172 pt | yes |
| `gates.svg` — fulladder, gate view | **453 × 171 pt** | yes |
| `rtl_ripple4.svg` — ripple4, RTL view | 1265 × 648 pt | yes |
| `gates_ripple4.svg` — ripple4, gate view | **3189 × 1264 pt** | no — **52× the canvas area of `gates.svg`** |

**The rule: gate view of the full adder, RTL view of anything bigger.**
`make bigger` exists so you see that happen once, deliberately, instead of
discovering it in the middle of the capstone.

## Two traps

**`show -format svg` draws exactly one module.** Both `.ys` files end their
`show` line with an explicit module name for this reason. Without it:

```
ERROR: For formats different than 'ps' or 'dot' only one module must be selected.
```

**Do not use `sak-v2svg.sh`.** It is on the PATH in this image and it looks
official. It is not usable — it wraps `netlistsvg`, which is not installed and
cannot be installed here (`npm` is absent; only `node` is present):

```
$ sak-v2svg.sh results/fulladder_sky130.v out.svg
[ERROR] Netlistsvg could not be found!
$ echo $?
2
```

`show` is the supported path. It is built into Yosys and it works.

## The `read_liberty -lib` line

Both scripts start by reading the liberty file **as a catalogue** (`-lib` loads
names, pins, and directions — no logic). Without it, `show` has no idea which
pins are outputs, draws every port down the left-hand side, and points the
arrows on `sum` and `cout` the wrong way. One line, much better picture.

## Reference numbers (Yosys 0.64, sky130A)

```
=== fulladder ===
     2   33.782 cells
     1    10.01   sky130_fd_sc_hd__maj3_1
     1   23.773   sky130_fd_sc_hd__xor3_1
   Chip area for module '\fulladder': 33.782400
```

Whole script: **about 1 second**, ~64 MB peak.
