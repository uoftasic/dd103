# Lab 02: RTL becomes gates

Writeup: [`docs/labs/lab-02-rtl-becomes-gates-overview.md`](../../docs/labs/lab-02-rtl-becomes-gates-overview.md)

This package draws the same module twice in one Yosys session, first with your own signal names
and then with the SKY130 cell names it was mapped to. The writeup also uses `src/counter.sv` and
the SKY130 library files directly, outside `make`.

Everything runs inside the workbench image `hpretl/iic-osic-tools:2026.08` (Yosys 0.68,
graphviz 2.43.0, cairosvg 2.9.0).

```bash
cd labs/lab-02-rtl-becomes-gates
make            # results/rtl.svg + results/gates.svg, about 1 s
make bigger     # the same two diagrams of ripple4
```

Open the SVGs in the noVNC desktop's file manager, or with
`firefox results/rtl.svg results/gates.svg &`.

| Target | What it runs |
|---|---|
| `make` | `show.ys` on `fulladder`, then `sizes` |
| `make bigger` | `bigger.ys` on `ripple4`, then `sizes` |
| `make png` | SVG → PNG at 1200 px with `cairosvg`, for slides |
| `make sizes` | reprint the canvas size of every SVG in `results/` |
| `make clean` | delete everything in `results/`, keep sources |

## Files

| File | What it is |
|---|---|
| `src/fulladder.sv` | The module `make` draws: one bit of the DD102 adder, written with five operators. |
| `src/ripple4.sv` | Four of them in a chain. Used by `make bigger` only. |
| `src/counter.sv` | Not built by `make`. The 4-bit counter used in Part 3 of the writeup and in [What synthesis does](../../docs/guide/synthesis-is-translation.md). |
| `src/alu.sv` | Not built by `make`, and deliberately unreadable by Yosys's built-in parser. The worked example in [When Yosys says syntax error](../../docs/reference/yosys-syntax-errors.md). Verilator lints it clean; `yosys` stops at `alu.sv:7`. |
| `show.ys` | RTL view, then gate view, in one session. |
| `bigger.ys` | The same on `ripple4`. |
| `Makefile` | `all`, `bigger`, `png`, `sizes`, `clean`. |
| `results/` | SVGs, dot files, logs. Gitignored except `.gitkeep`. |

## Canvas sizes

Measured on this image, in points (72 pt = 1 inch):

| Diagram | Canvas | Readable? |
|---|---|---|
| `rtl.svg`: fulladder, RTL view | 666 × 172 pt | yes |
| `gates.svg`: fulladder, gate view | 453 × 171 pt | yes |
| `rtl_ripple4.svg`: ripple4, RTL view | 1265 × 648 pt | yes |
| `gates_ripple4.svg`: ripple4, gate view | 3189 × 1264 pt | no; 52× the canvas area of `gates.svg` |

## Troubleshooting

- `show -format svg` draws exactly one module, so both `.ys` files end their `show` line with a
  module name. Without it:

  ```
  ERROR: For formats different than 'ps' or 'dot' only one module must be selected.
  ```

- `sak-v2svg.sh` is on the `PATH` in this image, but it does not work, because it wraps
  `netlistsvg`, which is not installed and can't be installed here: the image has `node`, but
  `npm` is absent:

  ```
  $ sak-v2svg.sh results/fulladder_sky130.v out.svg
  [ERROR] Netlistsvg could not be found!
  $ echo $?
  2
  ```

  Use Yosys's built-in `show` instead, as both `.ys` files do.

- Both scripts start with `read_liberty -lib`, which loads the cell names, pins and pin
  directions without any of the cells' logic. Without that line `show` doesn't know which pins
  are outputs, so it draws the arrows on `sum` and `cout` the wrong way round.

## Reference numbers (Yosys 0.68, sky130A)

```
=== fulladder ===
     2   33.782 cells
     1    10.01   sky130_fd_sc_hd__maj3_1
     1   23.773   sky130_fd_sc_hd__xor3_1
   Chip area for module '\fulladder': 33.782400
```

The whole script takes about 1 second and peaks around 64 MB.
