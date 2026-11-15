# Lab 03: Three ways to lose a latch

First you'll give Yosys some code that only makes sense to a simulator, and see the three
different ways it reacts. Then you'll take one `case` statement that is missing a branch, put it
under five different module headers, and record what each tool says about each version. To
finish, you'll count flip-flops to see what difference `=` and `<=` make, and track down a bug
that lint doesn't catch. In most parts we ask you to write down a prediction before you run
anything.

Time: about 2.5 hours.

Package: [`labs/lab-03-three-ways-to-lose-a-latch/`](https://github.com/uoftasic/dd103/tree/main/labs/lab-03-three-ways-to-lose-a-latch)

## Before you start

- [Lab 02](../labs/lab-02-rtl-becomes-gates-overview.md) is complete, so the `stat` output will look
  familiar, and `yosys -V` prints `Yosys 0.68`.
- Read [Synthesizable SystemVerilog](../guide/the-hardware-dialect.md),
  [Inferred latches](../guide/the-latch-you-didnt-ask-for.md) and
  [Blocking and non-blocking assignments](../guide/blocking-vs-nonblocking.md).

Start every part from the package directory, with the course loaded and `LIB` pointing at the
SKY130 cell library:

```bash
mod dd103
cd labs/lab-03-three-ways-to-lose-a-latch
LIB=/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

From Part 2 on, the design under test is a battery meter. It takes a 2-bit `level` and drives a
4-bit `bar`, and its `case` statement covers three values of `level`, with `2'b11` missing.
`src/bar_comb.sv`, `src/bar_star.sv`, `src/bar_unique.sv` and `src/bar_fixed.sv` differ only
in their header line, except that `bar_fixed` also has one `default:`.
`src/bar_latch.sv` puts the same `case` under `always_latch`.

`make` on its own runs Parts 2 to 4 and 6 to 8 in about 2 seconds, but you don't need to run it
first, because each part below names its own target.

## Part 1: Code that does not become hardware

What does Yosys do with code that only makes sense to a simulator?

1. Simulate the register and its testbench together:

   ```bash
   iverilog -g2012 -o results/sim.vvp examples/tb.sv examples/dut.sv && vvp results/sim.vvp
   ```

   You should see four `captured d =` lines and `final q = 9`. The testbench uses `#5`,
   `$display` and `$finish`, and none of them describes hardware.

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
   whole body is `assign q = d;`, which means your `#5` has been dropped. The third prints two
   `assign` lines of logic that you never wrote. How would you have caught the second and third
   without reading the netlist?

   <details>
   <summary>Answer</summary>

   You couldn't have caught them from the exit codes, since two of the three are zero. Reading
   the netlist catches both. Lint catches the third (Part 6 shows Verilator flagging `unique`),
   but not the second: `verilator --lint-only -Wall u_delay.sv`, run in `src/`, exits 0.

   </details>

4. Map the `$display` example to SKY130:

   ```bash
   yosys -p "read_verilog -sv examples/t_display.sv; synth -top t_display;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

   You should see 5 cells, one `$print` and four `sky130_fd_sc_hd__dfxtp_1`, along with
   `Area for cell type $print is unknown!` and a chip area of `80.076800`.

5. Compile the same file with Icarus:

   ```bash
   iverilog -g2012 -o results/t_display.vvp examples/t_display.sv
   ```

   You should see
   `examples/t_display.sv:21: warning: System task ($display) cannot be synthesized in an always_ff process.`

6. See what Yosys turns an `initial` block into:

   ```bash
   yosys -p "read_verilog -sv examples/t_initial.sv; synth -top t_initial" 2>&1 | grep -A2 'PROC_INIT pass'
   yosys -p "read_verilog -sv examples/t_initial.sv; synth -top t_initial;
             dfflibmap -liberty $LIB; abc -liberty $LIB; opt_clean;
             write_verilog /dev/stdout" 2>/dev/null | grep -B2 'output \[3:0\] count'
   ```

You should see `Set init value: \count = 4'0000` from the first command and
`(* init = 4'h0 *)` two lines above `output [3:0] count;` from the second. The `initial` block
has become an attribute on the port, and no reset logic was built for it.

What value does this counter hold when a SKY130 chip powers up?

<details>
<summary>Answer</summary>

It holds whatever value the transistors happen to settle to. On an FPGA the bitstream honours
the attribute, but on an ASIC the attribute is effectively a comment, because not one gate of
reset logic was built. If you want a reset, you have to build one out of gates, in an
`always_ff`.

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

3. Convince yourself that the header line is the only difference between the first two files:

   ```bash
   diff src/bar_comb.sv src/bar_star.sv
   ```

4. Synthesize the fifth, `always_latch`, version:

   ```bash
   yosys -p "read_verilog -sv src/bar_latch.sv; synth -top bar_latch; stat" > results/bar_latch.log 2>&1; echo "exit=$?"
   grep -E 'atch inferred|DLATCH' results/bar_latch.log
   ```

   You should see `exit=0`, three `Warning: Latch inferred for signal` lines for `\bar_latch.\bar`,
   and `2   $_DLATCH_N_`, which are the same two latches as in `bar_star`. This time Yosys
   builds them and exits 0, because by writing `always_latch` you asked for them.

5. Fill in this table from your own terminal, copying the tool's words rather than putting them
   in your own:

   | Header | Exit code | What Yosys built | The line the tool printed |
   |---|---|---|---|
   | `always_comb`, no `default:` | | | |
   | `always @*`, no `default:` | | | |
   | `always_comb unique case` | | | |
   | `always_comb` with `default:` | | | |
   | `always_latch` | | | |

Your table should have exactly one `exit 1`, for `bar_comb`, and the other four should have
exited 0.

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

`0111` is the reading from the line above, because the latch holds the last value it was given.
That makes the bug easy to miss. A test that never drives `level = 3` passes, and a test that
drives it after `2'b10` sees a plausible wrong answer, where an `X` would at least have stood
out.

</details>

## Part 4: The `unique` netlist

What did `unique` turn the missing branch into? To find out, the second half of `make sim`
synthesizes `bar_unique.sv` and simulates the resulting netlist rather than the source.

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

and, in the netlist, `assign { bar[3], bar[0] } = 2'h1;`. In Part 2, Yosys reported
"No latch inferred" for this file. Was that true, and what does a full battery look like?

<details>
<summary>Answer</summary>

It was true: there is no latch. That line ties `bar[3]` to constant 0, so nothing ever lights
the top LED, and a full battery displays as empty. `unique` told Yosys that the listed cases are
the only ones that can happen, so `2'b11` became a don't-care, and the optimizer produced
whatever was cheapest.

</details>

## Part 5: Latch area on SKY130

What does `stat` report for latches that never get mapped to a library cell?

1. Map the `always @*` version all the way to SKY130 cells:

   ```bash
   yosys -p "read_verilog -sv src/bar_star.sv; synth -top bar_star; dfflibmap -liberty $LIB;
             abc -liberty $LIB; opt_clean; stat -liberty $LIB"
   ```

2. The real SKY130 latch cell is `sky130_fd_sc_hd__dlxtp_1`, at 15.0144 µm² each. Work out
   what two of them would cost, and compare that with the chip area `stat` reports.

You should see that the two `$_DLATCH_N_` are still in the mapped netlist, along with
`Area for cell type $_DLATCH_N_ is unknown!`, a chip area of `21.270400`, and `0.00%`
sequential. How does that compare with your step 2 number, and why?

<details>
<summary>Answer</summary>

Two real latches alone would take 30.03 µm², which is more than the whole area `stat` reported.
The latches stayed as generic `$_DLATCH_N_` cells, which have no entry in the liberty file, so
`stat` counted their area as zero.

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
   `clean (exit 0)`. Verilator checks the cases itself, so unlike Yosys it isn't fooled by
   `unique`.

3. Lint the `always_latch` version:

   ```bash
   verilator --lint-only -Wall src/bar_latch.sv
   ```

   You should see `%Warning-CASEINCOMPLETE` with `(example pattern 0x3)`, no `%Warning-LATCH`, and
   `%Error: Exiting due to 1 warning(s)`. Why did one warning go and the other stay?

   <details>
   <summary>Answer</summary>

   `LATCH` warns about a latch that you didn't declare. Its own message suggests `always_latch`
   for latches you mean to have, and here you've declared one, so that warning goes. The `case`
   is still incomplete, though, so `CASEINCOMPLETE` stays.

   </details>

Of the five files, you should see exactly one clean file, `bar_fixed`. From here on, don't run
synthesis at all until `verilator --lint-only -Wall` returns 0. The check takes 4 ms.

## Part 7: Blocking and non-blocking

How many flip-flops do three `<=` statements build, compared with the same three statements
written with `=`?

1. `src/shift_nb.sv` uses `<=`, while `src/shift_b.sv` and `src/shift_b_rev.sv` both contain
   the same three blocking assignments, in different orders. Write down how many flip-flops you
   expect each of the three to synthesize to. Then count them:

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
   `src/shift_b.sv`, with `shift_b` in place of `shift_nb` in the command, and you'll see the
   count move between 1 and 3 as the order changes. When you've finished, put both files back
   the way they were (`git checkout src/shift_nb.sv src/shift_b.sv`).

5. Look at the mirror-image mistake, `<=` inside `always_comb`:

   ```bash
   make comb
   verilator --lint-only -Wall src/comb_nb.sv
   ```

You should see identical `assign` lines for `comb_b` and `comb_nb`, then a simulation in which
the `y_nb` column is the `y_b` column one row late. Verilator reports `%Warning-COMBDLY` with
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

then the `add9` run, which gives `205.196800` and `200 + 100 = 300`, and finally a
`%Warning-WIDTHTRUNC` for `add_trunc.sv`, which assigns a nine-bit sum, `{1'b0, a} + b`, to an
eight-bit output.

Why do Verilator, Yosys and Icarus all say nothing about `add8.sv`?

<details>
<summary>Answer</summary>

Because nothing in `add8.sv` is inconsistent. It declares an eight-bit `sum`, so the carry is
never computed at all. Unlike `add_trunc.sv`, there's no ninth bit being truncated for a tool to
warn about, because the hardware for it was never built. Widening `sum` to `[8:0]`, as `add9.sv`
does, costs one `sky130_fd_sc_hd__maj3_1` (10.01 µm²) and gets you `300`.

</details>

## Finishing

### You're done when

Your Part 2 table is filled in for all five headers, and you've filled in each row of this table
with the numbers from your own terminal:

| Question | Your answer |
|---|---|
| Cells in the correct (`bar_fixed`) design vs the latched one | |
| What `bar_unique` outputs at `level = 2'b11` | |
| Flip-flops from three `<=` statements vs three `=` statements | |
| SKY130 area of the `<=` and `=` versions | |
| Area `add8` reports, and what `200 + 100` gives | |
| Extra area that the ninth bit costs | |

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
   takes the promise at face value, so it infers no latch and reports none (Part 2), and for
   `2'b11` it builds whatever is cheapest, which here is a dead top LED (Part 4). Verilator
   checks the cases itself, so it still flags the file (Part 6).

   </details>

### Submit

Nothing to submit.

Next on the [Course path](../index.md#course-path): read
[Reading the `stat` report](../guide/reading-stat.md) and
[Carry delay and static timing](../guide/the-carry-has-to-walk.md), then do
[Lab 04: Reading the receipt](../labs/lab-04-reading-the-receipt-overview.md).
