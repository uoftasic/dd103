# Getting started

**Question this page answers:** *How do I get from a browser tab to a prompt where `yosys` works?*

You already did the hard part in [IC101](https://uoftasic.com/ic101/): Docker installed, the
`workspace` repo cloned, the noVNC desktop coming up in your browser. This page is four
commands and a version check. Nothing here installs anything — DD103 needs **one Docker image
and a browser**, and that is the whole tool story for the course.

If a step below fails, the fix is almost always back in IC101, not here.

## 1. Start the desktop

On your own machine, in your `workspace` clone:

```bash
cd workspace
./scripts/start_vnc.sh          # Windows: scripts\start_vnc.bat
```

Then open **http://localhost/** and open a terminal on that desktop — the same one you used
for the IC101 smoke test. Every command from here down is typed *inside* that terminal, not on
your laptop.

Ports, passwords, resolution, and what to do when the page is blank: [IC101 — Launch the noVNC
desktop](https://uoftasic.com/ic101/#/guide/launch-novnc).

## 2. Load the environment

```bash
. /foss/designs/common/.designinit
```

```
ASIC-EDU: PDK=sky130A  PDK_ROOT=/foss/pdks  designs=/foss/designs
          run 'mod' to list course modules, or 'mod <name>' to enter one.
```

That leading `.` is the shell's `source` command. It runs the file *in your current shell*
instead of a child process, which is the only way a script can change your environment. Typing
`/foss/designs/common/.designinit` without the dot and the space does nothing useful.

**This is not a decorative banner.** Check what the PDK was before you ran it:

```bash
echo $PDK
```

```
ihp-sg13g2
```

`ihp-sg13g2` is a real 130 nm process from IHP in Germany, and the image ships it as the
default. Every measurement in DD103 is on **SKY130**. Skip this step and the tools will run
cheerfully against the wrong technology and never once say so. Nothing errors. The only
symptom is a line deep in a log where Yosys reads cells named `sg13g2_*` and you expected
`sky130_fd_sc_hd__*`.

You must do this **in every new terminal.** It does not stick.

### One line `.designinit` does not set yet

`.designinit` sets `PDK=sky130A`, but the cell library is a separate variable and it is still
sitting on the image's default:

```bash
echo $STD_CELL_LIBRARY
```

```
sg13g2_stdcell
```

A SKY130 PDK with an IHP cell library is a combination that does not exist. LibreLane dies on
it in **1.2 seconds** — before it reads a line of your design — with a Tcl error naming a
directory you have never heard of:

```
_tkinter.TclError: no files matched glob pattern "/foss/pdks/sky130A/libs.ref/sg13g2_stdcell/lef/*.lef"
```

So add this line after you source `.designinit`:

```bash
export STD_CELL_LIBRARY=sky130_fd_sc_hd
```

The lab packages in this course pin `STD_CELL_LIBRARY` inside their own `config.json`, so they
work either way. It is everything *else* you try — the LibreLane example designs, anything you
copy off the internet — that falls over without it.

## 3. Get the course files

```bash
mod add dd103      # first time only — clones github.com/uoftasic/dd103
mod dd103          # every time after that
```

```
Cloning https://github.com/uoftasic/dd103.git
     into /foss/designs/modules/dd103
Cloning into '/foss/designs/modules/dd103'...
OK  module ready: /foss/designs/modules/dd103
    run: mod dd103
cwd: /foss/designs/modules/dd103
```

`mod` is a shell function that `.designinit` defines. `mod` with no arguments lists what you
already have:

```
Available modules:
dd103
ic101_setup
```

Everything lands under `/foss/designs/modules/`, which is your `workspace` folder bind-mounted
into the container. Your files are on **your** disk. Deleting the container does not delete
your work.

### Three errors you will see at least once

| What you see | What it means |
|---|---|
| `bash: mod: command not found` | You did not run step 2 *in this terminal*. Every new tab starts clean. |
| `mod: no such module: dd103` | You ran `mod dd103` before `mod add dd103`. |
| `fatal: could not read Username for 'https://github.com'` | git is being asked to log in, which means it could not read the repo anonymously. Check the spelling first; if it is right, ask in [Discord](https://discord.gg/hrJnP5UsGz) — do not type your password. |

## 4. Check your versions

This course is pinned to `hpretl/iic-osic-tools:2026.04`. Two commands confirm you are on it:

```bash
yosys -V
librelane --version
```

```
Yosys 0.64 (git sha1 6d2c445ae, g++ 13.3.0-6ubuntu2~24.04.1 -fPIC -O3)
```

```
LibreLane v3.0.2

Copyright ©2025-2026 LibreLane Contributors

Adapted from OpenLane 2.0
Copyright ©2020-2025 Efabless Corporation
```

**`0.64` and `3.0.2` are the numbers that matter.** If you see something else, you are on a
different image, and commands on these pages may fail in ways this course does not describe.

The full set, if you want to check the rest:

| Tool | Command | Expect |
|---|---|---|
| Yosys | `yosys -V` | `Yosys 0.64` |
| LibreLane | `librelane --version` | `LibreLane v3.0.2` |
| Icarus Verilog | `iverilog -V` | `14.0 (devel)` |
| Verilator | `verilator --version` | `Verilator 5.046` |
| Surfer | `surfer --version` | `surfer 0.6.0` |
| nextpnr | `nextpnr-ice40 --version` | `nextpnr-0.10-33-ge6ecd8fa` |

> Yosys and LibreLane are both moving fast. The official docs online describe **newer**
> releases, sometimes with renamed options. When the internet and this course disagree, this
> course is describing the program actually sitting on your disk. If you want the long version
> of why the names keep changing, read
> [OpenLane, OpenLane 2, LibreLane](reference/the-name-history.md).

## What the machine actually needs

**4 GB of RAM works. 8 GB is comfortable.** The image itself is about **19 GB on disk**, which
is the number that surprises people, not the RAM.

These tools are far smaller than their reputation. Measured on this image with
`/usr/bin/time -v`, on a six-core laptop with 7.5 GB of RAM:

| Job | Peak memory | Wall time |
|---|---|---|
| Yosys mapping a 1-bit full adder to SKY130 cells | **65 MB** | 0.3 s |
| A complete RTL → GDSII run of a 32-bit counter through LibreLane | **635 MB** | 1 min 16 s |

That second row is the whole flow — synthesis, floorplan, placement, clock tree, routing,
DRC, LVS, and a finished layout, eighty stages of it — on a six-core laptop, in two thirds of
a gigabyte.

What eats your 4 GB is the browser you left open, not Yosys.

## Where the error messages actually are

**Most of these tools print to the terminal you launched them from, not into their own
window.** Ask KLayout to open a file that is not there, and this is where the reason shows
up — in the terminal, not the window:

```
ERROR: Unable to open file: /foss/designs/modules/dd103/nope.gds (errno=2)
```

So: **launch GUI tools by typing their name in a terminal**, never from a desktop icon. If you
start KLayout or Surfer from the menu and something goes wrong, the explanation is written to
a terminal that does not exist, and you get a program that silently does nothing.

### Maximize the terminal window first

LibreLane formats its log to whatever width your terminal has, and the default noVNC terminal
is 80 columns. The same error, in the same run, at two widths:

At 80 columns:

```
[00:13:50] ERROR    [PDN-0185] Insufficient width (18.40 um) to  openroad.py:312
                    add straps on layer met4 in grid
                    "stdcell_grid" with total strap width 4.9 um
                    and offset 16.3 um.
```

At 200 columns:

```
[00:13:50] ERROR    [PDN-0185] Insufficient width (18.40 um) to add straps on layer met4 in grid "stdcell_grid" with total strap width 4.9 um and offset 16.3 um.
```

Same information, but the first one is four fragments scrolling past inside an 80-stage run
and the second is one line you can search for. Maximize the window, or set the width yourself,
next to the `STD_CELL_LIBRARY` line from step 2:

```bash
export COLUMNS=200
```

## You are ready when

```bash
. /foss/designs/common/.designinit
export STD_CELL_LIBRARY=sky130_fd_sc_hd
export COLUMNS=200
mod dd103
yosys -V                       # Yosys 0.64
ls labs/                       # the lab packages
```

Next: [Synthesis is translation with an accent](guide/synthesis-is-translation.md), where you
find out what `yosys` is actually doing to the SystemVerilog you wrote in DD102 — and it turns
out to be five steps, each of which you can watch.


## Getting help

This course is self-paced, which is not the same as alone.

- **Ask in the [team Discord](https://discord.gg/hrJnP5UsGz).**
  There is no such thing as a question too basic — most of what looks like a mistake here is
  the tool being unhelpful, not you.
- **Quote the exact error.** The first `ERROR:` line is the real one; everything after it is
  fallout. Paste that line, the command you ran, and what `yosys -V` says.
- **If a command in these pages does not do what the page says it does, that is a bug in the
  course.** Report it. Every command here was run before it was written, so a mismatch means
  something drifted and we want to know.

### Running a lab without tying up your laptop

A LibreLane run is about a minute of full CPU. If you would rather not spend it — or you want a
second opinion on whether your design really is clean — the team ships a GitHub Action that
hardens a design in CI and hands back the layout, a render of it, and the sign-off numbers:
[`uoftasic/librelane-action`](https://github.com/uoftasic/librelane-action).

Copy its `templates/harden.yml` into your own repo as `.github/workflows/harden.yml` and point
it at your design directory. It runs the same LibreLane 3.0.2 on the same `config.json` you run
locally — a convenience, not a replacement for the workbench, which is what every number in this
course was measured on.
