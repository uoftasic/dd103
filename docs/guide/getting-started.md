# Getting started

This page explains the environment DD103 runs in, and goes through the setup mistakes that are
worth knowing about before you make them. You'll load the course yourself in
[Lab 01, Part 1](../labs/lab-01-one-adder-two-targets-overview.md#part-1-load-the-course).

You did the hard part of the setup in [IC101](https://uoftasic.com/ic101/), which left you with
Docker installed, the `workspace` repo cloned, and a noVNC desktop that comes up in your browser.
DD103 doesn't install anything new; it needs one Docker image and a browser, and you already have
both.

## The workbench

You run every command in this course in a terminal on the noVNC desktop, which means inside the
container rather than on your laptop. You start the desktop from your `workspace` clone with
`./scripts/start_vnc.sh` (`scripts\start_vnc.bat` on Windows) and open it at
http://localhost/.
[IC101: Launch the noVNC desktop](https://uoftasic.com/ic101/guide/launch-novnc.html) covers the
ports, passwords and resolution, and what to do when the page comes up blank. If a setup step
fails, look there first, because the fix is usually in IC101.

Course files go under `/foss/designs/modules/`, which is your `workspace` folder bind-mounted
into the container. That means the files live on your own disk, so deleting the container doesn't
delete your work. The `mod` shell function, which the `.designinit` environment file (described below)
defines, clones a course into that
folder (`mod add dd103`) and moves you into it (`mod dd103`).

## Pinned versions

The course is pinned to the image `hpretl/iic-osic-tools:2026.08`, and the two versions in it
that matter are Yosys 0.68 and LibreLane 3.1.0.dev3. If your tools report something else, you're
on a different image, and commands on these pages may fail in ways this course doesn't describe.

Yosys and LibreLane both move fast, and the official docs online describe newer releases,
sometimes with renamed options. So when the docs online and this course disagree, it's
because the course describes the program installed in your container and the docs describe a
newer one.
[OpenLane, OpenLane 2, LibreLane](../reference/the-name-history.md) explains why the names keep
changing.

## The PDK the image starts on

`.designinit` is the environment file from the `workspace` repo, and you load it with
`. /foss/designs/common/.designinit`. The leading `.` is the shell's `source` command. It runs
the file in your current shell instead of in a child process, and that's the only way a script
can change your shell's environment. If you leave off the dot and the space, the file runs in a
child process, and its changes never reach your shell, so it does nothing useful.

The image's own default PDK is `ihp-sg13g2`, a real 130 nm process from IHP in Germany. Every
measurement in DD103 was made on SKY130, and `.designinit` sets `PDK=sky130A` for you. If your
shell is still on the IHP default, the tools run against the wrong technology without telling
you. Nothing reports an error, and the only symptom is a line deep in a log where Yosys reads
cells named `sg13g2_*` when you expected `sky130_fd_sc_hd__*`.

The standard-cell library is set by a separate variable, `STD_CELL_LIBRARY`, and the image's
default for it is `sg13g2_stdcell`. A SKY130 PDK with an IHP cell library is a combination that
doesn't exist, so LibreLane dies on it after 1.2 seconds, before it has read a line of your
design, with a Tcl error naming a directory you've never heard of:

```
_tkinter.TclError: no files matched glob pattern "/foss/pdks/sky130A/libs.ref/sg13g2_stdcell/lef/*.lef"
```

The lab packages in this course pin `STD_CELL_LIBRARY` in their own `config.json`, so they
work either way. Anything else you try, such as the LibreLane example designs or a config copied
off the internet, will fall over without it. In Lab 01 we have you check both variables, and set
`STD_CELL_LIBRARY=sky130_fd_sc_hd` if it isn't set already.

## What the machine needs

A machine with 4 GB of RAM works, and 8 GB is comfortable. The image itself takes about 19 GB of
disk, and that's the number that surprises people.

The tools need much less memory than their reputation suggests. Here is what two jobs used on
this image, measured with `/usr/bin/time -v` on a six-core laptop with 7.5 GB of RAM:

| Job | Peak memory | Wall time |
|---|---|---|
| Yosys mapping a 1-bit full adder to SKY130 cells | 65 MB | 0.3 s |
| A complete RTL → GDSII run of a 32-bit counter through LibreLane | 635 MB | 1 min 16 s |

The second row is the whole flow (synthesis, floorplan, placement, clock tree, routing, DRC,
LVS and a finished layout, eighty stages in all), and it fits in two thirds of a gigabyte. So if
a 4 GB machine runs out of memory, the browser you left open is a more likely cause than Yosys.

## Where error messages appear

Most of these tools print their messages to the terminal you launched them from rather than into
their own window. If you ask KLayout to open a file that isn't there, for example, the reason
shows up in the terminal:

```
ERROR: Unable to open file: /foss/designs/modules/dd103/nope.gds (errno=2)
```

That's why you should launch GUI tools by typing their name in a terminal, and never from a
desktop icon. If you start KLayout or Surfer from the menu there is no such terminal, so when
something goes wrong the explanation is lost and the program appears to do nothing at all.

### Terminal width

LibreLane formats its log to fit the width of your terminal, and the default noVNC terminal is
only 80 columns wide. Here is the same error from the same run at two widths, first at 80
columns:

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

Both carry the same information, but in an 80-stage run the first is four fragments scrolling
past among everything else, while the second is a single line you can search for. That's why
Lab 01 has you maximize the terminal window or set `COLUMNS=200`.

## Getting help

The course is self-paced, but you don't have to work through it alone.

- Ask in the [team Discord](https://discord.gg/hrJnP5UsGz). No question is too basic. With
  these tools, most of what looks like your own mistake is really the tool being unhelpful.
- Quote the exact error. The first `ERROR:` line is the real one, and everything after it is
  fallout from that first failure. Paste that line, along with the command you ran and the
  output of `yosys -V`.
- If a command on these pages doesn't do what the page says, that's a bug in the course. We
  ran every command before writing it down, so a mismatch means something has drifted, and we
  want to know about it.

### Running a lab without tying up your laptop

A LibreLane run keeps your CPU fully busy for about a minute. If you'd rather not spend that, or
you want a second opinion on whether your design really is clean, the team ships a GitHub
Action, [`uoftasic/librelane-action`](https://github.com/uoftasic/librelane-action), that hardens
a design in CI and hands back the layout, a rendered image of it, and the sign-off numbers.

To use it, copy its `templates/harden.yml` into your own repo as `.github/workflows/harden.yml`
and point it at your design directory. It runs the same LibreLane 3.1.0.dev3 on the same
`config.json` that you run locally. Treat it as a convenience rather than a replacement for the
workbench, though, because the workbench is where every number in this course was measured.

Next: [Lab 01: One adder, two targets](../labs/lab-01-one-adder-two-targets-overview.md).
