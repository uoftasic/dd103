# Lab 05 — Elevator to GDSII

Writeup: [`docs/labs/lab-05-elevator-overview.md`](../../docs/labs/lab-05-elevator-overview.md)

A 4-floor elevator controller, designed from a state table, taken all the way to a `.gds` file
that passes DRC, LVS and antenna signoff.

Run everything inside the workbench (`hpretl/iic-osic-tools:2026.08` — Verilator 5.050,
Icarus 14.0, Yosys 0.68, LibreLane 3.1.0.dev3).

```bash
. /foss/designs/common/.designinit
mod dd103
cd labs/lab-05-elevator

make lint        # verilator --lint-only -Wall        exit 0 on the shipped skeleton
make sim         # six checks; the skeleton fails three of them ON PURPOSE
make synth       # yosys -> sky130 cells, the receipt
make harden      # librelane config.json -> GDSII     ~1 min
make metrics     # the numbers to write down
```

## You are not starting from a blank file

`src/elevator.sv` is a **working 3-state machine** — `IDLE / MOVING / DOORS`. It lints clean,
it simulates, it synthesizes, and it hardens. It is also a bad elevator, in two specific ways
marked `TODO` in the source:

| TODO | What is missing | Which check fails |
|---|---|---|
| 1 | the **call queue** — a `pending` register | T3, and half of T5 |
| 3 | the **door-dwell timer** — a `dwell` counter | T4 |

TODO(2) is the state you have to add to hold the doors open while the timer runs.

`make sim` exits non-zero until all six checks pass. That is your definition of done for the
RTL half of the lab.

## Files

| File | What it is |
|---|---|
| `src/elevator.sv` | The skeleton you edit. Ports, reset and the 7-segment decoder are done. |
| `src/tb_elevator.sv` | Six checks. Drives on `negedge`, samples 1 ns after `posedge`. |
| `config.json` | LibreLane. **`PDK` and `STD_CELL_LIBRARY` are pinned** — see the writeup. |
| `Makefile` | `lint` `sim` `synth` `show` `harden` `metrics` `view` `clean` `distclean` |
| `solutions/elevator.sv` | A complete 5-state reference. Do not open it first. |
| `results/` | Logs, VCD, netlist, SVG. Gitignored except `.gitkeep`. |
| `runs/` | LibreLane run directories. Gitignored — ~65 MB each. |

## Numbers measured on this design

Reference implementation, `hpretl/iic-osic-tools:2026.08`, 6 cores / 7.5 GB:

| | Skeleton | Finished |
|---|---|---|
| `yosys` cells / area | 43 / **382.87 µm²** | 76 / **765.73 µm²** |
| flip-flops | 7 | **17** |
| sequential share of area | 46.08 % | **55.72 %** |

LibreLane `Classic` flow, 80 stages: **59 s wall clock, 525 MB peak RSS**, die
62.335 × 73.055 µm = **4553.88 µm²**, setup slack **+11.66 ns** on a 20 ns clock,
DRC / LVS / antenna **0 / 0 / 0**.

> Re-running `make harden` with the **same** `TAG` does not start over — LibreLane says
> `Using existing run at 'v1'` and appends stages 78, 79, 80… onto the finished run. Bump it:
> `make harden TAG=v2`.
