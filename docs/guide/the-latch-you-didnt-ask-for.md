# Inferred latches

This page explains what a latch is, how an incomplete `always` block creates one, and why
designers avoid them. You'll reproduce every result here in
[Lab 03](labs/lab-03-three-ways-to-lose-a-latch-overview.md), Parts 2 to 6 and Part 8.

Say you are building a battery meter: two bits in, four LEDs out. You write the obvious thing:

```systemverilog
always_comb begin
    case (level)
        2'b00: bar = 4'b0001;
        2'b01: bar = 4'b0011;
        2'b10: bar = 4'b0111;
    endcase
end
```

That is three cases, and a 2-bit input has four values. You forgot `2'b11`, the full battery.
Yosys does not say "you forgot a case". It says this:

```
ERROR: Latch inferred for signal `\bar_comb.\bar' from always_comb process `\bar_comb.$proc$bar_comb.sv:7$1'.
```

and exits 1. The rest of this page explains where the word "latch" came from.

## Missing assignments and memory

What should `bar` be when `level` is `2'b11`? You didn't say, so the language answers for you,
with the rule that makes an `always` block work like a program: an assignment that does not
execute leaves the variable alone. `bar` keeps whatever it had.

As a hardware request, "keep whatever it had" means remember the last value and keep driving it,
for as long as `level` is 3, which might be forever. No combinational gate can do that, because a
gate's output depends only on its inputs right now. If the output has to depend on something
else, the only thing that can supply it is memory. So Yosys builds memory, and that memory is a
latch.

## Simulating the latch

Take the same `case`, change `always_comb` to `always @*` so the tool lets it through, and
simulate it next to a version that has a `default:`. In Lab 03 this is `make sim`:

```
level   bar_star   bar_fixed
   00       0001        0001
   01       0011        0011
   10       0111        0111
   11       0111        1111
   00       0001        0001
```

Look at row four. The full battery reads `0111`, three bars, because `0111` is what the meter
was showing one line earlier, at `level = 2'b10`. The circuit is replaying an old value rather
than computing a new one.

Then `level` drops back to `2'b00` and the display corrects itself. So the bug is intermittent,
depends on the input history, and is invisible to any test that never drives `level = 3`.

## Latches and flip-flops

A flip-flop is like a door on a timer. It opens for an instant on the rising edge of the clock,
whatever is standing there walks through, and it shuts. Because everyone agrees on when it opens,
a timing tool can ask one clean question: did the data arrive before the clock edge? That
question is what timing analysis means, and it is why chips work.

A latch is like a door propped open by a lever. While the lever (the enable) is up, the door
stays open and anything that comes near flows straight through to the output. When the lever
drops, the door shuts and whatever was last inside stays inside.

Here is the enable Yosys built for your battery meter, from the synthesized netlist:

```verilog
sky130_fd_sc_hd__and2_0 _4_ (.A(level[1]), .B(level[0]), .X(_0_));
...
always @*
  if (!_0_) \bar_reg[1]  = _1_[0];
```

`_0_` is `level[1] & level[0]`, true exactly when `level` is 3. So the door is open whenever
`level` is not 3 and shut when it is. You never wrote an enable or chose that expression; it is
left over from which branches you happened to type.

Nobody writes a timing constraint for that door, because nobody knows it exists. A latch like
this is memory that nobody timed, and that is why designers are afraid of them.

## Three headers

The `case` is identical in all four files in the lab. `bar_comb`, `bar_star` and `bar_unique`
differ only in their header line, and `bar_fixed` adds one line. `make latch` synthesizes all
four:

```
--- bar_comb (exit 1) ---
ERROR: Latch inferred for signal `\bar_comb.\bar' from always_comb process `\bar_comb.$proc$bar_comb.sv:7$1'.
--- bar_star (exit 0) ---
Latch inferred for signal `\bar_star.\bar' from process `\bar_star.$proc$bar_star.sv:7$1': $auto$proc_dlatch.cc:432:proc_dlatch$29
        5 cells
        1   $_ANDNOT_
        1   $_AND_
        2   $_DLATCH_N_
        1   $_XOR_
--- bar_unique (exit 0) ---
No latch inferred for signal `\bar_unique.\bar' from process `\bar_unique.$proc$bar_unique.sv:7$1'.
        2 cells
        1   $_ANDNOT_
        1   $_XOR_
--- bar_fixed (exit 0) ---
No latch inferred for signal `\bar_fixed.\bar' from process `\bar_fixed.$proc$bar_fixed.sv:7$1'.
        2 cells
        1   $_AND_
        1   $_OR_
```

All four messages come from the same Yosys pass, `PROC_DLATCH`. Read side by side, the wording
shows what happened in each case.

With `always_comb`, Yosys stops. The message starts with `ERROR:` and says "from always_comb
process". You promised combinational logic, the code described sequential logic, and the tool
caught it. Exit code 1, no netlist, no harm done.

With `always @*`, Yosys builds the latch and carries on. The sentence is the same, but there is
no `ERROR:`, no `always_comb`, and a cell name where the full stop was. Exit code 0. Two
`$_DLATCH_N_` cells are now in your design, and the only sign is one line out of the 629 that
run printed. `always @*` and `always_comb` describe the same circuit to a simulator; only
`always_comb` makes a promise the synthesizer can check. In this course you never write
`always @*`.

With `always_comb` and `unique case`, the latch disappears and so does your fourth LED. The third
message says "No latch inferred": no error, no warning, just a statement that there was nothing
to worry about. The result is two cells, smaller than the correct version.

## `unique` and don't-care outputs

`unique` is a promise that the cases you listed are the only ones that can happen. Yosys believes
you, so `level = 2'b11` becomes a don't-care, and the optimizer may output whatever is cheapest.
Here is what it picked:

```verilog
assign bar[2] = level[1] & ~(level[0]);
assign bar[1] = level[1] ^ level[0];
assign { bar[3], bar[0] } = 2'h1;
```

`bar[3]` is wired to constant zero, so the top LED can never light. Simulating that netlist
gives:

```
level   bar (synthesized)
   00       0001
   01       0011
   10       0111
   11       0001
```

A full battery displays as empty. This time the reading isn't stale. It is wrong, generated by
two gates working exactly as built.

> Style guides do recommend `unique`, and their reason is real: to a simulator, `unique` is a
> runtime assertion that complains if no branch matches. To a synthesizer it is a permission
> slip. Same keyword, opposite job.
>
> This course does not use `unique`. At this stage you have one synthesizer and no
> constrained-random regression suite to fire that assertion. Trading a check that runs every
> time you type `make` for one that runs only if a test happens to hit the missing case is a bad
> trade. Write the `default:` instead. It costs one line and the synthesizer enforces it every
> time.

## Fixing the latch

```systemverilog
always_comb begin
    bar = 4'b0000;            // 1. default every output, first thing
    case (level)
        2'b00: bar = 4'b0001;
        2'b01: bar = 4'b0011;
        2'b10: bar = 4'b0111;
        default: bar = 4'b1111;   // 2. every case gets a default:
    endcase
end
```

Either half alone removes the latch. Do both anyway. The unconditional assignment at the top
still protects you if you later add an `if` that forgets its `else`, and the `default:` still
protects you if someone widens `level` to three bits.

`bar_fixed.sv` in the lab does only the second half, and that is already enough:

```
No latch inferred for signal `\bar_fixed.\bar' …
        2 cells
        1   $_AND_
        1   $_OR_
```

The correct circuit is two gates, three cells smaller than the latched one at 5, and it behaves
correctly at all four inputs. Getting it right costs you nothing; the correct version is the
smaller one.

## Latch area on SKY130

Here is the `always @*` version mapped all the way to SKY130 cells:

```
        5    21.27 cells
        2        -   $_DLATCH_N_
        1    6.256   sky130_fd_sc_hd__and2_0
        1    6.256   sky130_fd_sc_hd__lpflow_isobufsrc_1
        1    8.758   sky130_fd_sc_hd__xor2_1

   Area for cell type $_DLATCH_N_ is unknown!

   Chip area for module '\bar_star': 21.270400
     of which used for sequential elements: 0.000000 (0.00%)
```

Three things went wrong on that report.

The latches never became cells. `dfflibmap` maps flip-flops, so it skipped both `$_DLATCH_N_`
and left them as Yosys's own internal cell type. They are still in your technology-mapped netlist
with a `$` in front of their name. As in
[What synthesis does](guide/synthesis-is-translation.md#leaving-out-dfflibmap), a `$_` name in a
mapped netlist means something did not get built.

The area is wrong. `21.27 µm²` is the sum of three gates. SKY130 does have a real latch,
`sky130_fd_sc_hd__dlxtp_1`, at 15.0144 µm², and two of those would be 30.03 µm²: more than the
number the tool printed for the entire module.

The sequential percentage is worse: `0.00%`, on a module where two of the five cells are memory.
The one number on the report that is supposed to tell you there is state in the design reads
zero.

Every later tool inherits that. Place-and-route can't place a cell it doesn't recognise, and
static timing analysis can't constrain a path it never saw.

> If you really want a latch, and a handful of real designs do, the keyword is `always_latch`.
> Yosys builds the same two `$_DLATCH_N_` cells and exits 0 without complaint, because you asked.
> That is what the `always_*` family is for: each one tells the tool what you meant, so it can
> tell you when the code does something else.

## The lint gate

Yosys catches the latch, but only at the end of a synthesis run, in a log, in its own vocabulary.
Verilator, which is in your container, reads your source and reports problems in plain English
before synthesis starts. On `bar_comb.sv`:

```
%Warning-CASEINCOMPLETE: src/bar_comb.sv:8:9: Case values incompletely covered (example pattern 0x3)
    8 |         case (level)
      |         ^~~~
                         ... For warning description see https://verilator.org/warn/CASEINCOMPLETE?v=5.046
%Warning-LATCH: src/bar_comb.sv:7:5: Latch inferred for signal 'bar' (not all control paths of combinational always assign a value)
                                   : ... Suggest use of always_latch for intentional latches
    7 |     always_comb begin
      |     ^~~~~~~~~~~
                ... For warning description see https://verilator.org/warn/LATCH?v=5.046
%Error: Exiting due to 2 warning(s)
```

Compare that with the Yosys message at the top of this page. Verilator gives you the line, the
column, a caret under the token, the signal name, a plain-English reason, a suggestion, and a URL
that explains the warning class. It also names the case value it couldn't find a branch for,
`example pattern 0x3`, which is exactly the one you forgot.

Run on all four files, it gives:

| File | Verilator |
|---|---|
| `bar_comb.sv` | `CASEINCOMPLETE` + `LATCH`, exit 1 |
| `bar_star.sv` | `CASEINCOMPLETE` + `LATCH`, exit 1 |
| `bar_unique.sv` | `CASEINCOMPLETE` + `LATCH`, exit 1 |
| `bar_fixed.sv` | nothing, exit 0 |

Verilator is not fooled by `unique`. Yosys said "No latch inferred" and handed you a circuit with
a dead LED; Verilator, reading the same file, still points at line 7 and says
`Latch inferred for signal 'bar'`. It does not treat a promise as evidence.

For the rest of this track, lint clean before you synthesize. Verilator's exit code is 0 or it
isn't, and `-Wall` makes warnings fatal. It runs in 4 milliseconds, so there is no reason to skip
it.

## Limits of lint

Verilator is easy to over-trust, so here is its limit. This is an eight-bit adder with nothing
missing, nothing conditional, no `case` and no `always` at all:

```systemverilog
module add8 (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] sum
);
    assign sum = a + b;
endmodule
```

In Lab 03 this is `make width`:

```
add8.sv: LINT CLEAN (exit 0)
   Chip area for module '\add8': 195.187200
200 + 100 = 44
255 +   1 = 0
```

200 + 100 = 44. Eight bits plus eight bits needs nine bits. Your `sum` is eight bits wide, so the
ninth bit, the carry out, has nowhere to go, and Verilog's width rules evaluate the whole addition
at eight bits. The carry is not truncated at the assignment; it is never computed. Yosys did not
build it, so it does not appear in the netlist, the area, or anywhere else.

Verilator, Yosys and Icarus all said nothing. Every tool did exactly what you asked.

The fix is one character in the port declaration:

```systemverilog
output logic [8:0] sum
```

```
200 + 100 = 300
255 +   1 = 256
```

and the chip area goes from `195.1872` to `205.1968 µm²`: one extra `sky130_fd_sc_hd__maj3_1`,
10.01 µm², for the ninth bit of carry. That is what the missing answer was worth in silicon, and
no tool would have told you.

Verilator does catch width mismatches when there is one to catch. `src/add_trunc.sv` widens one
operand and leaves the output alone, and that is the last thing `make width` prints:

```systemverilog
assign sum = {1'b0, a} + b;    // sum is still [7:0]
```

```
%Warning-WIDTHTRUNC: add_trunc.sv:6:16: Operator ASSIGNW expects 8 bits on the Assign RHS, but Assign RHS's ADD generates 9 bits.
```

A width mismatch is visible in the text, and lint sees it. A width that is consistently too small
everywhere has no mismatch for lint to find. It is a design decision, and only you know it was the
wrong one.

`make lint` returning 0 means no tool found anything to say about the file. It does not mean the
circuit computes what you wanted. Lint is only a minimum check, which is why DD104 exists.

## Summary

| | |
|---|---|
| A latch appears when | a combinational block can finish without assigning an output |
| Because "leave it alone" means | remember, and remembering needs memory |
| `always_comb` | errors. Use it, always |
| `always @*` | builds the latch silently. Never write it |
| `unique` without `default:` | turns the check off. Not used in this course |
| The fix | default every output on entry; every `case` gets a `default:` |
| Before every synthesis | `verilator --lint-only -Wall`, exit 0 |
| And still | lint clean ≠ correct |

Next: [Blocking and non-blocking assignments](guide/blocking-vs-nonblocking.md), which counts
what the tool builds for `=` and `<=`.
