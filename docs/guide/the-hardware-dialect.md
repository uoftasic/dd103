# The hardware dialect

**Question this page answers:** *Why doesn't my textbook SystemVerilog compile?*

You copied something out of a textbook. It is unmistakably SystemVerilog. Your simulator ran
it. Yosys said:

```
ERROR: syntax error, unexpected TOK_ID
```

and pointed at a line that is obviously fine.

Nothing is wrong with your code. You wrote a sentence in the wrong half of the language.

## SystemVerilog is two languages sharing a keyboard

Here are two files. Both end in `.sv`. Both are legal SystemVerilog.

`dut.sv` — a register:

```systemverilog
always_ff @(posedge clk) q <= d;
```

`tb.sv` — the thing that pokes it:

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

Icarus runs both, together, happily:

```bash
iverilog -g2012 -o sim.vvp tb.sv dut.sv && ./sim.vvp
```

```
[5] captured d = 0
[15] captured d = 3
[25] captured d = 6
[35] captured d = 9
final q = 9
tb.sv:13: $finish called at 40 (1s)
```

Now look at what the testbench asks for. `#5` — wait five time units. `$display` — print a
line to my terminal. `$finish` — stop the universe.

**A chip has no terminal, no clock to check, and no way to stop the universe.** There is
nothing to build. Those three lines describe *an experiment being run on* a circuit. They do
not describe a circuit.

That is the whole distinction. One half of SystemVerilog describes **behaviour over time**,
for a program that will execute on your laptop. The other half describes **a structure made
of wires and gates**, which will exist all at once, forever, doing its thing every picosecond
whether anyone is watching.

Synthesis only reads the second half.

## The margin notes on a blueprint

An architect's drawing carries two kinds of marks.

There are walls, dimensions, and materials. Those become the building.

There are also notes in the margin: *"verify dimension on site"*, *"see sheet A-3"*,
*"contractor to confirm before pour"*. Real, useful, printed on the same sheet in the same
ink — and nobody pours concrete in the shape of them.

`$display` is a margin note. So is `#5`. So is `initial`.

The trouble is that Yosys is not an architect. It does not always know a margin note when it
sees one, and it has three different reactions when it meets one. Only one of those three is
the reaction you want.

## Reaction one: it stops and tells you

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

Every textbook writes functions with `return`. Yosys's built-in parser does not implement it.
This is the *good* case: the tool refuses, you find out immediately, and you fix it by
assigning to the function's own name instead.

```systemverilog
function automatic logic [3:0] flip (input logic [3:0] x);
    flip = ~x;             // works: 4 $_NOT_, no error
endfunction
```

## Reaction two: it quietly throws the line away

```systemverilog
module u_delay (input logic d, output logic q);
    always @(d) begin
        #5 q = d;
    end
endmodule
```

```bash
yosys -p "read_verilog -sv u_delay.sv; synth -top u_delay; write_verilog -noattr /dev/stdout"
```

```verilog
module u_delay(d, q);
  input d;
  wire d;
  output q;
  wire q;
  assign q = d;
endmodule
```

Count the warnings Yosys printed about this: **zero.** The `#5` is gone. Your five-nanosecond
delay became a piece of wire.

And it had to. Delay in real hardware is a *consequence* of the transistors you ended up
with — you find out what it is afterwards, in nanoseconds, by measuring. It is not something
you can request. There is no gate whose function is "be late".

## Reaction three: it builds something, and it is not what you meant

This is the dangerous one.

```systemverilog
always_comb begin
    case (s)
        2'b00: y = 2'b01;
        2'b01: y = 2'b10;
        2'b10: y = 2'b11;
    endcase
end
```

You forgot `2'b11`. Yosys catches you:

```
ERROR: Latch inferred for signal `\u_case_nodefault.\y' from always_comb process
```

Good. Now add one word — the word every textbook tells you to add:

```systemverilog
unique case (s)
```

```
exit=0
```

It synthesizes. Cleanly. Two cells. Here is what you actually got:

```verilog
assign y[0] = s[1] | ~(s[0]);
assign y[1] = s[1] ^ s[0];
```

Feed that `s = 2'b11` and it hands back `y = 2'b01`. You never wrote that. Yosys took
`unique` as your promise that `2'b11` can never happen, treated the output as don't-care, and
picked whatever made the gates smallest.

**`unique` did not make your code safer. It switched off the check that was protecting you.**

> In simulation, `unique` is a *runtime assertion* — a simulator will shout if two branches
> match or none do. In synthesis it is a *permission slip*. Same keyword, opposite job. This
> is the two-languages problem in a single word.

Reaction three has no error message and no warning. It is the reason this course makes you
read `stat` output instead of trusting a green exit code.

## `$display` does not even get thrown away

You would expect `$display` to be a margin note Yosys ignores. Watch what actually happens:

```systemverilog
always_ff @(posedge clk) begin
    q <= d;
    $display("d = %0d", d);
end
```

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "read_verilog -sv t_display.sv; synth -top t_display;
          dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

```
        5   80.077 cells
        1        -   $print
        4   80.077   sky130_fd_sc_hd__dfxtp_1

   Area for cell type $print is unknown!

   Chip area for module '\t_display': 80.076800
```

Your four flip-flops mapped to four real SKY130 cells. And a **fifth cell called `$print`
rode all the way through to the technology-mapped netlist**, where the area report gives up
on it: *Area for cell type `$print` is unknown!*

Yosys kept it because a `$print` cell is genuinely useful for formal verification and
simulation of the netlist. But there is no SKY130 standard cell that prints to a terminal,
so it will sit in your netlist as a thing no place-and-route tool can place.

Icarus, for its part, tells you outright:

```
dut.sv:4: warning: System task ($display) cannot be synthesized in an always_ff process.
```

**Why an engineer cares:** "it simulated fine" and "it synthesized without errors" are two
independent claims, and neither one implies the other. Every trap on this page passed
simulation.

## The short list

Things that are always safe, because each one names a piece of hardware:

| You write | You get |
|---|---|
| `logic` for every signal | a wire, or a flop, decided by how you drive it |
| `always_ff @(posedge clk)` | flip-flops |
| `always_comb` with every branch covered | gates |
| `assign` | gates |
| module-local `typedef enum logic [N:0]` | encoded state bits |
| packed `struct` | naming for bits you already had — zero cells |
| `generate` / `genvar`, `for` inside `always_comb` | N copies of the body |
| `localparam`, `pkg::NAME` | numbers, resolved before any hardware exists |

Things that never become hardware, because none of them names one:

| You write | Why there is no gate for it |
|---|---|
| `#5`, `wait`, `@(negedge clk)` in a body | delay is measured, not requested |
| `$display`, `$monitor`, `$finish` | the chip has no terminal to print to |
| `real`, `time`, `string` | there is no floating-point wire |
| `class`, `mailbox`, `fork`/`join` | these describe a program, not a circuit |
| `initial` as a way to reset | see below — this one is worse than useless |

`initial` deserves its own warning. It does not error. It survives:

```systemverilog
initial count = 4'd0;
```

```
2.2.4. Executing PROC_INIT pass (extract init attributes).
Found init rule in `\t_initial.$proc$t_initial.sv:2$3'.
  Set init value: \count = 4'0000
```

and lands in your SKY130 netlist as this:

```verilog
  (* init = 4'h0 *)
  output [3:0] count;
```

An **attribute**. A comment. Not one gate of reset logic was built. On an FPGA that attribute
is honoured — the bitstream really does load your flops with zero. On an ASIC, your counter
powers up holding whatever the transistors felt like, and the only thing standing between you
and that is a note in a file. If you want a reset, you have to build one, in an `always_ff`,
out of gates.

## The embarrassing question: is Yosys just bad?

It is a fair thing to wonder, and the answer is more interesting than yes or no.

Two separate things are going on, and it helps to keep them apart.

**The synthesizable subset is not a Yosys opinion.** No synthesizer on earth, at any price,
will build you a `#5`. That boundary is set by physics and by the IEEE 1364.1 standard, and a
$100,000 commercial tool draws it in the same place. Everything in the second table above
fails everywhere.

**The parser is a Yosys limitation, and a real one.** `return` inside a function and
`import pkg::*` inside a module are perfectly synthesizable ideas — they are just syntax
Yosys's hand-written front end never learned. Commercial tools accept both. This is not
physics; it is a missing feature, and the image ships two ways around it.

Knowing which of the two you have hit is the entire triage skill, and
[When Yosys says syntax error](reference/yosys-syntax-errors.md) is the page that drills it.

## Try this

You do not need a lab package for this one — the three modules are on this page. Save them as
`bad1.sv`, `bad2.sv` and `bad3.sv`, then watch all three reactions in a row:

```bash
# reaction one — it stops, loudly
yosys -p 'read_verilog -sv bad1.sv; synth -top bad1'      ; echo "exit=$?"

# reaction two — it says nothing and drops the line
yosys -p 'read_verilog -sv bad2.sv; synth -top bad2;
          write_verilog -noattr /dev/stdout'              ; echo "exit=$?"

# reaction three — it says nothing and builds a different circuit
yosys -p 'read_verilog -sv bad3.sv; synth -top bad3;
          write_verilog -noattr /dev/stdout'              ; echo "exit=$?"
```

**What you should see:** `exit=1`, then `exit=0`, then `exit=0`.

The first prints `ERROR: syntax error, unexpected TOK_ID` and stops. The second prints a
module whose body is `assign q = d;` — your `#5` is nowhere. The third prints two `assign`
lines of logic you never wrote.

**Why an engineer cares:** two of those three exit codes are zero. A green exit code means
Yosys did not crash, and nothing more than that. The only thing that catches reactions two and
three is reading the netlist that came out, which is what
[Reading `stat` like a receipt](guide/reading-stat.md) trains you to do.

---

Next, two reference pages you will come back to rather than read once:

- [The synthesizable subset](reference/synthesizable-subset.md) — every construct on this
  page, plus a dozen more, with the exact `stat` output each one produces on Yosys 0.64. Look
  up your construct before you write it.
- [When Yosys says syntax error](reference/yosys-syntax-errors.md) — what to do when the
  problem is the parser and not the physics, including the two escape hatches that are
  already installed in your container.

Then [A standard cell is a real thing](guide/standard-cells-are-real.md), where
`sky130_fd_sc_hd__dfxtp_1` stops being a string and starts being transistors.
