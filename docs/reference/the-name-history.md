# OpenLane, OpenLane 2, LibreLane

Use this page when a tutorial you found says something different from what is on your machine.

Search for an open-source RTL-to-GDSII tutorial and the top result tells you to run this:

```bash
./flow.tcl -design spm
```

A second one tells you to run this:

```bash
openlane config.json
```

Neither works in your workbench:

```
bash: openlane: command not found
```

You did not break anything. The program those tutorials describe is on your machine; it has been
renamed twice since they were written.

## What is installed

```bash
command -v librelane openlane openlane2
```

```
/foss/tools/bin/librelane
```

Only one of the three exists. There is no `openlane` command, no `openlane2` command, and no
`flow.tcl` anywhere on the filesystem. The Python package agrees:

```bash
pip3 list | grep -i lane
```

```
librelane                      3.1.0.dev3
```

The command is `librelane`, and that is the only correct answer for this course.

## The version banner

Run the version check from [Lab 01, Part 1](../labs/lab-01-one-adder-two-targets-overview.md) and
read the whole output, not just the first line:

```bash
librelane --version
```

```
LibreLane v3.1.0.dev3

Copyright ©2025-2026 LibreLane Contributors

Adapted from OpenLane 2.0
Copyright ©2020-2025 Efabless Corporation
```

Four lines, three organisations and six years: that banner is the history on this page, printed by
the program you run.

## The lineage

**OpenLane** started in 2020 at the OpenROAD Project; the repository
`The-OpenROAD-Project/OpenLane` was created on 20 July 2020. It was a set of Tcl scripts that drove
Yosys, OpenROAD, Magic and Netgen in sequence. You configured it with a `config.tcl`, ran
`./flow.tcl -design <name>`, and got a GDSII. It worked, it taped out real chips, and it is what
almost every blog post, YouTube video and university lecture slide about "open source ASIC design"
describes. Its README now says it is in maintenance mode and not recommended for new projects;
1.0.x still gets critical bugfixes so that older tapeouts can be reproduced.

**OpenLane 2** was a rewrite, not an upgrade. Efabless Corporation started it in January 2023 and
released 2.0.0 in April 2024. It used the same underlying tools in a different shape: Python
instead of Tcl, a `config.json` instead of a `config.tcl`, and, most importantly, a library of
composable "steps" and "flows" rather than one fixed pipeline. Releases went 2.0 → 2.1 → 2.2 → 2.3
through December 2024.

Then Efabless stopped. `efabless.com` now issues a permanent redirect to `chipfoundry.io/efabless`,
which says only that "Umbralogic Technologies LLC, doing business as ChipFoundry, has acquired the
assets of Efabless Corporation."

**LibreLane** is what OpenLane 2 became when the community picked it up. The `librelane` GitHub
organisation was created on 30 March 2025, under the FOSSi Foundation, a non-profit that holds open
silicon projects so they don't depend on any one company staying in business. LibreLane and its
logo are FOSSi trademarks. The repository description reads "ASIC implementation flow
infrastructure, successor to OpenLane."

Two details make this a rename rather than a fork:

- The version numbers continued. LibreLane's first releases were 2.4.x, picking up where
  OpenLane 2.3 left off. There was never a "LibreLane 1.0".
- The old repository `github.com/efabless/openlane2` still resolves. GitHub redirects it to
  `github.com/chipfoundry/openlane2`, whose README carries a banner saying development has moved
  to `github.com/librelane/librelane`.

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

Look for one word before you read anything else.

If it says `flow.tcl`, `config.tcl`, `make mount` or `make pdk`, it is OpenLane 1. None of the
commands apply to you. The ideas still do: same stages, same PDK, same OpenROAD underneath. Read it
to learn what floorplanning is, but don't copy a line of it.

If it says `openlane` with a `config.json`, it is OpenLane 2, and about 95 % of it is correct.
Change the command name to `librelane` and it will usually run. Watch the variable names: 2.x to
3.x is a major version, and some configuration keys were renamed or removed. LibreLane does not
silently ignore a bad key; it validates your config and tells you.

If it says `librelane`, check which version it targets. You have 3.1.0.dev3, a pre-release of the
3.1 line, which is what the pinned image ships. Anything written for 3.0.x still applies: nothing
this course uses was renamed between 3.0 and 3.1.

Here is the translation for the commands you are most likely to find:

| An old tutorial says | In your workbench |
|---|---|
| `git clone …/OpenLane`, `make pdk`, `make mount` | nothing; you are already inside the tools, and the PDK is at `/foss/pdks` |
| `docker run efabless/openlane …` | nothing; you are already in a container |
| `./flow.tcl -design spm` | `librelane --run-example spm`; see below |
| `./flow.tcl ~/my_designs/picorv32` | `librelane ~/my_designs/picorv32/config.json` |
| `make test` | `librelane --smoke-test` |
| `openlane config.json` | `librelane config.json` |
| `librelane --dockerized …` | drop `--dockerized` |

Two of those rows catch people.

`--dockerized` exists on your `librelane`, and it tells LibreLane to fetch and run its own Docker
image. Inside the workbench that is a container trying to start a container. You don't need it,
and it won't work.

`--run-example` works, but only with the right cell library. With `STD_CELL_LIBRARY` still on the
image default while `PDK` is SKY130, it fails:

```bash
librelane --run-example spm
```

```
_tkinter.TclError: no files matched glob pattern "/foss/pdks/sky130A/libs.ref/sg13g2_stdcell/lef/*.lef"
```

That is the `STD_CELL_LIBRARY` trap from [Getting started](../guide/getting-started.md): the image
defaults the cell library to IHP's while the PDK is SKY130, and LibreLane's own example does not
pin it. With `export STD_CELL_LIBRARY=sky130_fd_sc_hd` set, the same command runs the full flow
and writes `spm/runs/*/final/gds/spm.gds`.

`librelane --smoke-test` needs no such help. It ran to `Smoke test passed.` in a terminal with
nothing exported at all, which makes it the fastest way to check that LibreLane itself works
before you blame it for something your design did.

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

There are two OpenROADs and two OpenSTAs. The plain ones are the image's general copies. The
`-librelane` ones are the exact builds LibreLane pins, so a flow gives the same answer on every
machine. LibreLane picks them; you never call the `-librelane` pair yourself. Don't be alarmed
when they show up in a log.

The same thing happened one layer down, to the PDK manager. Old tutorials tell you to run `volare`;
`github.com/efabless/volare` now redirects to `github.com/chipfoundry/volare`, and the
FOSSi-hosted successor is `ciel` (`fossi-foundation/ciel`, "Open-source PDK version manager",
created six days after the LibreLane organisation). `pip3 list | grep ciel` shows it installed. In
this image it has nothing to do: the PDKs are already unpacked under `/foss/pdks`, and no download
is needed.

## Unchanged parts of the flow

Everything you are learning stayed the same. The stages are the same stages, in the same order,
run by the same programs: Yosys synthesizes, OpenROAD floorplans, places and routes, Magic, Netgen
and KLayout check the result, and a GDSII comes out the far end. A 2021 OpenLane blog post
explaining what a clock tree is still applies today. Only the name you type at the prompt moved.

When a page on the internet disagrees with your terminal, trust the terminal: it is describing the
program you have.

See also: [Lab 01, Part 1](../labs/lab-01-one-adder-two-targets-overview.md) for the version check,
and [From netlist to layout](../guide/from-gates-to-geometry.md) for what LibreLane does across those
stages.
