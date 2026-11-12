# Lab 03: Three ways to lose a latch

You'll feed Yosys simulation-only code and watch its three reactions, then take one `case`
statement with a branch missing through four module headers and get four different outcomes,
only one of which involves the tool telling you. You'll finish by counting flip-flops to settle
`=` against `<=`, and by finding a bug that lint does not catch.

Time: about 2.5 hours.

Package: [`labs/lab-03-three-ways-to-lose-a-latch/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-03-three-ways-to-lose-a-latch)

## Before you start

- [Lab 02](labs/lab-02-rtl-becomes-gates-overview.md) is complete, so `stat` output is familiar.
  `yosys -V` says `Yosys 0.68`.
- Read [Synthesizable SystemVerilog](guide/the-hardware-dialect.md),
  [Inferred latches](guide/the-latch-you-didnt-ask-for.md) and
  [Blocking and non-blocking assignments](guide/blocking-vs-nonblocking.md).

Start every part from the package directory:

```bash
mod dd103
cd labs/lab-03-three-ways-to-lose-a-latch
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

The design under test from Part 2 on is a battery meter: a 2-bit `level` in, a 4-bit `bar` out,
three cases written and `2'b11` missing. `src/bar_comb.sv`, `src/bar_star.sv`,
`src/bar_unique.sv` and `src/bar_fixed.sv` differ only in their header line and, for
`bar_fixed`, one `default:`.

`make` runs Parts 2 to 4 and 6 to 8 in about 2 seconds. Each part below names its own target.

## Part 1: Code that does not become hardware

1. Simulate the register and its testbench together:

   ```bash
   iverilog -g2012 -o results/sim.vvp examples/tb.sv examples/dut.sv && vvp results/sim.vvp
   ```

   You should see four `captured d =` lines and `final q = 9`. The testbench uses `#5`,
   `$display` and `$finish`; none of them describes hardware.

2. Run the three Yosys reactions. Note each exit code.

   ```bash
   cd src

   # reaction one: it stops
   yosys -p 'read_verilog -sv u_return_id.sv; synth -top u_return_id'   ; echo "exit=$?"

   # reaction two: it drops the line without saying so
   yosys -p 'read_verilog -sv u_delay.sv; synth -top u_delay;
             write_verilog -noattr /dev/stdout'                          ; echo "exit=$?"

   # reaction three: it builds a different circuit without saying so
   yosys -p 'read_verilog -sv u_unique_nodefault.sv; synth -top u_unique_nodefault;
             write_verilog -noattr /dev/stdout'                          ; echo "exit=$?"

   cd ..
   ```

   You should see `exit=1`, then `exit=0`, then `exit=0`. The first stops at
   `u_return_id.sv:5: ERROR: syntax error, unexpected TOK_ID`. The second prints a module whose
   whole body is `assign q = d;`; your `#5` is gone. The third prints two `assign` lines of
   logic you never wrote. Two of the three exit codes are zero, and only reading the netlist
   catches those two.

3. Map the `$display` example to SKY130:

   ```bash
   yosys -p "read_verilog -sv examples/t_display.sv; synth -top t_display;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see 5 cells: one `$print` and four `sky130_fd_sc_hd__dfxtp_1`, with
   `Area for cell type $print is unknown!` and a chip area of `80.076800`.

4. Compile the same file with Icarus:

   ```bash
   iverilog -g2012 -o results/t_display.vvp examples/t_display.sv
   ```

   You should see
   `examples/t_display.sv:21: warning: System task ($display) cannot be synthesized in an always_ff process.`

5. See what `initial` becomes:

   ```bash
   yosys -p "read_verilog -sv examples/t_initial.sv; synth -top t_initial" 2>&1 | grep -A2 'PROC_INIT pass'
   yosys -p "read_verilog -sv examples/t_initial.sv; synth -top t_initial;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
             write_verilog /dev/stdout" 2>/dev/null | grep -B2 'output \[3:0\] count'
   ```

You should see `Set init value: \count = 4'0000` from the first command and
`(* init = 4'h0 *)` two lines above `output [3:0] count;` from the second: an attribute on the
port, and no reset logic.

## Part 2: Four headers, one `case`

1. Synthesize the battery meter under all four headers:

   ```bash
   make latch
   ```

2. Convince yourself nothing else changed between the first two files:

   ```bash
   diff src/bar_comb.sv src/bar_star.sv
   ```

You should see four blocks and four different messages from the same Yosys pass:

```
--- bar_comb (exit 1) ---
ERROR: Latch inferred for signal `\bar_comb.\bar' from always_comb process ...
--- bar_star (exit 0) ---
Latch inferred for signal `\bar_star.\bar' from process ...
        2   $_DLATCH_N_
--- bar_unique (exit 0) ---
No latch inferred for signal `\bar_unique.\bar' from process ...
        2 cells
--- bar_fixed (exit 0) ---
No latch inferred for signal `\bar_fixed.\bar' from process ...
        2 cells
```

Three of the four exited 0. Fill in the first four rows of the table in
[Finishing](#finishing) now, quoting the line the tool printed.

## Part 3: Make the latch misbehave

1. Run the simulation. The testbench walks `level` through `0, 1, 2, 3, 0`.

   ```bash
   make sim
   ```

You should see this table first:

```
level   bar_star   bar_fixed
   00       0001        0001
   01       0011        0011
   10       0111        0111
   11       0111        1111
   00       0001        0001
```

At `level = 3` the latched design shows `0111`, the reading from the line above. A test that
never drives `level = 3` passes. A test that drives it after `2'b10` sees a plausible wrong answer
rather than an `X`.

## Part 4: The `unique` netlist

The second half of `make sim` synthesizes `bar_unique.sv` and simulates the netlist, not the
source.

1. Read the second table `make sim` printed, then open `results/bar_unique_net.v`.

You should see:

```
level   bar (synthesized)
   00       0001
   01       0011
   10       0111
   11       0001
```

and, in the netlist, `assign { bar[3], bar[0] } = 2'h1;`, which ties `bar[3]` to constant 0. The
top LED is not driven by anything, so a full battery displays as empty. Yosys reported "No latch
inferred", and that was true. Write down what `bar_unique` outputs at `level = 2'b11`.

## Part 5: Latch area on SKY130

1. Map the `always @*` version all the way to SKY130 cells:

   ```bash
   yosys -p "read_verilog -sv src/bar_star.sv; synth -top bar_star; dfflibmap -liberty $LIB;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

2. Compare the result with the real latch cell `sky130_fd_sc_hd__dlxtp_1`, 15.0144 µm² each.

You should see the two `$_DLATCH_N_` still in the mapped netlist,
`Area for cell type $_DLATCH_N_ is unknown!`, a chip area of `21.270400`, and `0.00%`
sequential. Two real latches alone would be 30.03 µm².

## Part 6: The lint gate

1. Lint the first file on its own:

   ```bash
   verilator --lint-only -Wall src/bar_comb.sv
   ```

   You should see `%Warning-CASEINCOMPLETE` with `(example pattern 0x3)`, then `%Warning-LATCH`,
   then `%Error: Exiting due to 2 warning(s)`.

2. Lint all four:

   ```bash
   make lint
   ```

You should see `bar_comb`, `bar_star` and `bar_unique` each produce `%Warning-CASEINCOMPLETE` and
`%Warning-LATCH` and exit 1, while `bar_fixed` prints a verilation report and `clean (exit 0)`.
Unlike Yosys, Verilator is not fooled by `unique`. From here on, `verilator --lint-only -Wall`
returning 0 is the precondition for running synthesis at all. It takes 4 ms.

## Part 7: Blocking and non-blocking

1. Count flip-flops:

   ```bash
   make flops
   ```

   You should see:

   ```
   shift_nb             3   60.058   sky130_fd_sc_hd__dfxtp_1
   shift_b              1   20.019   sky130_fd_sc_hd__dfxtp_1
   shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
   ```

   followed by the shift-register simulation. `shift_b` and `shift_b_rev` contain the same
   three blocking assignments in different orders.

2. Write the `=` version back out as Verilog, then the `<=` version:

   ```bash
   yosys -p "read_verilog -sv src/shift_b.sv; synth -top shift_b; write_verilog -noattr /dev/stdout"
   yosys -p "read_verilog -sv src/shift_nb.sv; synth -top shift_nb; write_verilog -noattr /dev/stdout"
   ```

   You should see `shift_b` reduced to a single `q <= d;`, while `shift_nb` keeps `reg a;`,
   `reg b;` and three clocked assignments.

3. Lint the blocking version:

   ```bash
   verilator --lint-only -Wall src/shift_b.sv
   ```

   You should see one `%Warning-BLKSEQ` per assignment.

4. Shuffle the three non-blocking assignments in `src/shift_nb.sv` into any order you like and
   synthesize again:

   ```bash
   yosys -p "read_verilog -sv src/shift_nb.sv; synth -top shift_nb; dfflibmap -liberty $LIB;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see `3   60.058   sky130_fd_sc_hd__dfxtp_1` for every ordering. Do the same to
   `src/shift_b.sv` and watch the count move between 1 and 3. Put both files back the way they
   were when you finish.

5. Look at the mirror-image mistake, `<=` inside `always_comb`:

   ```bash
   make comb
   verilator --lint-only -Wall src/comb_nb.sv
   ```

You should see identical `assign` lines for `comb_b` and `comb_nb`, then a simulation where the
`y_nb` column is the `y_b` column one row late. Verilator reports `%Warning-COMBDLY` with
"This will be executed as a blocking assignment '='!".

## Part 8: The bug lint misses

1. Run the width experiment:

   ```bash
   make width
   ```

You should see:

```
add8.sv: LINT CLEAN (exit 0)
   Chip area for module '\add8': 195.187200
200 + 100 = 44
```

then the `add9` run giving `205.196800` and `200 + 100 = 300`, and finally a
`%Warning-WIDTHTRUNC` for `add_trunc.sv`. `add8.sv` declares an eight-bit `sum`, so the carry is
never computed: not truncated, never built. Verilator, Yosys and Icarus all say nothing, because
nothing is inconsistent. Widening `sum` to `[8:0]` costs one `sky130_fd_sc_hd__maj3_1`,
10.01 µm², and gets you `300`.

## Finishing

The lab is done when this table is filled in from your own terminal, in the tool's words rather
than yours:

| Header | Exit code | What Yosys built | The line the tool printed |
|---|---|---|---|
| `always_comb`, no `default:` | | | |
| `always @*`, no `default:` | | | |
| `always_comb unique case` | | | |
| `always_comb` with `default:` | | | |
| `always_latch` (see Going further) | | | |

and each of these has one number:

| Question | Your answer |
|---|---|
| Cells in the correct (`bar_fixed`) design vs the latched one | |
| What `bar_unique` outputs at `level = 2'b11` | |
| Flip-flops from three `<=` statements vs three `=` statements | |
| SKY130 area of each | |
| Area `add8` reports, and what `200 + 100` gives | |
| Extra area buying the ninth bit | |

Check that your run matched ours:

- `make` completes in about 2 seconds and never stops on an error
- `make latch` shows exactly one `exit 1`, and it is `bar_comb`
- `make lint` shows exactly one clean file, and it is `bar_fixed`
- `results/bar_star.log` contains `$_DLATCH_N_`; `results/bar_fixed.log` does not

You should also be able to explain why `unique` makes an error go away without making the design
correct.

## Going further

- Synthesize `src/bar_latch.sv`, the same incomplete `case` under `always_latch`. Yosys builds the
  same two latches and exits 0, because this time you asked for them. Verilator drops its `LATCH`
  warning and keeps `CASEINCOMPLETE`.

Next: read [Reading the `stat` report](guide/reading-stat.md) and
[Carry delay and static timing](guide/the-carry-has-to-walk.md) before Lab 04.
