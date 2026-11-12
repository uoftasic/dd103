# FPGA and ASIC targets

This page explains why the same SystemVerilog becomes different hardware depending on where you
send it. Read it after [Lab 01](labs/lab-01-one-adder-two-targets-overview.md): every number
here is one you already measured there.

In Lab 01 you sent one `ripple4.sv` through two synthesis flows and got two answers that look nothing
alike. Neither tool was wrong. They were solving different problems.

## Analogy: the warehouse and the empty lot

Suppose you need a warehouse. You have two options.

You can rent a building that already exists. It has a fixed footprint, a fixed ceiling height,
and a grid of shelving already bolted to the floor. You can't move a wall, but you can decide
what goes on each shelf, and change your mind next week. You are in business tomorrow.

Or you can buy an empty lot and pour a foundation. Every wall goes exactly where you want it,
and nothing is wasted on shelving you never use. Once you build a hundred of them it is cheaper
per square metre. But it takes months, and once the concrete sets, that is the building you
have, forever.

An FPGA is the rented warehouse. An ASIC is the empty lot.

## The same adder, both ways

Here is your adder in the warehouse, from `synth_ice40`:

```
=== ripple4 ===
   12 cells
    4   $scopeinfo
    8   SB_LUT4
```

The four `$scopeinfo` are bookkeeping, not hardware, so the answer is eight `SB_LUT4`. Here is
the same file on the empty lot, from `synth` and `abc -liberty` with the SKY130 liberty file:

```
=== ripple4 ===
    4   40.038   sky130_fd_sc_hd__maj3_1
    8   70.067   sky130_fd_sc_hd__xnor2_1
   Chip area for module '\ripple4': 110.105600
```

One side reports eight lookup tables. The other reports twelve named SKY130 cells and an area
in square micrometres.

## LUTs and standard cells

`SB_LUT4` is a lookup table: four inputs, sixteen bits of memory, and a multiplexer. Load those
sixteen bits with one pattern and it is an XOR; load another and it is a carry function; load a
third and it is something nobody has a name for. The silicon is already on the FPGA whether you
use it or not. Synthesis for an FPGA mostly decides which shelves to fill, and with what.

`sky130_fd_sc_hd__maj3_1` is a majority gate: fourteen transistors arranged to compute "at
least two of these three inputs are high", and nothing else, ever. It occupies 10.01 µm²
because that is how much room those transistors need. Synthesis for an ASIC decides which
shapes to manufacture and how much area they take.

That is why one report counts slots used out of a fixed supply and the other reports area
consumed. An FPGA design can run out of LUTs. An ASIC design cannot run out of area; it just
gets bigger, and bigger costs money.

## Placing the FPGA design

In Lab 01 the FPGA flow went one step further: `nextpnr-ice40` placed the design on a real UP5K
and `icepack` wrote a bitstream. The placer reported:

```
Info: Device utilisation:
Info:            ICESTORM_LC:      10/   5280     0%
Info:                  SB_IO:      14/     39    35%
```

and the bitstream came out at about 104 KB.

Two things to notice. First, `nextpnr` reports 10 logic cells where `yosys` reported 8 LUTs:
placement packs LUTs together with carry logic, so the counts stop matching. Second, the 104 KB
file is the same size no matter what your design does. It is the settings for every shelf in
the whole warehouse, including the 5,270 you left empty. An ASIC's GDSII is the opposite: it
describes only what you built, and it grows when your design does.

The numbers `10/5280` and `110.11 µm²` are the first things anyone will ask about your design,
and they are not interchangeable. "It fits" is an FPGA answer. "It costs this much silicon" is
an ASIC answer.

## Deliverables

| | FPGA (iCE40 UP5K) | ASIC (SKY130) |
|---|---|---|
| your logic becomes | 8 × `SB_LUT4` | 4 × `maj3_1` + 8 × `xnor2_1` |
| the report says | 10 of 5280 logic cells | 110.11 µm² |
| you hand over | a 104 KB bitstream | a GDSII file |
| to change it | reload, three seconds | re-manufacture, months |
| cost shape | one chip, one price | enormous once, then nearly free per unit |

## Memory on each target

A design that works well on an FPGA can synthesize badly for an ASIC, and the reverse. They are
different targets, not different levels of quality.

Memory shows this most clearly. Lab 01, Part 7 used a 2 KB array, shipped as
[`labs/lab-01-one-adder-two-targets/examples/mem.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-01-one-adder-two-targets/examples/mem.sv):

```systemverilog
logic [7:0] store [0:2047];
always_ff @(posedge clk) begin
    if (we) store[addr] <= din;
    dout <= store[addr];
end
```

On the FPGA it becomes:

```
=== mem ===
   54 cells
   29   SB_DFF
   21   SB_LUT4
    4   SB_RAM40_4K
```

The four `SB_RAM40_4K` are block RAMs: dedicated memory hardware that was already sitting on
the die, whether you used it or not. That is 54 cells in total.

On SKY130, with the same `synth` / `dfflibmap` / `abc` / `stat -liberty` flow, it takes about
twelve seconds to map twenty-seven thousand cells:

```
=== mem ===
    27684 cells
    16384   sky130_fd_sc_hd__edfxtp_1
     2748   sky130_fd_sc_hd__mux4_2
   Chip area for module '\mem': 606554.233600
```

16,384 is exactly 2048 × 8: one physical flip-flop for every bit you asked for, plus 2,748
multiplexers to pick which one you meant. That is 0.61 mm² of silicon, about 5,500 times the
110 µm² of your adder. The source file is the same in both runs. The difference is that the FPGA
already had block RAM on the die, and SKY130 has to build every bit out of flip-flops.

On a real chip you would fix this by instantiating a macro: a memory block designed and
characterised separately, then placed in your floorplan as a fixed rectangle. Macros are out of
scope for DD103, but they are why chip designers treat memory as something you acquire rather
than something you write.

Next: [What synthesis does](guide/synthesis-is-translation.md).
