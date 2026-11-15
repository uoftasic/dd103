# OpenLane, OpenLane 2, LibreLane

Use this page when a tutorial you found online says something different from what you see on your
machine.

If you search for an open-source RTL-to-GDSII tutorial, the top result will probably tell you to
run this:

```bash
./flow.tcl -design spm
```

A second result will tell you to run this instead:

```bash
openlane config.json
```

Neither command works in your workbench:

```
bash: openlane: command not found
```

You haven't broken anything. The program those tutorials describe is on your machine, but it has
been renamed twice since they were written, so it answers to a different name now.

## What is installed

```bash
command -v librelane openlane openlane2
```

```
/foss/tools/bin/librelane
```

Only one of the three names exists. There is no `openlane` command and no `openlane2` command, and
there is no `flow.tcl` anywhere on the filesystem. The list of installed Python packages tells you
the same thing:

```bash
pip3 list | grep -i lane
```

```
librelane                      3.1.0.dev3
```

So the command is `librelane`, and it's the only one you'll use in this course.

## The version banner

Run the version check from [Lab 01, Part 1](../labs/lab-01-one-adder-two-targets-overview.md) and
read all of its output, including the lines after the first:

```bash
librelane --version
```

```
LibreLane v3.1.0.dev3

Copyright ©2025-2026 LibreLane Contributors

Adapted from OpenLane 2.0
Copyright ©2020-2025 Efabless Corporation
```

Those four lines name three organisations and cover six years, which makes the banner a short
version of the history on this page, printed by the program you run.

## The lineage

**OpenLane** started in 2020 at the OpenROAD Project; the repository
`The-OpenROAD-Project/OpenLane` was created on 20 July 2020. It was a set of Tcl scripts that ran
Yosys, OpenROAD, Magic and Netgen one after another. You configured it with a `config.tcl`, ran
`./flow.tcl -design <name>`, and got a GDSII at the end. It worked, real chips were taped out
with it, and it's what almost every blog post, YouTube video and university lecture slide about "open
source ASIC design" describes. Its README now says that it's in maintenance mode and not
recommended for new projects, although 1.0.x still gets critical bugfixes so that older tapeouts
can be reproduced.

**OpenLane 2** was a rewrite rather than an upgrade. Efabless Corporation started it in January
2023 and released 2.0.0 in April 2024. It drove the same underlying tools but was organised
differently: it was written in Python instead of Tcl, it read a `config.json` instead of a
`config.tcl`, and, most importantly, it was built as a library of composable "steps" and "flows"
rather than as one fixed pipeline. Releases went 2.0 → 2.1 → 2.2 → 2.3 through December 2024.

Then Efabless itself stopped. `efabless.com` now issues a permanent redirect to
`chipfoundry.io/efabless`, and that page says only that "Umbralogic Technologies LLC, doing
business as ChipFoundry, has acquired the assets of Efabless Corporation."

**LibreLane** is what OpenLane 2 became when the community picked it up. The `librelane` GitHub
organisation was created on 30 March 2025 under the FOSSi Foundation, a non-profit that holds open
silicon projects so that they don't depend on any one company staying in business. LibreLane and
its logo are FOSSi trademarks, and the repository description reads "ASIC implementation flow
infrastructure, successor to OpenLane."

Two details show that this was a rename of the same project rather than a fork into a new one:

- The version numbers carried on. LibreLane's first releases were 2.4.x, picking up where
  OpenLane 2.3 left off, and there was never a "LibreLane 1.0".
- The old repository `github.com/efabless/openlane2` still resolves. GitHub redirects it to
  `github.com/chipfoundry/openlane2`, and that repository's README carries a banner saying that
  development has moved to `github.com/librelane/librelane`.

| | OpenLane | OpenLane 2 | LibreLane |
|---|---|---|---|
| first appeared | July 2020 | January 2023 | March 2025 |
| owned by | OpenROAD Project | Efabless | FOSSi Foundation |
| written in | Tcl | Python | Python |
| you configure | `config.tcl` | `config.json` | `config.json` |
| you run | `./flow.tcl -design x` | `openlane config.json` | `librelane config.json` |
| status | maintenance only | renamed | current |
| latest | 1.0.x | 2.3.1 (Dec 2024) | 3.0.11 (Aug 2026) |

Your image has LibreLane 3.1.0.dev3, released 2 April 2026.

## Reading an old tutorial

Before you read anything else in an old tutorial, look at the command and file names it uses,
because they tell you which generation of the tool it was written for.

If it says `flow.tcl`, `config.tcl`, `make mount` or `make pdk`, it's about OpenLane 1, and none of
its commands apply to you. Its ideas still do, because the stages, the PDK and the OpenROAD
underneath are all the same. Read it to learn what floorplanning is, but don't copy a line of it.

If it says `openlane` with a `config.json`, it's about OpenLane 2, and about 95 % of it is still
correct. Change the command name to `librelane` and it will usually run. Watch the variable names,
though: going from 2.x to 3.x is a major version change, and some configuration keys were renamed
or removed. LibreLane won't silently ignore a key it doesn't recognise; it validates your config
and tells you what's wrong.

If it says `librelane`, check which version it targets. You have 3.1.0.dev3, a pre-release of the
3.1 line, because that's what the pinned image ships. Anything written for 3.0.x still applies,
since nothing this course uses was renamed between 3.0 and 3.1.

Here is how to translate the commands you're most likely to find:

| An old tutorial says | In your workbench |
|---|---|
| `git clone …/OpenLane`, `make pdk`, `make mount` | nothing; you are already inside the tools, and the PDK is at `/foss/pdks` |
| `docker run efabless/openlane …` | nothing; you are already in a container |
| `./flow.tcl -design spm` | `librelane --run-example spm`; see below |
| `./flow.tcl ~/my_designs/picorv32` | `librelane ~/my_designs/picorv32/config.json` |
| `make test` | `librelane --smoke-test` |
| `openlane config.json` | `librelane config.json` |
| `librelane --dockerized …` | drop `--dockerized` |

Two of those rows catch people out, so they need a little more explanation.

Your `librelane` does accept `--dockerized`, which tells LibreLane to fetch its own Docker image
and run inside it. The workbench is already a container, so the option would have a container
trying to start another container. You don't need it, and it won't work.

`--run-example` works, but only if the right cell library is selected. If `STD_CELL_LIBRARY` is
still on the image's default while `PDK` is SKY130, it fails:

```bash
librelane --run-example spm
```

```
_tkinter.TclError: no files matched glob pattern "/foss/pdks/sky130A/libs.ref/sg13g2_stdcell/lef/*.lef"
```

This is the `STD_CELL_LIBRARY` trap described in [Getting started](../guide/getting-started.md).
The image sets the cell library to IHP's by default even when the PDK is SKY130, and LibreLane's
own example doesn't set the library itself, so it looks for IHP cells inside the SKY130 PDK. Once
you've run `export STD_CELL_LIBRARY=sky130_fd_sc_hd`, the same command runs the full flow and
writes `spm/runs/*/final/gds/spm.gds`.

`librelane --smoke-test` doesn't need that setting. When we ran it in a terminal with nothing
exported at all, it ran through to `Smoke test passed.`, so it's the fastest way to check that
LibreLane itself works before you blame it for something your design did.

## Two more names in `/foss/tools/bin`

```bash
ls /foss/tools/bin | grep -E 'lane|openroad|^sta'
```

```
librelane
openroad
openroad-librelane
sta
sta-librelane
```

The image has two copies each of OpenROAD and OpenSTA. The plain ones are the image's
general-purpose copies, and the `-librelane` ones are the exact builds that LibreLane pins, so that
a flow gives the same answer on every machine. LibreLane chooses them itself, and you never need to
call the `-librelane` pair yourself, so don't be alarmed when their names show up in a log.

The same renaming happened one layer down, to the PDK manager. Old tutorials tell you to run
`volare`, but `github.com/efabless/volare` now redirects to `github.com/chipfoundry/volare`, and
the successor hosted by FOSSi is `ciel` (`fossi-foundation/ciel`, "Open-source PDK version
manager", created six days after the LibreLane organisation). `pip3 list | grep ciel` shows that
it's installed, but in this image it has nothing to do, because the PDKs are already unpacked under
`/foss/pdks` and no download is needed.

## Unchanged parts of the flow

Everything you're learning in this course stayed the same through the renames. The flow has the
same stages, in the same order, run by the same programs: Yosys synthesizes, OpenROAD floorplans,
places and routes, Magic, Netgen and KLayout check the result, and a GDSII comes out at the end.
A 2021 OpenLane blog post explaining what a clock tree is still applies today, because the only
thing that changed is the name you type at the prompt.

When a page on the internet disagrees with your terminal, trust the terminal, because it's
describing the program you actually have.

See also: [Lab 01, Part 1](../labs/lab-01-one-adder-two-targets-overview.md) for the version check,
and [From netlist to layout](../guide/from-gates-to-geometry.md) for what LibreLane does across those
stages.
