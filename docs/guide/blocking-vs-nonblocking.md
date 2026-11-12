# Blocking and non-blocking assignments

This page explains what `=` and `<=` actually build, by counting flip-flops. You'll run every
example here in
[Lab 03, Part 7](labs/lab-03-three-ways-to-lose-a-latch-overview.md#part-7-blocking-and-non-blocking).

Every SystemVerilog resource you have met says the same two things: use `<=` in clocked blocks,
and `=` in combinational ones. Most say it in bold, and almost none say what happens if you
don't. So the rule arrives as something to memorise, and rules like that are the first thing you
forget at 2 a.m.

You don't need to memorise it. The two operators build different numbers of flip-flops out of
the same three lines, and you can count them.

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

Both are in the lab. Synthesized to SKY130 cells with `make flops`, they give:

```
shift_nb             3   60.058   sky130_fd_sc_hd__dfxtp_1
shift_b              1   20.019   sky130_fd_sc_hd__dfxtp_1
shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
```

That is three flip-flops against one, 60.0576 µm² against 20.0192 µm². Neither run produced an
error, a Yosys warning, or anything else you would notice in a log.

Ignore the third row for now. The first two rows are the case for `<=`; the rest of this page
explains them.

## Where the other two flops went

Writing the `=` version back out as Verilog shows what Yosys thinks you wrote:

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

`a` and `b` were not optimized down; they are not there at all. Your three-stage shift register
is a single flip-flop wired straight from `d` to `q`.

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

Three registers and three separate clocked assignments: a shift register.

## Three people with whiteboards

Stand three people in a line, each holding a small whiteboard, and hold a numbered card up in
front of the first one. Everyone gets the same instruction: write down whatever the person on
your right is showing.

In method one, you go down the line in order. The first person copies the card. The second looks
right, sees the number the first has just written, and copies that. The third copies the second.
After one round all three whiteboards show the card's number. It went from one end of the line
to the other in a single round, and the middle two people did nothing you could detect.

In method two, everybody acts at once. On the count of three, everyone looks right, remembers
what they saw, and only then writes. The second person recorded what the first was showing
before the first updated. Each number moves exactly one place per round, and the card's number
needs three rounds to reach the end of the line.

`=` is method one. The assignment takes effect the instant it executes, so the next statement
reads what was just written. `b = a` sees the new `a`, which is `d`. `q = b` sees the new `b`,
which is still `d`. All three lines collapse into `q = d`, and the synthesizer, having noticed
that nothing ever reads `a` or `b`, deletes them.

`<=` is method two. Every right-hand side is sampled first, at the clock edge, from the values
that existed before the edge. Only then is every left-hand side written. `b <= a` reads the old
`a`, and `q <= b` reads the old `b`. Each value moves one place.

Method two is what flip-flops physically do: they all sample their inputs at the same instant,
and they all change their outputs a moment later. `<=` is the operator that describes a
flip-flop. `=` describes a sequence of steps, which is what a program is.

## In simulation

The same two modules, with one pulse on `d` over eight clock edges:

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

At `t = 36`, `d` is high for its one cycle, and `q_b` is already high: the pulse went in one side
and out the other on the same edge. `q_nb` does not go high until `t = 56`, two edges later,
which is what a three-deep pipeline does.

The `x` in the first two rows is expected. The `<=` version has three flip-flops and nobody has
reset them, so `q` is unknown until data has walked all the way through. The `=` version shows
`0` immediately because there is nothing to walk through.

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

That is three flip-flops: same statements, same operator, different order, different chip.

With `=`, the order you typed the lines in is part of the design. With `<=` it is not: write
those three non-blocking assignments in any of the six possible orders and you get the same three
flops every time, because none of them can see the others' results.

That is the bigger hazard, beyond getting one flop instead of three. A teammate reordering your
statements for readability, or a merge conflict resolved the tidy way, silently changes your
hardware. `<=` makes statement order stop mattering, and that is the whole point of it.

## `<=` in `always_comb`

The rule has a second half, and it fails in the opposite direction:

```systemverilog
always_comb begin
    t <= a & 4'hC;
    y <= t | 4'h1;
end
```

In the lab this is `make comb`:

```
--- comb_b netlist ---
  assign t = { a[3:2], 2'h0 };
  assign y = { a[3:2], 2'h1 };
--- comb_nb netlist ---
  assign t = { a[3:2], 2'h0 };
  assign y = { a[3:2], 2'h1 };
```

The hardware is identical. Yosys builds the same two wires either way, exits 0, and says nothing.
Simulating both gives:

```
   a   y_nb   y_b
   0      X     1
   f      1     d
   3      d     1
```

Read the `y_nb` column against the row above it. It is `y_b`, one row late, every time. In
simulation the non-blocking version gives you the answer to the previous input.

So the two mistakes have different shapes:

| | what the simulator does | what the chip does |
|---|---|---|
| `=` inside `always_ff` | plausible, but a 1-cycle pipeline | wrong: 1 flop, not 3 |
| `<=` inside `always_comb` | wrong: everything lags | correct combinational logic |

The first gives you a good simulation of a chip you did not build. The second gives you the right
chip and a testbench that misleads you. Both tend to cost an afternoon of looking in the wrong
place.

## Lint warnings for both mistakes

Neither mistake reaches synthesis if you run the lint gate from
[Inferred latches](guide/the-latch-you-didnt-ask-for.md) first. On `shift_b.sv`:

```
%Warning-BLKSEQ: src/shift_b.sv:9:11: Blocking assignment '=' in sequential logic process
                                    : ... note: In instance 'shift_b'
                                    : ... Suggest using delayed assignment '<='
    9 |         a = d;
      |           ^
                 ... For warning description see https://verilator.org/warn/BLKSEQ?v=5.046
```

There is one warning per line, and Verilator exits 1. In the other direction, on `comb_nb.sv`:

```
%Warning-COMBDLY: src/comb_nb.sv:4:11: Non-blocking assignment '<=' in combinational logic process
                                     : ... This will be executed as a blocking assignment '='!
    4 |         t <= a & 4'hC;
      |           ^~
                  ... For warning description see https://verilator.org/warn/COMBDLY?v=5.046
                  *** See https://verilator.org/warn/COMBDLY?v=5.046 before disabling this,
                  else you may end up with different sim results.
```

Notice what `COMBDLY` says: Verilator will execute your `<=` as `=`. Icarus will not. It schedules
the `<=` properly and gives you the lagging column above. That is two simulators disagreeing about
your source file, which is a situation you want to avoid. Icarus flags it too, in its own words,
when `make comb` compiles the testbench:

```
comb_nb.sv:4: warning: A non-blocking assignment should not be used in an always_comb process.
```

## The rule

```
always_ff @(posedge clk)   →   <=   always
always_comb                →   =    always
```

Never mix the two operators on the same signal, and never write to the same signal from two
different `always` blocks.

You don't have to remember which is which if you remember what they are. `<=` is "everybody
reads, then everybody writes", which is what a row of flip-flops does on a clock edge. `=` is "do
this, then do that", which is what a signal does as it ripples through a chain of gates. When you
can't remember, build both and count.

| | `always_ff`, `<=` | `always_ff`, `=` |
|---|---|---|
| flip-flops | 3 | 1 |
| SKY130 area | 60.0576 µm² | 20.0192 µm² |
| depends on statement order | no | yes |
| `verilator --lint-only -Wall` | exit 0 | `BLKSEQ` ×3, exit 1 |

The number of flip-flops in a design is its cost, its power and its latency. An operator that
changes that number based on the order you typed lines in is not a style preference.

Next: [Lab 03: Three ways to lose a latch](labs/lab-03-three-ways-to-lose-a-latch-overview.md),
which has you produce both traps from these pages and fill in a table.
