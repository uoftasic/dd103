# From netlist to layout

This page explains what LibreLane does when it turns a netlist into a `.gds`, and how to check
that the result is worth having. It follows one run on the vending machine from
[Writing a state machine](../guide/state-machine-is-a-table.md). You'll run the same flow on your
elevator, and make the same checks, in
[Lab 05, Parts 7 to 9](../labs/lab-05-elevator-overview.md#part-7-rtl-to-gdsii).

Everything you've produced so far has been a list: `stat` gave you a list of cells, and the
netlist is a list of connections. Nothing in a list has a position, a size or a wire, but a chip
is geometry. It's rectangles of metal and doped silicon at specific coordinates, which a mask shop
turns into glass plates. Turning the list into geometry is called **place and route**, and
LibreLane does it in about a minute.

Keep in mind that a zero exit code doesn't mean you have a clean chip. The last section of this
page shows a run that exited with zero and printed three green ticks, and still produced a useless
chip.

## The config

The run used this `config.json`, next to a `src/` directory holding the `.sv` files:

```json
{
    "DESIGN_NAME": "vending",
    "VERILOG_FILES": ["dir::src/*.sv"],
    "PDK": "sky130A",
    "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
    "CLOCK_PORT": "clk",
    "CLOCK_PERIOD": 20.0,
    "FP_CORE_UTIL": 35,
    "PL_TARGET_DENSITY_PCT": 45,
    "RUN_HEURISTIC_DIODE_INSERTION": true,
    "RUN_ANTENNA_REPAIR": true
}
```

and was started with `librelane config.json`, with no command-line flags.

Only `DESIGN_NAME` and `VERILOG_FILES` are strictly required. The `dir::` prefix means "relative
to this config file". You don't have to give a `DIE_AREA` either, because `FP_CORE_UTIL` tells
the floorplanner to pick one for you.

> **`"PDK": "sky130A"` is not optional.** The workbench image ships with `PDK=ihp-sg13g2` in its
> environment, and a config that doesn't set `PDK` inherits that value. The flow then runs, exits
> 0 and hands you a chip in the wrong technology; the last section of this page is that run. Set
> `PDK` in every config.

Check your LibreLane version (Lab 01, Part 1) before you compare any number on this page with
your own, because the course is pinned to LibreLane 3.1.0.dev3. If you find a tutorial that says
`openlane` instead of `librelane`, it's about a different tool from a different year;
[OpenLane, OpenLane 2, LibreLane](../reference/the-name-history.md) explains the names.

## The run directory

```
[00:36:25] INFO     Flow complete.
Classic - Stage 80 - Report Manufacturability ━━━━━━━━━━━━━━━━━━━━ 80/80 0:00:56

real	0m57.449s
LIBRELANE EXIT: 0
```

That run went through eighty stages in fifty-seven seconds, on a six-core laptop with 7.5 GB of
RAM, for a seventeen-cell state machine. The stage that needed the most memory was detailed
routing, which peaked at 598 MiB, and every step writes its own `*.process_stats.json` if you want
to check yours. So your machine won't be what limits you here.

The run directory, `runs/<tag>/`, contains:

```
01-verilator-lint			     43-openroad-repairantennas
02-checker-linttimingconstructs		     44-openroad-stamidpnr-3
03-checker-linterrors			     45-openroad-detailedrouting
04-checker-lintwarnings			     46-odb-removeroutingobstructions
05-yosys-jsonheader			     47-openroad-checkantennas-1
06-yosys-synthesis			     48-checker-trdrc
07-checker-yosysunmappedcells		     49-odb-reportdisconnectedpins
08-checker-yosyssynthchecks		     50-checker-disconnectedpins
09-checker-netlistassignstatements	     51-odb-reportwirelength
10-openroad-checksdcfiles		     52-checker-wirelength
11-openroad-checkmacroinstances		     53-openroad-fillinsertion
12-openroad-staprepnr			     54-odb-cellfrequencytables
13-openroad-floorplan			     55-openroad-rcx
14-openroad-dumprcvalues		     56-openroad-stapostpnr
15-odb-checkmacroantennaproperties	     57-openroad-irdropreport
16-odb-setpowerconnections		     58-magic-streamout
17-odb-manualmacroplacement		     59-klayout-streamout
18-openroad-cutrows			     60-klayout-render
19-openroad-tapendcapinsertion		     61-magic-writelef
20-odb-addpdnobstructions		     62-odb-checkdesignantennaproperties
21-openroad-generatepdn			     63-klayout-xor
22-odb-removepdnobstructions		     64-checker-xor
23-odb-addroutingobstructions		     65-magic-drc
24-openroad-globalplacementskipio	     66-klayout-drc
25-openroad-ioplacement			     67-checker-magicdrc
26-odb-customioplacement		     68-checker-klayoutdrc
27-odb-applydeftemplate			     69-magic-spiceextraction
28-openroad-globalplacement		     70-checker-illegaloverlap
29-odb-writeverilogheader		     71-netgen-lvs
30-checker-powergridviolations		     72-checker-lvs
31-openroad-stamidpnr			     73-checker-setupviolations
32-openroad-repairdesignpostgpl		     74-checker-holdviolations
33-odb-manualglobalplacement		     75-checker-maxslewviolations
34-openroad-detailedplacement		     76-checker-maxcapviolations
35-openroad-cts				     77-misc-reportmanufacturability
36-openroad-stamidpnr-1			     error.log
37-openroad-resizertimingpostcts	     final
38-openroad-stamidpnr-2			     flow.log
39-openroad-globalrouting		     resolved.json
40-openroad-checkantennas		     tmp
41-odb-diodesonports			     warning.log
42-odb-heuristicdiodeinsertion
```

There are seventy-seven numbered directories rather than eighty, because three steps were switched
off by the config and never ran, as `flow.log` reports:

```
Gating variable for step 'OpenROAD.RepairDesignPostGRT' set to 'False'- the step will be skipped.
Gating variable for step 'OpenROAD.ResizerTimingPostGRT' set to 'False'- the step will be skipped.
Gating variable for step 'Yosys.EQY' set to 'False'- the step will be skipped.
```

Each directory holds the tool's log, the config the tool saw, its runtime and its output, so you
can see everything every step did. You don't need to read all seventy-seven, though; the six in
the next section are enough to follow the whole run.

> Stage numbers change between LibreLane versions: floorplan was `13` in this run, and had a
> different number two releases ago. So match directories by their name, never by their number.

## Six stages

### `06-yosys-synthesis`: synthesis

This is the same Yosys you have been running by hand, driven by LibreLane's own script. The last `stat`
in `06-yosys-synthesis/yosys-synthesis.log` is:

```
=== vending ===

       17  252.742 cells
        1    8.758   sky130_fd_sc_hd__a21o_2
        2   22.522   sky130_fd_sc_hd__a221o_2
        2   20.019   sky130_fd_sc_hd__a22o_2
        3   22.522   sky130_fd_sc_hd__and2_2
        1    8.758   sky130_fd_sc_hd__and2b_2
        5  131.376   sky130_fd_sc_hd__dfrtp_2
        1   26.275   sky130_fd_sc_hd__dfstp_2
        1    6.256   sky130_fd_sc_hd__nor2_2
        1    6.256   sky130_fd_sc_hd__or2_2
```

These are the same seventeen cells you got by hand, but they take 252.74 µm² instead of 231.47,
because every cell is a `_2` where your hand run produced a `_1`. Those suffixes are drive
strengths. A `_2` cell has wider transistors, so it can charge a longer wire faster, and it costs
more area. LibreLane picks the stronger family from the start because it knows real wires are
coming, which your bare `abc` run didn't allow for.

### `13-openroad-floorplan`: floorplan

```
[INFO IFP-0107] Defining die area using utilization: 35.00% and aspect ratio: 1.
[INFO IFP-0102] Core area:                          653.126 um^2
[INFO] Floorplanned on a die area of 0.0 0.0 37.91 48.63 (µm).
[INFO] Floorplanned on a core area of 5.52 10.88 32.2 35.36 (µm).
```

`FP_CORE_UTIL: 35` said "let the cells occupy 35 % of the core", so the tool worked out a
rectangle that allows that: 37.91 × 48.63 µm, or 1843.56 µm² of die. Inside the die is a smaller
core where standard cells may sit, with a margin around it for power rails and I/O. The chip is
now 38 micrometres wide, which is narrower than a human hair (50 to 100 µm).

### `28-openroad-globalplacement`: placement

Placement is an optimization problem: the tool has to put connected cells near each other without
overlapping them and without cramming them into one corner. Global placement solves it quickly and
approximately, and allows cells to overlap slightly. `34-openroad-detailedplacement` then snaps
every cell onto the legal row grid, so that no two cells share space. After this, the netlist and
the layout describe the same thing.

### `35-openroad-cts`: clock tree

Every flip-flop needs `clk`, and `clk` can't simply be one long wire, because the far end would
tick measurably later than the near end and your `always_ff` would sample garbage. Instead the
tool builds a balanced tree of clock buffers, whose branches are deliberately made equal.

```
[INFO CTS-0050] Root buffer is sky130_fd_sc_hd__clkbuf_16.
[INFO CTS-0010]  Clock net "clk" has 6 sinks.
```

The six sinks are the six flip-flops of the one-hot state register. This is the first point in
the flow where the clock has any physics at all; every step before it assumed that `clk` arrives
everywhere at the same instant.

### `45-openroad-detailedrouting`: detailed routing

Global routing, in `39-openroad-globalrouting`, decided roughly which corridors each net takes.
Detailed routing commits each net to exact wires on exact metal layers, and it's the stage most
likely to struggle:

```
[INFO DRT-0195] Start 0th optimization iteration.
[INFO DRT-0199]   Number of violations = 7.
[INFO DRT-0195] Start 1st optimization iteration.
[INFO DRT-0199]   Number of violations = 4.
[INFO DRT-0195] Start 2nd optimization iteration.
[INFO DRT-0199]   Number of violations = 9.
[INFO DRT-0195] Start 3rd guides tiles iteration.
[INFO DRT-0199]   Number of violations = 2.
[INFO DRT-0195] Start 4th guides tiles iteration.
[INFO DRT-0199]   Number of violations = 1.
[INFO DRT-0195] Start 5th guides tiles iteration.
[INFO DRT-0199]   Number of violations = 1.
[INFO DRT-0195] Start 6th stubborn tiles iteration.
[INFO DRT-0199]   Number of violations = 0.
```

The violation count goes 7, 4, 9, 2, 1, 1, 0, so it got worse at iteration 2. That's normal: the
router rips up wires it has already placed to make room for ones it can't otherwise finish. The
number to look at is the last one, which should be 0. If a run ends with a non-zero count here,
the design can't be routed at the density you asked for, and the usual fix is to lower
`PL_TARGET_DENSITY_PCT` so that the cells spread out.

The result is 526 µm of wire:

```
Total wire length = 526 um.
Total wire length on LAYER li1 = 0 um.
Total wire length on LAYER met1 = 206 um.
Total wire length on LAYER met2 = 274 um.
Total wire length on LAYER met3 = 45 um.
```

That's half a millimetre of metal in a chip 38 µm across, spread over three routing layers. The
flow was allowed to go up to `met5` (see `RT_MAX_LAYER` in `resolved.json`), but the vending
machine never needed `met4` or `met5`. It's congestion that forces a design onto the higher
layers, and this one wasn't congested enough to need them.

### `58-magic-streamout`: streamout

```
> gds read /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
   Copying output for cell sky130_fd_sc_hd__dfstp_2 from $PDKPATH/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
   Copying output for cell sky130_fd_sc_hd__fill_1 from $PDKPATH/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
```

The foundry has already drawn every standard cell as polygons and ships them all in one big GDS
file. Streamout copies the polygons of each cell you used to the coordinates placement chose, then
adds the routing wires on top. `59-klayout-streamout` does the same job with a second, independent
tool, so that `63-klayout-xor` can compare the two results.

## Cells added by the flow

Yosys handed the flow 17 cells, but the `count__class` entries in `final/metrics.json` show that
a good deal more than that ended up on the die:

```
antenna_cell 4
clock_buffer 4
fill_cell 57
multi_input_combinational_cell 11
sequential_cell 6
tap_cell 5
timing_repair_buffer 11
```

| Class | Count | What it is |
|---|---|---|
| `sequential_cell` | 6 | your flip-flops |
| `multi_input_combinational_cell` | 11 | your logic |
| `timing_repair_buffer` | 11 | buffers and delay cells the resizer added once the wires were real |
| `clock_buffer` | 4 | the clock tree from stage 35 |
| `tap_cell` | 5 | well taps, which tie the substrate to power so the chip does not latch up |
| `antenna_cell` | 4 | protection diodes, see below |
| `fill_cell` | 57 | inert filler that makes the rows continuous |
| total instances | 98 | |

Your 17 cells are the first two rows of the table. To make them manufacturable, the physical flow
added 24 more real cells, and then 57 fill cells, because a standard-cell row with gaps in it isn't
a legal shape. So 41 of the 98 instances are real cells, and only 17 of those are the ones your
design asked for. (Forty-six of the fillers are `decap_3` decoupling capacitors, which do earn
their space by holding local charge for the gates around them. The rest are inert.)

Following the area outward, from your cells to the edge of the die, shows where a chip's size
goes:

| Metric | µm² | What it covers |
|---|---|---|
| your 17 cells | 252.74 | `sequential_cell` 157.65 + `multi_input_combinational_cell` 95.09, exactly the number `06-yosys-synthesis` printed |
| `design__instance__area__stdcell` | 461.69 | those, plus every buffer, tap and diode the flow added |
| `design__core__area` | 653.13 | the region where cells may sit. `design__instance__utilization` says 70.7 % of it is real cells, and filler occupies the rest, which is why `design__instance__area` also comes out at 653.13 |
| `design__die__area` | 1843.56 | the whole chip, including the margin around the core |

The logic you wrote takes up 13.7 % of the silicon you pay for. That's normal, and the rest is
what it costs to turn seventeen gates into something a factory can print.

## The `final/` directory

```
def		   lib		      nl		 sdf
gds		   mag		      odb		 spef
json_h		   mag_gds	      pnl		 spice
klayout_gds	   metrics.csv	      render		 vh
lef		   metrics.json	      sdc
```

This directory is the deliverable, and it's what a tapeout handoff consists of: the same design
written down in about a dozen ways, because about a dozen different people each need their own
view of it.

| View | File | Who needs it |
|---|---|---|
| `gds/` | `vending.gds`, 172,136 bytes | the foundry. It's the polygons, which makes it the chip itself. |
| `nl/` | `vending.nl.v` | the gate-level netlist: cells and connections, with no geometry. Simulate this to show that the flow didn't change your logic. |
| `pnl/` | powered netlist | the same netlist with `VPWR`/`VGND` on every cell, which is what LVS compares against |
| `def/` | `vending.def` | placement and routing as text: every cell's x/y, every wire's path |
| `lef/` | abstract | your design as a black box for whoever instantiates it inside a bigger chip: outline, pin locations, blockages |
| `lib/` | timing model | your design characterised like a standard cell, so a larger design can time through it |
| `sdc/` | constraints | the clock definition the timing tools used |
| `sdf/`, `spef/` | delays, parasitics | the extracted resistance and capacitance of your actual wires, for accurate post-layout simulation |
| `spice/` | transistor netlist | extracted from the layout; the input to LVS |
| `mag/`, `odb/`, `json_h/` | tool databases | Magic, OpenROAD and LibreLane's own formats |
| `render/` | `vending.png` | a KLayout picture of your chip, produced by stage 60 |
| `metrics.json`, `metrics.csv` | the report card | every number this page quotes |

## Sign-off checks

When `librelane` returns 0, that means no stage crashed. It doesn't mean the layout is
manufacturable, or that it matches your netlist. Three separate checks answer those questions, and
the flow prints their results last:

```
───────────────── Report Manufacturability (DRC, LVS, Antenna) ─────────────────
* Antenna
Passed ✅

* LVS
Passed ✅

* DRC
Passed ✅
```

The same text is saved at `runs/*/77-misc-reportmanufacturability/manufacturability.rpt`. Learn
what the three mean, because when one says `Failed`, the word alone doesn't tell you what to do.

**DRC (Design Rule Check)** asks whether the shapes are physically printable. The foundry
publishes hundreds of rules: minimum metal width, minimum spacing, minimum enclosure of a via.
Magic and KLayout each check them independently. Magic's report,
`65-magic-drc/reports/drc.magic.rpt`, says:

```
vending
----------------------------------------
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4
```

`COUNT: 0` is what you want. The second line is Magic being pedantic. It counts violations as
groups of coordinate pairs, so a raw non-zero count overstates the number of real errors, but when
the count is zero the division doesn't matter.

**LVS (Layout Versus Schematic)** asks whether what you drew is what you designed. Netgen extracts
a transistor netlist from the layout, takes another from your gate-level netlist, and compares
them node by node. The end of `71-netgen-lvs/reports/lvs.netgen.rpt`:

```
Cell pin lists are equivalent.
Device classes vending and vending are equivalent.

Final result: Circuits match uniquely.
.
```

`Circuits match uniquely` is the sentence you're looking for. A chip that is DRC-clean but fails
LVS can be manufactured without trouble, and the silicon will do the wrong thing.

**Antenna** asks whether the chip will survive being built. During manufacturing, a long stretch
of metal connected to a transistor gate but not yet to anything else acts as an antenna: it
collects charge from the plasma etch and can punch through the gate oxide. The fix is a protection
diode, which is what the four `antenna_cell` instances above are, and `RUN_ANTENNA_REPAIR` is what
put them there. The report, `47-openroad-checkantennas-1/reports/antenna_summary.rpt`:

```
┏━━━━━━━┳━━━━━━━━━┳━━━━━━━━━━┳━━━━━┳━━━━━┳━━━━━━━┓
┃ P / R ┃ Partial ┃ Required ┃ Net ┃ Pin ┃ Layer ┃
┡━━━━━━━╇━━━━━━━━━╇━━━━━━━━━━╇━━━━━╇━━━━━╇━━━━━━━┩
└───────┴─────────┴──────────┴─────┴─────┴───────┘
```

An empty table is a pass. If there were violations, each row would be one net whose partial
antenna ratio exceeds what the PDK requires.

### The same checks in `metrics.json`

`final/metrics.json` collects every one of these numbers, so you don't have to search the reports
for them:

| Metric | Value | Read it as |
|---|---|---|
| `design__die__area` | 1843.56 | µm² of silicon you pay for |
| `design__instance__count` | 98 | everything on the die |
| `design__instance__utilization` | 0.706897 | 70.7 % of the core is cells |
| `timing__setup__ws` | +12.95 | ns of slack at the slowest corner; positive means it passes |
| `timing__hold__ws` | +0.117 | ns of hold slack; positive means it passes |
| `magic__drc_error__count` | 0 | |
| `klayout__drc_error__count` | 0 | a second opinion from a different tool |
| `design__lvs_error__count` | 0 | |
| `antenna__violating__nets` | 0 | |
| `design__xor_difference__count` | 0 | Magic's GDS and KLayout's GDS are identical |

Those last five zeros are what makes a chip clean, so when you change your RTL and re-run, check
them first, before you look at area.

> `timing__setup__ws = +12.95 ns` against a `CLOCK_PERIOD` of 20 means the longest path takes
> about 7 ns when you allowed 20, so you could have asked for a period of 8.
> [Carry delay and static timing](../guide/the-carry-has-to-walk.md) explains where that number
> comes from.

## The wrong-PDK run

Here is the same design run with a bare config: no `PDK`, no `STD_CELL_LIBRARY` and none of the
tuning. Everything else is identical.

```json
{
    "DESIGN_NAME": "vending",
    "VERILOG_FILES": ["dir::src/*.sv"],
    "CLOCK_PORT": "clk",
    "CLOCK_PERIOD": 20.0
}
```

```
* Antenna
Passed ✅

* LVS
Passed ✅

* DRC
Passed ✅

LIBRELANE EXIT: 0
```

This run went through all eighty stages with zero errors, printed three green ticks and left a
`final/gds/vending.gds` on disk, but that GDS is the wrong chip. You can see why further up the
log:

```
Generating RTLIL representation for module `\sg13g2_a21oi_1'.
...
> gds read /foss/pdks/ihp-sg13g2/libs.ref/sg13g2_io/gds/sg13g2_io.gds
Reading "sg13g2_IOPadIOVdd".
```

`sg13g2` is IHP SG13G2, a 130 nm BiCMOS process from a German foundry. It's a perfectly good PDK,
but it isn't the one this course, your cell library or any number you've measured is based on.
The die came out at 2420.4 µm² instead of 1843.56, because the technology, the cells and
everything else were different. Nothing in the flow mentioned the switch, because as far as the
tool could tell, you asked for it.

You did ask for it, through your shell environment. In a shell where `.designinit` hasn't run,
the environment holds:

```
PDK=ihp-sg13g2  STD_CELL_LIBRARY=sg13g2_stdcell
```

A `config.json` with no `PDK` key doesn't fall back to a sensible default; it takes whatever the
environment says. `PDK` in `config.json` outranks both the environment and a `--pdk` flag, so
writing that one line fixes the problem permanently, however anyone's shell is set up.

### Checks for every run

`resolved.json` holds every configuration variable after LibreLane has merged your file, the
environment and its own defaults, so it shows the values the run actually used. Its `PDK` line
should read:

```
    "PDK": "sky130A",
```

Checking it takes a moment, and there's another check that's just as cheap: your final netlist should be full of
`sky130_fd_sc_hd__` cell names. Counting the matching lines in `final/nl/vending.nl.v` gives 98,
one per instance on the die, which is the same 98 the metrics counted. If the count is `0`, you
hardened your design in somebody else's technology.

> Most real chip-design failures look like this one: a run that succeeds at the wrong thing,
> rather than a crash. Every check on this page exists because somebody once shipped the mistake
> it catches.

Next: [Lab 05: Elevator to GDSII](../labs/lab-05-elevator-overview.md). In it you design a four-floor
elevator controller with the recipe from the previous page, harden it with a config like the one on
this page, and finish with a `.gds` file, a `metrics.json` full of zeros, and a picture of a chip
you designed. Record your five numbers (die area, instance count, setup slack, DRC count, LVS
count) and compare them with someone else's elevator; the two sets will not match.
