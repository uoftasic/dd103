# Lab 03: Three ways to lose a latch

You'll feed Yosys simulation-only code and watch its three reactions, then take one `case`
statement with a branch missing through five module headers and record what each tool says about
each one. You'll finish by counting flip-flops to settle `=` against `<=`, and by finding a bug
that lint does not catch. Most parts ask you to write down a prediction before you run anything.

Time: about 2.5 hours.

Package: [`labs/lab-03-three-ways-to-lose-a-latch/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-03-three-ways-to-lose-a-latch)

## Before you start

- [Lab 02](../labs/lab-02-rtl-becomes-gates-overview.md) is complete, so `stat` output is familiar.
  `yosys -V` says `Yosys 0.68`.
- Read [Synthesizable SystemVerilog](../guide/the-hardware-dialect.md),
  [Inferred latches](../guide/the-latch-you-didnt-ask-for.md) and
  [Blocking and non-blocking assignments](../guide/blocking-vs-nonblocking.md).

Start every part from the package directory:

```bash
mod dd103
cd labs/lab-03-three-ways-to-lose-a-latch
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

The design under test from Part 2 on is a battery meter: a 2-bit `level` in, a 4-bit `bar` out,
three cases written and `2'b11` missing. `src/bar_comb.sv`, `src/bar_star.sv`,
`src/bar_unique.sv` and `src/bar_fixed.sv` differ only in their header line and, for
`bar_fixed`, one `default:`. `src/bar_latch.sv` has the same `case` under `always_latch`.

`make` runs Parts 2 to 4 and 6 to 8 in about 2 seconds. You don't need to run it first: each part
below names its own target.

## Part 1: Code that does not become hardware

What does Yosys do with code that only makes sense to a simulator?

1. Simulate the register and its testbench together:

   ```bash
   iverilog -g2012 -o results/sim.vvp examples/tb.sv examples/dut.sv && vvp results/sim.vvp
   ```

   You should see four `captured d =` lines and `final q = 9`. The testbench uses `#5`,
   `$display` and `$finish`; none of them describes hardware.

2. Step 3 runs Yosys on three files from
   [Synthesizable SystemVerilog](../guide/the-hardware-dialect.md): a function that uses `return`, a
   `#5` delay, and a `unique case` with no `default:`. Write down which of the three you expect to
   exit 0.

3. Run the three, noting each exit code:

   ```bash
   cd src

   # one: a function that uses return
   yosys -p 'read_verilog -sv u_return_id.sv; synth -top u_return_id'   ; echo "exit=$?"

   # two: a #5 delay
   yosys -p 'read_verilog -sv u_delay.sv; synth -top u_delay;
             write_verilog -noattr /dev/stdout'                          ; echo "exit=$?"

   # three: unique case with no default:
   yosys -p 'read_verilog -sv u_unique_nodefault.sv; synth -top u_unique_nodefault;
             write_verilog -noattr /dev/stdout'                          ; echo "exit=$?"

   cd ..
   ```

   You should see `exit=1`, then `exit=0`, then `exit=0`. The first stops at
   `u_return_id.sv:5: ERROR: syntax error, unexpected TOK_ID`. The second prints a module whose
   whole body is `assign q = d;`; your `#5` is gone. The third prints two `assign` lines of
   logic you never wrote. How would you have caught the second and third without reading the
   netlist?

   <details>
   <summary>Answer</summary>

   Not from the exit codes: two of the three are zero. Reading the netlist catches both. Lint
   catches the third, as Part 6 shows for `unique`, but not the second:
   `verilator --lint-only -Wall u_delay.sv`, run in `src/`, exits 0.

   </details>

4. Map the `$display` example to SKY130:

   ```bash
   yosys -p "read_verilog -sv examples/t_display.sv; synth -top t_display;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see 5 cells: one `$print` and four `sky130_fd_sc_hd__dfxtp_1`, with
   `Area for cell type $print is unknown!` and a chip area of `80.076800`.

5. Compile the same file with Icarus:

   ```bash
   iverilog -g2012 -o results/t_display.vvp examples/t_display.sv
   ```

   You should see
   `examples/t_display.sv:21: warning: System task ($display) cannot be synthesized in an always_ff process.`

6. See what `initial` becomes:

   ```bash
   yosys -p "read_verilog -sv examples/t_initial.sv; synth -top t_initial" 2>&1 | grep -A2 'PROC_INIT pass'
   yosys -p "read_verilog -sv examples/t_initial.sv; synth -top t_initial;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
             write_verilog /dev/stdout" 2>/dev/null | grep -B2 'output \[3:0\] count'
   ```

You should see `Set init value: \count = 4'0000` from the first command and
`(* init = 4'h0 *)` two lines above `output [3:0] count;` from the second: an attribute on the
port, and no reset logic.

What value does this counter hold when a SKY130 chip powers up?

<details>
<summary>Answer</summary>

Whatever the transistors settle to. The attribute is effectively a comment: on an FPGA the
bitstream honours it, but on an ASIC not one gate of reset logic was built. If you want a reset,
build one in an `always_ff`, out of gates.

</details>

## Part 2: Five headers, one `case`

Which of five headers on the same incomplete `case` does Yosys complain about, and what does it
build for each?

1. Read the header line of each of the five `bar_*.sv` files and write down which ones you expect
   Yosys to stop on with an error, and which ones you expect to build a latch.

2. Synthesize the battery meter under the first four headers:

   ```bash
   make latch
   ```

   You should see four blocks and four different messages from the same Yosys pass:

   ```
   --- bar_comb (exit 1) ---
   ERROR: Latch inferred for signal `\bar_comb.\bar' from always_comb process ...
   --- bar_star (exit 0) ---
   Latch inferred for signal `\bar_star.\bar' from process ...
           5 cells
           2   $_DLATCH_N_
   --- bar_unique (exit 0) ---
   No latch inferred for signal `\bar_unique.\bar' from process ...
           2 cells
   --- bar_fixed (exit 0) ---
   No latch inferred for signal `\bar_fixed.\bar' from process ...
           2 cells
   ```

3. Convince yourself nothing else changed between the first two files:

   ```bash
   diff src/bar_comb.sv src/bar_star.sv
   ```

4. Synthesize the fifth, `always_latch`, version:

   ```bash
   yosys -p "read_verilog -sv src/bar_latch.sv; synth -top bar_latch; stat" > results/bar_latch.log 2>&1; echo "exit=$?"
   grep -E 'atch inferred|DLATCH' results/bar_latch.log
   ```

   You should see `exit=0`, three `Warning: Latch inferred for signal` lines for `\bar_latch.\bar`,
   and `2   $_DLATCH_N_`: the same two latches as `bar_star`. Yosys builds them and exits 0
   because this time you asked for them.

5. Fill in this table from your own terminal, in the tool's words rather than yours:

   | Header | Exit code | What Yosys built | The line the tool printed |
   |---|---|---|---|
   | `always_comb`, no `default:` | | | |
   | `always @*`, no `default:` | | | |
   | `always_comb unique case` | | | |
   | `always_comb` with `default:` | | | |
   | `always_latch` | | | |

You should see exactly one `exit 1`, for `bar_comb`; the other four exited 0.

## Part 3: Make the latch misbehave

What does the latched design output when you drive the branch nobody wrote?

1. The testbench walks `level` through `0, 1, 2, 3, 0`. Write down what you expect `bar_star` to
   show at `level = 3`. Then run the simulation:

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

Why does `bar_star` show `0111` at `level = 3`, and why is that worse than an `X`?

<details>
<summary>Answer</summary>

`0111` is the reading from the line above: the latch holds the last value it was given. A test
that never drives `level = 3` passes. A test that drives it after `2'b10` sees a plausible wrong
answer rather than an `X`.

</details>

## Part 4: The `unique` netlist

What did `unique` turn the missing branch into? The second half of `make sim` synthesizes
`bar_unique.sv` and simulates the netlist, not the source.

1. Read the second table `make sim` printed, and write down what `bar_unique` outputs at
   `level = 2'b11`.
2. Open `results/bar_unique_net.v` and find the line that drives `bar[3]`.

You should see:

```
level   bar (synthesized)
   00       0001
   01       0011
   10       0111
   11       0001
```

and, in the netlist, `assign { bar[3], bar[0] } = 2'h1;`. Yosys reported "No latch inferred".
Was that true, and what does a full battery look like?

<details>
<summary>Answer</summary>

It was true. That line ties `bar[3]` to constant 0, so the top LED is not driven by anything and
a full battery displays as empty. `unique` told Yosys the listed cases are the only ones that
can happen, so `2'b11` became a don't-care and the optimizer output whatever was cheapest.

</details>

## Part 5: Latch area on SKY130

What does `stat` report for latches that never get mapped to a library cell?

1. Map the `always @*` version all the way to SKY130 cells:

   ```bash
   yosys -p "read_verilog -sv src/bar_star.sv; synth -top bar_star; dfflibmap -liberty $LIB;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

2. The real latch cell is `sky130_fd_sc_hd__dlxtp_1`, 15.0144 µm² each. Work out what two of
   them would cost and compare it with the chip area `stat` reports.

You should see the two `$_DLATCH_N_` still in the mapped netlist,
`Area for cell type $_DLATCH_N_ is unknown!`, a chip area of `21.270400`, and `0.00%`
sequential. How does that compare with your step 2 number, and why?

<details>
<summary>Answer</summary>

Two real latches alone would be 30.03 µm², more than the whole reported area. The latches
stayed generic `$_DLATCH_N_`, which has no liberty entry, so `stat` counted them as zero.

</details>

## Part 6: The lint gate

Which of the five files does Verilator flag, and does `unique` fool it?

1. Lint the first file on its own:

   ```bash
   verilator --lint-only -Wall src/bar_comb.sv
   ```

   You should see `%Warning-CASEINCOMPLETE` with `(example pattern 0x3)`, then `%Warning-LATCH`,
   then `%Error: Exiting due to 2 warning(s)`.

2. Lint the four from `make latch`:

   ```bash
   make lint
   ```

   You should see `bar_comb`, `bar_star` and `bar_unique` each produce `%Warning-CASEINCOMPLETE`
   and `%Warning-LATCH` and exit 1, while `bar_fixed` prints a verilation report and
   `clean (exit 0)`. Unlike Yosys, Verilator is not fooled by `unique`.

3. Lint the `always_latch` version:

   ```bash
   verilator --lint-only -Wall src/bar_latch.sv
   ```

   You should see `%Warning-CASEINCOMPLETE` with `(example pattern 0x3)`, no `%Warning-LATCH`, and
   `%Error: Exiting due to 1 warning(s)`. Why did one warning go and the other stay?

   <details>
   <summary>Answer</summary>

   `LATCH` warns about a latch you didn't declare; its own message suggests `always_latch` for
   intentional latches, and here you declared one. The `case` is still incomplete, so
   `CASEINCOMPLETE` stays.

   </details>

You should see exactly one clean file, `bar_fixed`. From here on, `verilator --lint-only -Wall`
returning 0 is the precondition for running synthesis at all. It takes 4 ms.

## Part 7: Blocking and non-blocking

How many flip-flops do three `<=` statements build, compared with the same three statements
written with `=`?

1. `src/shift_nb.sv` uses `<=`; `src/shift_b.sv` and `src/shift_b_rev.sv` contain the same three
   blocking assignments in different orders. Write down how many flip-flops you expect each of
   the three to synthesize to. Then count them:

   ```bash
   make flops
   ```

   You should see:

   ```
   shift_nb             3   60.058   sky130_fd_sc_hd__dfxtp_1
   shift_b              1   20.019   sky130_fd_sc_hd__dfxtp_1
   shift_b_rev          3   60.058   sky130_fd_sc_hd__dfxtp_1
   ```

   followed by the shift-register simulation.

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
   `src/shift_b.sv`, with `shift_b` in place of `shift_nb` in the command, and watch the count
   move between 1 and 3. Put both files back the way they
   were when you finish (`git checkout src/shift_nb.sv src/shift_b.sv`).

5. Look at the mirror-image mistake, `<=` inside `always_comb`:

   ```bash
   make comb
   verilator --lint-only -Wall src/comb_nb.sv
   ```

You should see identical `assign` lines for `comb_b` and `comb_nb`, then a simulation where the
`y_nb` column is the `y_b` column one row late. Verilator reports `%Warning-COMBDLY` with
"This will be executed as a blocking assignment '='!".

## Part 8: The bug lint misses

Where does the carry go when two 8-bit numbers are added into an 8-bit `sum`?

1. `src/add8.sv` declares an eight-bit `sum`. Write down what you expect `200 + 100` to print.
   Then run the width experiment:

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
`%Warning-WIDTHTRUNC` for `add_trunc.sv`, which assigns a nine-bit sum, `{1'b0, a} + b`, to an
eight-bit output.

Why do Verilator, Yosys and Icarus all say nothing about `add8.sv`?

<details>
<summary>Answer</summary>

Because nothing in `add8.sv` is inconsistent. It declares an eight-bit `sum`, so the carry is
never computed: not truncated, never built. Widening `sum` to `[8:0]`, as `add9.sv` does, costs one
`sky130_fd_sc_hd__maj3_1`, 10.01 µm², and gets you `300`.

</details>

## Finishing

### You're done when

Your Part 2 table is filled in for all five headers, and each row of this table has the numbers
from your own terminal:

| Question | Your answer |
|---|---|
| Cells in the correct (`bar_fixed`) design vs the latched one | |
| What `bar_unique` outputs at `level = 2'b11` | |
| Flip-flops from three `<=` statements vs three `=` statements | |
| SKY130 area of the `<=` and `=` versions | |
| Area `add8` reports, and what `200 + 100` gives | |
| Extra area buying the ninth bit | |

To check your run against ours:

- `make` completes in about 2 seconds and never stops on an error
- `make latch` shows exactly one `exit 1`, and it is `bar_comb`
- `make lint` shows exactly one clean file, and it is `bar_fixed`
- `results/bar_star.log` contains `$_DLATCH_N_`; `results/bar_fixed.log` does not

### Questions

1. Why does `unique` make an error go away without making the design correct?

   <details>
   <summary>Answer</summary>

   `unique` is a promise that the cases you listed are the only ones that can happen. Yosys
   believes it, so it infers no latch and reports none (Part 2), and builds whatever is cheapest
   for `2'b11`: a dead top LED (Part 4). Verilator checks the cases itself and still flags the
   file (Part 6).

   </details>

### Submit

Nothing to submit.

Next on the [Course path](../index.md#course-path): read
[Reading the `stat` report](../guide/reading-stat.md) and
[Carry delay and static timing](../guide/the-carry-has-to-walk.md), then do
[Lab 04: Reading the receipt](../labs/lab-04-reading-the-receipt-overview.md).
