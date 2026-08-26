# DD103 — RTL on FPGAs & ASICs

Write SystemVerilog, watch it become **both** a bitstream and a chip, and understand why those
two are not the same thing.

Part of the **UofT ASIC Team** education materials. Published at **https://uoftasic.com/dd103/**.
Labs run inside the shared **workspace** you set up in [IC101](https://uoftasic.com/ic101/).

## At a glance

| | |
|---|---|
| **Track** | Digital |
| **Prerequisites** | [DD102](https://uoftasic.com/dd102/) · **[IC101](https://uoftasic.com/ic101/) — this is where the container becomes mandatory** |
| **Tools** | Yosys, Verilator, Icarus, nextpnr, OpenSTA, LibreLane, KLayout — all inside the workbench |
| **Time** | 16–20 hours, self-paced |
| **You need** | 4 GB RAM to run, 8 GB to be comfortable |

> **This course is pinned to the workbench image `hpretl/iic-osic-tools:2026.04`**, which ships
> **Yosys 0.64** and **LibreLane 3.0.2**. Official docs online describe newer versions with
> different option names. When a command here disagrees with the internet, the command here is
> the one that runs on your machine.
>
> Check yours: `yosys -V` should say `0.64`.

## What you'll do

DD102 ended with a 4-bit ripple adder you wrote yourself. DD103 takes that same file and
refuses to let it stay abstract.

1. Run **one** `ripple4.sv` through **two** synthesizers and get two different pieces of hardware
2. See your own RTL as a diagram, then see the same design as named SKY130 standard cells
3. Read `stat` like a receipt — cells, square micrometres, and what fraction is flip-flops
4. Find out how slow your adder is, in nanoseconds, and why the carry is to blame
5. Design a **4-floor elevator controller** from a state table
6. Take it all the way to a **GDSII file** — a real chip layout, DRC and LVS clean

## Path

| Part | Guide | Lab |
|------|-------|-----|
| 0 | [Getting started](guide/getting-started.md) | — |
| I — What synthesis is | [Synthesis is translation with an accent](guide/synthesis-is-translation.md) · [The hardware dialect](guide/the-hardware-dialect.md) | [Lab 01](labs/lab-01-one-adder-two-targets.md) |
| II — Reading what it did | [A standard cell is a real thing](guide/standard-cells-are-real.md) · [Reading `stat` like a receipt](guide/reading-stat.md) | [Lab 02](labs/lab-02-rtl-becomes-gates.md) |
| III — The traps | [The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) · [Blocking vs non-blocking](guide/blocking-vs-nonblocking.md) | [Lab 03](labs/lab-03-three-ways-to-lose-a-latch.md) |
| IV — Two targets | **[The warehouse and the empty lot](guide/warehouse-and-empty-lot.md)** · [The carry has to walk](guide/the-carry-has-to-walk.md) | [Lab 04](labs/lab-04-reading-the-receipt.md) |
| Capstone | [A state machine is a table with a memory](guide/state-machine-is-a-table.md) · [From gates to geometry](guide/from-gates-to-geometry.md) | [Lab 05](labs/lab-05-elevator.md) |

Reference: [The synthesizable subset](reference/synthesizable-subset.md) ·
[When Yosys says syntax error](reference/yosys-syntax-errors.md) ·
[OpenLane, OpenLane 2, LibreLane](reference/the-name-history.md)

## Quick start

```bash
# in the noVNC desktop, after IC101
. /foss/designs/common/.designinit
mod add dd103          # first time only
mod dd103
yosys -V               # expect: Yosys 0.64
cd labs/lab-01-one-adder-two-targets && make
```

## What you'll have at the end

A `.gds` file containing a chip you designed, that passes the same physical checks a
commercial design would — plus the ability to answer, for any RTL you write, *"how big, how
fast, and how do I know?"*

## Next courses

- **DD104** — Pre-Silicon Verification: find the bugs hiding in a real 8-bit core
- **DD201** — HLS · **DD202** — Computer Architecture
