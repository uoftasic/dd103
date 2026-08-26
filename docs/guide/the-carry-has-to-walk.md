# The carry has to walk

**Question this page answers:** *How do I know when something is too slow?*

You know how big your adder is. [Reading `stat` like a receipt](guide/reading-stat.md) gave you
12 cells and 110.11 µm², and [The warehouse and the empty lot](guide/warehouse-and-empty-lot.md)
gave you the same file as 8 LUTs on an FPGA.

Nobody has told you how *fast* it is. This page gets you a number in nanoseconds, and then
shows you the one line of a timing report that decides whether your design ships.

## Bit 3 is waiting on bit 0

Look at what your `ripple4.sv` actually asks for.

Bit 0 adds `a[0]`, `b[0]`, and `cin`. It produces `sum[0]` and a carry.

Bit 1 adds `a[1]`, `b[1]`, and **the carry bit 0 just produced**. It cannot start until bit 0
is finished. Bit 2 cannot start until bit 1 is finished. Bit 3 cannot start until bit 2 is.

There is no parallelism available here, and no clever compiler can invent any, because the
question "what is the carry into bit 3?" genuinely depends on `a[0]` and `b[0]`. Add
`1111 + 0001` and the carry born at bit 0 has to travel all the way to `cout`.

So the adder is a queue. Four people, each waiting on the one in front. The time to serve the
queue is the time to serve one person, times the length of the queue. **That length is your
bit width, and it is the thing you are about to measure.**

## The tool that measures it

Static timing analysis asks a question about your netlist that no simulation asks: *over
every possible input, what is the slowest path from anywhere to anywhere?* It does not need
test vectors. It walks the graph of cells, adds up the delay each one contributes, and reports
the worst total.

The tool in your workbench is **OpenSTA**, at `/foss/tools/bin/sta`:

```bash
sta -version
```

```
3.1.0
```

> **Do not use `yosys ... sta`.** Yosys has a built-in `sta` command and it does not work on
> sky130 liberty in this image. Feed it your mapped netlist and it dies on the first cell:
>
> ```
> 4. Executing STA pass (static timing analysis).
> ERROR: Module `sky130_fd_sc_hd__xnor2_1' is used with parameters but is not parametric!
> ```
>
> Expect to hit this at least once, because it is the first thing you find when you search.
> The real tool is `sta`, and it is the same one LibreLane calls later in this course.

## Step one: get gates, not RTL

STA needs to know what the cells *are* — how many picoseconds a `maj3_1` takes. That
information lives in the liberty file, and it only applies to a netlist that has already been
mapped to real cells. So synthesize first and write the netlist out:

```bash
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -q -p "read_verilog -sv ripple.sv fulladder.sv
             chparam -set N 4 ripple
             synth -top ripple
             flatten
             abc -liberty $LIB
             opt_clean
             write_verilog -noattr gates4.v"
```

Two new things in there. `chparam -set N 4 ripple` sets the parameter before elaboration —
that is how you get every width from one file, and it is why this page uses a `ripple.sv` with
`parameter int N = 4` instead of the hard-coded `ripple4.sv` you wrote in DD102. The only
change to your source is the parameter; the `generate for` loop is the same one. Both files
ship as `src/ripple.sv` and `src/fulladder.sv` in the
[Lab 04 package](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt).

`write_verilog -noattr gates4.v` is the handoff. That file is your design in SKY130 cells,
and it is what the timing tool reads.

## Step two: ask for the worst path

Save this as `timing.tcl` — it also ships as `scripts/timing.tcl` in the
[Lab 04 package](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt):

```tcl
read_liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog $env(NETLIST)
link_design ripple
create_clock -name clk -period 100
set_input_delay  0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -digits 3
```

`$env(NETLIST)` just reads a shell variable, so the same script works on every width you
synthesize. Run it:

```bash
NETLIST=gates4.v sta -exit timing.tcl
```

**What you should see:**

```
Startpoint: b[0] (input port clocked by clk)
Endpoint: cout (output port clocked by clk)
Path Group: clk
Path Type: max

   Delay     Time   Description
-----------------------------------------------------------
   0.000    0.000   clock clk (rise edge)
   0.000    0.000   clock network delay (ideal)
   0.000    0.000 v input external delay
   0.000    0.000 v b[0] (in)
   0.370    0.370 v _08_/X (sky130_fd_sc_hd__maj3_1)
   0.392    0.761 v _11_/X (sky130_fd_sc_hd__maj3_1)
   0.392    1.153 v _14_/X (sky130_fd_sc_hd__maj3_1)
   0.328    1.481 v _17_/X (sky130_fd_sc_hd__maj3_1)
   0.000    1.481 v cout (out)
            1.481   data arrival time
```

**Read the middle four lines again.** Four `maj3_1` cells, one after another. That is the
carry chain — one majority gate per bit, exactly as you drew it — and the tool found it
without being told where to look. It starts at `b[0]` — bit 0's inputs are where the longest
journey begins, and `a[0]`, `b[0]`, and `cin` are all equally good starting points, so the tool
picked one — and it ends at `cout`, the last thing in the design to settle.

**Your 4-bit adder takes 1.481 ns.** That is the number. Nothing in your design can be asked
to produce an answer faster than that.

> **`No paths found.`** is what you get if you delete the `create_clock` /
> `set_input_delay` / `set_output_delay` lines. A combinational block has no flip-flops, so
> there is nothing for STA to time *between* until you tell it that the inputs and outputs are
> related to a clock. The three lines are not decoration.

## The queue gets longer

Now run the same two commands at `N` = 8, 16, and 32. Every measurement below came from that
loop:

| N | cells | area | worst path | fastest possible clock |
|---|---|---|---|---|
| 4 | 12 | 110.11 µm² | **1.481 ns** | 675 MHz |
| 8 | 24 | 220.21 µm² | **3.049 ns** | 328 MHz |
| 16 | 48 | 440.42 µm² | **6.184 ns** | 162 MHz |
| 32 | 96 | 880.84 µm² | **12.455 ns** | 80 MHz |

Area doubles when the width doubles, which is unsurprising — twice the bits, twice the full
adders. The delay doubles too, and *that* is the expensive part. A 32-bit ripple adder is an
unremarkable 881 µm² of silicon — and it cannot be clocked above **80 MHz**. Your laptop runs
at forty times that.

Subtract the neighbouring rows and the reason falls out:

$$\frac{3.049 - 1.481}{4} = 0.392 \qquad \frac{6.184 - 3.049}{8} = 0.392 \qquad \frac{12.455 - 6.184}{16} = 0.392$$

**Every extra bit costs 0.392 ns**, and 0.392 ns is precisely the delay printed next to each
middle `maj3_1` in the report above. You are not looking at a trend line. You are looking at
one cell delay, multiplied by how many times the carry has to hop.

The first and last hops differ (0.370 and 0.328) because the first cell is driven by an input
port and the last one drives an output port, with different loading. So:

$$T(N) = 0.370 + 0.392\,(N-2) + 0.328$$

### Try this

Predict $T(64)$ with that formula before you run anything. Write the number down. Then:

```bash
yosys -q -p "read_verilog -sv ripple.sv fulladder.sv; chparam -set N 64 ripple;
             synth -top ripple; flatten; abc -liberty $LIB; opt_clean;
             write_verilog -noattr gates64.v"
NETLIST=gates64.v sta -exit timing.tcl | grep "data arrival"
```

**What you should see:**

```
           24.996   data arrival time
```

The formula says 25.002. The tool says 24.996. **You were right to six picoseconds** — and you
got there from four numbers and a subtraction.

**Why an engineer cares:** you just built a model of your own design's speed. When somebody
asks "can we make it 128 bits?", you do not need to re-run anything to know the answer is
"yes, at 20 MHz." Being able to predict the tool is the difference between using it and being
surprised by it.

## Arrival, required, slack

The bottom half of the report is the part that actually decides anything. Here it is on the
4-bit adder with the clock set to a realistic 2 ns instead of 100:

```
            1.481   data arrival time

   2.000    2.000   clock clk (rise edge)
   0.000    2.000   clock network delay (ideal)
   0.000    2.000   clock reconvergence pessimism
   0.000    2.000   output external delay
            2.000   data required time
-----------------------------------------------------------
            2.000   data required time
           -1.481   data arrival time
-----------------------------------------------------------
            0.519   slack (MET)
```

Three words, and everything else is bookkeeping:

- **Data arrival time** — when the answer actually shows up. 1.481 ns. This is a fact about
  your gates.
- **Data required time** — when the answer was *due*. 2.000 ns, because you said the clock
  period was 2 ns. This is a fact about what you asked for.
- **Slack** — required minus arrival. **0.519 ns of margin.** Positive slack means you got
  there early.

Slack is the only number in the report you have to memorise, because it is signed and the sign
is the verdict. Now tighten the clock to 1 ns and run it again:

```
            1.000   data required time
           -1.481   data arrival time
-----------------------------------------------------------
           -0.481   slack (VIOLATED)
```

Same design. Same 1.481 ns arrival. You moved the deadline, and now the answer is 0.481 ns
late. `VIOLATED` means this design will not work at this clock — not "runs slowly", not
"degraded". It latches a value that has not finished computing.

**Positive slack is the whole job.** Chip design has a name for the point where every path in
a design has non-negative slack: *timing closure*. It is the milestone teams organise around.

## Why the clock cannot be arbitrarily fast

DD101 told you a clock is a drumbeat, and that on every edge the flip-flops take a snapshot of
whatever is on their inputs. Here is what that costs.

Put your adder between two registers — flop the inputs, flop the result:

```systemverilog
always_ff @(posedge clk) begin
    a_q <= a_in;
    b_q <= b_in;
    r   <= {co, s};
end

ripple #(.N(8)) u_add (.a(a_q), .b(b_q), .cin(1'b0), .sum(s), .cout(co));
```

Synthesize it (add `dfflibmap -liberty $LIB` before `abc`, so the flip-flops get mapped too),
set a real clock on the real port, and ask again:

```tcl
create_clock -name clk -period 3.0 [get_ports clk]
report_checks -path_delay max -digits 3
```

```
Startpoint: _62_ (rising edge-triggered flip-flop clocked by clk)
Endpoint: _60_ (rising edge-triggered flip-flop clocked by clk)

   0.000    0.000 ^ _62_/CLK (sky130_fd_sc_hd__dfxtp_1)
   0.282    0.282 v _62_/Q (sky130_fd_sc_hd__dfxtp_1)
   0.111    0.393 ^ _18_/Y (sky130_fd_sc_hd__nor2_1)
   0.124    0.517 v _20_/Y (sky130_fd_sc_hd__o21ai_0)
   0.399    0.916 v _22_/X (sky130_fd_sc_hd__maj3_1)
   0.392    1.308 v _24_/X (sky130_fd_sc_hd__maj3_1)
   0.392    1.700 v _26_/X (sky130_fd_sc_hd__maj3_1)
   0.392    2.092 v _28_/X (sky130_fd_sc_hd__maj3_1)
   0.392    2.485 v _30_/X (sky130_fd_sc_hd__maj3_1)
   0.348    2.833 v _32_/X (sky130_fd_sc_hd__maj3_1)
   0.000    2.833 v _60_/D (sky130_fd_sc_hd__dfxtp_1)
            2.833   data arrival time

   3.000    3.000   clock clk (rise edge)
            3.000 ^ _60_/CLK (sky130_fd_sc_hd__dfxtp_1)
  -0.127    2.873   library setup time
            2.873   data required time
-----------------------------------------------------------
            0.040   slack (MET)
```

The path now starts and ends at flip-flops — `_62_/Q` to `_60_/D` — which is what a real path
in a real chip looks like. Three things appeared that were not in the combinational report:

- **0.282 ns of `_62_/Q`** — clock-to-Q. The launching flip-flop does not produce its output
  the instant the edge arrives; it takes 282 ps to get going.
- **only six `maj3_1`, not eight** — you tied `cin` to `1'b0`, so synthesis folded bits 0 and
  1 into a `nor2` and an `o21ai`. Fixing an input to a constant genuinely removes hardware.
- **−0.127 ns of `library setup time`** — the capturing flip-flop needs the data to be stable
  **127 ps before** the edge, not at it. That is the setup time from the liberty file, and it
  is subtracted from your budget.

So the real inequality is:

$$T_{\text{clk-to-Q}} + T_{\text{logic}} + T_{\text{setup}} \le T_{\text{period}}$$

$$0.282 + 2.551 + 0.127 = 2.960 \text{ ns}$$

Ask OpenSTA to state that directly:

```tcl
report_clock_min_period
```

```
clk period_min = 2.96 fmax = 337.89
```

**2.96 ns, 337.89 MHz.** Set the period to 2.9 — a 2 % ask — and the same design reports
`-0.060 slack (VIOLATED)`. There is no setting, no flag, and no amount of wanting it that gets
this circuit to 400 MHz: a 2.5 ns period leaves the carry roughly one `maj3_1` hop short of
the finish line when the edge arrives, and the flip-flop captures a half-finished number.

That is the answer to *"why can't a clock just be faster?"* It can. Your logic cannot.

## What you do about it

Nothing, in this course. But it is worth knowing that the fix exists and what shape it is:
a **carry-lookahead** adder computes all the carries at once from the inputs, in parallel,
instead of passing them down the line. It costs more cells and gets you a delay that grows
like $\log N$ instead of $N$. Trading area for speed is the trade in digital design, and you
have now measured both halves of it on the same file.

The other fix is to stop asking for the answer in one cycle — cut the queue in half and put a
register in the middle. That is called pipelining, and DD202 is where it lives.

## The part that trips people up

**A number with no clock is not a timing result.** `1.481 ns` came out of a report where you
set the period to 100 — a deliberately absurd value, so that slack would be enormous and the
arrival time would be the only interesting thing on the page. That is a fine way to *measure*
combinational delay. It is not timing closure. Closure is the report where the period is the
one you actually intend to run at, and slack is still positive.

**Slack is reported for the worst path, not for your design.** `report_checks` prints one path
by default. Pass `-group_count 10` to see the next nine. Fixing the worst path just promotes
whatever was second.

**Every number on this page has conditions attached.** The liberty file is named
`sky130_fd_sc_hd__tt_025C_1v80` — **t**ypical silicon, **25 °C**, **1.80 V**. There are
**18 `.lib` files** in that one directory. Point `read_liberty` at two of the others and re-run
the 4-bit adder, changing nothing else:

| Liberty file | Meaning | Worst path |
|---|---|---|
| `ss_n40C_1v28` | slow silicon, −40 °C, 1.28 V | **13.249 ns** |
| `tt_025C_1v80` | typical, 25 °C, 1.80 V | **1.481 ns** |
| `ff_100C_1v65` | fast silicon, 100 °C, 1.65 V | **1.000 ns** |

**The same netlist is nine times slower at one corner than at another.** Nothing in your
design changed — that is the voltage and the manufacturing spread. Real sign-off runs every
corner and reports the worst. When someone quotes you a frequency without saying which corner,
they have told you almost nothing.

---

Take this to your own design: [Lab 04 — Reading the receipt](labs/lab-04-reading-the-receipt.md)
makes you produce five different area numbers for one unchanged source file and defend all of
them. `src/ripple.sv` and `scripts/timing.tcl` are in that package, so every command on this
page runs from it too.

Then: [A state machine is a table with a memory](guide/state-machine-is-a-table.md), where you
build something that has a clock on purpose — and where the path you just learned to read
becomes the thing that decides how fast the elevator can think.
