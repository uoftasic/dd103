# FPGA and ASIC targets

This page explains why the same SystemVerilog becomes different hardware depending on where you
send it. Read it after [Lab 01](../labs/lab-01-one-adder-two-targets-overview.md), because every
number on this page is one you've already measured there.

In Lab 01 you sent one file, `ripple4.sv`, through two synthesis flows and got two answers that
look nothing alike. Neither tool got it wrong, because the two tools were solving different
problems.

## Analogy: the warehouse and the empty lot

Suppose you need a warehouse, and you have two ways to get one.

You can rent a building that already exists, with a fixed footprint, a fixed ceiling height and
a grid of shelving already bolted to the floor. You can't move a wall, but you can decide what
goes on each shelf and change your mind next week, and since the building is already standing,
you can be in business tomorrow.

Or you can buy an empty lot and pour a foundation. Then every wall goes exactly where you want
it, nothing is wasted on shelving you never use, and once you've built a hundred of the same
building it works out cheaper per square metre. The catch is that building takes months, and
once the concrete sets you can't change it: that's the building you have, forever.

An FPGA is the rented warehouse, and an ASIC is the empty lot.

## The same adder, both ways

Here is your adder in the warehouse, from `synth_ice40`:

```
=== ripple4 ===
   13 cells
    4   $scopeinfo
    9   SB_LUT4
```

The four `$scopeinfo` entries are bookkeeping rather than hardware, so the adder itself is nine
`SB_LUT4`s. Here is the same file on the empty lot, from `synth` and `abc -liberty` with the
SKY130 liberty file:

```
=== ripple4 ===
    4   40.038   sky130_fd_sc_hd__maj3_1
    8   70.067   sky130_fd_sc_hd__xnor2_1
   Chip area for module '\ripple4': 110.105600
```

The FPGA flow reports nine lookup tables, and the ASIC flow reports twelve named SKY130 cells
(four `maj3_1` and eight `xnor2_1`) and an area in square micrometres.

## LUTs and standard cells

`SB_LUT4` is a lookup table: sixteen bits of memory and a multiplexer, with four inputs that
pick which of the sixteen bits comes out. Load those sixteen bits with one pattern and it is an
XOR; load another and it is a carry function; load a third and it is something nobody has a name
for. The silicon for every LUT is already on the FPGA whether you use it or not, so synthesis
for an FPGA mostly decides which shelves to fill, and with what.

`sky130_fd_sc_hd__maj3_1` is a majority gate: fourteen transistors arranged to compute "at
least two of these three inputs are high". Unlike a LUT, it can never be made to compute
anything else. It occupies 10.01 µm² because that's how much room those transistors need, so
synthesis for an ASIC decides which shapes to manufacture, and with them, how much area the
design takes.

That's why the FPGA report counts slots used out of a fixed supply, while the ASIC report gives
the area consumed. An FPGA design can run out of LUTs, but an ASIC design can't run out of
area: it just gets bigger, and a bigger chip costs more money.

## Placing the FPGA design

In Lab 01 the FPGA flow went one step further: `nextpnr-ice40` placed the design on a real UP5K
and `icepack` wrote a bitstream. The placer reported:

```
Info: Device utilisation:
Info:            ICESTORM_LC:      11/   5280     0%
Info:                  SB_IO:      14/     39    35%
```

and the bitstream came out at about 104 KB.

There are two things to notice here. The first is that `nextpnr` reports 11 logic cells where
`yosys` reported 9 LUTs, because the two tools count different things. Yosys counts the lookup
tables it mapped, and `nextpnr` counts the logic cells it placed, which include two that its
packer adds, `$PACKER_GND` and `$PACKER_VCC`. Some of the LUT inputs are tied to a constant, and
the chip has no wire that is permanently 0 or permanently 1, so the constants have to come from
logic cells too. The second is that the 104 KB file is the same size no matter what your
design does, because it holds the settings for every shelf in the whole warehouse, including the
5,269 you left empty. An ASIC's GDSII file works the other way: it describes only what you
built, so it grows as your design does.

The numbers `11/5280` and `110.11 µm²` are the first things anyone will ask about your design,
but they answer different questions, so you can't swap one for the other. "It fits" is an FPGA
answer, because on an FPGA the question is whether your design fits in the chip you have. "It
costs this much silicon" is an ASIC answer, because there the question is how much silicon your
design needs.

## Deliverables

| | FPGA (iCE40 UP5K) | ASIC (SKY130) |
|---|---|---|
| your logic becomes | 9 × `SB_LUT4` | 4 × `maj3_1` + 8 × `xnor2_1` |
| the report says | 11 of 5280 logic cells | 110.11 µm² |
| you hand over | a 104 KB bitstream | a GDSII file |
| to change it | reload, three seconds | re-manufacture, months |
| cost shape | one chip, one price | enormous once, then nearly free per unit |

## Memory on each target

A design that works well on an FPGA can synthesize badly for an ASIC, and the reverse is also
true. That doesn't make either target the better one; they're simply different targets.

Memory shows this most clearly. In Lab 01, Part 7 you synthesized a 2 KB array, which ships as
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
   53 cells
   29   SB_DFF
   20   SB_LUT4
    4   SB_RAM40_4K
```

The four `SB_RAM40_4K` are block RAMs, dedicated memory hardware that was already sitting on
the die whether you used it or not, and with them the whole memory comes to 53 cells.

On SKY130, with the same `synth` / `dfflibmap` / `abc` / `stat -liberty` flow (the run that took
about twelve seconds in Lab 01, because it had twenty-seven thousand cells to map), it becomes:

```
=== mem ===
    27684 cells
    16384   sky130_fd_sc_hd__edfxtp_1
     2748   sky130_fd_sc_hd__mux4_2
   Chip area for module '\mem': 606554.233600
```

As you worked out in Lab 01, 16,384 is exactly 2048 × 8, so there is one physical flip-flop for
every bit you asked for, plus 2,748 multiplexers to pick out the one you meant. The whole memory
takes 0.61 mm² of silicon, about 5,500 times the 110 µm² of your adder. The source file is the
same in both runs; the FPGA could use block RAM that was already on the die, while on SKY130
every bit has to be built out of flip-flops.

On a real chip you would fix this by instantiating a macro, which is a memory block designed and
characterised separately and then placed in your floorplan as a fixed rectangle. Macros are out
of scope for DD103, but they're the reason chip designers treat memory as something you acquire
rather than something you write.

Next: [What synthesis does](../guide/synthesis-is-translation.md).
