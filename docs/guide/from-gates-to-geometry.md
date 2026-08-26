# From gates to geometry

**Question this page answers:** *I typed one command, eighty stage banners scrolled past, and a
minute later there was a `.gds`. What actually happened?*

> The full `vending.sv` ships at
> [`labs/lab-05-elevator/examples/vending.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-05-elevator/examples/vending.sv)
> so every command on this page is copy-pasteable.

Everything up to now produced **lists**. `stat` gave you a list of cells. The netlist is a list
of connections. Nothing in a list has a position, a size, or a wire.

A chip is not a list. A chip is **geometry** — rectangles of metal and doped silicon at
specific coordinates, which a mask shop will turn into glass plates. The job of turning the
one into the other is called **place and route**, and LibreLane does it for you in about a
minute.

This page runs it on the vending machine from
[A state machine is a table with a memory](guide/state-machine-is-a-table.md), opens the
stages worth opening, and — the part nobody tells you — shows how to check that the result is
worth having. A zero exit code is not a clean chip. There is a run at the bottom of this page
that exited zero, printed three green ticks, and is completely useless.

## The config, and the one line you must not omit

Put this next to a `src/` directory containing your `.sv` files:

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

Then, with no command-line flags at all:

```bash
librelane config.json
```

Only `DESIGN_NAME` and `VERILOG_FILES` are strictly required. `dir::` means "relative to this
config file". You do not have to give a `DIE_AREA` — `FP_CORE_UTIL` tells the floorplanner to
pick one.

> **`"PDK": "sky130A"` is not optional and not a default.** The workbench image ships with
> `PDK=ihp-sg13g2` in its environment, and a config that stays silent inherits it. The flow
> then runs perfectly, exits 0, and hands you a chip in the wrong technology. The last section
> of this page is that run. Pin it, every time.

Confirm your version before you compare any number on this page to your own:

```bash
librelane --version
```

```
LibreLane v3.0.2
```

> If you find a tutorial that says `openlane` instead of `librelane`, you are reading about a
> different tool from a different year. [OpenLane, OpenLane 2,
> LibreLane](reference/the-name-history.md) untangles the names.

## What one minute buys you

```
[00:36:25] INFO     Flow complete.
Classic - Stage 80 - Report Manufacturability ━━━━━━━━━━━━━━━━━━━━ 80/80 0:00:56

real	0m57.449s
LIBRELANE EXIT: 0
```

**Eighty stages, fifty-seven seconds**, on a six-core laptop with 7.5 GB of RAM, for a
seventeen-cell state machine. The hungriest stage was detailed routing, and it peaked at
**598 MiB** — every step writes its own `*.process_stats.json` if you want to check yours.
Your machine is not the limiting factor here.

Now look at what it left behind:

```bash
ls runs/*/
```

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

Seventy-seven numbered directories, not eighty — three steps were gated off by your config and
never ran at all, which `flow.log` says out loud:

```
Gating variable for step 'OpenROAD.RepairDesignPostGRT' set to 'False'- the step will be skipped.
Gating variable for step 'OpenROAD.ResizerTimingPostGRT' set to 'False'- the step will be skipped.
Gating variable for step 'Yosys.EQY' set to 'False'- the step will be skipped.
```

Every directory holds the tool's log, the config it saw, its runtime, and its output. Nothing
is hidden. **You are not expected to read seventy-seven of them.** Six carry the whole story.

> The stage numbers move between LibreLane versions — floorplan was `13` here and something
> else two releases ago. Match on the **name**, never the number.

## The six stages worth understanding

### `06-yosys-synthesis` — your code becomes a list of real cells

The same Yosys you have been running by hand, with LibreLane's own script. Open
`06-yosys-synthesis/yosys-synthesis.log` and scroll to the last `stat`:

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

Seventeen cells, the same seventeen you got by hand — but **252.74 µm² instead of 231.47**.
Look at the suffixes: every cell is a `_2`, where your hand run produced `_1`. Those are
**drive strengths**. A `_2` cell has wider transistors, so it can charge a longer wire faster,
and it costs more area. LibreLane picks the stronger family up front because it knows real
wires are coming; your bare `abc` run did not.

This is the first stage where your design stops being an idea and starts being a thing with a
price.

### `13-openroad-floorplan` — the chip gets a size and a border

```
[INFO IFP-0107] Defining die area using utilization: 35.00% and aspect ratio: 1.
[INFO IFP-0102] Core area:                          653.126 um^2
[INFO] Floorplanned on a die area of 0.0 0.0 37.91 48.63 (µm).
[INFO] Floorplanned on a core area of 5.52 10.88 32.2 35.36 (µm).
```

Your `FP_CORE_UTIL: 35` said *"let the cells occupy 35% of the core"*, so the tool solved for
a rectangle: **37.91 × 48.63 µm**, which is 1843.56 µm² of die. Inside it, a smaller **core**
where standard cells are allowed to sit, with a margin around the edge for power rails and I/O.

Your chip is now 38 micrometres wide. A human hair is 50 to 100.

### `28-openroad-globalplacement` — every cell gets an x and a y

Placement is an optimisation problem: put connected cells near each other, do not overlap, do
not cram one corner. Global placement solves it approximately and fast, allowing cells to
overlap slightly; `34-openroad-detailedplacement` then snaps everything onto the legal row
grid so no two cells share a square nanometre.

After this, "the netlist" and "the layout" refer to the same thing.

### `35-openroad-cts` — the clock gets its own tree

Every flip-flop needs `clk`, and `clk` cannot be one long wire, because the far end would tick
measurably later than the near end and your carefully written `always_ff` would sample garbage.
So the tool builds a **balanced tree of clock buffers** whose branches are deliberately made
equal length.

```
[INFO CTS-0050] Root buffer is sky130_fd_sc_hd__clkbuf_16.
[INFO CTS-0010]  Clock net "clk" has 6 sinks.
```

**Six sinks.** Those are the six flip-flops of your one-hot state register, and this is the
first moment in the whole flow where the physics of a clock exists. Everything before this
pretended `clk` arrives everywhere at once.

### `45-openroad-detailedrouting` — actual metal

Global routing decided roughly which corridors each net takes. Detailed routing commits to
exact wires on exact metal layers, and it is the only stage that will fight you:

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

Read that sequence: 7, 4, **9**, 2, 1, 1, 0. It got *worse* at iteration 2. The router rips up
wires it already placed to make room for ones it cannot otherwise finish, and that is normal —
what matters is that the last number is **0**. If your run ends here with a non-zero count, the
design is not routable at the density you asked for, and the fix is usually to lower
`PL_TARGET_DENSITY_PCT` and let it spread out.

The result, all 526 µm of it:

```
Total wire length = 526 um.
Total wire length on LAYER li1 = 0 um.
Total wire length on LAYER met1 = 206 um.
Total wire length on LAYER met2 = 274 um.
Total wire length on LAYER met3 = 45 um.
```

Half a millimetre of metal in a chip 38 µm across. Also notice this used **three** routing
layers. The flow was allowed up to `met5` — check `resolved.json` for `RT_MAX_LAYER` — and your
vending machine never needed `met4` or `met5`. Congestion is what forces a design upward.

### `58-magic-streamout` — the list becomes polygons

```
> gds read /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
   Copying output for cell sky130_fd_sc_hd__dfstp_2 from $PDKPATH/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
   Copying output for cell sky130_fd_sc_hd__fill_1 from $PDKPATH/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
```

That is the whole trick, and it is less magical than you expected. The foundry already drew
every standard cell as polygons and shipped them in one big GDS. Streamout **copies** the
polygons for each cell you used to the coordinates placement chose, then adds the routing
wires on top. `59-klayout-streamout` does the same job with a second, independent tool, so the
two can be compared — which is exactly what `63-klayout-xor` does.

## Twenty-four cells you did not write

Yosys handed the flow 17 cells. Count what is actually on the die:

```bash
python3 -c "
import json, glob
m = json.load(open(glob.glob('runs/*/final/metrics.json')[0]))
for k, v in sorted(m.items()):
    if 'count__class' in k: print(k.split(':')[-1], v)"
```

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
| `tap_cell` | 5 | well taps — they tie the substrate to power so the chip does not latch up |
| `antenna_cell` | 4 | protection diodes, see below |
| `fill_cell` | 57 | inert filler making the rows continuous |
| **total instances** | **98** | |

Your 17 cells are the first two rows. The physical flow added **24 more real cells** to make
them manufacturable, and then 57 fill cells because a standard-cell row with gaps in it is not
a legal shape.

**41 of 98 instances are cells the design asked for.** (Forty-six of the fillers are
`decap_3` — decoupling capacitors, which do earn their space by holding local charge for the
gates around them. The rest are literally inert.)

Follow the area outward and you can see where a chip's size actually goes:

| Metric | µm² | What it covers |
|---|---|---|
| your 17 cells | **252.74** | `sequential_cell` 157.65 + `multi_input_combinational_cell` 95.09 — and it is exactly the number `06-yosys-synthesis` printed |
| `design__instance__area__stdcell` | **461.69** | those, plus every buffer, tap and diode the flow added |
| `design__core__area` | **653.13** | the region cells are allowed to sit in. `design__instance__utilization` says 70.7% of it is real cells; filler occupies every square nanometre of the rest, which is why `design__instance__area` comes out at 653.13 too |
| `design__die__area` | **1843.56** | the whole chip, including the margin around the core |

**The logic you actually wrote is 13.7% of the silicon you pay for.** That is not waste and it
is not unusual — it is what it costs to make seventeen gates into something a factory can
print.

## What `final/` is

```bash
ls runs/*/final/
```

```
def		   lib		      nl		 sdf
gds		   mag		      odb		 spef
json_h		   mag_gds	      pnl		 spice
klayout_gds	   metrics.csv	      render		 vh
lef		   metrics.json	      sdc
```

This directory is the deliverable. It is the first time you are looking at what a **tapeout
handoff** actually consists of, and the answer is: the same design written down about a dozen
different ways, because a dozen different people need a different view of it.

| View | File | Who needs it |
|---|---|---|
| `gds/` | `vending.gds`, 172,136 bytes | **the foundry.** Polygons. This is the chip. |
| `nl/` | `vending.nl.v` | the gate-level netlist — cells and connections, no geometry. Simulate this to prove the flow did not change your logic. |
| `pnl/` | powered netlist | the same, but with `VPWR`/`VGND` on every cell — what LVS compares against |
| `def/` | `vending.def` | placement and routing as text. Every cell's x/y, every wire's path. |
| `lef/` | abstract | your design as a **black box** for whoever instantiates it inside a bigger chip: outline, pin locations, blockages |
| `lib/` | timing model | your design characterised like a standard cell, so a larger design can time through it |
| `sdc/` | constraints | the clock definition the timing tools used |
| `sdf/`, `spef/` | delays, parasitics | the extracted resistance and capacitance of your actual wires, for accurate post-layout simulation |
| `spice/` | transistor netlist | extracted from the layout; the input to LVS |
| `mag/`, `odb/`, `json_h/` | tool databases | Magic, OpenROAD, and LibreLane's own formats |
| `render/` | `vending.png` | a KLayout picture of your chip, produced free by stage 60 |
| `metrics.json`, `metrics.csv` | the report card | every number this page quotes |

Open `render/vending.png`. That is your state machine.

## A zero exit code is not a clean chip

Here is the part that separates a run from a result.

`librelane` returning 0 means *no stage crashed*. It does not mean the layout is
manufacturable, and it does not mean the layout matches your netlist. Three separate checks
answer those questions, and the flow prints them as its last act:

```
───────────────── Report Manufacturability (DRC, LVS, Antenna) ─────────────────
* Antenna
Passed ✅

* LVS
Passed ✅

* DRC
Passed ✅
```

Same text, saved to disk, at `runs/*/77-misc-reportmanufacturability/manufacturability.rpt`.
Learn what the three mean, because when one of them says `Failed` the word tells you nothing
about what to do.

**DRC — Design Rule Check.** *Are these shapes physically printable?* The foundry publishes
hundreds of rules: minimum metal width, minimum spacing, minimum enclosure of a via. Magic and
KLayout each check independently:

```bash
cat runs/*/65-magic-drc/reports/drc.magic.rpt
```

```
vending
----------------------------------------
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4
```

`COUNT: 0` is what you want. (The second line is Magic being pedantic — it counts rule
violations as groups of coordinate pairs, so a raw non-zero count overstates the number of
actual errors. At zero it does not matter.)

**LVS — Layout Versus Schematic.** *Is the thing you drew the thing you designed?* Netgen
extracts a transistor netlist from the layout, extracts another from your gate-level netlist,
and compares them node by node:

```bash
tail -5 runs/*/71-netgen-lvs/reports/lvs.netgen.rpt
```

```
Cell pin lists are equivalent.
Device classes vending and vending are equivalent.

Final result: Circuits match uniquely.
.
```

**`Circuits match uniquely`** is the sentence you are looking for. A DRC-clean chip that fails
LVS is a perfectly manufacturable piece of silicon that does the wrong thing.

**Antenna.** *Will this survive being built?* During manufacturing, a long stretch of metal
that is connected to a transistor gate but not yet to anything else acts as an antenna,
collecting charge from the plasma etch and punching through the gate oxide. The fix is a
protection diode — those four `antenna_cell` instances in the table above — and
`RUN_ANTENNA_REPAIR` is what put them there.

```bash
cat runs/*/47-openroad-checkantennas-1/reports/antenna_summary.rpt
```

```
┏━━━━━━━┳━━━━━━━━━┳━━━━━━━━━━┳━━━━━┳━━━━━┳━━━━━━━┓
┃ P / R ┃ Partial ┃ Required ┃ Net ┃ Pin ┃ Layer ┃
┡━━━━━━━╇━━━━━━━━━╇━━━━━━━━━━╇━━━━━╇━━━━━╇━━━━━━━┩
└───────┴─────────┴──────────┴─────┴─────┴───────┘
```

An empty table is a pass. Every row would be one net whose *partial* antenna ratio exceeds
what the PDK *requires*.

### Or read all of it at once

`final/metrics.json` has every number without any greping:

| Metric | Value | Read it as |
|---|---|---|
| `design__die__area` | 1843.56 | µm² of silicon you are paying for |
| `design__instance__count` | 98 | everything on the die |
| `design__instance__utilization` | 0.706897 | 70.7% of the core is cells |
| `timing__setup__ws` | **+12.95** | ns of slack at the slowest corner. Positive is passing. |
| `timing__hold__ws` | **+0.117** | ns. Positive is passing. |
| `magic__drc_error__count` | 0 | |
| `klayout__drc_error__count` | 0 | a second opinion from a different tool |
| `design__lvs_error__count` | 0 | |
| `antenna__violating__nets` | 0 | |
| `design__xor_difference__count` | 0 | Magic's GDS and KLayout's GDS are identical |

**Those last five zeros are the definition of a clean chip.** Write them down. When you change
your RTL and re-run, they are the first thing to check, before you look at area.

> `timing__setup__ws = +12.95 ns` against a `CLOCK_PERIOD` of 20 means your longest path takes
> about 7 ns and you asked for 20. You could have asked for 8. [The carry has to
> walk](guide/the-carry-has-to-walk.md) is where that number came from.

## The run that passed everything and is worthless

Here is the same design with a bare config — no `PDK`, no `STD_CELL_LIBRARY`, none of the
tuning. Everything else is identical:

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

Eighty stages. Zero errors. Three green ticks. A `final/gds/vending.gds` on disk.

And it is the wrong chip. Scroll up in that log:

```
Generating RTLIL representation for module `\sg13g2_a21oi_1'.
...
> gds read /foss/pdks/ihp-sg13g2/libs.ref/sg13g2_io/gds/sg13g2_io.gds
Reading "sg13g2_IOPadIOVdd".
```

`sg13g2` is **IHP SG13G2**, a 130 nm BiCMOS process from a German foundry. It is a perfectly
good PDK. It is not the one this course, your cell library, or any number you have measured so
far is based on. The die came out 2420.4 µm² instead of 1843.56 — different technology,
different cells, different everything — and **nothing in the flow said a word about it**,
because from the tool's point of view you asked for it.

You asked for it in your shell environment. Look:

```bash
echo "PDK=$PDK  STD_CELL_LIBRARY=$STD_CELL_LIBRARY"
```

```
PDK=ihp-sg13g2  STD_CELL_LIBRARY=sg13g2_stdcell
```

A `config.json` with no `PDK` key does not *default* to something sensible; it **inherits**.
And because `PDK` in `config.json` outranks the environment — and outranks a `--pdk` flag —
writing that one line is the fix, permanently, regardless of how anyone's shell is set up.

### The check, and do it every run

```bash
grep '"PDK"' runs/*/resolved.json
```

```
    "PDK": "sky130A",
```

`resolved.json` is every configuration variable after LibreLane has merged your file, the
environment, and its own defaults — the values the run *actually used*. One line, one second,
and it is the difference between a chip and a curiosity.

A second check that costs nothing: your final netlist should be full of `sky130_fd_sc_hd__`.

```bash
grep -c sky130_fd_sc_hd runs/*/final/nl/vending.nl.v
```

```
98
```

One line per instance on the die — the same 98 the metrics counted. If that number comes back
`0`, you hardened somebody else's technology.

> **This is the shape of most real chip-design failures.** Not a crash — a run that succeeds at
> the wrong thing. Every check on this page exists because somebody once shipped the thing it
> catches.

## Where to go from here

You have now seen the whole path: RTL → gates → area → placement → metal → polygons → three
green ticks. Everything in DD103 has been building to one run of one command.

Next: [Lab 05 — Elevator to GDSII](labs/lab-05-elevator-overview.md). You design a four-floor elevator
controller with the recipe from the previous page, harden it with the config from this one, and
finish the course holding a `.gds` file, a `metrics.json` full of zeros, and a picture of a
chip you designed.

Record your five numbers — die area, instance count, setup slack, DRC count, LVS count — and
compare them with somebody else's elevator. Nobody's will match, and the reasons why are the
rest of your degree.
