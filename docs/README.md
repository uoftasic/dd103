# DD103 — RTL on FPGAs & ASICs

Write SystemVerilog, watch it become **both** a bitstream and a chip, and understand why those
two are not the same thing.

Part of the **UofT ASIC Team** education materials. Published at **https://uoftasic.com/dd103/**.
Labs run inside the shared **workspace** you set up in [IC101](https://uoftasic.com/ic101/).

## At a glance

| | |
|---|---|
| **Track** | Digital |
| **Prerequisites** | [IC101](https://uoftasic.com/ic101/) then [DD102](https://uoftasic.com/dd102/), in that order |
| **Tools** | Yosys, Verilator, Icarus, nextpnr, OpenSTA, LibreLane, KLayout — all inside the workbench |
| **Time** | 16–20 hours, self-paced |
| **Machine** | 4 GB RAM to run, 8 GB to be comfortable. You already have the workbench from IC101. |

> **This course is pinned to the workbench image `hpretl/iic-osic-tools:2026.08`**, which ships
> **Yosys 0.68** and **LibreLane 3.1.0.dev3**. Official docs online describe newer versions with
> different option names. When a command here disagrees with the internet, the command here is
> the one that runs on your machine.
>
> Check yours: `yosys -V` should say `0.64`.

> **If a setup command fails, try `make` anyway.** Every lab package pins its own PDK and
> liberty paths, so Labs 01–04 run to completion in a bare container with no environment setup
> at all. A broken `.designinit` should cost you a confused minute, not the course. (Lab 05
> uses LibreLane and does need the workbench proper.)

## What you'll do

DD102 ended with a 4-bit ripple adder you wrote yourself. DD103 takes that same file and
refuses to let it stay abstract.

1. Run **one** `ripple4.sv` through **two** synthesizers and get two different pieces of hardware
2. See your own RTL as a diagram, then see the same design as named SKY130 standard cells
3. Read `stat` like a receipt — cells, square micrometres, and what fraction is flip-flops
4. Find out how slow your adder is, in nanoseconds, and why the carry is to blame
5. Design a **4-floor elevator controller** from a state table
6. Take it all the way to a **GDSII file** — a real chip layout, DRC and LVS clean

![The Lab 02 counter hardened to GDSII and opened in KLayout: the die outline, the standard-cell rows filling the core, the routing on top, and the sky130A layer list on the right](assets/img/dd103-klayout-counter-gds.png)

*That is the four-bit counter from Lab 02, after LibreLane at `FP_CORE_UTIL: 30`.
35.5 µm by 46.3 µm, 98 cell instances, opened in KLayout with the SKY130 layer palette. The
cell list on the left is every standard cell it is made of.*

## Path

| Part | Guide | Lab |
|------|-------|-----|
| 0 | [Getting started](guide/getting-started.md) | — |
| I — What synthesis is | [Synthesis is translation with an accent](guide/synthesis-is-translation.md) · [The hardware dialect](guide/the-hardware-dialect.md) | [Lab 01](labs/lab-01-one-adder-two-targets-overview.md) |
| II — Reading what it did | [A standard cell is a real thing](guide/standard-cells-are-real.md) · [Reading `stat` like a receipt](guide/reading-stat.md) | [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) |
| III — The traps | [The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) · [Blocking vs non-blocking](guide/blocking-vs-nonblocking.md) | [Lab 03](labs/lab-03-three-ways-to-lose-a-latch-overview.md) |
| IV — Two targets | **[The warehouse and the empty lot](guide/warehouse-and-empty-lot.md)** · [The carry has to walk](guide/the-carry-has-to-walk.md) | [Lab 04](labs/lab-04-reading-the-receipt-overview.md) |
| Capstone | [A state machine is a table with a memory](guide/state-machine-is-a-table.md) · [From gates to geometry](guide/from-gates-to-geometry.md) | [Lab 05](labs/lab-05-elevator-overview.md) |

**Stuck?** Ask in the [team Discord](https://discord.gg/hrJnP5UsGz). Nobody expects you to work this out alone at
2 a.m. — see [Getting help](guide/getting-started.md#getting-help).

Reference: [The synthesizable subset](reference/synthesizable-subset.md) ·
[When Yosys says syntax error](reference/yosys-syntax-errors.md) ·
[OpenLane, OpenLane 2, LibreLane](reference/the-name-history.md)

## Quick start

```bash
# in the noVNC desktop, after IC101
. /foss/designs/common/.designinit
mod add dd103          # first time only
mod dd103
yosys -V               # expect: Yosys 0.68
cd labs/lab-01-one-adder-two-targets && make
```

## What you'll have at the end

A `.gds` file containing a chip you designed, that passes the same physical checks a
commercial design would — plus the ability to answer, for any RTL you write, *"how big, how
fast, and how do I know?"*

## Next courses

- **[DD104](https://uoftasic.com/dd104/)** — Pre-Silicon Verification: find the bugs hiding in a real 8-bit core
- **DD201** — HLS · **DD202** — Computer Architecture
