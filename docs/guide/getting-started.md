# Getting started

This page explains the environment DD103 runs in and the setup traps worth knowing about
before you hit them. You'll load the course in
[Lab 01, Part 1](../labs/lab-01-one-adder-two-targets-overview.md#part-1-load-the-course).

You already did the hard part in [IC101](https://uoftasic.com/ic101/): Docker is installed,
the `workspace` repo is cloned, and the noVNC desktop comes up in your browser. DD103 installs
nothing new. It needs one Docker image and a browser.

## The workbench

Every command in this course runs in a terminal on the noVNC desktop, inside the container, and
not on your laptop. You start the desktop from your `workspace` clone with
`./scripts/start_vnc.sh` (`scripts\start_vnc.bat` on Windows) and open it at
http://localhost/. Ports, passwords, resolution and what to do when the page is blank are in
[IC101: Launch the noVNC desktop](https://uoftasic.com/ic101/#/guide/launch-novnc). If a setup
step fails, the fix is usually in IC101.

Course files go under `/foss/designs/modules/`, which is your `workspace` folder bind-mounted
into the container. Your files are on your own disk, so deleting the container does not delete
your work. The `mod` shell function, defined by `.designinit`, clones a course into that folder
(`mod add dd103`) and moves you into it (`mod dd103`).

## Pinned versions

The course is pinned to `hpretl/iic-osic-tools:2026.08`. The two versions that matter are
Yosys 0.68 and LibreLane 3.1.0.dev3. If your tools report something else, you are on a
different image, and commands on these pages may fail in ways this course does not describe.

Yosys and LibreLane both move fast, and the official docs online describe newer releases,
sometimes with renamed options. When the internet and this course disagree, the course is
describing the program installed in your container.
[OpenLane, OpenLane 2, LibreLane](../reference/the-name-history.md) explains why the names keep
changing.

## The PDK the image starts on

`.designinit` is the environment file from the `workspace` repo. You source it with
`. /foss/designs/common/.designinit`. The leading `.` is the shell's `source` command: it runs
the file in your current shell instead of a child process, which is the only way a script can
change your environment. Running the file without the dot and the space does nothing useful.

The image's own default PDK is `ihp-sg13g2`, a real 130 nm process from IHP in Germany. Every
measurement in DD103 is on SKY130, and `.designinit` sets `PDK=sky130A`. If your shell is
still on the IHP default, the tools run against the wrong technology and never say so. Nothing
errors. The only symptom is a line deep in a log where Yosys reads cells named `sg13g2_*` and
you expected `sky130_fd_sc_hd__*`.

The standard-cell library is a separate variable, `STD_CELL_LIBRARY`, and the image default
for it is `sg13g2_stdcell`. A SKY130 PDK with an IHP cell library is a combination that does
not exist. LibreLane dies on it in 1.2 seconds, before it reads a line of your design, with a
Tcl error naming a directory you have never heard of:

```
_tkinter.TclError: no files matched glob pattern "/foss/pdks/sky130A/libs.ref/sg13g2_stdcell/lef/*.lef"
```

The lab packages in this course pin `STD_CELL_LIBRARY` in their own `config.json`, so they
work either way. It is everything else you try, such as the LibreLane example designs or a
config copied off the internet, that falls over without it. Lab 01 has you check both variables
and set `STD_CELL_LIBRARY=sky130_fd_sc_hd` if it isn't already.

## What the machine needs

4 GB of RAM works and 8 GB is comfortable. The image itself is about 19 GB on disk, which is
the number that surprises people.

These tools are smaller than their reputation. Measured on this image with `/usr/bin/time -v`,
on a six-core laptop with 7.5 GB of RAM:

| Job | Peak memory | Wall time |
|---|---|---|
| Yosys mapping a 1-bit full adder to SKY130 cells | 65 MB | 0.3 s |
| A complete RTL → GDSII run of a 32-bit counter through LibreLane | 635 MB | 1 min 16 s |

The second row is the whole flow: synthesis, floorplan, placement, clock tree, routing, DRC,
LVS and a finished layout, eighty stages in all, in two thirds of a gigabyte. When your 4 GB
runs out, the browser you left open is the more likely cause than Yosys.

## Where error messages appear

Most of these tools print to the terminal you launched them from, not into their own window.
Ask KLayout to open a file that is not there, and the reason shows up in the terminal:

```
ERROR: Unable to open file: /foss/designs/modules/dd103/nope.gds (errno=2)
```

So launch GUI tools by typing their name in a terminal, never from a desktop icon. If you start
KLayout or Surfer from the menu and something goes wrong, the explanation goes to a terminal
that does not exist, and the program appears to do nothing.

### Terminal width

LibreLane formats its log to the width of your terminal, and the default noVNC terminal is 80
columns. Here is the same error from the same run at two widths. At 80 columns:

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

The information is the same, but the first is four fragments scrolling past inside an 80-stage
run and the second is one line you can search for. Lab 01 has you maximize the window or set
`COLUMNS=200`.

## Getting help

The course is self-paced, but you don't have to work through it alone.

- Ask in the [team Discord](https://discord.gg/hrJnP5UsGz). No question is too basic. Most of
  what looks like your mistake here is the tool being unhelpful.
- Quote the exact error. The first `ERROR:` line is the real one; everything after it is
  fallout. Paste that line, the command you ran, and what `yosys -V` says.
- If a command on these pages does not do what the page says, that is a bug in the course.
  Every command was run before it was written, so a mismatch means something drifted, and we
  want to know.

### Running a lab without tying up your laptop

A LibreLane run takes about a minute of full CPU. If you would rather not spend it, or you want
a second opinion on whether your design really is clean, the team ships a GitHub Action that
hardens a design in CI and hands back the layout, a render of it, and the sign-off numbers:
[`uoftasic/librelane-action`](https://github.com/uoftasic/librelane-action).

Copy its `templates/harden.yml` into your own repo as `.github/workflows/harden.yml` and point
it at your design directory. It runs the same LibreLane 3.1.0.dev3 on the same `config.json`
you run locally. It is a convenience, not a replacement for the workbench, which is where every
number in this course was measured.

Next: [Lab 01: One adder, two targets](../labs/lab-01-one-adder-two-targets-overview.md).
