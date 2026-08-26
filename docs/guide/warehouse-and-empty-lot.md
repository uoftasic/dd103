# The warehouse and the empty lot

**Question this page answers:** *Why does the same SystemVerilog become different hardware
depending on where I send it?*

You have written exactly one `ripple4.sv`. In [Lab 01](labs/lab-01-one-adder-two-targets.md)
you sent that one file to two synthesizers and got two answers that do not resemble each
other. Neither tool was wrong. They were solving different problems.

## Two ways to get a building

Suppose you need a warehouse.

**Option one:** rent a building that already exists. It has a fixed footprint, fixed ceiling
height, and a grid of shelving already bolted to the floor. You cannot move a wall. What you
*can* do is decide what goes on each shelf, and re-decide next week. You are in business
tomorrow.

**Option two:** buy an empty lot and pour a foundation. Every wall goes exactly where you want
it. Nothing is wasted on shelving you never use. It is cheaper per square metre once you build
a hundred of them — and it takes months, and once the concrete sets, that is the building you
have, forever.

An **FPGA** is the rented warehouse. An **ASIC** is the empty lot.

## The same adder, both ways

Here is your adder in the warehouse:

```bash
yosys -p "read_verilog -sv ripple4.sv fulladder.sv; synth_ice40 -top ripple4; stat"
```

```
=== ripple4 ===
   12 cells
    4   $scopeinfo
    8   SB_LUT4
```

(The four `$scopeinfo` are bookkeeping, not hardware —
[Lab 01](labs/lab-01-one-adder-two-targets.md) explains them. Eight `SB_LUT4` is the answer.)

And the same file on the empty lot:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "read_verilog -sv ripple4.sv fulladder.sv; synth -top ripple4; flatten;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

```
=== ripple4 ===
    4   40.038   sky130_fd_sc_hd__maj3_1
    8   70.067   sky130_fd_sc_hd__xnor2_1
   Chip area for module '\ripple4': 110.105600
```

Same source file. Eight `SB_LUT4` on one side; twelve named SKY130 cells and a number in
square micrometres on the other.

## The difference is what a "cell" is allowed to be

**`SB_LUT4` is a lookup table.** It is four inputs, sixteen bits of memory, and a multiplexer.
Load those sixteen bits with one pattern and it is an XOR; load a different pattern and it is
a carry function; load a third and it is something nobody has a name for. The silicon is
already there, sitting on the FPGA, whether you use it or not. Synthesis for an FPGA is
mostly the question **"which of the shelves do I fill, and with what?"**

**`sky130_fd_sc_hd__maj3_1` is a majority gate.** Fourteen transistors, arranged in a pattern
that computes "at least two of these three inputs are high", and nothing else, ever. It
occupies 10.01 µm² because that is how much room those transistors need. Synthesis for an ASIC
is the question **"which shapes do I pour, and how much land does that take?"**

That is why one report counts *slots used out of a fixed supply* and the other reports *area
consumed*. An FPGA design can run out of LUTs. An ASIC design cannot run out of area — it just
gets bigger, and bigger costs money.

## Try this

Take the FPGA flow one step further and actually place the design:

```bash
yosys -p "read_verilog -sv ripple4.sv fulladder.sv; synth_ice40 -top ripple4 -json r4.json"
nextpnr-ice40 --up5k --package sg48 --json r4.json --asc r4.asc --freq 50
icepack r4.asc r4.bin
ls -l r4.bin
```

**What you should see:**

```
Info: Device utilisation:
Info:            ICESTORM_LC:      10/   5280     0%
Info:                  SB_IO:      14/     39    35%
```

and a bitstream of about **104 KB**.

Two things worth noticing. First, `nextpnr` says **10** logic cells where `yosys` said **8**
LUTs — placement packs LUTs together with carry logic and the counts stop matching. Second,
that 104 KB file is **the same size no matter what your design does**. It is not a description
of your adder; it is the settings for every shelf in the entire warehouse, including the
5,270 you left empty.

An ASIC's GDSII is the opposite: it describes only what you actually built, and it grows when
your design does.

**Why an engineer cares:** these two numbers — `10/5280` and `110.11 µm²` — are the first
questions anyone will ask about your design, and they are not interchangeable. "It fits" is an
FPGA answer. "It costs this much silicon" is an ASIC answer.

## What you ship

| | FPGA (iCE40 UP5K) | ASIC (SKY130) |
|---|---|---|
| your logic becomes | 8 × `SB_LUT4` | 4 × `maj3_1` + 8 × `xnor2_1` |
| the report says | 10 of 5280 logic cells | 110.11 µm² |
| you hand over | a 104 KB **bitstream** | a **GDSII** file |
| to change it | reload, three seconds | re-manufacture, months |
| cost shape | one chip, one price | enormous once, then nearly free per unit |

## The part that trips people up

A design that works beautifully on an FPGA can synthesize badly for an ASIC, and the reverse.
They are different targets, not different qualities.

The clearest case is memory. Here is a 2 KB array — eleven lines, nothing clever:

```systemverilog
logic [7:0] store [0:2047];
always_ff @(posedge clk) begin
    if (we) store[addr] <= din;
    dout <= store[addr];
end
```

Send it to the FPGA:

```
=== mem ===
   54 cells
   29   SB_DFF
   21   SB_LUT4
    4   SB_RAM40_4K
```

Four **block RAMs** — dedicated memory hardware that was already sitting on the die, free,
whether you used it or not. Fifty-four cells in total.

Send the same file to SKY130:

```
=== mem ===
    27684 cells
    16384   sky130_fd_sc_hd__edfxtp_1
     2748   sky130_fd_sc_hd__mux4_2
   Chip area for module '\mem': 606554.233600
```

Look at that flip-flop count. **16,384 is exactly 2048 × 8** — one physical flip-flop for
every single bit you asked for, plus 2,748 multiplexers to pick which one you meant.

**0.61 mm² of silicon.** Your adder was 110 µm². The memory is about **5,500 times bigger**.

Nothing in your source code changed. What changed is what was lying around for free.

> On a real chip you would fix this by instantiating a **macro** — a memory block designed and
> characterised separately, dropped into your floorplan as a fixed rectangle. That is out of
> scope here, but it is the reason chip designers talk about memory as a thing you *acquire*
> rather than a thing you *write*.

Next: [The carry has to walk](guide/the-carry-has-to-walk.md), where the adder you just
measured turns out to have a speed limit — and you find it in nanoseconds.
