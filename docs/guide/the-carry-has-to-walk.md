# Carry delay and static timing

This page explains how fast your adder is, why the carry chain sets that speed, and how to read
the timing report that decides whether a design works at a given clock. You'll run the timing
analysis yourself in
[Lab 04, Part 7](labs/lab-04-reading-the-receipt-overview.md#part-7-time-the-adder).

You know how big your adder is: [Reading the `stat` report](guide/reading-stat.md) gave you 12
cells and 110.11 µm², and [FPGA and ASIC targets](guide/warehouse-and-empty-lot.md) gave you the
same file as 8 LUTs on an FPGA. This page gets you its speed in nanoseconds.

## Video: the carry travels

This video runs 3 min 12 s and is silent and captioned; the captions are the narration. Every
number in it came out of the analysis on this page, run against the files the
[Lab 04 package](https://github.com/uoftasic/dd103/tree/main/labs/lab-04-reading-the-receipt)
ships.

<video controls loop muted playsinline preload="none"
       poster="assets/img/carry-travels.poster.png"
       style="width:100%;max-width:820px;border-radius:8px">
  <source src="assets/img/carry-travels.web.mp4" type="video/mp4">
</video>

The animation puts `1111 + 0001` into a four-bit adder and lets you watch the answer appear.
Before the carry starts moving, decide whether a purely combinational circuit can show a value
that is simply wrong, and for how long. Then count how many different wrong answers it shows
before it settles on sixteen. (It is four, and one of them is zero.)

The animation calls 1.481 ns "675 MHz". That is the ceiling the carry chain alone imposes. A
real registered design is slower still, because clock-to-Q and setup time eat into the same
budget; [the clock period](#registered-adder-and-minimum-clock-period) section below measures
both.

## The carry chain

Look at what your `ripple4.sv` asks for. Bit 0 adds `a[0]`, `b[0]` and `cin`, and produces
`sum[0]` and a carry. Bit 1 adds `a[1]`, `b[1]` and the carry bit 0 just produced, so it can't
finish until bit 0 has. Bit 2 waits on bit 1, and bit 3 waits on bit 2.

No compiler can parallelize this, because the carry into bit 3 really does depend on `a[0]` and
`b[0]`. Add `1111 + 0001` and the carry born at bit 0 has to travel all the way to `cout`.

So the adder is a queue: four people, each waiting on the one in front. The time to serve the
queue is the time to serve one person times the length of the queue, and that length is your bit
width.

## Static timing analysis

Static timing analysis (STA) asks a question no simulation asks: over every possible input, what
is the slowest path from anywhere to anywhere? It doesn't need test vectors. It walks the graph
of cells, adds up the delay each one contributes, and reports the worst total.

The tool in your workbench is OpenSTA, at `/foss/tools/bin/sta`, version `3.1.0`.

> **Do not use `yosys ... sta`.** Yosys has a built-in `sta` command, and it does not work on
> the SKY130 liberty in this image. Feed it your mapped netlist and it dies on the first cell:
>
> ```
> 4. Executing STA pass (static timing analysis).
> ERROR: Module `sky130_fd_sc_hd__xnor2_1' is used with parameters but is not parametric!
> ```
>
> It is the first thing a web search turns up. The tool to use is `sta`, the same one LibreLane
> calls later in the course.

### The gate-level netlist

STA needs to know what the cells are, such as how many picoseconds a `maj3_1` takes. That
information lives in the liberty file and only applies to a netlist already mapped to real
cells. So the first step is to synthesize and write the netlist out with
`write_verilog -noattr`. That file is your design in SKY130 cells, and it is what the timing tool
reads.

The Lab 04 package uses `src/ripple.sv`, the same adder with its width as a parameter,
`parameter int N = 4`, instead of the hard-coded `ripple4.sv` you wrote in DD102. The
`generate for` loop is unchanged. Yosys's `chparam -set N 4 ripple` sets the parameter before
elaboration, which is how one file gives you every width.

### The timing script

The package ships this as `scripts/timing.tcl`:

```tcl
read_liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog $env(NETLIST)
link_design ripple
create_clock -name clk -period 100
set_input_delay  0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -digits 3
```

`$env(NETLIST)` reads a shell variable, so the same script works on every width you synthesize.

### The worst path

On the 4-bit netlist it reports:

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

The middle four lines are four `maj3_1` cells, one after another. That is the carry chain, one
majority gate per bit, and the tool found it without being told where to look. The path starts
at `b[0]`, because bit 0's inputs are where the longest journey begins (`a[0]`, `b[0]` and `cin`
are equally good starting points, so the tool picked one). It ends at `cout`, the last thing in
the design to settle.

Your 4-bit adder takes 1.481 ns. Nothing in the design can produce an answer faster than that.

> If you delete the `create_clock`, `set_input_delay` and `set_output_delay` lines, you get
> `No paths found.` A combinational block has no flip-flops, so STA has nothing to time between
> until you tell it the inputs and outputs are related to a clock.

## Longer adders

Running the same two steps at `N` = 8, 16 and 32 gives:

| N | cells | area | worst path | fastest possible clock |
|---|---|---|---|---|
| 4 | 12 | 110.11 µm² | 1.481 ns | 675 MHz |
| 8 | 24 | 220.21 µm² | 3.049 ns | 328 MHz |
| 16 | 48 | 440.42 µm² | 6.184 ns | 162 MHz |
| 32 | 96 | 880.84 µm² | 12.455 ns | 80 MHz |

Area doubles when the width doubles, which you'd expect: twice the bits, twice the full adders.
The delay doubles too, and that is the expensive part. A 32-bit ripple adder is an unremarkable
881 µm² of silicon, and it can't be clocked above 80 MHz. Your laptop runs at forty times that.

Subtracting neighbouring rows shows why:

$$\frac{3.049 - 1.481}{4} = 0.392 \qquad \frac{6.184 - 3.049}{8} = 0.392 \qquad \frac{12.455 - 6.184}{16} = 0.392$$

Every extra bit costs 0.392 ns, which is exactly the delay printed next to each middle `maj3_1`
in the report above. This is one cell delay multiplied by the number of hops the carry makes, not
a trend line.

The first and last hops differ (0.370 and 0.328) because the first cell is driven by an input
port and the last drives an output port, with different loading. So:

$$T(N) = 0.370 + 0.392\,(N-2) + 0.328$$

That formula is a model of your own design's speed. Asked "can we make it 128 bits?", you can
answer "yes, at 20 MHz" without re-running anything. You'll test the model at $N = 64$ in the
lab.

## Arrival, required and slack

The bottom half of the report is the part that decides anything. Here it is on the 4-bit adder
with the clock set to a realistic 2 ns instead of 100:

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

The report turns on three terms:

- **Data arrival time** is when the answer actually shows up: 1.481 ns. It is a fact about your
  gates.
- **Data required time** is when the answer was due: 2.000 ns, because you said the clock period
  was 2 ns. It is a fact about what you asked for.
- **Slack** is required minus arrival: 0.519 ns of margin. Positive slack means the answer
  arrived early.

Slack is the number to remember, because it is signed and the sign is the result. Tighten the
clock to 1 ns:

```
            1.000   data required time
           -1.481   data arrival time
-----------------------------------------------------------
           -0.481   slack (VIOLATED)
```

Same design, same 1.481 ns arrival. You moved the deadline, and now the answer is 0.481 ns late.
`VIOLATED` means the design will not work at this clock. It doesn't run slowly; it latches a
value that hasn't finished computing.

Positive slack on every path is the goal. The point where every path in a design has
non-negative slack is called timing closure, and teams organise schedules around reaching it.

## Registered adder and minimum clock period

DD101 described a clock as a drumbeat: on every edge the flip-flops take a snapshot of their
inputs. Here is what that costs.

Put the adder between two registers, flopping the inputs and the result:

```systemverilog
always_ff @(posedge clk) begin
    a_q <= a_in;
    b_q <= b_in;
    r   <= {co, s};
end

ripple #(.N(8)) u_add (.a(a_q), .b(b_q), .cin(1'b0), .sum(s), .cout(co));
```

Synthesized with `dfflibmap` so the flip-flops are mapped too, and timed with a real clock on the
real port:

```tcl
create_clock -name clk -period 3.0 [get_ports clk]
report_checks -path_delay max -digits 3
```

it reports:

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

The path now starts and ends at flip-flops, `_62_/Q` to `_60_/D`, which is what a real path in a
real chip looks like. Three things appear that were not in the combinational report:

- 0.282 ns at `_62_/Q` is the clock-to-Q delay. The launching flip-flop doesn't produce its output
  the instant the edge arrives; it takes 282 ps.
- There are six `maj3_1`, not eight. You tied `cin` to `1'b0`, so synthesis folded bits 0 and 1
  into a `nor2` and an `o21ai`. Fixing an input to a constant removes hardware.
- −0.127 ns of `library setup time`: the capturing flip-flop needs the data to be stable 127 ps
  before the edge, not at it. That setup time comes from the liberty file and is subtracted from
  your budget.

So the real inequality is:

$$T_{\text{clk-to-Q}} + T_{\text{logic}} + T_{\text{setup}} \le T_{\text{period}}$$

$$0.282 + 2.551 + 0.127 = 2.960 \text{ ns}$$

OpenSTA states it directly with `report_clock_min_period`:

```
clk period_min = 2.96 fmax = 337.89
```

That is 2.96 ns, or 337.89 MHz. Set the period to 2.9, a 2 % tighter ask, and the same design
reports `-0.060 slack (VIOLATED)`. No setting or flag gets this circuit to 400 MHz: a 2.5 ns
period leaves the carry roughly one `maj3_1` hop short of the finish when the edge arrives, and
the flip-flop captures a half-finished number.


## Faster adders

Nothing, in this course. The fixes exist, though. A carry-lookahead adder computes all the carries
at once from the inputs, in parallel, instead of passing them down the line. It costs more cells
and gives a delay that grows like $\log N$ instead of $N$. Trading area for speed is the central
trade in digital design, and you have now measured both halves of it on the same file.

The other fix is to stop asking for the answer in one cycle: cut the queue in half and put a
register in the middle. That is pipelining, which DD202 covers.

## Caveats

A number with no realistic clock is not a timing result. The `1.481 ns` came from a report with
the period set to 100, a deliberately absurd value, so that slack would be huge and the arrival
time would be the only interesting number. That is a fine way to measure combinational delay. It
is not timing closure. Closure is the report where the period is the one you actually intend to
run at, and slack is still positive.

Slack is reported for the worst path, not for your whole design. `report_checks` prints one path
by default; pass `-group_count 10` to see the next nine. Fixing the worst path just promotes
whatever was second.

Every number on this page has conditions attached. The liberty file is named
`sky130_fd_sc_hd__tt_025C_1v80`: typical silicon, 25 °C, 1.80 V. There are 18 `.lib` files in
that directory. Pointing `read_liberty` at two of the others and re-running the 4-bit adder, with
nothing else changed, gives:

| Liberty file | Meaning | Worst path |
|---|---|---|
| `ss_n40C_1v28` | slow silicon, −40 °C, 1.28 V | 13.249 ns |
| `tt_025C_1v80` | typical, 25 °C, 1.80 V | 1.481 ns |
| `ff_100C_1v65` | fast silicon, 100 °C, 1.65 V | 1.000 ns |

The same netlist is nine times slower at one corner than at another. Nothing in the design
changed; the difference is voltage, temperature and manufacturing spread. Real sign-off runs every
corner and reports the worst. A frequency quoted without its corner tells you very little.

## Check yourself

1. Using $T(N)$, predict the worst path for $N = 64$ before you measure it in Lab 04.
2. A 4-bit adder runs with a 1.6 ns clock. Is the slack positive or negative, and by how much?
3. Why does the registered 8-bit adder have six `maj3_1` on its critical path instead of eight?

Next: [Lab 04: Reading the receipt](labs/lab-04-reading-the-receipt-overview.md).
