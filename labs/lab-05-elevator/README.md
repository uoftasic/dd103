# Lab 05: Elevator to GDSII

Writeup: [`docs/labs/lab-05-elevator-overview.md`](../../docs/labs/lab-05-elevator-overview.md)

A 4-floor elevator controller, designed from a state table and taken all the way to a `.gds`
file that passes DRC, LVS and antenna signoff.

Run everything inside the workbench (`hpretl/iic-osic-tools:2026.08`: Verilator 5.050, Icarus
14.0, Yosys 0.68, LibreLane 3.1.0.dev3).

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-05-elevator
make lint
make sim
```

| Target | What it runs |
|---|---|
| `make` | `lint`, `sim`, `synth` |
| `make lint` | `verilator --lint-only -Wall`; exits 0 on the shipped skeleton |
| `make sim` | `iverilog` + `vvp`, six checks; the skeleton fails three of them on purpose |
| `make synth` | Yosys → SKY130 cells, and the `stat` receipt |
| `make show` | the RTL diagram, `results/elevator_rtl.svg` (not the gate diagram) |
| `make harden TAG=v1` | `librelane config.json` → GDSII, about 1 min |
| `make metrics TAG=v1` | the numbers to write down, from `runs/<tag>/final/metrics.json` |
| `make view` | open the last run in KLayout (noVNC desktop only) |
| `make clean` | delete `results/`, keep `runs/` |
| `make distclean` | `clean`, then delete `runs/` |

`make sim` exits non-zero until all six checks pass. That is the definition of done for the RTL
half of the lab.

Re-running `make harden` with the same `TAG` does not start over: LibreLane says
`Using existing run at 'v1'` and appends stages 78, 79, 80… onto the finished run. Use a new tag,
such as `make harden TAG=v2`.

## The skeleton

`src/elevator.sv` is a working 3-state machine (`IDLE / MOVING / DOORS`). It lints, simulates,
synthesizes and hardens. It is missing two things, marked `TODO` in the source:

| TODO | What is missing | Which check fails |
|---|---|---|
| 1 | the call queue, a `pending` register | T3, and half of T5 |
| 3 | the door-dwell timer, a `dwell` counter | T4 |

TODO(2) is the state you add to hold the doors open while the timer runs.

## Files

| File | What it is |
|---|---|
| `src/elevator.sv` | The skeleton you edit. Ports, reset and the 7-segment decoder are done. |
| `src/tb_elevator.sv` | Six checks. Drives on `negedge`, samples 1 ns after `posedge`. |
| `examples/vending.sv` | The vending machine from [Writing a state machine](../../docs/guide/state-machine-is-a-table.md), used in Part 1 of the writeup. |
| `config.json` | LibreLane config. `PDK` and `STD_CELL_LIBRARY` are pinned; see the writeup. |
| `Makefile` | `lint` `sim` `synth` `show` `harden` `metrics` `view` `clean` `distclean` |
| `solutions/elevator.sv` | A complete 5-state reference. Don't open it first. |
| `results/` | Logs, VCD, netlist, SVG. Gitignored except `.gitkeep`. |
| `runs/` | LibreLane run directories, about 65 MB each. Gitignored. |

## Reference numbers

Reference implementation on `hpretl/iic-osic-tools:2026.08`, 6 cores / 7.5 GB:

| | Skeleton | Finished |
|---|---|---|
| `yosys` cells / area | 43 / 382.87 µm² | 76 / 765.73 µm² |
| flip-flops | 7 | 17 |
| sequential share of area | 46.08 % | 55.72 % |

LibreLane `Classic` flow, 80 stages: 59 s wall clock, 525 MB peak RSS, die
62.335 × 73.055 µm = 4553.88 µm², setup slack +11.66 ns on a 20 ns clock, and DRC / LVS / antenna
0 / 0 / 0.
