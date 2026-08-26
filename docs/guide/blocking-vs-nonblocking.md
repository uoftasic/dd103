# Blocking vs non-blocking

**Question this page answers:** *Why does everyone shout about `<=`?*

Every SystemVerilog resource you have met says the same two things: use `<=` in clocked
blocks, use `=` in combinational ones. Most of them say it in bold. Almost none of them say
what happens if you don't, so the rule arrives as an incantation, and incantations are the
first thing you forget at 2 a.m.

There is nothing to memorise here. The two operators build **different numbers of flip-flops**
out of the same three lines, and you can count them.

## Three statements

Here is a three-stage shift register. `d` goes in, and three clock ticks later it comes out
at `q`.

```systemverilog
logic a, b;
always_ff @(posedge clk) begin
    a <= d;
    b <= a;
    q <= b;
end
```

Now the same three statements with one character dropped from each line:

```systemverilog
logic a, b;
always_ff @(posedge clk) begin
    a = d;
    b = a;
    q = b;
end
```

Both files are in the lab. Synthesize both to SKY130 cells and count:

```bash
cd labs/lab-03-three-ways-to-lose-a-latch
make flops
```

```
shift_nb             3   60.058   sky130_fd_sc_hd__dfxtp_1
shift_b              1   20.019   sky130_fd_sc_hd__dfxtp_1
shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
```

**Three flip-flops versus one.** 60.0576 µm² versus 20.0192 µm². Neither run produced an error,
a warning from Yosys, or anything else you would notice in a log.

Ignore the third row for a moment. The argument for `<=` is those first two lines, and it is
now over. Everything below is why.

## Where the other two flops went

Ask Yosys to write the `=` version back out as Verilog and read what it thinks you wrote:

```bash
yosys -p "read_verilog -sv src/shift_b.sv; synth -top shift_b; write_verilog -noattr /dev/stdout"
```

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

`a` and `b` are not optimized down. They are **not there**. Your three-stage shift register is
a single flip-flop wired straight from `d` to `q`.

The `<=` version, same command:

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

Three registers, three separate clocked assignments. That is a shift register.

## Three people with whiteboards

Stand three people in a line, each holding a small whiteboard, and hold a numbered card up in
front of the first one. Everyone gets the same instruction: **write down whatever the person to
your right is showing.**

**Method one — go down the line in order.** The first person copies the card. The second looks
right, sees the number the first has *just written*, and copies that. The third copies the
second. One round later all three whiteboards show the card's number: it went from one end of
the line to the other in a single round, and the middle two people did nothing you could
detect.

**Method two — everybody at once.** On the count of three, everyone looks right, remembers
what they saw, and only then writes. The second person recorded what the first was showing
*before* the first updated. Each number moves exactly one place per round, and the card's
number needs three rounds to reach the end of the line.

`=` is method one. The assignment takes effect the instant it executes, so the next statement
reads what was just written. `b = a` sees the *new* `a`, which is `d`. `q = b` sees the new
`b`, which is still `d`. All three lines collapse into `q = d` — and the synthesizer, having
noticed that `a` and `b` are never observed by anyone, deletes them.

`<=` is method two. Every right-hand side is sampled first, at the clock edge, out of the
values that existed *before* the edge. Only then is every left-hand side written. `b <= a`
reads the old `a`; `q <= b` reads the old `b`. Each value moves one place.

Method two is not a convention someone picked to annoy you. It is what flip-flops physically
do: they all sample their inputs at the same instant, and they all change their outputs a
moment later. `<=` is the operator that describes a flip-flop. `=` describes a sequence of
steps, which is what a program is.

## Watch it in a simulator

Same two modules, one pulse on `d`, eight clock edges:

```bash
make flops
```

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

At `t = 36`, `d` is high for its one cycle. `q_b` is **already** high — the pulse went in one
side and out the other on the same edge. `q_nb` does not go high until `t = 56`, two edges
later, which is what a three-deep pipeline does.

The `x` in the first two rows is not a bug: the `<=` version has three flip-flops and nobody
has reset them, so `q` is genuinely unknown until data has walked all the way through. The
`=` version shows `0` immediately because there is nothing to walk through.

## Now look at the third row again

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

**Three flip-flops.** Same statements, same operator, different order — different chip.

With `=`, the order you typed the lines is part of the design. With `<=`, it is not: write
those three non-blocking assignments in any of the six possible orders and you get the same
three flops every time, because none of them can see each other's results.

That is the real hazard, and it is worse than "you might get one flop instead of three". It
means a teammate reordering your statements for readability, or a merge conflict resolved the
tidy way, silently changes your hardware. `<=` makes statement order stop mattering. That is
the whole feature.

## The mirror image: `<=` in `always_comb`

The rule has a second half, and it fails in the opposite direction — which is why it is worth
seeing rather than memorising.

```systemverilog
always_comb begin
    t <= a & 4'hC;
    y <= t | 4'h1;
end
```

```bash
make comb
```

```
--- comb_b netlist ---
  assign t = { a[3:2], 2'h0 };
  assign y = { a[3:2], 2'h1 };
--- comb_nb netlist ---
  assign t = { a[3:2], 2'h0 };
  assign y = { a[3:2], 2'h1 };
```

**The hardware is identical.** Yosys builds the same two wires either way, exit 0, no
complaint. Now simulate both:

```
   a   y_nb   y_b
   0      X     1
   f      1     d
   3      d     1
```

Read the `y_nb` column against the row above it. It is `y_b`, one row late — every time. In
simulation the non-blocking version hands you the answer to the *previous* input, forever.

So the two mistakes are not the same shape at all:

| | what the simulator does | what the chip does |
|---|---|---|
| `=` inside `always_ff` | plausible — but a 1-cycle pipeline | **wrong: 1 flop, not 3** |
| `<=` inside `always_comb` | **wrong: everything lags** | correct combinational logic |

One gives you a good simulation of a chip you did not build. The other gives you the right
chip and a testbench that lies to you. Both are debugged by staring at the wrong thing for an
afternoon.

## Both tools will tell you, if you ask

Neither mistake reaches synthesis if you run the lint gate from
[The latch you didn't ask for](guide/the-latch-you-didnt-ask-for.md) first:

```bash
verilator --lint-only -Wall src/shift_b.sv
```

```
%Warning-BLKSEQ: src/shift_b.sv:9:11: Blocking assignment '=' in sequential logic process
                                    : ... note: In instance 'shift_b'
                                    : ... Suggest using delayed assignment '<='
    9 |         a = d;
      |           ^
                 ... For warning description see https://verilator.org/warn/BLKSEQ?v=5.046
```

One warning per line, exit 1. And the other direction:

```bash
verilator --lint-only -Wall src/comb_nb.sv
```

```
%Warning-COMBDLY: src/comb_nb.sv:4:11: Non-blocking assignment '<=' in combinational logic process
                                     : ... This will be executed as a blocking assignment '='!
    4 |         t <= a & 4'hC;
      |           ^~
                  ... For warning description see https://verilator.org/warn/COMBDLY?v=5.046
                  *** See https://verilator.org/warn/COMBDLY?v=5.046 before disabling this,
                  else you may end up with different sim results.
```

Note what `COMBDLY` actually says: *Verilator* will execute your `<=` as `=`. Icarus will not —
Icarus schedules it properly and gives you the lagging column above. That is two simulators
disagreeing about your source file, which is a category of problem you do not want to be in.
Icarus flags it too, in its own words — `make comb` compiles the testbench and this falls out
on the way:

```
comb_nb.sv:4: warning: A non-blocking assignment should not be used in an always_comb process.
```

## The rule, now that it is a consequence

```
always_ff @(posedge clk)   →   <=   always
always_comb                →   =    always
```

Never mix the two operators on the same signal, and never write to the same signal from two
different `always` blocks.

You do not have to remember which is which if you remember what they *are*: `<=` is "everybody
reads, then everybody writes", which is what a row of flip-flops does on a clock edge. `=` is
"do this, then do that", which is what a signal does as it ripples through a chain of gates.

And when you cannot remember, do what this page did: build both, and count.

| | `always_ff`, `<=` | `always_ff`, `=` |
|---|---|---|
| flip-flops | **3** | **1** |
| SKY130 area | 60.0576 µm² | 20.0192 µm² |
| depends on statement order | no | **yes** |
| `verilator --lint-only -Wall` | exit 0 | `BLKSEQ` ×3, exit 1 |

## Try this

Take `shift_nb.sv`, shuffle the three non-blocking assignments into any order you like, and
re-run:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "read_verilog -sv src/shift_nb.sv; synth -top shift_nb; dfflibmap -liberty $LIB;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

**What you should see:** `3   60.058   sky130_fd_sc_hd__dfxtp_1`, every time, for every
ordering. Then do the same to `shift_b.sv` and watch the count move between 1 and 3 depending
on nothing but where your cursor was.

**Why an engineer cares:** the number of flip-flops in a design is its cost, its power, and
its latency. An operator that changes that number based on the order you happened to type is
not a style preference.

---

Next: [Lab 03 — Three ways to lose a latch](labs/lab-03-three-ways-to-lose-a-latch-overview.md), which
drills both traps on the same afternoon and hands you a table to fill in.

After that, [The warehouse and the empty lot](guide/warehouse-and-empty-lot.md) takes the
clean RTL you can now write and asks the question this course was named for: why does it
become two different pieces of hardware?
