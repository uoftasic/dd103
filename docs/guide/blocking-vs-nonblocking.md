# Blocking and non-blocking assignments

This page explains what `=` and `<=` actually build, by counting flip-flops. You'll run every
example here in
[Lab 03, Part 7](../labs/lab-03-three-ways-to-lose-a-latch-overview.md#part-7-blocking-and-non-blocking).

Every SystemVerilog resource you have met says the same two things: use `<=` in clocked blocks,
and `=` in combinational ones. Most say it in bold, and almost none say what happens if you
don't. So the rule arrives as something to memorise, and rules like that are the first thing you
forget at 2 a.m.

You don't need to memorise it, because the two operators build different numbers of flip-flops
out of the same three lines, and you can count them.

## Three statements

Here is a three-stage shift register. `d` goes in, and three clock ticks later it comes out at
`q`.

```systemverilog
logic a, b;
always_ff @(posedge clk) begin
    a <= d;
    b <= a;
    q <= b;
end
```

Here are the same three statements with one character dropped from each line:

```systemverilog
logic a, b;
always_ff @(posedge clk) begin
    a = d;
    b = a;
    q = b;
end
```

Both modules are in the lab, and when `make flops` synthesizes them to SKY130 cells it reports:

```
shift_nb             3   60.058   sky130_fd_sc_hd__dfxtp_1
shift_b              1   20.019   sky130_fd_sc_hd__dfxtp_1
shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
```

The `<=` version has three flip-flops and an area of 60.0576 µm²; the `=` version has one
flip-flop and 20.0192 µm². Neither run produced an error, a Yosys warning or anything else you
would notice in a log.

Ignore the third row for now; it comes up again under [Statement order](#statement-order). The first two rows are the
reason to use `<=`, and the rest of this page explains them.

## The two missing flip-flops

If you have Yosys write the `=` version back out as Verilog, you can see what it thinks you
wrote:

```verilog
module shift_b(clk, d, q);
  input clk;
  input d;
  output q;
  reg q;
  always @(posedge clk)
    q <= d;
endmodule
```

Yosys has removed `a` and `b` entirely, rather than optimizing them into something smaller, so
your three-stage shift register is a single flip-flop wired straight from `d` to `q`.

The `<=` version, written out the same way:

```verilog
  reg q;
  reg a;
  reg b;
  always @(posedge clk)
    a <= d;
  always @(posedge clk)
    b <= a;
  always @(posedge clk)
    q <= b;
```

This one has three registers and three separate clocked assignments, which is the shift register
you meant to write.

## Analogy: three people with whiteboards

Stand three people in a line, each holding a small whiteboard, and hold a numbered card up in
front of the first one. Everyone gets the same instruction: write down whatever the person on
your right is showing.

In method one, you go down the line in order. The first person copies the card. The second looks
right, sees the number the first has just written, and copies that. The third copies the second.
After one round all three whiteboards show the card's number, so the number has gone from one end
of the line to the other in a single round, and nothing the middle two people did can be seen
from outside.

In method two, everybody acts at once. On the count of three, everyone looks right, remembers
what they saw, and only then writes. So the second person writes down what the first was showing
before the first person updated it. Each number moves exactly one place per round, and the card's
number needs three rounds to reach the end of the line.

`=` works like method one. Each assignment takes effect the instant it executes, so the next
statement reads what was just written: `b = a` sees the new `a`, which is `d`, and `q = b` sees
the new `b`, which is also `d`. All three lines collapse into `q = d`, and since nothing ever
reads `a` or `b`, the synthesizer deletes them.

`<=` works like method two. At the clock edge every right-hand side is sampled first, from the
values that existed before the edge, and only then is every left-hand side written. So `b <= a`
reads the old `a` and `q <= b` reads the old `b`, and each value moves one place.

Method two is what flip-flops physically do: they all sample their inputs at the same instant,
and they all change their outputs a moment later. That's why `<=` is the operator that describes
a flip-flop, while `=` describes a sequence of steps, which is what a program is.

## In simulation

Here are the same two modules in simulation over eight clock edges, with one pulse on `d`:

```
time   d   q_nb   q_b
   6   0    x      0
  16   0    x      0
  26   0    0      0
  36   1    0      1
  46   0    0      0
  56   0    1      0
  66   0    0      0
  76   0    0      0
```

At `t = 36`, `d` is high for its one cycle, and `q_b` is already high, because the pulse went in
one side and came out the other on the same edge. `q_nb` doesn't go high until `t = 56`, two
edges later, which is what a three-deep pipeline does.

You should expect the `x` in the first two rows. The `<=` version has three flip-flops and nothing
resets them, so `q` is unknown until data has walked all the way through them. The `=` version
shows `0` from the start because it has only one flip-flop, so there is nothing to walk through.

## Statement order

`shift_b_rev.sv` has the same three blocking assignments, written bottom-up:

```systemverilog
always_ff @(posedge clk) begin
    q = b;
    b = a;
    a = d;
end
```

```
shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
```

That's three flip-flops again, and the only thing that changed is the order of the statements.

With `=`, the order you typed the lines in is part of the design. With `<=` it isn't, because none
of the assignments can see the others' results: write those three non-blocking assignments in any
of the six possible orders and you get the same three flops every time.

That's a bigger hazard than getting one flop instead of three. With `=`, a teammate who reorders
your statements for readability, or a merge conflict resolved the tidy way, changes your hardware
without any warning. `<=` makes statement order stop mattering, and that's what it's for.

## `<=` in `always_comb`

The rule has a second half, and breaking it goes wrong in the opposite direction. Here is `<=`
in a combinational block:

```systemverilog
always_comb begin
    t <= a & 4'hC;
    y <= t | 4'h1;
end
```

In the lab, `make comb` synthesizes this alongside the `=` version and prints both netlists:

```
--- comb_b netlist ---
  assign t = { a[3:2], 2'h0 };
  assign y = { a[3:2], 2'h1 };
--- comb_nb netlist ---
  assign t = { a[3:2], 2'h0 };
  assign y = { a[3:2], 2'h1 };
```

The hardware is identical: Yosys builds the same two wires either way, exits 0, and says nothing.
Simulating the two versions, though, gives different results:

```
   a   y_nb   y_b
   0      X     1
   f      1     d
   3      d     1
```

Each `y_nb` is the `y_b` from the row above it, every time, so the `<=` column is the `=` column
one row late. In simulation, the non-blocking version gives you the answer to the previous
input.

So the two mistakes go wrong in different places:

| | what the simulator does | what the chip does |
|---|---|---|
| `=` inside `always_ff` | plausible, but behaves as a 1-cycle pipeline | wrong: 1 flop instead of 3 |
| `<=` inside `always_comb` | wrong: every output lags one input behind | correct combinational logic |

The first gives you a good simulation of a chip you didn't build, and the second gives you the
right chip and a testbench that misleads you. Either one tends to cost an afternoon of looking in
the wrong place.

## Lint warnings for both mistakes

If you run the lint gate from [Inferred latches](../guide/the-latch-you-didnt-ask-for.md) first,
neither mistake gets as far as synthesis. On `shift_b.sv`, Verilator warns:

```
%Warning-BLKSEQ: src/shift_b.sv:9:11: Blocking assignment '=' in sequential logic process
                                    : ... note: In instance 'shift_b'
                                    : ... Suggest using delayed assignment '<='
    9 |         a = d;
      |           ^
                 ... For warning description see https://verilator.org/warn/BLKSEQ?v=5.050
                 ... Use "/* verilator lint_off BLKSEQ */" and lint_on around source to disable this message.
```

Verilator prints one warning for each of the three lines and exits 1. The mistake in the other
direction, in `comb_nb.sv`, gets a different warning:

```
%Warning-COMBDLY: src/comb_nb.sv:4:11: Non-blocking assignment '<=' in combinational logic process
                                     : ... This will be executed as a blocking assignment '='!
    4 |         t <= a & 4'hC;
      |           ^~
                  ... For warning description see https://verilator.org/warn/COMBDLY?v=5.050
                  ... Use "/* verilator lint_off COMBDLY */" and lint_on around source to disable this message.
                  *** See https://verilator.org/warn/COMBDLY?v=5.050 before disabling this,
                  else you may end up with different sim results.
```

Notice what `COMBDLY` says: Verilator will execute your `<=` as `=`. Icarus doesn't do that; it
schedules the `<=` properly and gives you the lagging column above. So two simulators disagree
about what your source file does, which is a situation you want to avoid. Icarus flags the problem
too, in its own words, when `make comb` compiles the testbench:

```
comb_nb.sv:4: warning: A non-blocking assignment should not be used in an always_comb process.
```

## Rule: `<=` in `always_ff`, `=` in `always_comb`

```
always_ff @(posedge clk)   →   <=   always
always_comb                →   =    always
```

Never mix the two operators on the same signal, and never write to the same signal from two
different `always` blocks.

You don't have to remember which is which if you remember what they are. `<=` is "everybody
reads, then everybody writes", which is what a row of flip-flops does on a clock edge. `=` is "do
this, then do that", which is what a signal does as it ripples through a chain of gates. When you
can't remember, build both versions and count the flip-flops.

| | `always_ff`, `<=` | `always_ff`, `=` |
|---|---|---|
| flip-flops | 3 | 1 |
| SKY130 area | 60.0576 µm² | 20.0192 µm² |
| depends on statement order | no | yes |
| `verilator --lint-only -Wall` | exit 0 | `BLKSEQ` ×3, exit 1 |

The number of flip-flops in a design sets its cost, its power and its latency, and with `=` in a
clocked block that number depends on the order you typed the lines in. That's why the choice of
operator is more than a style preference.

Next: [Lab 03: Three ways to lose a latch](../labs/lab-03-three-ways-to-lose-a-latch-overview.md),
which has you produce both traps from these pages and fill in a table.
