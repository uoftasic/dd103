# Synthesizable SystemVerilog

This page explains why some legal SystemVerilog doesn't synthesize, and what Yosys does when it
meets it. You'll run every example here in
[Lab 03, Part 1](../labs/lab-03-three-ways-to-lose-a-latch-overview.md#part-1-code-that-does-not-become-hardware).

Suppose you copy something out of a textbook. It's clearly SystemVerilog, and your simulator
runs it, but Yosys says:

```
ERROR: syntax error, unexpected TOK_ID
```

and points at a line that looks fine. Usually there's nothing wrong with the code. The trouble is
that you wrote it in the wrong half of the language, and the next section explains what that
means.

## Two languages in one

Here are two files, both ending in `.sv` and both legal SystemVerilog. They ship in
[`labs/lab-03-three-ways-to-lose-a-latch/examples/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-03-three-ways-to-lose-a-latch/examples),
and the lines below are the interesting part of each.

`dut.sv` is a register:

```systemverilog
always_ff @(posedge clk) q <= d;
```

`tb.sv` is the testbench that drives it:

```systemverilog
always #5 clk = ~clk;
initial begin
    repeat (3) begin
        @(negedge clk); d = d + 3;
    end
    $display("final q = %0d", q);
    $finish;
end
```

Icarus runs both together without complaint:

```
[5] captured d = 0
[15] captured d = 3
[25] captured d = 6
[35] captured d = 9
final q = 9
tb.sv:22: $finish called at 36 (1ns)
```

Look at what the testbench asks for: `#5` means wait five time units, `$display` means print a
line to my terminal, and `$finish` means stop the simulation.

A chip has no terminal, no clock to check the time on and no way to stop, so there is nothing to
build for those three lines. They describe an experiment you run on a circuit, rather than the
circuit itself.

One half of SystemVerilog describes behaviour over time, for a program that will run on your
laptop. The other half describes a structure made of wires and gates, which exists all at once
and keeps working every picosecond whether anyone is watching. Synthesis reads only the second
half.

## Analogy: margin notes on a blueprint

An architect's drawing carries two kinds of marks. Walls, dimensions and materials become the
building. Notes in the margin, such as "verify dimension on site", "see sheet A-3" or
"contractor to confirm before pour", are useful and printed in the same ink, but nobody pours
concrete in their shape.

In SystemVerilog, `$display` is a margin note, and so are `#5` and `initial`.

Yosys doesn't always recognise a margin note when it meets one. It reacts in one of three ways,
and only the first is the reaction you want.

## Reaction one: it stops

```systemverilog
function automatic logic [3:0] passthru (input logic [3:0] x);
    logic [3:0] t;
    t = x;
    return t;
endfunction
```

```
u_return_id.sv:5: ERROR: syntax error, unexpected TOK_ID
```

Every textbook writes functions with `return`, but Yosys's built-in parser doesn't implement it.
This is the good case, because the tool refuses, you find out immediately, and the fix is to
assign to the function's own name instead:

```systemverilog
function automatic logic [3:0] flip (input logic [3:0] x);
    flip = ~x;             // works: 4 $_NOT_, no error
endfunction
```

## Reaction two: it drops the line without a warning

```systemverilog
module u_delay (input logic d, output logic q);
    always @(d) begin
        #5 q = d;
    end
endmodule
```

Synthesized and written back out as Verilog, this becomes:

```verilog
module u_delay(d, q);
  input d;
  wire d;
  output q;
  wire q;
  assign q = d;
endmodule
```

Yosys printed zero warnings while doing this, but the `#5` is gone and your five-nanosecond delay
has become a wire.

Yosys has no other choice here. In real hardware, delay is a consequence of the transistors you
end up with, and you find out what it is afterwards by measuring it. You can't ask for a delay,
because there is no gate whose function is "be late".

## Reaction three: it builds something you didn't mean

This is the most dangerous of the three, because nothing tells you it has happened.

```systemverilog
always_comb begin
    case (s)
        2'b00: y = 2'b01;
        2'b01: y = 2'b10;
        2'b10: y = 2'b11;
    endcase
end
```

The `2'b11` case is missing, and Yosys catches it:

```
ERROR: Latch inferred for signal `\u_case_nodefault.\y' from always_comb process
```

Now add the one word many textbooks tell you to add:

```systemverilog
unique case (s)
```

With that change it synthesizes, with exit status 0, to two cells:

```verilog
assign y[0] = s[1] | ~(s[0]);
assign y[1] = s[1] ^ s[0];
```

If you feed that logic `s = 2'b11`, it returns `y = 2'b01`, a value you never wrote. Yosys took
`unique` as your promise that `2'b11` can never happen, so it treated the output for that case as
don't-care and picked whatever made the gates smallest. Instead of making the code safer,
`unique` switched off the latch check that was protecting you.

> In simulation, `unique` is a runtime assertion, so a simulator complains if two branches match
> or if none does. In synthesis it's a permission slip that lets the tool assume the missing
> cases never happen. The same keyword does opposite jobs, which is the two-languages problem in a
> single word.

Reaction three produces no error message and no warning, and it's the reason this course has you
read `stat` output instead of trusting a zero exit code.

## `$display`

You might expect Yosys to ignore `$display`, but it doesn't, as this fragment shows:

```systemverilog
always_ff @(posedge clk) begin
    q <= d;
    $display("d = %0d", d);
end
```

The complete file ships as
[`labs/lab-03-three-ways-to-lose-a-latch/examples/t_display.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-03-three-ways-to-lose-a-latch/examples/t_display.sv).
Mapped to SKY130, it gives:

```
        5   80.077 cells
        1        -   $print
        4   80.077   sky130_fd_sc_hd__dfxtp_1

   Area for cell type $print is unknown!

   Chip area for module '\t_display': 80.076800
```

The four flip-flops became four real SKY130 cells, but a fifth cell, `$print`, went all the way
through to the technology-mapped netlist, and the area report has no area to give it.

Yosys keeps it because a `$print` cell is useful for formal verification and for simulating the
netlist. No SKY130 standard cell prints to a terminal, though, so in your netlist it would be a
cell that no place-and-route tool can place.

Icarus tells you this directly when it compiles the file:

```
t_display.sv:21: warning: System task ($display) cannot be synthesized in an always_ff process.
```

"It simulated fine" and "it synthesized without errors" are two independent claims, and neither
implies the other: every trap on this page passed simulation.

## The short list

These are always safe, because each one names a piece of hardware:

| You write | You get |
|---|---|
| `logic` for every signal | a wire or a flop, decided by how you drive it |
| `always_ff @(posedge clk)` | flip-flops |
| `always_comb` with every branch covered | gates |
| `assign` | gates |
| module-local `typedef enum logic [N:0]` | encoded state bits |
| packed `struct` | names for bits you already had; zero cells |
| `generate` / `genvar`, `for` inside `always_comb` | N copies of the body |
| `localparam`, `pkg::NAME` | numbers, resolved before any hardware exists |

These never become hardware, because none of them names a piece of it:

| You write | Why there is no gate for it |
|---|---|
| `#5`, `wait`, `@(negedge clk)` in a body | delay is measured, not requested |
| `$display`, `$monitor`, `$finish` | the chip has no terminal to print to |
| `real`, `time`, `string` | there is no floating-point wire |
| `class`, `mailbox`, `fork`/`join` | these describe a program, not a circuit |
| `initial` as a way to reset | see below; this one is worse than useless |

### `initial`

`initial` doesn't cause an error, and it survives synthesis, though not as hardware. Take this
line:

```systemverilog
initial count = 4'd0;
```

The complete module is
[`examples/t_initial.sv`](https://github.com/uoftasic/dd103/blob/main/labs/lab-03-three-ways-to-lose-a-latch/examples/t_initial.sv).
Running `synth` on it prints:

```
2.2.4. Executing PROC_INIT pass (extract init attributes).
Found init rule in `\t_initial.$proc$t_initial.sv:18$3'.
  Set init value: \count = 4'0000
```

and it lands in your SKY130 netlist as this:

```verilog
  (* init = 4'h0 *)
  output [3:0] count;
```

That is an attribute, which is effectively a comment, and not one gate of reset logic was built
for it. On an FPGA the attribute is honoured, because the bitstream really does load your flops
with zero. On an ASIC your counter powers up holding whatever value the transistors settle to,
and the only record of the value you wanted is a note in a file. If you want a reset, build one
out of gates in an `always_ff`.

## Physics limits and parser gaps

You might wonder whether Yosys is just a bad tool. There are really two separate things going on,
and it helps to keep them apart.

The first is the synthesizable subset, which is not a Yosys opinion: no synthesizer at any price
will build you a `#5`. That boundary is set by physics and by the IEEE 1364.1 standard, and a
$100,000 commercial tool draws it in the same place, so everything in the second table above
fails in every tool.

The second is the parser, and that is a real Yosys limitation. `return` inside a function and
`import pkg::*` inside a module are synthesizable ideas, written in syntax that Yosys's
hand-written front end never learned, and commercial tools accept both. This is a missing
feature rather than a limit set by physics, and the course's container image ships two ways
around it.

Most of the skill in triaging a syntax error is working out which of the two you've hit, and
[When Yosys says syntax error](../reference/yosys-syntax-errors.md) walks you through it.

Four of this page's examples (reactions two and three, `$display` and `initial`) exit with code
zero even though the designs are wrong. A zero exit code means only that Yosys didn't crash. The only way to catch reactions two and three is to read
the netlist that comes out, which [Reading the `stat` report](../guide/reading-stat.md) trains
you to do.

## Reference pages

You'll come back to these pages rather than read them once:

- [The synthesizable subset](../reference/synthesizable-subset.md) covers most of the constructs
  on this page and a dozen more, with the exact result each one gives on Yosys 0.68. Look up
  your construct before you write it.
- [When Yosys says syntax error](../reference/yosys-syntax-errors.md) covers what to do when the
  problem is the parser and not the physics, including the two workarounds already installed in
  your container.

Next: [Inferred latches](../guide/the-latch-you-didnt-ask-for.md).
