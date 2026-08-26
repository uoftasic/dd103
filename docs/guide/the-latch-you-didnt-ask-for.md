# The latch you didn't ask for

**Question this page answers:** *What is a latch, and why is everyone afraid of it?*

You are building a battery meter. Two bits in, four LEDs out. You write the obvious thing:

```systemverilog
always_comb begin
    case (level)
        2'b00: bar = 4'b0001;
        2'b01: bar = 4'b0011;
        2'b10: bar = 4'b0111;
    endcase
end
```

Three cases. A 2-bit input has four values. You forgot `2'b11` — the full battery.

Yosys does not say "you forgot a case". It says this:

```
ERROR: Latch inferred for signal `\bar_comb.\bar' from always_comb process `\bar_comb.$proc$bar_comb.sv:7$1'.
```

and exits 1. Somewhere between your four LEDs and that sentence, a word you never typed
appeared. This page is about where it came from.

## The question you accidentally answered

Ask yourself what `bar` should be when `level` is `2'b11`.

You did not say. So the language answers for you, and its answer is the one that makes an
`always` block work like a program: **an assignment that does not execute leaves the variable
alone.** `bar` keeps whatever it had.

Read that again as a hardware request. *Keep whatever it had.* Not "output zero", not "output
`4'b1111`" — **remember the last value and keep driving it**, for as long as `level` is 3,
which might be forever.

There is no combinational gate that does that. Gates have no yesterday. If the output has to
depend on something other than the inputs in front of it right now, the only thing that can
supply it is **memory**.

So Yosys built you memory. That memory is a **latch**.

## Watch it happen

Take the exact same `case`, change `always_comb` to `always @*` so the tool will let it
through, and simulate it next to a version that has a `default:`.

```bash
cd labs/lab-03-three-ways-to-lose-a-latch
make sim
```

```
level   bar_star   bar_fixed
   00       0001        0001
   01       0011        0011
   10       0111        0111
   11       0111        1111
   00       0001        0001
```

Row four. The full battery reads **`0111`** — three bars — because `0111` is what the meter was
showing one line earlier, at `level = 2'b10`. The circuit is not computing. It is
**reminiscing**.

Then `level` drops back to `2'b00` and the display corrects itself. So the bug is intermittent,
input-dependent, and invisible in any test that never drives `level = 3`.

## A latch is a door propped open

A **flip-flop** is a door on a timer. It opens for an instant on the rising edge of the clock,
whatever is standing there walks through, and it shuts. Because everybody agrees on when it
opens, a timing tool can ask one clean question: *did the data arrive before the tick?* That
question is what "timing analysis" means, and it is the reason chips work.

A **latch** is a door propped open by a lever. While the lever — the *enable* — is up, the door
stands open and anything that comes near flows straight through to the output. When the lever
drops, the door shuts and whatever was last inside stays inside.

Here is the lever Yosys built for your battery meter, taken out of the synthesized netlist:

```verilog
sky130_fd_sc_hd__and2_0 _4_ (.A(level[1]), .B(level[0]), .X(_0_));
...
always @*
  if (!_0_) \bar_reg[1]  = _1_[0];
```

`_0_` is `level[1] & level[0]` — true exactly when `level` is 3. So the door is **open
whenever level is not 3, and shut when it is**. You never wrote an enable. You never chose
that expression. It is a leftover of which branches you happened to type.

Nobody wrote a constraint for that door, because nobody knows it exists. That is the whole
fear, in one sentence: **a latch is memory nobody timed.**

## Three headers, three completely different days

The `case` is identical in all four files. `bar_comb`, `bar_star` and `bar_unique` differ by
their header line and nothing else; `bar_fixed` adds one line.

```bash
cd labs/lab-03-three-ways-to-lose-a-latch
make latch
```

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

All four lines come out of the same Yosys pass, `PROC_DLATCH`. Read them side by side and the
grammar gives the game away.

**`always_comb` → it stops.** The message starts with `ERROR:` and says **"from always_comb
process"**. Those two words are the entire safety net. You promised combinational; you built
sequential; the tool called it. Exit code 1, no netlist, no harm done.

**`always @*` → it builds it and moves on.** Same sentence, no `ERROR:`, no `always_comb`,
and a cell name where the full stop was. Exit code 0. Two `$_DLATCH_N_` cells are now in your
design, and the only sign is **one line out of the 629** that run printed. `always @*` and
`always_comb` describe the same circuit to a simulator; only one of them makes a promise the
synthesizer can check. **In this course you never write `always @*`.**

**`always_comb` + `unique case` → the latch vanishes and so does your fourth LED.** Read that
third line carefully: **"No latch inferred."** Not an error, not a warning — a statement that
there was nothing to worry about. Two cells, smaller than the correct version.

## What `unique` actually bought you

`unique` is a promise: *the cases I listed are the only ones that can ever happen.* Yosys
believes you, so `level = 2'b11` becomes a don't-care, and don't-care means the optimizer may
output whatever is cheapest. Look at what it picked:

```verilog
assign bar[2] = level[1] & ~(level[0]);
assign bar[1] = level[1] ^ level[0];
assign { bar[3], bar[0] } = 2'h1;
```

`bar[3]` is wired to constant zero. The top LED can never light. Simulate that netlist:

```
level   bar (synthesized)
   00       0001
   01       0011
   10       0111
   11       0001
```

**A full battery displays as empty.** Not a stale reading this time — a wrong one, generated
fresh, by two gates working exactly as built.

> Style guides do recommend `unique`, and they are not wrong about *why*: to a **simulator**,
> `unique` is a runtime assertion that shouts if no branch matches. To a **synthesizer** it is
> a permission slip. Same keyword, opposite job.
>
> **This course does not use `unique`.** You are a first-year with one synthesizer and no
> constrained-random regression suite to fire that assertion. Trading a check that runs every
> time you type `make` for a check that runs only if a test happens to hit the case is a bad
> trade at your stage. Write the `default:` instead — it costs one line and it is enforced by
> physics rather than by hope.

## The rule, and it is two lines long

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

Either half alone is enough to kill the latch. Do both anyway — the unconditional assignment
at the top survives you later adding an `if` that forgets its `else`, and the `default:`
survives someone widening `level` to three bits.

`bar_fixed.sv` in the lab does only the second half, and that is already enough:

```
No latch inferred for signal `\bar_fixed.\bar' …
        2 cells
        1   $_AND_
        1   $_OR_
```

**Two gates.** The correct circuit is *three cells smaller* than the latched one — 2 against
`bar_star`'s 5 — and it behaves correctly at all four inputs. Getting this right is not a tax
you pay; it is a discount.

## What a latch costs on real silicon

Push the `always @*` version all the way to SKY130 cells and read the receipt:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "read_verilog -sv src/bar_star.sv; synth -top bar_star; dfflibmap -liberty $LIB;
          abc -liberty $LIB; opt_clean; stat -liberty $LIB"
```

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

Three separate things went wrong on that receipt.

**The latches never became cells.** `dfflibmap` maps flip-flops. It walked past both
`$_DLATCH_N_` and left them as Yosys's own internal cell type, so they are still sitting in
your technology-mapped netlist with a `$` in front of their name. From
[Reading `stat` like a receipt](guide/reading-stat.md): a `$_` name in a mapped netlist means
something did not get built.

**The area is a lie.** `21.27 µm²` is the sum of three gates. SKY130 does ship a real latch —
`sky130_fd_sc_hd__dlxtp_1`, **15.0144 µm²** — and two of those would be **30.03 µm²**, more
than the number the tool just printed for the entire module.

**The sequential percentage is a worse lie.** `0.00%`, on a module where two of the five cells
are memory. The one number on the receipt that is supposed to tell you "there is state in
here" reads zero.

Every downstream tool inherits that. Place-and-route cannot place a cell it does not
recognise, and static timing analysis cannot constrain a path it never saw.

> If you genuinely want a latch — and a handful of real designs do — the keyword is
> `always_latch`. Yosys builds the same two `$_DLATCH_N_` cells and exits **0** without
> complaint, because you asked. That is the point of the `always_*` family: they are not
> decoration, they are the sentence in which you tell the tool what you meant, so it can tell
> you when you didn't.

## The lint gate

Yosys catches the latch, but it catches it at the end of a synthesis run, in a log, in
Yosys's own vocabulary. There is a tool in your container whose entire job is to read your
source and complain in English before any of that happens.

```bash
verilator --lint-only -Wall src/bar_comb.sv
```

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
column, the caret under the token, the name of the signal, a plain-English reason, a
suggestion, and **a URL that explains the warning class**. It also tells you the case value it
could not find a branch for — `example pattern 0x3` — which is the exact number you forgot.

Now run it on all four:

```bash
make lint
```

| File | Verilator |
|---|---|
| `bar_comb.sv` | `CASEINCOMPLETE` + `LATCH`, **exit 1** |
| `bar_star.sv` | `CASEINCOMPLETE` + `LATCH`, **exit 1** |
| `bar_unique.sv` | `CASEINCOMPLETE` + `LATCH`, **exit 1** |
| `bar_fixed.sv` | nothing, **exit 0** |

**Verilator is not fooled by `unique`.** Yosys said "No latch inferred" and handed you a
circuit with a dead LED; Verilator, reading the same file, still points at line 7 and says
`Latch inferred for signal 'bar'`. It refuses to treat a promise as evidence.

**The rule for the rest of this track: lint clean before you synthesize.** Verilator's exit
code is 0 or it is not, and `-Wall` makes warnings fatal for you. It runs in **4
milliseconds**. There is no argument for skipping it.

## Lint clean does not mean correct

Now the honest part, because you are about to over-trust the tool you just met.

Here is an eight-bit adder. Nothing is missing, nothing is conditional, no `case`, no `always`
at all:

```systemverilog
module add8 (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] sum
);
    assign sum = a + b;
endmodule
```

```bash
make width
```

```
add8.sv: LINT CLEAN (exit 0)
   Chip area for module '\add8': 195.187200
200 + 100 = 44
255 +   1 = 0
```

**200 + 100 = 44.**

Eight bits plus eight bits is nine bits. Your `sum` is eight bits wide, so the ninth — the
carry out — has nowhere to go, and Verilog's width rules quietly evaluate the whole addition
at eight bits. The carry is not truncated at the assignment; it is **never computed**. Yosys
did not build it, so it does not appear in the netlist, the area, or anywhere else.

Verilator said nothing. Yosys said nothing. Icarus said nothing. Every tool did exactly what
you asked.

The fix is one character in the port declaration:

```systemverilog
output logic [8:0] sum
```

```
200 + 100 = 300
255 +   1 = 256
```

and the chip area goes from `195.1872` to **`205.1968 µm²`** — one extra
`sky130_fd_sc_hd__maj3_1`, **10.01 µm²**, the ninth bit of carry. That is what the missing
answer was worth in silicon, and no tool would sell it to you.

Verilator *does* catch width mismatches when there is one to catch. `src/add_trunc.sv` widens
one operand and leaves the output alone, and that is the last thing `make width` prints:

```systemverilog
assign sum = {1'b0, a} + b;    // sum is still [7:0]
```

```
%Warning-WIDTHTRUNC: add_trunc.sv:6:16: Operator ASSIGNW expects 8 bits on the Assign RHS, but Assign RHS's ADD generates 9 bits.
```

That is the difference. A width **mismatch** is visible in the text and lint sees it. A width
that is uniformly, consistently, self-consistently *too small* is not a mismatch — it is a
design decision, and the only thing that knows it was the wrong one is you.

**Why an engineer cares:** `make lint` returning 0 means "no tool found anything to say about
this file". It does not mean the circuit computes what you wanted. Lint is a floor, not a
ceiling — which is exactly why DD104 exists.

## What to take with you

| | |
|---|---|
| A latch appears when | a combinational block can finish without assigning an output |
| Because "leave it alone" means | remember — and remembering needs memory |
| `always_comb` | **errors.** Use it, always |
| `always @*` | builds the latch silently. Never write it |
| `unique` without `default:` | turns the check off. Not used in this course |
| The fix | default every output on entry; every `case` gets a `default:` |
| Before every synthesis | `verilator --lint-only -Wall`, exit 0 |
| And still | lint clean ≠ correct |

Now go do it yourself:
[Lab 03 — Three ways to lose a latch](labs/lab-03-three-ways-to-lose-a-latch.md).

Then [Blocking vs non-blocking](guide/blocking-vs-nonblocking.md), where the other operator
everyone shouts about turns out to be settleable the same way this one was — by counting what
the tool actually built.
